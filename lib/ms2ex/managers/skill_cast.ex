defmodule Ms2ex.SkillCast do
  alias Ms2ex.Metadata

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
      skill_level: skill_lvl
      # meta: Metadata.Skills.get(skill_id)
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
      meta: Metadata.Skills.get(skill_id)
    }
  end

  def get(skill_cast_id), do: Agent.get(process_name(skill_cast_id), & &1)

  def duration(%__MODULE__{skill_level: lvl, meta: meta}) do
    case Metadata.Skills.get_level(meta, lvl) do
      %{data: %{duration: duration}} -> duration
      _ -> 5_000
    end
  end

  def max_stacks(%__MODULE__{skill_level: lvl, meta: meta}) do
    case Metadata.Skills.get_level(meta, lvl) do
      %{data: %{max_stacks: max_stacks}} -> max_stacks
      _ -> 1
    end
  end

  def sp_cost(%__MODULE__{skill_level: lvl, meta: meta}) do
    case Metadata.Skills.get_level(meta, lvl) do
      %{spirit: sp} -> sp
      _ -> 15
    end
  end

  def stamina_cost(%__MODULE__{skill_level: lvl, meta: meta}) do
    case Metadata.Skills.get_level(meta, lvl) do
      %{stamina: stamina} -> stamina
      _ -> 10
    end
  end

  def damage_rate(%__MODULE__{skill_level: lvl, meta: meta}) do
    case Metadata.Skills.get_level(meta, lvl) do
      %{damage_rate: dmg_rate} -> dmg_rate
      _ -> 0.1
    end
  end

  def physical?(%__MODULE__{meta: meta}) do
    meta.damage_type == :physical
  end

  def magic?(%__MODULE__{meta: meta}) do
    meta.damage_type == :magic
  end

  def heal?(%__MODULE__{} = cast) do
    verify_skill_type(cast, :none, :status, :buff, :recovery)
  end

  def crit_damage_rate(%__MODULE__{} = skill_cast) do
    damage_rate(skill_cast) * 2
  end

  def condition_skills(%__MODULE__{skill_level: lvl, meta: meta}) do
    if skill_lvl = Metadata.Skills.get_level(meta, lvl) do
      skill_lvl.conditions
    else
      []
    end
  end

  def magic_path(%__MODULE__{skill_level: lvl, meta: meta}) do
    cube_magic_path_id =
      case Metadata.Skills.get_level(meta, lvl) do
        %Metadata.SkillLevel{attacks: [attack | _]} ->
          attack.cube_magic_path_id

        _ ->
          0
      end

    Metadata.MagicPaths.get(cube_magic_path_id)
  end

  def owner_buff?(%__MODULE__{} = cast) do
    verify_skill_type(cast, :none, :status, :buff, :owner)
  end

  def entity_buff?(%__MODULE__{} = cast) do
    verify_skill_type(cast, :none, :status, :buff, :entity)
  end

  def entity_debuff?(%__MODULE__{} = cast) do
    verify_skill_type(cast, :none, :status, :debuff, :entity) ||
      verify_buff_type(cast, :debuff, :entity)
  end

  def element_debuff?(%__MODULE__{} = cast) do
    verify_skill_type(cast, :none, :status, :debuff, :element)
  end

  def shield_buff?(%__MODULE__{} = cast) do
    verify_skill_type(cast, :none, :status, :buff, :shield)
  end

  def owner_debuff?(%__MODULE__{} = cast) do
    verify_buff_type(cast, :debuff, :owner)
  end

  def start(%__MODULE__{} = skill_cast) do
    Agent.start(fn -> skill_cast end, name: process_name(skill_cast.id))
  end

  defp verify_skill_type(cast, type, sub_type, buff_type, sub_buff_type) do
    meta = cast.meta
    skill_lvl = Metadata.Skills.get_level(meta, cast.skill_level)

    meta && type == meta.type && sub_type == meta.sub_type && skill_lvl &&
      skill_lvl.data.buff_type == buff_type && skill_lvl.data.sub_buff_type == sub_buff_type
  end

  defp verify_buff_type(%{type: type, sub_type: sub_type}, _buff_type, _sub_buff_type)
       when type != :none or sub_type != :none do
    false
  end

  defp verify_buff_type(cast, buff_type, sub_buff_type) do
    skill_lvl = Metadata.Skills.get_level(cast.meta, cast.skill_level)

    skill_lvl && skill_lvl.data.buff_type == buff_type &&
      skill_lvl.data.sub_buff_type == sub_buff_type
  end

  defp process_name(skill_cast_id), do: :"skill_cast:#{skill_cast_id}"
end
