defmodule Ms2ex.Managers.Field.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets

  def add_buff(skill_cast, skill, character, state) do
    {object_id, state} = Managers.Field.next_local_id(state)
    buff = Types.Buff.new(object_id, skill_cast, skill, character, character)
    Managers.Buff.start(buff)

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    reset_skill_cooldowns(buff, character)

    schedule_removal(buff)

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

    apply_recovery(buff, character)
    apply_status(buff, character)
    schedule_removal(buff)

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

  defp apply_recovery(buff, character) do
    crit? = Context.Damage.roll_crit(character)
    {hp, sp, ep} = Types.Buff.recovery_amounts(buff, character, crit?)

    stats =
      [health: hp, spirit: sp, stamina: ep] |> Enum.filter(fn {_stat, amount} -> amount > 0 end)

    if stats != [] do
      Managers.Character.cast(character, {:increase_stats, stats})
    end

    if hp > 0 or sp > 0 or ep > 0 do
      Context.Field.broadcast(
        character,
        Packets.SkillDamage.heal(%{
          caster_id: character.object_id,
          target_id: character.object_id,
          owner_id: buff.object_id,
          hp_amount: hp,
          sp_amount: sp,
          ep_amount: ep
        })
      )
    end
  end

  defp schedule_removal(buff) do
    Process.send_after(self(), {:remove_buff, buff.object_id}, buff.end_tick - buff.start_tick)
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
