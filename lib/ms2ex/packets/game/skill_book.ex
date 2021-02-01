defmodule Ms2ex.Packets.ResponseSkillBook do
  alias Ms2ex.Skills

  import Ms2ex.Packets.PacketWriter

  def open(character) do
    skill_tab = Skills.get_tab(character)

    skills = Skills.list(character, skill_tab)
    skills = Enum.filter(skills, & &1.learned)

    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(0x1)
    |> put_long(skill_tab.id)
    |> put_int(0x1)
    |> put_long(skill_tab.id)
    |> put_ustring(skill_tab.name)
    |> put_int(length(skills))
    |> reduce(skills, fn skill, packet ->
      packet
      |> put_int(skill.skill_id)
      |> put_int(skill.level)
    end)
  end

  def save(character) do
    skill_tab = Skills.get_tab(character)

    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_long(skill_tab.id)
    |> put_long(skill_tab.id)
    |> put_int(0x1)
  end
end
