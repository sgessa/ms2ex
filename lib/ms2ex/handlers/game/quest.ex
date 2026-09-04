defmodule Ms2ex.GameHandlers.Quest do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Packets.PacketReader

  @accept 0x02
  @complete 0x04
  @abandon 0x06
  @expired 0x07
  @exploration 0x08
  @tracking 0x09
  @go_to_npc 0x0C
  @dispatch 0x14
  @remote_complete 0x18

  def handle(packet, session) do
    {command, packet} = get_byte(packet)
    handle_command(command, packet, session)
  end

  defp handle_command(@accept, packet, session) do
    {:ok, character} = Managers.Character.lookup(session.character_id)

    {quest_id, packet} = get_int(packet)
    {npc_object_id, _packet} = get_int(packet)

    case Storage.Quests.get_meta(quest_id) do
      nil ->
        :ok

      quest ->
        remote_accept_type = get_in(quest, [:remote_accept, :type])

        if remote_accept_type in [nil, :none] do
          handle_accept(character, quest, npc_object_id)
        else
          handle_remote_accept(character, quest)
        end
    end
  end

  defp handle_command(@complete, packet, session) do
    {quest_id, _packet} = get_int(packet)
    Managers.Quest.complete(quest_id, session.character_id)
  end

  defp handle_command(@abandon, packet, session) do
    {quest_id, _packet} = get_int(packet)
    Managers.Quest.abandon(quest_id, session.character_id)
  end

  defp handle_command(@exploration, packet, session) do
    {:ok, character} = Managers.Character.lookup(session.character_id)
    {count, packet} = get_int(packet)
    {quest_ids, _packet} = read_ids(packet, count, [])

    Enum.each(quest_ids, fn quest_id ->
      case Storage.Quests.get_meta(quest_id) do
        %{basic: %{type: :field_mission}} = quest -> Managers.Quest.start(character, quest)
        _ -> :ok
      end
    end)
  end

  defp handle_command(@tracking, packet, session) do
    {quest_id, packet} = get_int(packet)
    {tracking, _packet} = get_bool(packet)

    Managers.Quest.update_tracking(session.character_id, quest_id, tracking)
  end

  defp handle_command(@remote_complete, packet, session) do
    {quest_id, _packet} = get_int(packet)
    Managers.Quest.complete(quest_id, session.character_id)
  end

  defp handle_command(@expired, packet, session) do
    {count, packet} = get_int(packet)
    {quest_ids, _packet} = read_ids(packet, count, [])

    Managers.Quest.expire_quests(session.character_id, quest_ids)
  end

  defp handle_command(@go_to_npc, packet, session) do
    {quest_id, _packet} = get_int(packet)

    Managers.Quest.go_to_npc(session.character_id, quest_id)
  end

  defp handle_command(@dispatch, packet, session) do
    {quest_id, packet} = get_int(packet)
    {_unknown, _packet} = get_short(packet)

    Managers.Quest.dispatch(session.character_id, quest_id)
  end

  defp handle_command(_command, _packet, _session), do: :ok

  defp read_ids(packet, 0, acc), do: {Enum.reverse(acc), packet}

  defp read_ids(packet, remaining, acc) do
    {quest_id, packet} = get_int(packet)
    read_ids(packet, remaining - 1, [quest_id | acc])
  end

  defp handle_remote_accept(character, quest) do
    quest_map_id = get_in(quest, [:remote_accept, :map_id]) || 0

    if quest_map_id == 0 || quest_map_id == character.map_id do
      Managers.Quest.start(character, quest)
    end
  end

  defp handle_accept(character, quest, npc_object_id) do
    use_postbox? = get_in(quest, [:basic, :use_postbox]) == true
    postbox? = npc_object_id == 0 and use_postbox?

    if postbox? or npc_exists?(character, npc_object_id) do
      Managers.Quest.start(character, quest)
    end
  end

  defp npc_exists?(_character, 0), do: false

  defp npc_exists?(character, npc_object_id) do
    Context.Field.lookup_npc(character, npc_object_id) != :error
  end
end
