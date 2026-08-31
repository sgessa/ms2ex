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

  The attack roll is the character's weapon attack plus bonus attack; an
  unarmed character falls back to the job attack stat. Skill rate scales the
  hit, target defense and resistance reduce it, and piercing ignores a share
  of both. Critical hits multiply by the critical damage stat.

  ## Parameters

    * `skill_cast` - The skill being cast
    * `mob` - The target field NPC
    * `crit?` - Whether the hit is a critical hit (default: false)

  ## Examples

      iex> calculate(skill_cast, mob)
      %{dmg: 1, crit?: false}
  """
  @spec calculate(SkillCast.t(), FieldNpc.t(), boolean()) :: %{dmg: integer(), crit?: boolean()}
  def calculate(%SkillCast{} = skill_cast, %FieldNpc{} = mob, crit? \\ false) do
    damage(
      skill_cast.caster,
      mob,
      SkillCast.damage_rate(skill_cast),
      SkillCast.damage_value(skill_cast),
      SkillCast.physical?(skill_cast),
      crit?
    )
  end

  @doc """
  Calculates damage for a given rate (e.g. a damage-over-time tick) instead of
  the skill's own rate.
  """
  def calculate_rate(rate, caster, mob, physical?, crit? \\ false) do
    damage(caster, mob, rate, 0, physical?, crit?)
  end

  defp damage(caster, mob, rate, value, physical?, crit?) do
    stats = caster.stats
    target = mob.stats

    attack_dmg = base_attack(stats, physical?)
    crit_mult = if crit?, do: critical_multiplier(stats.critical_damage_cur), else: 1.0

    damage_bonus = 1 + stats.damage_cur / 1000
    damage_multiplier = damage_bonus * crit_mult * rate

    # target defense reduces damage; piercing ignores a capped share of it
    defense_pierce = 1 - min(0.3, stats.piercing_cur / 1000 - 1)
    damage_multiplier = damage_multiplier / max(target.defense.total, 1) / defense_pierce

    # the attack stat drives the hit; the target's resistance cuts it down
    attack_stat = if physical?, do: stats.physical_atk_cur, else: stats.magical_atk_cur
    target_res = if physical?, do: target.physical_res.total, else: target.magical_res.total

    resistance =
      (1500 - max(target_res - 1500 * (stats.piercing_cur / 1000), 0)) / 1500

    damage_multiplier = damage_multiplier * attack_stat * resistance

    dmg = trunc(attack_dmg * (damage_multiplier * 4) + value)

    %{dmg: max(dmg, 1), crit?: crit?}
  end

  defp base_attack(stats, physical?) do
    min_atk = stats.min_weapon_atk_cur + stats.bonus_atk_cur
    max_atk = stats.max_weapon_atk_cur + stats.bonus_atk_cur

    if max_atk > 0 do
      first_roll = :rand.uniform()
      second_roll = :rand.uniform()
      interpolation = :rand.uniform()
      roll = first_roll + (second_roll - first_roll) * interpolation

      min_atk + (max_atk - min_atk) * roll
    else
      if physical?, do: stats.physical_atk_cur, else: stats.magical_atk_cur
    end
  end

  defp critical_multiplier(critical_damage) do
    critical_damage
    |> Kernel./(1000)
    |> Kernel.+(1)
    |> max(1.0)
    |> min(2.5)
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
