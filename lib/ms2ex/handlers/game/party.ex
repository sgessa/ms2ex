defmodule Ms2ex.GameHandlers.Party do
  alias Ms2ex.{CharacterManager, Enums, Packets, PartyServer, Types}

  import Packets.PacketReader
  import Ms2ex.GameHandlers.Helper.Party
  import Ms2ex.Net.SenderSession, only: [push: 2, run: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Invite
  defp handle_mode(0x1, packet, session) do
    {target_name, _packet} = get_ustring(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)

    target =
      case CharacterManager.lookup_by_name(target_name) do
        {:ok, target} -> target
        _ -> nil
      end

    cond do
      is_nil(target) ->
        push(session, Packets.Party.notice(:unable_to_invite, character))

      character.id == target.id ->
        push(session, Packets.Party.notice(:invite_self, character))

      character.party_id ->
        invite_to_party(character, target)

      true ->
        create_party(session, character, target)
    end
  end

  # Invitation Response
  defp handle_mode(0x2, packet, session) do
    {_target_name, packet} = get_ustring(packet)

    {resp_code, packet} = get_byte(packet)
    response = Enums.PartyNotice.get_key(resp_code)

    {party_id, _packet} = get_int(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)

    case PartyServer.lookup(party_id) do
      {:ok, party} ->
        handle_invitation(session, response, party, character)

      _ ->
        push(session, Packets.Party.notice(:party_not_found, character))
    end
  end

  # Leave
  defp handle_mode(0x3, _packet, session) do
    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, _party} <- PartyServer.lookup(character.party_id) do
      run(session, fn -> PartyServer.unsubscribe(character.party_id) end)

      PartyServer.remove_member(character)

      character = %{character | party_id: nil}
      CharacterManager.update(character)

      push(session, Packets.Party.leave(character))
    end
  end

  # Kick
  defp handle_mode(0x4, packet, session) do
    {target_id, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, party} <- PartyServer.lookup(character.party_id),
         true <- Types.Party.is_leader?(party, character),
         {:ok, target} <- PartyServer.kick_member(party, target_id) do
      if target.online? do
        run(target, fn -> PartyServer.unsubscribe(party.id) end)
      end

      CharacterManager.update(%{target | party_id: nil})
    end
  end

  # Promote Leader
  defp handle_mode(0x11, packet, session) do
    {target_name, _packet} = get_ustring(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, new_leader} <- CharacterManager.lookup_by_name(target_name),
         {:ok, party} <- PartyServer.lookup(character.party_id),
         true <- party.leader_id == character.id do
      PartyServer.broadcast(party.id, Packets.Party.set_leader(new_leader))
    end
  end

  # Start Vote Kick
  defp handle_mode(0x2D, packet, session) do
    {target_id, _packet} = get_long(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, party} <- PartyServer.lookup(character.party_id) do
      if Enum.count(party.members) < 4 do
        push(session, Packets.Party.notice(:insufficient_memmber_count_for_kick_vote, character))
      else
        PartyServer.start_vote_kick(party, target_id)
      end
    end
  end

  # Start Ready Check
  defp handle_mode(0x2E, _packet, session) do
    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, party} <- PartyServer.lookup(character.party_id) do
      if Types.Party.is_leader?(party, character) do
        PartyServer.start_ready_check(party)
      end
    end
  end

  # Handle Ready Check
  defp handle_mode(0x30, packet, session) do
    {_n, packet} = get_int(packet)
    {resp, _packet} = get_bool(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, party} <- PartyServer.lookup(character.party_id),
         false <- Enum.member?(party.ready_check, character.id) do
      PartyServer.ready_check(party, character, resp)
    end
  end

  defp handle_mode(_, _packet, session), do: session

  defp handle_invitation(session, response, party, character) do
    leader = Types.Party.get_leader(party)

    cond do
      Types.Party.in_party?(party, character) ->
        {:error, :already_in_party}

      response != :accepted_invite ->
        push(leader, Packets.Party.notice(response, character))

      Types.Party.full?(party) ->
        push(session, Packets.Party.notice(:full_party, character))

      true ->
        PartyServer.broadcast(party.id, Packets.Party.join(character))

        character = %{character | party_id: party.id}
        {:ok, party} = PartyServer.update_member(character)

        CharacterManager.update(character)
        run(session, fn -> PartyServer.subscribe(party.id) end)

        push(session, Packets.Party.create(party))

        for m <- party.members do
          PartyServer.broadcast(party.id, Packets.Party.update_hitpoints(m))
        end
    end
  end
end
