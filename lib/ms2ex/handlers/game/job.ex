defmodule Ms2ex.GameHandlers.Job do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Net
  alias Ms2ex.Packets

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
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    skill_tab = Context.Skills.get_active_tab(character)
    {skills_length, packet} = get_int(packet)

    character = save_skills(character, skill_tab, skills_length, packet)
    Managers.Character.call(character, {:update, character})

    :ok = Managers.CharacterConfig.update_hotbar_skills(character)
    hot_bars = Managers.CharacterConfig.list(character.id)

    session
    |> push(Packets.Job.save(character))
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
  end

  # Reset Skill Build
  defp handle_mode(0xA, packet, session) do
    {_rank, _packet} = get_int(packet)

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    skill_tab = Context.Skills.get_active_tab(character)
    character = reset_skills(character, skill_tab)
    Managers.Character.call(character, {:update, character})

    :ok = Managers.CharacterConfig.update_hotbar_skills(character)
    hot_bars = Managers.CharacterConfig.list(character.id)

    session
    |> push(Packets.Job.reset(character))
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
  end

  # Preset Skill Build
  defp handle_mode(0xB, packet, session) do
    {skills_length, packet} = get_int(packet)

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    skill_tab = Context.Skills.get_active_tab(character)
    character = save_skills(character, skill_tab, skills_length, packet)
    Managers.Character.call(character, {:update, character})

    :ok = Managers.CharacterConfig.update_hotbar_skills(character)
    hot_bars = Managers.CharacterConfig.list(character.id)

    session
    |> push(Packets.Job.save(character))
    |> push(Packets.KeyTable.send_hot_bars(hot_bars))
  end

  defp handle_mode(_mode, _character, _session), do: :ok

  defp reset_skills(character, tab) do
    Enum.each(tab.skills, &Context.Skills.find_and_update(tab, &1.skill_id, %{level: 0}))
    Context.Characters.load_skills(character, force: true)
  end

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
