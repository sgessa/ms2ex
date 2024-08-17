defmodule Ms2ex.Types.Buff do
  alias Ms2ex.Storage
  alias Ms2ex.Types.SkillCast
  alias Ms2ex.Enums

  defstruct [
    :object_id,
    :caster,
    :owner,
    :skill_cast,
    :skill,
    :start_tick,
    :end_tick,
    :can_proc,
    :can_expire,
    :interval_tick,
    :stacks,
    :enabled,
    :effect,
    :shield_health,
    proc_count: 0,
    activated: false
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
    |> get_ticks()
    |> set_shield_health()
  end

  def get_ticks(%__MODULE__{} = buff) do
    prop_interval_tick = buff.effect[:property][:interval_tick] || 0

    interval_tick =
      if prop_interval_tick > 0,
        do: prop_interval_tick,
        else: buff.effect[:property][:duration_tick] + 1000

    next_proc_tick =
      buff.start_tick + (buff.effect[:property][:delay_tick] || 0) +
        (buff.effect[:property][:interval_tick] || 0)

    keep_condition =
      if c = buff.effect[:property][:keep_condition], do: Enums.BuffKeepCondition.get_key(c)

    can_proc = keep_condition != :unlimited_duration

    can_expire = can_proc && buff.end_tick >= buff.start_tick

    buff
    |> Map.put(:interval_tick, interval_tick)
    |> Map.put(:can_proc, can_proc)
    |> Map.put(:can_expire, can_expire)
    |> Map.put(:next_proc_tick, next_proc_tick)
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
