defmodule Ms2ex.GameHandlers.Quest do
  alias Ms2ex.{Managers, Packets, Storage}

  import Packets.PacketReader

  # Command opcodes
  @accept 0x02
  @complete 0x04
  @abandon 0x06
  # @expired 0x07
  # @exploration 0x08
  @tracking 0x09
  # @go_to_npc 0x0C
  # @go_to_dungeon 0x0D
  # @sky_fortress 0x0E
  # @maple_guide 0x10
  # @epic_restart 0x11
  # @resume_dungeon 0x13
  # @dispatch 0x14
  @remote_complete 0x18
  # @complete_field_mission 0x1A

  def handle(packet, session) do
    {command, packet} = get_byte(packet)
    handle_command(command, packet, session)
  end

  defp handle_command(@accept, packet, session) do
    {:ok, character} = Managers.Character.lookup(session.character_id)

    {quest_id, packet} = get_int(packet)
    {npc_object_id, _packet} = get_int(packet)

    quest = Storage.Quests.get_meta(quest_id)
    quest_accept_type = get_in(quest, [:remote_accept, :type]) || 0

    if quest_accept_type != :none do
      handle_remote_accept(character, quest)
    else
      handle_accept(character, quest, npc_object_id)
    end
  end

  defp handle_command(@complete, packet, session) do
    {quest_id, _packet} = get_int(packet)

    Managers.Quest.complete(quest_id, session.character_id)
  end

  defp handle_command(@abandon, _packet, session) do
    # {quest_id, _packet} = get_int(packet)

    # Managers.Quest.abandon(quest_id, session.character_id)
    session
  end

  defp handle_command(@tracking, packet, session) do
    {quest_id, packet} = get_int(packet)
    {tracking, _packet} = get_bool(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, quest_manager} <- Managers.Quest.get_state(character.id),
         %{} = quest <- Managers.Quest.get_quest(quest_manager, quest_id),
         true <- quest.state != :completed do
      {:ok, _updated_quest_manager} =
        Managers.Quest.update_tracking(quest_manager, quest_id, tracking)

      # Send tracking update packet
      # Net.SenderSession.push(session, Packets.Game.Quest.set_tracking(quest_id, tracking))
      :ok
    else
      _ -> :ok
    end
  end

  defp handle_command(@remote_complete, packet, session) do
    {quest_id, _packet} = get_int(packet)

    Managers.Quest.complete(quest_id, session.character_id)
  end

  defp handle_command(_command, _packet, _session), do: :ok

  defp handle_remote_accept(character, quest) do
    quest_map_id = get_in(quest, [:remote_accept, :map_id]) || 0

    if quest_map_id == 0 || quest_map_id == character.map_id do
      Managers.Quest.start(character, quest)
    end
  end

  def handle_accept(character, quest, npc_object_id) do
    quest_use_postbox = get_in(quest, [:basic, :use_postbox])
    postbox? = npc_object_id == 0 && quest_use_postbox

    if postbox? || npc_exists?(npc_object_id) do
      Managers.Quest.start(quest.id, character)
    end
  end

  defp npc_exists?(_npc_object_id) do
    # TODO: Implement NPC existence check
    true
  end
end
