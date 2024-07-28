defmodule Ms2ex.Packets.Job do
  alias Ms2ex.{Character, ProtoMetadata, Skills}

  import Ms2ex.Packets.PacketWriter

  @job_skill_splits %{
    none: 0,
    knight: 9,
    berserker: 15,
    wizard: 17,
    priest: 10,
    archer: 14,
    heavy_gunner: 13,
    thief: 13,
    assassin: 8,
    rune_blade: 8,
    striker: 12,
    soul_binder: 16,
    game_master: 0
  }

  def save(character) do
    real_job_id = Character.real_job_id(character)

    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte(0x9)
    |> put_int(Character.job_id(character))
    |> put_byte(0x1)
    |> put_int(real_job_id)
    |> put_skills(character)
  end

  def close() do
    __MODULE__
    |> build()
    |> put_int()
  end

  def put_passive_skills(packet, character) do
    skill_tab = Skills.get_active_tab(character)

    skills =
      skill_tab.skills
      |> Enum.map(&Map.put(&1, :metadata, ProtoMetadata.Skills.get(&1.skill_id)))
      |> Enum.filter(&(&1.metadata.type == 1 and &1.metadata.starting_level == 1))

    packet
    |> put_short(length(skills))
    |> reduce(skills, fn sk, packet ->
      packet
      |> put_int(character.object_id)
      |> put_int()
      |> put_int(character.object_id)
      |> put_int()
      |> put_int()
      |> put_int(sk.skill_id)
      |> put_short(sk.level)
      |> put_int(0x1)
      |> put_byte(0x1)
      |> put_long()
    end)
  end

  def put_skills(packet, character) do
    skill_tab = Skills.get_active_tab(character)

    skills =
      Enum.map(skill_tab.skills, fn s ->
        meta = ProtoMetadata.Skills.get(s.skill_id)
        Map.put(s, :meta, meta)
      end)

    split = Map.get(@job_skill_splits, character.job)
    split_skill = Enum.at(skills, length(skills) - split)

    packet
    |> put_byte(length(skills) - split)
    |> reduce(skills, fn skill, packet ->
      %{level: max_level} = List.last(skill.meta.skill_levels)
      skill_level = 1 |> max(skill.level) |> min(max_level)

      packet
      |> maybe_split(skill.skill_id, split_skill.skill_id, split)
      |> put_byte()
      |> put_bool(skill.level > 0)
      |> put_int(skill.skill_id)
      |> put_int(skill_level)
      |> put_byte()
    end)
    |> put_short()
  end

  defp maybe_split(packet, skill_id, split_skill_id, split) when skill_id == split_skill_id do
    put_byte(packet, split)
  end

  defp maybe_split(packet, _skill_id, _split_skill_id, _split), do: packet
end
