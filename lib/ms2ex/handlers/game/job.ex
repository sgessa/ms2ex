defmodule Ms2ex.GameHandlers.Job do
  require Logger

  alias Ms2ex.{CharacterManager, Context, Net, Packets}

  import Net.SenderSession, only: [push: 2]
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
    {:ok, character} = CharacterManager.lookup(session.character_id)

    skill_tab = Context.Skills.get_active_tab(character)
    {skills_length, packet} = get_int(packet)

    character = save_skills(character, skill_tab, skills_length, packet)
    CharacterManager.update(character)

    hot_bars = Context.HotBars.list(character)

    session
    |> push(Packets.Job.save(character))
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
  end

  # Reset Skill Build
  defp handle_mode(0xA, _packet, session) do
    {:ok, character} = CharacterManager.lookup(session.character_id)
    push(session, Packets.Job.save(character))
  end

  # Preset Skill Build
  defp handle_mode(0xB, packet, session) do
    {skills_length, packet} = get_int(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)

    skill_tab = Context.Skills.get_active_tab(character)
    character = save_skills(character, skill_tab, skills_length, packet)
    CharacterManager.update(character)

    hot_bars = Context.HotBars.list(character)

    session
    |> push(Packets.Job.save(character))
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
  end

  defp handle_mode(_mode, _character, session), do: session

  defp save_skills(character, _tab, len, _packet) when len < 1 do
    Context.Characters.load_skills(character, force: true)
  end

  defp save_skills(character, tab, len, packet) do
    {skill_id, packet} = get_int(packet)
    {level, packet} = get_short(packet)
    {learned, packet} = get_bool(packet)

    level = if learned, do: level, else: 0
    Context.Skills.find_and_update(tab, skill_id, %{level: level})

    save_skills(character, tab, len - 1, packet)
  end
end
