defmodule Ms2ex.GameHandlers.Helper.Party do
  alias Ms2ex.{CharacterManager, Packets, Party, PartyManager, PartyServer}

  import Ms2ex.Net.Session, only: [push: 2]

  def create_party(session, character, %{party_id: nil} = target) do
    {:ok, party} = PartyManager.create(character)

    character = %{character | party_id: party.id}
    CharacterManager.update(character)

    PartyServer.subscribe(party.id)

    send(target.session_pid, {:push, Packets.Party.invite(character)})
    push(session, Packets.Party.create(party))
  end

  def create_party(session, character, %{party_id: target_party_id} = target) do
    {:ok, target_party} = PartyServer.lookup(target_party_id)

    if Enum.count(target_party.members) == 1 do
      {:ok, party} = PartyManager.create(character)

      character = %{character | party_id: party.id}
      CharacterManager.update(character)

      send(target.session_pid, {:push, Packets.Party.invite(character)})
      push(session, Packets.Party.create(party))
    else
      leader = Party.get_leader(target_party)
      send(leader.session_pid, {:push, Packets.Party.join_request(character)})
      push(session, Packets.Party.notice(:request_to_join, target))
    end
  end

  def invite_to_party(session, character, target) do
    with {:ok, party} <- PartyServer.lookup(character.party_id),
         :ok <- is_leader?(party, character),
         :ok <- target_already_in_party?(character, target) do
      send(target.session_pid, {:push, Packets.Party.invite(character)})
      session
    else
      {:error, notice_packet} ->
        push(session, notice_packet)
    end
  end

  defp is_leader?(party, character) do
    if party.leader_id == character.id do
      :ok
    else
      {:error, Packets.Party.notice(:not_leader, character)}
    end
  end

  defp target_already_in_party?(character, target) do
    case PartyServer.lookup(target.party_id) do
      {:ok, party} ->
        if Enum.count(party.members) > 1 do
          {:error, Packets.Party.notice(:unable_to_invite, character)}
        else
          :ok
        end

      :error ->
        :ok
    end
  end
end
