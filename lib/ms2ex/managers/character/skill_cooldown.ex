defmodule Ms2ex.Managers.Character.SkillCooldown do
  def save(character, cooldown) do
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    existing = Map.get(cooldowns, cooldown.skill_id)

    cooldown =
      if is_nil(existing) or cooldown.start_tick > existing.end_tick do
        %{
          skill_id: cooldown.skill_id,
          level: cooldown.level,
          group_id: cooldown.group_id,
          end_tick: cooldown.end_tick,
          recharge_max_count: cooldown.recharge_max_count,
          charges: 0
        }
      else
        existing
      end

    cooldown =
      if cooldown.recharge_max_count > 0 do
        %{cooldown | charges: min(cooldown.charges + 1, cooldown.recharge_max_count)}
      else
        cooldown
      end

    Map.put(character, :skill_cooldowns, Map.put(cooldowns, cooldown.skill_id, cooldown))
  end

  def set(character, skill_id, level, end_tick) do
    cooldown = %{
      skill_id: skill_id,
      level: level,
      group_id: 0,
      end_tick: end_tick,
      recharge_max_count: 0,
      charges: 0
    }

    character =
      Map.put(
        character,
        :skill_cooldowns,
        Map.put(Map.get(character, :skill_cooldowns, %{}), skill_id, cooldown)
      )

    {character, cooldown}
  end

  def get_active(character, now) do
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    active = Map.values(cooldowns) |> Enum.filter(&(&1.end_tick > now))

    character =
      Map.put(
        character,
        :skill_cooldowns,
        Map.filter(cooldowns, fn {_id, cooldown} -> cooldown.end_tick > now end)
      )

    {character, active}
  end
end
