defmodule Ms2ex.SkillCast do
  alias Ms2ex.Metadata

  defstruct [
    :id,
    :character_object_id,
    :skill_id,
    :skill_level,
    :server_tick,
    :client_tick,
    :attack_point,
    :meta
  ]

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

  def owner_buff?(cast) do
    verify_skill_type(cast, :none, :status, :buff, :owner)
  end

  def entity_buff?(cast) do
    verify_skill_type(cast, :none, :status, :buff, :entity)
  end

  def shield_buff?(cast) do
    verify_skill_type(cast, :none, :status, :buff, :shield)
  end

  def owner_debuff?(cast) do
    verify_buff_type(cast, :debuff, :owner)
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
end
