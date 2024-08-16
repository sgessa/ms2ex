defmodule Ms2ex.Types.Buff do
  alias Ms2ex.Storage
  alias Ms2ex.Types.SkillCast

  defstruct [
    :object_id,
    :caster,
    :owner,
    :skill_cast,
    :skill,
    :start_tick,
    :end_tick,
    :stacks,
    :enabled,
    :effect,
    :shield_health
  ]

  def build(object_id, %SkillCast{} = skill_cast, skill, caster, owner) do
    effect =
      Storage.Skills.get_effect(skill[:id], skill[:level])

    attrs =
      Map.new()
      |> Map.put(:object_id, object_id)
      |> Map.put(:effect, effect)
      |> Map.put(:skill, skill)
      |> Map.put(:caster, caster)
      |> Map.put(:owner, owner)
      |> Map.put(:skill_cast, skill_cast)
      |> Map.put(:enabled, true)

    __MODULE__
    |> struct(attrs)
    |> stack()
    |> set_shield_health()
  end

  def stack(%__MODULE__{} = buff) do
    stacks = min(buff.stacks, buff.effect.property.max_count)
    start_tick = Ms2ex.sync_ticks()

    end_tick =
      if stacks == 1 or buff.effect.reset_condition != buff.effect.persist_end_tick,
        do: start_tick + buff.effect.property.duration_tick,
        else: buff.end_tick

    buff
    |> Map.put(:stacks, stacks)
    |> Map.put(:start_tick, start_tick)
    |> Map.put(:end_tick, end_tick)
  end

  def set_shield_health(%__MODULE__{} = buff) do
    shield_health =
      if buff.effect.shield[:hp_value],
        do: buff.effect.shield.hp_value,
        else: buff.owner.stats.health_max * buff.effect.shield.hp_by_target_max_hp

    Map.put(buff, :shield_health, shield_health)
  end
end
