defmodule Ms2ex.Types.SkillCast do
  alias Ms2ex.Storage
  alias Ms2ex.Enums

  defstruct [
    :id,
    :meta,
    :skill_id,
    :skill_level,
    :position,
    :impact_position,
    :rotation,
    :direction,
    :rotate2z,
    :unknown,
    :hold_int,
    :hold_string,
    :caster,
    :server_tick,
    is_hold: false,
    motion_point: 0,
    attack_point: 0
  ]

  def build(caster, attrs) do
    meta = Storage.Skills.get_meta(attrs[:skill_id])
    attrs = attrs |> Map.put(:meta, meta) |> Map.put(:caster, caster)

    struct(__MODULE__, attrs)
  end

  def skill_level(%__MODULE__{meta: meta, skill_level: level}) do
    meta.levels["#{level}"]
  end

  def duration(%__MODULE__{} = skill_cast) do
    case splash(skill_cast) do
      %{interval: interval} -> interval
      _ -> 0
    end
  end

  def spirit_cost(%__MODULE__{} = skill_cast) do
    case skill_level(skill_cast) do
      %{consume: %{stat: %{spirit: sp}}} -> sp
      _ -> 0
    end
  end

  def stamina_cost(%__MODULE__{skill_level: lvl, meta: meta}) do
    case meta.levels["#{lvl}"] do
      %{consume: %{stat: %{stamina: stamina}}} -> stamina
      _ -> 0
    end
  end

  def damage_rate(%__MODULE__{skill_level: lvl, meta: meta}) do
    case meta.levels["#{lvl}"] do
      %{motions: [%{attacks: [%{damage: %{rate: rate}}]}]} -> rate
      _ -> 0.1
    end
  end

  def physical?(%__MODULE__{meta: meta}) do
    Enums.AttackType.get_value(meta.property.attack_type) == :physical
  end

  def magic?(%__MODULE__{meta: meta}) do
    Enums.AttackType.get_value(meta.property.attack_type) == :magic
  end

  def crit_damage_rate(%__MODULE__{} = skill_cast) do
    damage_rate(skill_cast) * 2
  end

  def condition_skills(%__MODULE__{skill_level: lvl, meta: meta}) do
    if skill_level = meta.levels["#{lvl}"] do
      skill_level.condition
    else
      []
    end
  end

  def attack_point(%__MODULE__{motion_point: motion, attack_point: attack} = skill_cast) do
    level = skill_cast.meta[:levels]["#{skill_cast.skill_level}"]
    motion = level[:motions] |> Enum.at(motion)
    motion[:attacks] |> Enum.at(attack)
  end

  def splash(%__MODULE__{} = skill_cast) do
    attack_skill = attack_point(skill_cast)[:skills] |> List.first()
    attack_skill[:splash]
  end
end
