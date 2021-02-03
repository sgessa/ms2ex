defmodule Ms2ex.GameHandlers.Job do
  require Logger

  alias Ms2ex.{HotBars, Net, Packets, Skills, World}

  import Net.Session, only: [push: 2]
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
    {:ok, character} = World.get_character(session.world, session.character_id)

    skill_tab = Skills.get_tab(character)
    {skills_length, packet} = get_int(packet)

    save_skills(skill_tab, skills_length, packet)

    hot_bars = HotBars.list(character)

    session
    |> push(Packets.Job.save(character))
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
  end

  # TODO: Reset Skill Build (need to check again)
  defp handle_mode(0xA, _packet, session) do
    {:ok, character} = World.get_character(session.world, session.character_id)

    skill_tab = Skills.get_tab(character)
    Skills.reset(character, skill_tab)

    hot_bars = HotBars.list(character)

    session
    |> push(Packets.Job.save(character))
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
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
