defmodule Ms2ex.GameHandlers.Helper.Party do
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Managers.PartyManager
  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Types

  import Ms2ex.Net.SenderSession, only: [push: 2, run: 2]

  def create_party(session, character, %Ms2ex.Net.Session{character_id: target_id}) do
    case Managers.Character.call(target_id, :lookup) do
      {:ok, target} -> create_party(session, character, target)
      _ -> :ok
    end
  end

  def create_party(session, character, %{party_id: nil} = target) do
    {:ok, party} = PartyManager.create(character)

    character = %{character | party_id: party.id}
    Managers.Character.call(character, {:update, character})

    run(session, fn -> PartyServer.subscribe(party.id) end)

    push(target, Packets.Party.invite(character))
    push(session, Packets.Party.create(party))
  end

  def create_party(session, character, %{party_id: target_party_id} = target) do
    {:ok, target_party} = PartyServer.call(target_party_id, :lookup)

    if Enum.count(target_party.members) == 1 do
      {:ok, party} = PartyManager.create(character)

      character = %{character | party_id: party.id}
      Managers.Character.call(character, {:update, character})

      run(session, fn -> PartyServer.subscribe(party.id) end)
      push(target, Packets.Party.invite(character))
      push(character, Packets.Party.create(party))
    else
      leader = Types.Party.get_leader(target_party)
      push(leader, Packets.Party.join_request(character))
      push(character, Packets.Party.notice(:request_to_join, target))
    end
  end

  def invite_to_party(character, target) do
    with {:ok, party} <- PartyServer.call(character.party_id, :lookup),
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
    case PartyServer.call(target.party_id, :lookup) do
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

  # The fields of the summoning member that the party manager needs to run
  # a recall; full character structs never cross into party state.
  def recall_caster(character) do
    %{id: character.id, name: character.name, map_id: character.map_id}
  end

  # A follow prompt goes to every live party member on a different field:
  # online, not dead, in a field, and not already on the caster's field.
  # Resolved here so the party manager receives only what it needs (member
  # id and session pid); the session process can safely call the character
  # managers.
  def recall_targets(party, caster) do
    party.members
    |> Enum.reject(&(&1.id == caster.id))
    |> Enum.flat_map(fn member ->
      with true <- Map.get(member, :online?, false),
           {:ok, live} <- Managers.Character.call(member.id, :lookup),
           false <- Map.get(live, :dead?, false),
           true <- is_pid(Map.get(live, :field_pid)),
           false <- live.field_pid == caster.field_pid do
        [%{id: live.id, sender_session_pid: live.sender_session_pid}]
      else
        _ -> []
      end
    end)
  end
end
