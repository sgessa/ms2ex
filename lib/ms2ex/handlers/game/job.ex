defmodule Ms2ex.GameHandlers.Job do
  require Logger

  alias Ms2ex.{Net, Packets, Registries, Skills}

  import Net.SessionHandler, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Close Skill Book
  defp handle_mode(0x8, _packet, session) do
    push(session, Packets.Job.close())
  end

  # Save Skill Build
  defp handle_mode(0x9, packet, session) do
    {:ok, character} = Registries.Characters.lookup(session.character_id)

    skill_tab = Skills.get_tab(character)
    {skills_length, packet} = get_int(packet)

    save_skills(skill_tab, skills_length, packet)

    push(session, Packets.Job.save(character))
  end

  # TODO: Reset Skill Build (need to check again)
  defp handle_mode(0xA, _packet, session) do
    {:ok, character} = Registries.Characters.lookup(session.character_id)

    skill_tab = Skills.get_tab(character)
    Skills.reset(character, skill_tab)

    push(session, Packets.Job.save(character))
  end

  defp handle_mode(_mode, _character, session), do: session

  defp save_skills(_tab, len, _packet) when len < 1, do: :ok

  defp save_skills(tab, len, packet) do
    {skill_id, packet} = get_int(packet)
    {level, packet} = get_short(packet)
    {learned, packet} = get_bool(packet)

    Skills.find_and_update(tab, skill_id, %{level: level, learned: learned})

    save_skills(tab, len - 1, packet)
  end
end
