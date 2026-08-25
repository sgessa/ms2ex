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

    # TODO calculate from character stats
    attk_dmg = 1_000_000

    skill_dmg_rate =
      if crit?,
        do: SkillCast.crit_damage_rate(skill_cast),
        else: SkillCast.damage_rate(skill_cast)

    skill_dmg = skill_dmg_rate * attk_dmg

    enemy_res = calc_enemy_res(skill_cast, mob)
    pierce_res = calc_pierce_res(skill_cast, caster)

    # TODO fix dmg multiplier
    numerator =
      skill_dmg * (1 + caster.stats.bonus_atk_cur) * (1500 - (enemy_res - pierce_res * 15))

    pierce_coeff = 1 - caster.stats.piercing_cur

    # TODO find correct enemy def stats
    denominator = mob.stats.defense.total * pierce_coeff * 15

    dmg = trunc(numerator / denominator)
    %{dmg: dmg, crit?: crit?}
  end

  defp calc_enemy_res(%SkillCast{} = skill_cast, mob) do
    if SkillCast.physical?(skill_cast) do
      mob.stats.physical_res.total
    else
      mob.stats.magical_res.total
    end
  end

  defp calc_pierce_res(%SkillCast{} = skill_cast, caster) do
    if SkillCast.physical?(skill_cast) do
      caster.stats.physical_atk_cur
    else
      caster.stats.magical_atk_cur
    end
  end

  @fall_dmg 150

  @doc """
  Calculates damage a character takes from falling.

  Currently returns a constant value of #{@fall_dmg}.

  ## Examples

      iex> calculate_fall_dmg(character)
      150
  """
  @spec calculate_fall_dmg(Schema.Character.t()) :: integer()
  def calculate_fall_dmg(%Schema.Character{}) do
    @fall_dmg
  end
end
