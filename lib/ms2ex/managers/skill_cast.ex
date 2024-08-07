defmodule Ms2ex.Managers.SkillCast do
  alias Ms2ex.Storage
  alias Ms2ex.Enums

  defstruct [
    :character_object_id,
    :client_tick,
    :id,
    :meta,
    :effect,
    :parent_skill,
    :server_tick,
    :skill_id,
    :skill_level,
    :position,
    :rotation,
    :direction,
    :rotate2z,
    motion_point: 0,
    attack_point: 0
  ]

  def build(skill_id, skill_level, parent_skill, srv_tick) do
    meta = Storage.Skills.get_meta(skill_id)

    %__MODULE__{
      id: Ms2ex.generate_long(),
      parent_skill: parent_skill,
      server_tick: srv_tick,
      skill_id: skill_id,
      skill_level: skill_level,
      meta: meta,
      effect: List.first(meta.additional_effects)
    }
  end

  def build(attrs) do
    meta = Storage.Skills.get_meta(attrs[:skill_id])
    effect = List.first(meta.additional_effects)
    attrs = attrs |> Map.put(:meta, meta) |> Map.put(:effect, effect)

    struct(__MODULE__, attrs)
  end

  def get(skill_cast_id), do: Agent.get(process_name(skill_cast_id), & &1)

  def duration(%__MODULE__{skill_id: skill_id}) do
    case Storage.Skills.get_region_skill(skill_id) do
      %{interval: interval} -> interval
      _ -> 5_000
    end
  end

  def max_stacks(%__MODULE__{effect: effect}) do
    effect.property.max_count || 1
  end

  def spirit_cost(%__MODULE__{skill_level: lvl, meta: meta}) do
    case meta.levels["#{lvl}"] do
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

  def heal?(%__MODULE__{effect: effect}) do
    # 1 = Buff
    # 16 = Recovery
    effect[:property][:type] == 1 && effect[:property][:sub_type] == 16
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

  def magic_path(%__MODULE__{meta: meta, motion_point: motion_point, attack_point: attack_point}) do
    motion = meta[:motions] |> Enum.at(motion_point)
    attack = motion[:attacks] |> Enum.at(attack_point)
    cube_magic_path_id = attack[:cube_magic_path_id] || 0

    Storage.Table.MagicPaths.get(cube_magic_path_id)
  end

  def owner_buff?(%__MODULE__{effect: effect}) do
    # 1 = Buff
    # 2 = Owner
    effect[:property][:type] == 1 && effect[:dot][:buff][:target] == 2
  end

  def entity_buff?(%__MODULE__{effect: effect}) do
    # 1 = Buff
    # 1 = Target
    effect[:property][:type] == 1 && effect[:dot][:buff][:target] == 1
  end

  def entity_debuff?(%__MODULE__{effect: effect}) do
    # 2 = Debuff
    # 1 = Target
    effect[:property][:type] == 2 && effect[:dot][:buff][:target] == 1
  end

  def element_debuff?(%__MODULE__{effect: effect}) do
    # 2 = Debuff
    # 1, 2 = Target, Owner
    effect[:property][:type] == 2 && effect[:dot][:buff][:target] not in [1, 2]
  end

  def shield_buff?(%__MODULE__{} = _cast) do
    # TODO
    # verify_skill_type(cast, :none, :status, :buff, :shield)
    false
  end

  def owner_debuff?(%__MODULE__{effect: effect}) do
    # 1 = Debuff
    # 2 = Owner
    effect[:property][:type] == 2 && effect[:dot][:buff][:target] == 2
  end

  def start(%__MODULE__{} = skill_cast) do
    Agent.start(fn -> skill_cast end, name: process_name(skill_cast.id))
  end

  defp process_name(skill_cast_id), do: :"skill_cast:#{skill_cast_id}"
end
