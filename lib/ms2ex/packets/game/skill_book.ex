defmodule Ms2ex.Packets.ResponseSkillBook do
  alias Ms2ex.Skills

  import Ms2ex.Packets.PacketWriter

  def open(character) do
    skill_tabs = character.skill_tabs

    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(length(skill_tabs))
    |> put_long(character.active_skill_tab_id)
    |> put_int(length(skill_tabs))
    |> reduce(skill_tabs, fn tab, packet ->
      skills = character |> Skills.list(tab) |> Enum.filter(&(&1.level > 0))

      packet
      |> put_long(tab.id)
      |> put_ustring(tab.name)
      |> put_int(length(skills))
      |> reduce(skills, fn skill, packet ->
        packet
        |> put_int(skill.skill_id)
        |> put_int(skill.level)
      end)
    end)
  end

  def save(character, selected_tab_id) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_long(character.active_skill_tab_id)
    |> put_long(selected_tab_id)
    # 0x1 = unsaved points, 0x2 = no unsaved points
    |> put_int(0x2)
  end
end
