defmodule Ms2ex.GameHandlers.UserChat do
  alias Ms2ex.{
    CharacterManager,
    Commands,
    Context,
    Enums,
    Field,
    Net,
    Packets,
    PartyServer,
    World
  }

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  @world_chat_cost -30

  def handle(packet, session) do
    {type_id, packet} = get_int(packet)
    type = Enums.ChatType.get_key(type_id)

    {msg, packet} = get_ustring(packet)
    {rcpt, packet} = get_ustring(packet)
    {_, _packet} = get_long(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)

    case msg do
      "!" <> cmd ->
        cmd
        |> String.trim()
        |> String.split(" ")
        |> Commands.handle(character, session)

      _ ->
        handle_message({type, msg, rcpt}, character, session)
    end
  end

  defp handle_message({:all, msg, _rcpt_name}, character, _session) do
    packet = Packets.UserChat.bytes(:all, character, msg)
    Field.broadcast(character, packet)
  end

  defp handle_message({:whisper_to, msg, rcpt_name}, character, session) do
    case CharacterManager.lookup_by_name(rcpt_name) do
      {:ok, rcpt} ->
        # TODO check if rcpt blocked character

        push(rcpt, Packets.UserChat.bytes(:whisper_from, character, msg))
        push(session, Packets.UserChat.bytes(:whisper_to, rcpt, msg))

      _ ->
        push(session, Packets.UserChat.error(character, :whisper_fail, :unable_to_whisper))
    end
  end

  defp handle_message({:world, msg, _rcpt_name}, character, session) do
    # TODO check if user has a voucher

    case Context.Wallets.update(character, :merets, @world_chat_cost) do
      {:ok, wallet} ->
        World.broadcast(Packets.UserChat.bytes(:world, character, msg))
        push(session, Packets.Wallet.update(wallet, :merets))

      _ ->
        push(session, Packets.UserChat.error(character, :notice_alert, :insufficient_merets))
    end
  end

  defp handle_message({:party, msg, _rcpt_name}, character, _session) do
    packet = Packets.UserChat.bytes(:party, character, msg)

    if character.party_id do
      PartyServer.broadcast(character.party_id, packet)
    end
  end

  defp handle_message(_msg, _character, session), do: session
end
