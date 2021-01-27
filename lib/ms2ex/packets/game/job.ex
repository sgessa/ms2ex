defmodule Ms2ex.Packets.Job do
  alias Ms2ex.Skills

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

  def put_skills(packet, character) do
    %{skills: skills, ordered_ids: ordered_ids} = Skills.get_tab(character.job)

    split = Map.get(@job_skill_splits, character.job)
    split_skill_id = Enum.at(ordered_ids, length(ordered_ids) - split)

    packet
    |> put_byte(length(ordered_ids) - split)
    |> reduce(ordered_ids, fn skill_id, packet ->
      packet = if skill_id == split_skill_id, do: put_byte(packet, split), else: packet
      skill = Map.get(skills, skill_id)

      skill_level = List.first(skill.skill_levels) || %{}
      level = Map.get(skill_level, :level) || 0

      packet
      |> put_byte()
      |> put_bool(skill.learned)
      |> put_int(skill_id)
      |> put_int(level)
      |> put_byte()
    end)
    |> put_short()
  end
end
