defmodule Ms2ex.GameHandlers.Party do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Managers.PartySearchServer
  alias Ms2ex.Types

  import Packets.PacketReader
  import Ms2ex.GameHandlers.Helper.Party
  import Ms2ex.Net.SenderSession, only: [push: 2, run: 2]

  @party_summon_scroll_id 20_300_053
  @party_summon_price 30

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Invite
  defp handle_mode(0x1, packet, session) do
    {target_name, _packet} = get_ustring(packet)

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    target =
      case Managers.Character.lookup_by_name(target_name) do
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

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    case PartyServer.call(party_id, :lookup) do
      {:ok, party} ->
        handle_invitation(session, response, party, character)

      _ ->
        push(session, Packets.Party.notice(:party_not_found, character))
    end
  end

  # Leave
  defp handle_mode(0x3, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, _party} <- PartyServer.call(character.party_id, :lookup) do
      run(session, fn -> PartyServer.unsubscribe(character.party_id) end)

      PartyServer.call(character.party_id, {:remove_member, character})

      character = %{character | party_id: nil}
      Managers.Character.call(character, {:update, character})

      push(session, Packets.Party.leave(character))
    end
  end

  # Kick
  defp handle_mode(0x4, packet, session) do
    {target_id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, party} <- PartyServer.call(character.party_id, :lookup),
         true <- Types.Party.leader?(party, character),
         {:ok, target} <- PartyServer.call(party.id, {:kick_member, character.id, target_id}) do
      if target.online? do
        run(target, fn -> PartyServer.unsubscribe(party.id) end)
      end

      Managers.Character.call(target, {:update, %{target | party_id: nil}})
    end
  end

  # Promote Leader
  defp handle_mode(0x11, packet, session) do
    {target_name, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, new_leader} <- Managers.Character.lookup_by_name(target_name),
         {:ok, party} <- PartyServer.call(character.party_id, :lookup),
         true <- party.leader_id == character.id,
         true <- Types.Party.in_party?(party, new_leader),
         {:ok, _party} <- PartyServer.call(party.id, {:set_leader, character.id, new_leader.id}) do
      :ok
    end
  end

  # Join Party Finder listing
  defp handle_mode(0x17, packet, session) do
    {party_id, packet} = get_int(packet)
    {_leader_name, packet} = get_ustring(packet)
    {listing_id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         nil <- character.party_id,
         listing when not is_nil(listing) <-
           PartySearchServer.call({:lookup, listing_id}),
         true <- listing.party_id == party_id,
         {:ok, party} <- PartyServer.call(party_id, :lookup),
         true <- Enum.count(party.members) < listing.size do
      if listing.no_approval do
        PartyServer.broadcast(party.id, Packets.Party.join(character))
        updated = %{character | party_id: party.id}
        Managers.Character.call(updated, {:update, updated})
        {:ok, party} = PartyServer.call(party.id, {:update_member, updated})
        run(session, fn -> PartyServer.subscribe(party.id) end)
        push(session, Packets.Party.create(party))
      else
        leader = Types.Party.get_leader(party)
        push(leader, Packets.Party.join_request(character))
        push(session, Packets.Party.notice(:request_to_join, character))
      end
    else
      nil -> push(session, Packets.PartySearch.error(:server_db))
      false -> push(session, Packets.PartySearch.error(:server_db))
      _ -> :ok
    end

    session
  end

  # Summon Party: the party menu's recall button. Consumes a held recall
  # scroll (buying one for merets first if none) and sends every eligible
  # member a follow prompt; members who accept are pulled to the caster's
  # field by the RecallUser handler. The leader and prompt-target checks
  # run before anything is consumed or charged.
  defp handle_mode(0x1D, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, party} <- PartyServer.call(character.party_id, :lookup),
         true <- party.leader_id == character.id,
         nil <- party.recall,
         targets when targets != [] <- recall_targets(party, character) do
      caster = %{id: character.id, name: character.name, map_id: character.map_id}

      case party_summon_item(character) do
        %Schema.Item{} = item ->
          recall_party(session, party, caster, item, targets)

        nil ->
          purchase_and_recall_party(session, party, caster, character, targets)
      end
    else
      _ -> session
    end
  end

  # Start Vote Kick
  defp handle_mode(0x2D, packet, session) do
    {target_id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, party} <- PartyServer.call(character.party_id, :lookup) do
      cond do
        Enum.count(party.members) < 4 ->
          push(
            session,
            Packets.Party.notice(:insufficient_memmber_count_for_kick_vote, character)
          )

        target_id == character.id ->
          :ok

        is_nil(Types.Party.get_member(party, target_id)) ->
          :ok

        true ->
          PartyServer.cast(party.id, {:start_vote_kick, character, target_id})
      end
    end
  end

  # Start Ready Check
  defp handle_mode(0x2E, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, party} <- PartyServer.call(character.party_id, :lookup) do
      if Types.Party.leader?(party, character) do
        PartyServer.cast(party.id, :start_ready_check)
      end
    end
  end

  # Handle Ready Check
  defp handle_mode(0x30, packet, session) do
    {_n, packet} = get_int(packet)
    {resp, _packet} = get_bool(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, party} <- PartyServer.call(character.party_id, :lookup) do
      cond do
        party.vote_kick ->
          PartyServer.cast(party.id, {:vote_kick, character, resp})

        Enum.member?(party.ready_check, character.id) ->
          :ok

        true ->
          PartyServer.cast(party.id, {:ready_check, character, resp})
      end
    end
  end

  defp handle_mode(_, _packet, session), do: session

  defp charge_party_summon(character) do
    if Context.PremiumMemberships.active?(character.account_id) do
      {:ok, :premium}
    else
      Managers.Wallet.debit(character, :merets, @party_summon_price)
    end
  end

  defp purchase_party_summon(session, character, item) do
    premium? = Context.PremiumMemberships.active?(character.account_id)

    case if(premium?, do: {:ok, :premium}, else: charge_party_summon(character)) do
      {:ok, _wallet} ->
        add_party_summon(character, item, premium?)

      {:error, reason} ->
        if reason == :insufficient_funds,
          do: push(session, Packets.Party.notice(:insufficient_merets, character))

        {:error, reason}
    end
  end

  defp purchase_and_recall_party(session, party, caster, character, targets) do
    with item when not is_nil(item) <- Context.Items.drop_item(@party_summon_scroll_id, 1, 1),
         {:ok, result} <- purchase_party_summon(session, character, item),
         %Schema.Item{} = purchased_item <- purchased_item(result) do
      recall_party(session, party, caster, purchased_item, targets)
    else
      _ -> session
    end
  end

  defp purchased_item({:create, item}), do: item
  defp purchased_item({:update, item}), do: item
  defp purchased_item({:update_and_create, {_updated, _amount}, item}), do: item
  defp purchased_item(_result), do: nil

  defp party_summon_item(character) do
    character
    |> Managers.Inventory.all()
    |> Enum.find(&(&1.item_id == @party_summon_scroll_id and &1.amount > 0))
  end

  defp recall_party(session, party, caster, item, targets) do
    consumed_item = Managers.Inventory.consume(item)
    push(session, Packets.InventoryItem.consume(consumed_item))

    PartyServer.call(party.id, {:start_recall, caster, targets})

    session
  end

  # A follow prompt goes to every live party member on a different field:
  # online, not dead, in a field, and not already on the caster's field.
  # Resolved here so the party manager receives only what it needs (member
  # id and session pid); the session process can safely call the character
  # managers.
  defp recall_targets(party, caster) do
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

  defp add_party_summon(character, item, premium?) do
    case Managers.Inventory.add_item(character, item) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        if not premium?, do: Managers.Wallet.earn(character, :merets, @party_summon_price)
        {:error, reason}
    end
  end

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
        {:ok, party} = PartyServer.call(character.party_id, {:update_member, character})

        Managers.Character.call(character, {:update, character})
        run(session, fn -> PartyServer.subscribe(party.id) end)

        push(session, Packets.Party.create(party))

        for m <- party.members do
          PartyServer.broadcast(party.id, Packets.Party.update_hitpoints(m))
        end
    end
  end
end
