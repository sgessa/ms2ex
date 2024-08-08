defmodule Ms2ex.Packets.SkillBook do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    load: 0x0,
    save: 0x1,
    rename: 0x2,
    expand: 0x4
  }

  def open(character) do
    skill_tabs = character.skill_tabs

    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_int(length(skill_tabs))
    |> put_long(character.active_skill_tab_id)
    |> put_int(length(skill_tabs))
    |> reduce(skill_tabs, fn tab, packet ->
      learned_skills = Enum.filter(tab.skills, &(&1.level > 0))

      packet
      |> put_long(tab.id)
      |> put_ustring(tab.name)
      |> put_int(length(learned_skills))
      |> reduce(learned_skills, fn skill, packet ->
        packet
        |> put_int(skill.skill_id)
        |> put_int(skill.level)
      end)
    end)
  end

  def save(character, selected_tab_id, rank) do
    __MODULE__
    |> build()
    |> put_byte(@modes.save)
    |> put_long(character.active_skill_tab_id)
    |> put_long(selected_tab_id)
    |> put_int(rank)
  end

  def rename(tab_id, new_name) do
    __MODULE__
    |> build()
    |> put_byte(@modes.rename)
    |> put_long(tab_id)
    |> put_ustring(new_name)
    |> put_byte()
  end

  def add_tab(character) do
    __MODULE__
    |> build()
    |> put_byte(@modes.expand)
    |> put_int(0x2)
    |> put_long(character.active_skill_tab_id)
  end
end
