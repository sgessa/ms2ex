defmodule Ms2ex.GameHandlers.Helper.Party do
  alias Ms2ex.{Managers, Packets, PartyManager, PartyServer, Types}

  import Ms2ex.Net.SenderSession, only: [push: 2, run: 2]

  def create_party(session, character, %{party_id: nil} = target) do
    {:ok, party} = PartyManager.create(character)

    character = %{character | party_id: party.id}
    Managers.Character.update(character)

    run(session, fn -> PartyServer.subscribe(party.id) end)

    push(target, Packets.Party.invite(character))
    push(session, Packets.Party.create(party))
  end

  def create_party(character, %{party_id: target_party_id} = target) do
    {:ok, target_party} = PartyServer.lookup(target_party_id)

    if Enum.count(target_party.members) == 1 do
      {:ok, party} = PartyManager.create(character)

      character = %{character | party_id: party.id}
      Managers.Character.update(character)

      push(target, Packets.Party.invite(character))
      push(character, Packets.Party.create(party))
    else
      leader = Types.Party.get_leader(target_party)
      push(leader, Packets.Party.join_request(character))
      push(character, Packets.Party.notice(:request_to_join, target))
    end
  end

  def invite_to_party(character, target) do
    with {:ok, party} <- PartyServer.lookup(character.party_id),
         :ok <- leader?(party, character),
         :ok <- target_already_in_party?(character, target) do
      push(target, Packets.Party.invite(character))
    else
      {:error, notice_packet} ->
        push(character, notice_packet)
    end
  end

  defp leader?(party, character) do
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
