defmodule Ms2ex.Managers.Field.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  def add_buff(skill_cast, skill, character, state) do
    if effect_available?(skill.id, skill.level) do
      {object_id, state} = Managers.Field.next_local_id(state)
      buff = Types.Buff.new(object_id, skill_cast, skill, character, character)
      {buff, state} = apply_buff(buff, state, false)
      reset_skill_cooldowns(buff, character)
      {buff, state}
    else
      {nil, state}
    end
  end

  def add_effect_buff(effect_id, effect_level, character, state, overlap_count \\ 0, opts \\ []) do
    if effect_available?(effect_id, effect_level) do
      {object_id, state} = Managers.Field.next_local_id(state)
      skill = %{id: effect_id, level: effect_level, overlap_count: overlap_count}

      skill_cast = %Types.SkillCast{
        id: 0,
        skill_id: effect_id,
        skill_level: effect_level,
        caster: character
      }

      buff = Types.Buff.new(object_id, skill_cast, skill, character, character, opts)
      apply_buff(buff, state, true)
    else
      {nil, state}
    end
  end

  # buff applied to a field npc (e.g. an on-hit burn from a skill)
  def add_mob_buff(caster, effect_id, effect_level, mob, state, overlap_count \\ 0) do
    if effect_available?(effect_id, effect_level) do
      {object_id, state} = Managers.Field.next_local_id(state)
      skill = %{id: effect_id, level: effect_level, overlap_count: overlap_count}

      skill_cast = %Types.SkillCast{
        id: 0,
        skill_id: effect_id,
        skill_level: effect_level,
        caster: caster
      }

      buff = Types.Buff.new(object_id, skill_cast, skill, caster, mob)
      apply_buff(buff, state, false)
    else
      {nil, state}
    end
  end

  # removes a buff and unregisters it from the field's active set; a non-forced
  # removal reschedules when the buff was refreshed since its timer was set
  def remove_buff(buff_id, state, force \\ false) do
    case Managers.Buff.fetch(buff_id) do
      nil ->
        state

      buff ->
        if not force and Ms2ex.sync_ticks() < buff.end_tick do
          schedule_removal(buff)
          state
        else
          unregister_removed_buff(buff_id, buff, state)
        end
    end
  end

  defp unregister_removed_buff(buff_id, buff, state) do
    remove_buff_status(buff)
    Context.Field.broadcast(state.topic, Packets.Buff.send(:remove, buff))
    Managers.Buff.stop(buff_id)

    case Map.get(state.buffs, buff_key(buff)) do
      ^buff_id -> %{state | buffs: Map.delete(state.buffs, buff_key(buff))}
      _ -> state
    end
  end

  defp apply_buff(buff, state, apply_status?) do
    case Map.get(state.buffs, buff_key(buff)) do
      nil -> create_buff(buff, state, apply_status?)
      buff_id -> stack_buff(buff, buff_id, state)
    end
  end

  defp create_buff(buff, state, apply_status?) do
    state = cancel_effects(buff, state)
    Managers.Buff.start(buff)
    state = put_in(state, [:buffs, buff_key(buff)], buff.object_id)

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    if apply_status?, do: apply_status(buff)
    state = modify_overlap(buff, state)
    schedule(buff)

    {buff, state}
  end

  defp stack_buff(buff, buff_id, state) do
    existing = Managers.Buff.fetch(buff_id)
    max = Types.Buff.max_stacks(buff)
    overlap = Map.get(buff.skill, :overlap_count, 0) || 0
    previous = existing.stacks
    stacks = min(max(previous + overlap, 0), max)

    # re-applying refreshes the effect's window and adds the condition's
    # overlap_count stacks
    new_end = Ms2ex.sync_ticks() + get_in(buff.effect, [:property, :duration_tick])
    end_tick = if new_end > existing.end_tick, do: new_end, else: existing.end_tick

    # cancel the pending removal and reschedule for the extended window
    if existing.removal_timer, do: Process.cancel_timer(existing.removal_timer)
    existing = Managers.Buff.update(existing, %{stacks: stacks, end_tick: end_tick})
    schedule_removal(existing)
    Context.Field.broadcast(state.topic, Packets.Buff.send(:update, existing))

    state =
      if stacks >= max and previous < max and overlap > 0 do
        fire_skills(existing, state)
      else
        state
      end

    {existing, state}
  end

  # re-applying the effect cancels buffs listed in its update.cancel metadata
  # (e.g. frozen cancels the chill it replaces)
  defp cancel_effects(buff, state) do
    case Types.Buff.cancel(buff) do
      nil ->
        state

      %{ids: ids, check_same_caster: same_caster?} ->
        Enum.reduce(ids, state, fn cancel_id, state ->
          state
          |> cancel_candidates(buff, cancel_id, same_caster?)
          |> remove_cancelled(state)
        end)
    end
  end

  defp cancel_candidates(state, buff, cancel_id, same_caster?) do
    Enum.filter(state.buffs, fn {{owner_id, effect_id, caster_id}, _buff_id} ->
      owner_id == buff.owner.object_id and
        effect_id == cancel_id and
        (not same_caster? or caster_id == buff.caster.object_id)
    end)
  end

  defp remove_cancelled(candidates, state) do
    Enum.reduce(candidates, state, fn {_key, buff_id}, state ->
      remove_buff(buff_id, state, true)
    end)
  end

  # once a buff reaches its stack cap it fires its skills (chill -> frozen)
  defp fire_skills(buff, state) do
    Enum.reduce(Types.Buff.skills(buff), state, fn effect, state ->
      apply_effect_to_owner(buff, effect, state)
    end)
  end

  # a buff's modify_overlap bumps another effect's stacks on the owner (e.g.
  # the splash marker 10300182 stacks the chill 10300051); at the cap the
  # target fires its skills, at zero it is removed
  defp modify_overlap(buff, state) do
    case get_in(buff.effect, [:modify_overlap]) do
      list when is_list(list) and list != [] ->
        Enum.reduce(list, state, fn %{id: target_id, offset: offset}, state ->
          apply_overlap(state, buff, target_id, offset)
        end)

      _ ->
        state
    end
  end

  defp apply_overlap(state, buff, target_id, offset) do
    overlap_targets(state, buff, target_id)
    |> Enum.reduce(state, fn {_key, buff_id}, state ->
      stack_target(buff_id, offset, state)
    end)
  end

  defp overlap_targets(state, buff, target_id) do
    Enum.filter(state.buffs, fn {{owner_id, effect_id, _caster_id}, _buff_id} ->
      owner_id == buff.owner.object_id and effect_id == target_id
    end)
  end

  defp stack_target(buff_id, offset, state) do
    case Managers.Buff.fetch(buff_id) do
      nil ->
        state

      target ->
        max = Types.Buff.max_stacks(target)
        previous = target.stacks
        stacks = min(max(previous + offset, 0), max)
        target = Managers.Buff.update(target, %{stacks: stacks})
        Context.Field.broadcast(state.topic, Packets.Buff.send(:update, target))

        cond do
          stacks <= 0 ->
            remove_buff(buff_id, state)

          stacks >= max and previous < max and offset > 0 ->
            fire_skills(target, state)

          true ->
            state
        end
    end
  end

  defp buff_key(buff) do
    {buff.owner.object_id, buff.skill.id, buff.caster.object_id}
  end

  defp effect_available?(effect_id, effect_level) do
    not is_nil(Storage.Skills.get_effect(effect_id, effect_level))
  end

  # per-interval proc: apply recovery/dot while procs remain, otherwise expire
  def tick(buff_id, state) do
    case Managers.Buff.fetch(buff_id) do
      nil ->
        state

      buff ->
        elapsed = Ms2ex.sync_ticks() - buff.start_tick
        interval = Types.Buff.interval_tick(buff)

        cond do
          buff.can_proc and elapsed >= buff.next_proc_tick ->
            {buff, state} = proc(buff, state)
            next_tick(buff, interval, state)

          buff.can_proc ->
            Process.send_after(
              self(),
              {:buff_tick, buff.object_id},
              max(buff.next_proc_tick - elapsed, 1)
            )

            state

          true ->
            schedule_removal(buff)
            state
        end
    end
  end

  defp next_tick(buff, interval, state) do
    if buff.next_proc_tick + interval > buff.end_tick - buff.start_tick do
      buff = Managers.Buff.update(buff, %{can_proc: false})
      schedule_removal(buff)
      state
    else
      buff = Managers.Buff.update(buff, %{next_proc_tick: buff.next_proc_tick + interval})
      Process.send_after(self(), {:buff_tick, buff.object_id}, interval)
      state
    end
  end

  defp proc(buff, state) do
    buff = Managers.Buff.update(buff, %{proc_count: buff.proc_count + 1})

    state = apply_recovery(buff, state)
    state = apply_dot_damage(buff, state)
    state = apply_dot_buff(buff, state)
    state = apply_tick_skills(buff, state)

    {buff, state}
  end

  defp apply_status(%Types.Buff{owner: %Schema.Character{}} = buff) do
    character = buff.owner
    modifiers = Types.Buff.stat_modifiers(buff, character)

    if map_size(modifiers) > 0 do
      Managers.Buff.update(buff, %{stat_modifiers: modifiers})
      Managers.Character.cast(character, {:modify_buff_status, modifiers})
    end

    :ok
  end

  defp apply_status(_buff), do: :ok

  defp remove_buff_status(%Types.Buff{owner: %Schema.Character{}} = buff) do
    modifiers = buff.stat_modifiers

    if map_size(modifiers) > 0 do
      Managers.Character.cast(buff.owner, {:remove_buff_status, modifiers})
    end

    :ok
  end

  defp remove_buff_status(_buff), do: :ok

  defp apply_recovery(%Types.Buff{owner: %Types.FieldNpc{}}, state), do: state

  defp apply_recovery(buff, state) do
    owner = buff.owner
    crit? = Context.Damage.roll_crit(owner)
    {hp, sp, ep} = Types.Buff.recovery_amounts(buff, owner, crit?)

    stats =
      [health: hp, spirit: sp, stamina: ep] |> Enum.filter(fn {_stat, amount} -> amount > 0 end)

    if stats != [] do
      Managers.Character.cast(owner, {:increase_stats, stats})
    end

    if hp > 0 or sp > 0 or ep > 0 do
      Context.Field.broadcast(
        owner,
        Packets.SkillDamage.heal(%{
          caster_id: owner.object_id,
          target_id: owner.object_id,
          owner_id: buff.object_id,
          hp_amount: hp,
          sp_amount: sp,
          ep_amount: ep
        })
      )
    end

    state
  end

  # dot damage on a field npc is applied through the field's own damage path
  defp apply_dot_damage(%Types.Buff{owner: %Types.FieldNpc{}} = buff, state) do
    case Types.Buff.dot_amounts(buff) do
      {0, 0, 0} ->
        state

      {hp, _sp, _ep} ->
        apply_npc_dot_damage(buff, state, hp)
    end
  end

  defp apply_dot_damage(buff, state) do
    case Types.Buff.dot_amounts(buff) do
      {0, 0, 0} ->
        state

      {hp, sp, ep} ->
        owner = buff.owner

        stats =
          [health: hp, spirit: sp, stamina: ep]
          |> Enum.filter(fn {_stat, amount} -> amount > 0 end)

        if stats != [] do
          Managers.Character.cast(owner, {:decrease_stats, stats})
        end

        if hp > 0 do
          Context.Field.broadcast(
            owner,
            Packets.SkillDamage.dot_damage(%{
              caster_id: buff.caster.object_id,
              target_id: owner.object_id,
              proc_count: buff.proc_count,
              type: 0,
              hp_amount: -hp
            })
          )
        end

        recover = trunc(get_in(buff.effect, [:dot, :damage, :recover_hp_by_damage]) * hp)

        if recover > 0 do
          Managers.Character.cast(buff.caster, {:increase_stats, [health: recover]})
        end

        state
    end
  end

  defp apply_npc_dot_damage(_buff, state, hp) when hp <= 0, do: state

  defp apply_npc_dot_damage(buff, state, hp) do
    if npc_alive?(state, buff.owner.object_id) do
      case Managers.Field.Npc.damage(state, buff.caster, hp, buff.owner.object_id) do
        {:ok, _mob, state} ->
          Context.Field.broadcast(
            state.topic,
            Packets.SkillDamage.dot_damage(%{
              caster_id: buff.caster.object_id,
              target_id: buff.owner.object_id,
              proc_count: buff.proc_count,
              type: 0,
              hp_amount: -hp
            })
          )

          state

        {:error, state} ->
          state
      end
    else
      state
    end
  end

  defp apply_dot_buff(buff, state) do
    case get_in(buff.effect, [:dot, :buff]) do
      nil ->
        state

      %{id: id, level: level} = dot ->
        target = if dot.target == 0, do: buff.caster, else: buff.owner

        case target do
          %Types.FieldNpc{} = mob ->
            {_buff, state} = add_mob_buff(buff.caster, id, level, mob, state)
            state

          %Schema.Character{} ->
            {_buff, state} = add_effect_buff(id, level, target, state)
            state
        end
    end
  end

  # effects the buff applies to its owner on every proc (tick skills)
  defp apply_tick_skills(buff, state) do
    Enum.reduce(Types.Buff.tick_skills(buff), state, fn effect, state ->
      apply_effect_to_owner(buff, effect, state)
    end)
  end

  defp apply_effect_to_owner(buff, %{id: id, level: level}, state) do
    case buff.owner do
      %Types.FieldNpc{} = mob ->
        {_buff, state} = add_mob_buff(buff.caster, id, level, mob, state)
        state

      %Schema.Character{} ->
        {_buff, state} = add_effect_buff(id, level, buff.owner, state)
        state
    end
  end

  defp npc_alive?(state, object_id) do
    case Map.get(state.npcs, object_id) do
      %{dead?: false} -> true
      _ -> false
    end
  end

  defp schedule(buff) do
    if Types.Buff.ticks?(buff) do
      Process.send_after(self(), {:buff_tick, buff.object_id}, buff.next_proc_tick)
    else
      schedule_removal(buff)
    end
  end

  defp schedule_removal(buff) do
    ms_left = max(buff.end_tick - Ms2ex.sync_ticks(), 1)
    ref = Process.send_after(self(), {:remove_buff, buff.object_id}, ms_left)
    Managers.Buff.update(buff, %{removal_timer: ref})
    ref
  end

  defp reset_skill_cooldowns(buff, character) do
    case get_in(buff.effect, [:update, :reset_cooldown]) do
      skill_ids when is_list(skill_ids) and skill_ids != [] ->
        Enum.each(skill_ids, fn skill_id ->
          {:ok, cooldown} =
            Managers.Character.call(character, {:set_skill_cooldown, skill_id, 1, 0})

          Net.SenderSession.push(character, Packets.SkillCooldown.bytes([cooldown]))
        end)

      _ ->
        :ok
    end
  end

  def remove_owner_buffs(owner_object_id, state) do
    state.buffs
    |> Enum.filter(fn {{owner_id, _effect, _caster}, _buff_id} ->
      owner_id == owner_object_id
    end)
    |> Enum.reduce(state, fn {{_owner, _effect, _caster}, buff_id}, state ->
      remove_buff(buff_id, state)
    end)
  end

  @doc """
  Whether an actor currently has the given effect active, regardless of who
  cast it.
  """
  def owner_has_buff?(owner_object_id, effect_id, state) do
    Enum.any?(state.buffs, fn {{owner_id, effect, _caster_id}, _buff_id} ->
      owner_id == owner_object_id and effect == effect_id
    end)
  end

  @doc """
  Stores the character's still-running buffs so they can be restored on the
  next field they enter, including after a relog.
  """
  def save_owner_buffs(character, state) do
    buffs =
      state.buffs
      |> Enum.filter(fn {{owner_id, _effect, _caster}, _buff_id} ->
        owner_id == character.object_id
      end)
      |> Enum.flat_map(fn {_key, buff_id} ->
        case Managers.Buff.fetch(buff_id) do
          nil -> []
          buff -> [buff]
        end
      end)

    Context.Buffs.save(character.id, buffs)
    state
  end

  @doc """
  Re-applies the character's stored buffs for the remainder of their duration.
  """
  def restore_buffs(character, state) do
    character.id
    |> Context.Buffs.load()
    |> Enum.reduce(state, fn stored, state ->
      {_buff, state} =
        add_effect_buff(stored.effect_id, stored.effect_level, character, state, 0,
          duration_tick: stored.remaining_ms
        )

      state
    end)
  end
end
