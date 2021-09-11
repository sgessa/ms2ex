defmodule Ms2ex.GameHandlers.Party do
  alias Ms2ex.{Packets, Party, PartyNotice, PartyServer, World}

  import Packets.PacketReader
  import Ms2ex.GameHandlers.Helper.Party
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
  defp handle_mode(0x2, packet, session) do
    {_target_name, packet} = get_ustring(packet)

    {resp_code, packet} = get_byte(packet)
    response = PartyNotice.from_int(resp_code)

    {party_id, _packet} = get_int(packet)

    {:ok, character} = World.get_character(session.character_id)

    case PartyServer.lookup(party_id) do
      {:ok, party} ->
        handle_invitation(session, response, party, character)

      _ ->
        push(session, Packets.Party.notice(:party_not_found, character))
    end
  end

  defp handle_mode(_, _packet, session), do: session

  defp handle_invitation(session, response, party, character) do
    leader = Party.get_leader(party)

    cond do
      Party.in_party?(party, character) ->
        session

      response != :accepted_invite ->
        send(leader.session_pid, {:push, Packets.Party.notice(response, character)})
        session

      Party.full?(party) ->
        push(session, Packets.Party.notice(:full_party, character))

      true ->
        PartyServer.broadcast(party.id, Packets.Party.join(character))

        character = %{character | party_id: party.id}
        {:ok, party} = PartyServer.update_member(character)

        World.update_character(character)
        PartyServer.subscribe(party.id)

        session = push(session, Packets.Party.create(party))

        for m <- party.members do
          PartyServer.broadcast(party.id, Packets.Party.update_hitpoints(m))
        end

        session
    end
  end
end
