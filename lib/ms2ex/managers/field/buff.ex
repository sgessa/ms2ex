defmodule Ms2ex.Managers.Field.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  def add_buff(skill_cast, skill, character, state) do
    {object_id, state} = Managers.Field.next_local_id(state)
    buff = Types.Buff.new(object_id, skill_cast, skill, character, character)
    Managers.Buff.start(buff)

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    reset_skill_cooldowns(buff, character)
    schedule(buff)

    {buff, state}
  end

  def add_effect_buff(effect_id, effect_level, character, state) do
    {object_id, state} = Managers.Field.next_local_id(state)
    skill = %{id: effect_id, level: effect_level}

    skill_cast = %Types.SkillCast{
      id: 0,
      skill_id: effect_id,
      skill_level: effect_level,
      caster: character
    }

    buff = Types.Buff.new(object_id, skill_cast, skill, character, character)
    Managers.Buff.start(buff)

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    apply_status(buff, character)
    schedule(buff)

    {buff, state}
  end

  # buff applied to a field npc (e.g. an on-hit burn from a skill)
  def add_mob_buff(caster, effect_id, effect_level, mob, state) do
    {object_id, state} = Managers.Field.next_local_id(state)
    skill = %{id: effect_id, level: effect_level}

    skill_cast = %Types.SkillCast{
      id: 0,
      skill_id: effect_id,
      skill_level: effect_level,
      caster: caster
    }

    buff = Types.Buff.new(object_id, skill_cast, skill, caster, mob)
    Managers.Buff.start(buff)

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))
    schedule(buff)

    {buff, state}
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

  defp apply_status(buff, character) do
    modifiers = Types.Buff.stat_modifiers(buff, character)

    if map_size(modifiers) > 0 do
      Managers.Buff.update(buff, %{stat_modifiers: modifiers})
      Managers.Character.cast(character, {:modify_buff_status, modifiers})
    end

    :ok
  end

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
        if hp > 0 and npc_alive?(state, buff.owner.object_id) do
          {_reply, state} =
            Managers.Field.damage_npc(state, buff.caster, hp, buff.owner.object_id)

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
        end

        state
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
    Process.send_after(self(), {:remove_buff, buff.object_id}, ms_left)
  end

  defp reset_skill_cooldowns(buff, character) do
    case get_in(buff.effect, [:update, :reset_cooldown]) do
      skill_ids when is_list(skill_ids) and skill_ids != [] ->
        Enum.each(skill_ids, fn skill_id ->
          {:ok, cooldown} = Managers.Character.set_skill_cooldown(character, skill_id, 1, 0)
          Net.SenderSession.push(character, Packets.SkillCooldown.bytes([cooldown]))
        end)

      _ ->
        :ok
    end
  end
end
