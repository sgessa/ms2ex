defmodule Ms2ex.Managers.Character.Skill do
  alias Ms2ex.Context
  alias Ms2ex.Types

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character
  alias Ms2ex.Packets

  def cast_skill(%{stats: stats} = character, skill_cast) do
    spirit_cost = Types.SkillCast.spirit_cost(skill_cast)
    stamina_cost = Types.SkillCast.stamina_cost(skill_cast)

    # Ensure player has enough spirit & stamina
    if stats.spirit_cur >= spirit_cost && stats.stamina_cur >= stamina_cost do
      cast_skill(character, skill_cast, spirit_cost, stamina_cost)
    else
      character
    end
  end

  def cast_skill(character, skill_cast, spirit_cost, stamina_cost) do
    Managers.SkillCast.start_link(skill_cast)

    character =
      for effect <- Types.SkillCast.skill_level(skill_cast).skills,
          skill <- effect.skills,
          reduce: character do
        character ->
          case Context.Field.call(character, {:add_buff, skill_cast, skill, character}) do
            {:ok, buff} ->
              apply_status(character, buff)

            _ ->
              character
          end
      end

    # battle stance only arms for skills flagged to put the caster in combat;
    # also schedules the stance drop. battle-start packets are emitted by the
    # cast handler in live-server order
    if Types.SkillCast.in_battle?(skill_cast) do
      Context.Field.enter_battle_stance(character)
    end

    # costs are carried to clients inside the battle-start stat refresh
    # emitted by the cast handler; no per-stat broadcasts here
    character
    |> Character.Stats.decrease(:spirit, spirit_cost, broadcast: false)
    |> Character.Stats.decrease(:stamina, stamina_cost, broadcast: false)
  end

  # --------------------------------
  # State skills
  # --------------------------------

  # a state skill (toggle/stance) is cast repeatedly for as long as it is
  # active: the cast is gated on having enough resources and every drain tick
  # re-validates and consumes again. Cancelled when resources run out, the
  # actor dies, the actor leaves the skill's movement state, or a replacement
  # state skill arrives.
  def cast_state_skill(%{stats: stats} = character, skill_cast, _state) do
    spirit_cost = Types.SkillCast.spirit_cost(skill_cast)
    stamina_cost = Types.SkillCast.stamina_cost(skill_cast)

    if stats.spirit_cur >= spirit_cost && stats.stamina_cur >= stamina_cost do
      Managers.SkillCast.start_link(skill_cast)

      character =
        character
        |> Character.Stats.decrease(:spirit, spirit_cost, broadcast: false)
        |> Character.Stats.decrease(:stamina, stamina_cost, broadcast: false)

      {:ok, character}
    else
      :error
    end
  end

  # arms the drain loop for a freshly accepted state-skill cast; any
  # previously active state skill is cancelled first so an actor holds at
  # most one at a time. Runs inside the character manager (the loop's owner).
  def activate_state_skill(character, skill_cast, state) do
    character = cancel_state_skill(character)

    Process.send_after(
      self(),
      {:state_skill_tick, skill_cast.id},
      Types.SkillCast.drain_interval(skill_cast)
    )

    Map.put(character, :state_skill, %{skill_cast: skill_cast, state: state})
  end

  # a drain tick for a cast that is no longer the active one is stale and
  # just dies out
  def state_skill_tick(%{state_skill: %{skill_cast: %{id: active_id}}} = character, cast_id)
      when active_id == cast_id do
    drain_state_skill(character, character.state_skill)
  end

  def state_skill_tick(character, _stale_cast_id), do: character

  defp drain_state_skill(%{dead?: true} = character, _active),
    do: cancel_state_skill(character)

  defp drain_state_skill(character, active) do
    skill_cast = active.skill_cast
    spirit_cost = Types.SkillCast.spirit_cost(skill_cast)
    stamina_cost = Types.SkillCast.stamina_cost(skill_cast)
    stats = character.stats

    cond do
      # the actor left the skill's movement state (e.g. released the swim
      # boost): the state-synced actor state no longer matches
      left_skill_state?(character, skill_cast) ->
        cancel_state_skill(character)

      stats.spirit_cur < spirit_cost or stats.stamina_cur < stamina_cost ->
        # resources exhausted: drop the stance so the drain cannot go negative
        cancel_state_skill(character)

      true ->
        character =
          character
          |> Character.Stats.decrease(:spirit, spirit_cost, [])
          |> Character.Stats.decrease(:stamina, stamina_cost, [])

        Process.send_after(
          self(),
          {:state_skill_tick, skill_cast.id},
          Types.SkillCast.drain_interval(skill_cast)
        )

        character
    end
  end

  # state skills carry the ActorState they put the actor in; user syncs keep
  # the actor's current state and a mismatch means the movement ended
  defp left_skill_state?(character, skill_cast) do
    expected = skill_cast.meta[:state][:state] || 0
    expected != 0 and Map.get(character, :animation, 0) != expected
  end

  # server-side cancel: stops the drain loop, drops the cast, and tells the
  # field the actor left the skill state (state 0). The client keeps its own
  # stance UI until it observes the resource drain.
  def cancel_state_skill(%{state_skill: nil} = character), do: character

  def cancel_state_skill(%{state_skill: active} = character) when active != nil do
    skill_cast = active.skill_cast
    character = Map.put(character, :state_skill, nil)

    Managers.SkillCast.stop(skill_cast.id)

    Context.Field.broadcast(
      character,
      Packets.StateSkill.bytes(character, skill_cast.skill_id, skill_cast.id, 0)
    )

    character
  end

  # character state predating the state-skill tracking: nothing to cancel
  def cancel_state_skill(character), do: character

  defp apply_status(character, buff) do
    modifiers = Types.Buff.stat_modifiers(buff, character)

    if map_size(modifiers) > 0 do
      Managers.Buff.update(buff, %{stat_modifiers: modifiers})

      Enum.reduce(modifiers, character, fn {stat, amount}, character ->
        Character.Stats.modify_max(character, stat, amount)
      end)
    else
      character
    end
  end
end
