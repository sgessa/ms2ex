defmodule Ms2ex.GameHandlers.SkillBook do
  require Logger

  alias Ms2ex.{Net, Packets, World}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, _packet} = get_byte(packet)
    {:ok, character} = World.get_character(session.character_id)
    handle_mode(mode, packet, character, session)
  end

  # Open
  defp handle_mode(0x0, _packet, character, session) do
    push(session, Packets.SkillBook.open(character))
  end

  # Save
  defp handle_mode(0x1, packet, character, session) do
    {_active_tab_id, packet} = get_long(packet)
    {selected_tab_id, _packet} = get_long(packet)
    # {_, packet} = get_int(packet)
    # {_tab_count, packet} = get_int(packet)

    # Enum.reduce(1..tab_count, packet, fn _, packet ->
    #   {tab_id, packet} = get_long(packet)
    #   {tab_name, packet} = get_ustring(packet)

    #   tab = Skills.get_tab(character, tab_id)

    #   # TODO check tab_id meaning
    #   {skill_tabs, tab} =
    #     if tab do
    #       tab = %{tab | tab_id: tab_id, name: tab_name}
    #       index = Enum.find_index(character.skill_tabs, &(&1.id == tab_id))
    #       skill_tabs = List.update_at(character.skill_tabs, index, fn _ -> tab end)
    #       {skill_tabs, tab}
    #     else
    #       new_tab = %{tab_id: tab_id, name: tab_name}
    #       skill_tabs = character.skill_tabs ++ [new_tab]
    #       {skill_tabs, new_tab}
    #     end

    #   {:ok, tab} = Skills.reset(character, tab)

    #   {skill_count, packet} = get_int(packet)

    #   Enum.reduce(1..skill_count, packet, fn _, packet ->
    #     {skill_id, packet} = get_int(packet)
    #     {skill_level, packet} = get_int(packet)

    #     # TODO add or update skill

    #     packet
    #   end)

    # # TODO update character skill tabs
    # {:ok, character} = Characters.update(character, %{active_skill_tab_id: active_tab_id})
    # World.update_character(character)

    push(session, Packets.SkillBook.save(character, selected_tab_id))
  end

  defp handle_mode(_mode, _packet, _character, session), do: session
end
