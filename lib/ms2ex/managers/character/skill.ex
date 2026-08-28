defmodule Ms2ex.Managers.Character.Skill do
  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Types

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character

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
              character = apply_recovery(character, buff)
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

  defp apply_recovery(character, buff) do
    crit? = Context.Damage.roll_crit(character)
    {hp, sp, ep} = Types.Buff.recovery_amounts(buff, character, crit?)

    character =
      character
      |> maybe_increase(:health, hp)
      |> maybe_increase(:spirit, sp)
      |> maybe_increase(:stamina, ep)

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

    character
  end

  defp maybe_increase(character, _stat, 0), do: character

  defp maybe_increase(character, stat, amount),
    do: Character.Stats.increase(character, stat, amount)

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
