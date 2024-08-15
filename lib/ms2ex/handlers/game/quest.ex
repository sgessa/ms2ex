defmodule Ms2ex.GameHandlers.Quest do
  alias Ms2ex.{Enums, Managers, Packets, Storage}

  import Packets.PacketReader

  @accept 0x02
  # @complete 0x04
  # @abandon 0x06

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  defp handle_mode(@accept, packet, session) do
    {quest_id, packet} = get_int(packet)
    {npc_object_id, _packet} = get_ustring(packet)

    quest = Storage.Quests.get_meta(quest_id)
    quest_accept_type = get_in(quest, [:remote_accept, :type]) || 0
    quest_map_id = get_in(quest, [:remote_accept, :map_id]) || 0
    quest_use_postbox = get_in(quest, [:basic, :use_postbox])

    {:ok, character} = Managers.Character.lookup(session.character_id)

    # IO.inspect(quest)
    if quest_accept_type == Enums.QuestRemoteType.get_value(:none) do
      postbox? = npc_object_id == 0 && quest_use_postbox

      if postbox? || npc_exists?(npc_object_id) do
        Managers.Quest.start(quest_id)
      end
    else
      if quest_map_id == 0 || quest_map_id == character.map_id do
        Managers.Quest.start(quest_id)
      end
    end
  end

  defp handle_mode(_mode, _packet, session), do: session

  defp npc_exists?(_npc_object_id) do
    # TODO
    true
  end
end
