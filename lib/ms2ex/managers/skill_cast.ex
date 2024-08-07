defmodule Ms2ex.SkillCast do
  alias Ms2ex.Storage
  alias Ms2ex.Enums
  alias Ms2ex.ProtoMetadata

  defstruct [
    :attack_point,
    :character_object_id,
    :client_tick,
    :id,
    :meta,
    :parent_skill,
    :server_tick,
    :skill_id,
    :skill_level,
    motion_point: 0
  ]

  def build(skill_id, skill_lvl, parent_skill, srv_tick) do
    %__MODULE__{
      id: Ms2ex.generate_long(),
      parent_skill: parent_skill,
      server_tick: srv_tick,
      skill_id: skill_id,
      skill_level: skill_lvl,
      meta: Storage.Skills.get_meta(skill_id)
    }
  end

  def build(id, char_obj_id, skill_id, skill_lvl, attack_pt, srv_tick, client_tick) do
    %__MODULE__{
      id: id,
      character_object_id: char_obj_id,
      skill_id: skill_id,
      skill_level: skill_lvl,
      attack_point: attack_pt,
      server_tick: srv_tick,
      client_tick: client_tick,
      meta: Storage.Skills.get_meta(skill_id)
    }
  end

  def get(skill_cast_id), do: Agent.get(process_name(skill_cast_id), & &1)

  def duration(%__MODULE__{skill_id: skill_id}) do
    case Storage.Skills.get_region_skill(skill_id) do
      %{interval: interval} -> interval
      _ -> 5_000
    end
  end

  def max_stacks(%__MODULE__{skill_level: lvl, meta: meta}) do
    case ProtoMetadata.Skills.get_level(meta, lvl) do
      %{data: %{max_stacks: max_stacks}} -> max_stacks
      _ -> 1
    end
  end

  def spirit_cost(%__MODULE__{skill_level: lvl, meta: meta}) do
    case meta.levels["#{lvl}"] do
      %{consume: %{stat: %{spirit: sp}}} -> sp
      _ -> 15
    end
  end

  def stamina_cost(%__MODULE__{skill_level: lvl, meta: meta}) do
    case meta.levels["#{lvl}"] do
      %{consume: %{stat: %{stamina: stamina}}} -> stamina
      _ -> 10
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

  def heal?(%__MODULE__{} = cast) do
    ae = List.first(cast.meta.additional_effects)

    # 1 = Buff
    # 16 = Recovery
    ae[:property][:type] == 1 && ae[:property][:sub_type] == 16
  end

  def crit_damage_rate(%__MODULE__{} = skill_cast) do
    damage_rate(skill_cast) * 2
  end

  def condition_skills(%__MODULE__{skill_level: lvl, meta: meta}) do
    if skill_lvl = meta.levels["#{lvl}"] do
      skill_lvl.conditions
    else
      []
    end
  end

  def magic_path(%__MODULE__{skill_level: lvl, meta: meta}) do
    cube_magic_path_id =
      case ProtoMetadata.Skills.get_level(meta, lvl) do
        %ProtoMetadata.SkillLevel{attacks: [attack | _]} ->
          attack.cube_magic_path_id

        _ ->
          0
      end

    ProtoMetadata.MagicPaths.get(cube_magic_path_id)
  end

  def owner_buff?(%__MODULE__{} = cast) do
    ae = List.first(cast.meta.additional_effects)

    # 1 = Buff
    # 2 = Owner
    ae[:property][:type] == 1 && ae[:dot][:buff][:target] == 2
  end

  def entity_buff?(%__MODULE__{} = cast) do
    ae = List.first(cast.meta.additional_effects)

    # 1 = Buff
    # 1 = Target
    ae[:property][:type] == 1 && ae[:dot][:buff][:target] == 1
  end

  def entity_debuff?(%__MODULE__{} = cast) do
    ae = List.first(cast.meta.additional_effects)

    # 2 = Debuff
    # 1 = Target
    ae[:property][:type] == 2 && ae[:dot][:buff][:target] == 1
  end

  def element_debuff?(%__MODULE__{} = cast) do
    ae = List.first(cast.meta.additional_effects)

    # 2 = Debuff
    # 1, 2 = Target, Owner
    ae[:property][:type] == 2 && ae[:dot][:buff][:target] not in [1, 2]
  end

  def shield_buff?(%__MODULE__{} = _cast) do
    # TODO
    # verify_skill_type(cast, :none, :status, :buff, :shield)
    false
  end

  def owner_debuff?(%__MODULE__{} = cast) do
    ae = List.first(cast.meta.additional_effects)

    # 1 = Debuff
    # 2 = Owner
    ae[:property][:type] == 2 && ae[:dot][:buff][:target] == 2
  end

  def start(%__MODULE__{} = skill_cast) do
    Agent.start(fn -> skill_cast end, name: process_name(skill_cast.id))
  end

  defp process_name(skill_cast_id), do: :"skill_cast:#{skill_cast_id}"
end
