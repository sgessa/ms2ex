defmodule Ms2ex.GameHandlers.Party do
  alias Ms2ex.{Packets, Party, PartyManager, PartyServer, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Invite
  defp handle_mode(0x1, packet, session) do
    {target_name, _packet} = get_ustring(packet)

    {:ok, character} = World.get_character(session.character_id)

    target =
      case World.get_character_by_name(target_name) do
        {:ok, target} -> target
        _ -> nil
      end

    cond do
      is_nil(target) ->
        push(session, Packets.Party.notice(:unable_to_invite, character))

      character.id == target.id ->
        push(session, Packets.Party.notice(:invite_self, character))

      character.party_id ->
        invite_to_party(session, character, target)

      true ->
        create_party(session, character, target)
    end
  end

  # Invitation Response
  # defp handle_mode(0x2, packet, session) do
  #   {target_name, packet} = get_ustring(packet)
  #   {notice_code, packet} = get_byte(packet)
  #   {party_id, _packet} = get_int(packet)

  #   PartyServer.lookup(party_id)
  # end

  defp handle_mode(_, _packet, session), do: session

  def create_party(session, character, %{party_id: nil} = target) do
    {:ok, party} = PartyManager.create(character)

    character = %{character | party_id: party.id}
    World.update_character(character)

    send(target.session_pid, {:push, Packets.Party.invite(character)})
    push(session, Packets.Party.create(party))
  end

  def create_party(session, character, %{party_id: target_party_id} = target) do
    {:ok, target_party} = PartyServer.lookup(target_party_id)

    if Enum.count(target_party.members) == 1 do
      {:ok, party} = PartyManager.create(character)

      character = %{character | party_id: party.id}
      World.update_character(character)

      send(target.session_pid, {:push, Packets.Party.invite(character)})
      push(session, Packets.Party.create(party))
    else
      leader = Party.get_leader(target_party)
      send(leader.session_pid, {:push, Packets.Party.join_request(character)})
      push(session, Packets.Party.notice(:request_to_join, target))
    end
  end

  def invite_to_party(session, character, target) do
    with :ok <- is_leader?(character),
         :ok <- already_in_party?(character, target) do
      send(target.session_pid, {:push, Packets.Party.invite(character)})
      session
    else
      {:error, notice_packet} ->
        push(session, notice_packet)
    end
  end

  defp is_leader?(character) do
    if character.party.leader_id == character.id do
      :ok
    else
      {:error, Packets.Party.notice(:not_leader, character)}
    end
  end

  defp already_in_party?(character, target) do
    if target.party && Enum.count(target.party.members) > 1 do
      {:error, Packets.Party.notice(:unable_to_invite, character)}
    else
      :ok
    end
  end
end
