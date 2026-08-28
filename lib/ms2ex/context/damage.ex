defmodule Ms2ex.Context.Damage do
  @moduledoc """
  Context module for damage calculation operations.

  This module provides functions for calculating damage dealt between entities,
  including critical hit calculation, skill damage, and fall damage.
  """

  alias Ms2ex.Schema
  alias Ms2ex.Types.FieldNpc
  alias Ms2ex.Types.SkillCast

  @doc """
  Determines if a character's attack results in a critical hit based on their critical rate.

  The critical rate is clamped between 0 and 400, and the roll is against 1000.

  ## Examples

      iex> roll_crit(character)
      true

      iex> roll_crit(character)
      false
  """
  @spec roll_crit(Schema.Character.t()) :: boolean()
  def roll_crit(%Schema.Character{} = character) do
    crit_rate = character.stats.critical_rate_cur + 50
    crit_rate = crit_rate |> max(0) |> min(400)
    Enum.random(1..1000) <= crit_rate
  end

  @doc """
  Calculates the damage dealt by a skill cast on a field NPC.

  Takes into account attack damage, skill damage rate, enemy resistance, and piercing.
  Can calculate critical damage if the `crit?` parameter is set to true.

  ## Parameters

    * `skill_cast` - The skill being cast
    * `mob` - The target field NPC
    * `crit?` - Whether the hit is a critical hit (default: false)

  ## Examples

      iex> calculate(skill_cast, mob)
      %{dmg: 10000, crit?: false}

      iex> calculate(skill_cast, mob, true)
      %{dmg: 15000, crit?: true}
  """
  @spec calculate(SkillCast.t(), FieldNpc.t(), boolean()) :: %{dmg: integer(), crit?: boolean()}
  def calculate(%SkillCast{} = skill_cast, %FieldNpc{} = mob, crit? \\ false) do
    caster = skill_cast.caster

    stats = caster.stats
    attack_min = stats.min_weapon_atk_cur + stats.bonus_atk_cur
    attack_max = stats.max_weapon_atk_cur + stats.bonus_atk_cur

    attack = attack_min + :rand.uniform() * (attack_max - attack_min)

    resistance = calc_enemy_res(skill_cast, mob)
    resistance_multiplier = calculate_resistance(resistance, stats.piercing_cur / 100)
    attack_type_amount =
      if SkillCast.physical?(skill_cast),
        do: stats.physical_atk_cur,
        else: stats.magical_atk_cur

    defense = max(mob.stats.defense.current, 1)
    skill_rate = if crit?, do: SkillCast.crit_damage_rate(skill_cast), else: SkillCast.damage_rate(skill_cast)

    dmg = attack * skill_rate * attack_type_amount * resistance_multiplier / defense
    dmg = max(trunc(dmg), 1)
    %{dmg: dmg, crit?: crit?}
  end

  defp calculate_resistance(target_resistance, piercing_multiplier) do
    (1500 - max(0, target_resistance - 1500 * piercing_multiplier)) / 1500
  end

  defp calc_enemy_res(%SkillCast{} = skill_cast, mob) do
    if SkillCast.physical?(skill_cast) do
      mob.stats.physical_res.total
    else
      mob.stats.magical_res.total
    end
  end

  @doc """
  Calculates damage a character takes from falling.

  ## Examples

      iex> calculate_fall_dmg(character, 0)
      24
  """
  @spec calculate_fall_dmg(Schema.Character.t(), number()) :: integer()
  def calculate_fall_dmg(%Schema.Character{stats: stats}, distance) do
    current_hp = stats.health_cur
    max_hp = stats.health_max
    distance_factor = 0.04813 * :math.exp(0.0046 * distance)
    hp_ratio = current_hp / max_hp
    hp_scaling = :math.pow(hp_ratio, 1.087)

    current_hp
    |> min(current_hp * 0.25)
    |> min(current_hp * distance_factor * hp_scaling)
    |> trunc()
  end
end
