defmodule Ms2ex.GameHandlers.Party do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Packets
  alias Ms2ex.Managers.PartyServer
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
         {:ok, target} <- PartyServer.call(party.id, {:kick_member, target_id}) do
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
         true <- party.leader_id == character.id do
      PartyServer.broadcast(party.id, Packets.Party.set_leader(new_leader))
    end
  end

  # Summon Party: buy one party summon scroll from the party menu.
  defp handle_mode(0x1D, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         item when not is_nil(item) <- Context.Items.drop_item(@party_summon_scroll_id, 1, 1),
         {:ok, result} <- purchase_party_summon(character, item) do
      push_summon_scroll(session, result, character)
    else
      {:error, :insufficient_funds} ->
        :ok

      _reason ->
        :ok
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
      Context.Wallets.debit(character, :merets, @party_summon_price)
    end
  end

  defp purchase_party_summon(character, item) do
    premium? = Context.PremiumMemberships.active?(character.account_id)

    case if(premium?, do: {:ok, :premium}, else: charge_party_summon(character)) do
      {:ok, _wallet} ->
        add_party_summon(character, item, premium?)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_party_summon(character, item, premium?) do
    case Managers.Inventory.add_item(character, item) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        if not premium?, do: Context.Wallets.update(character, :merets, @party_summon_price)
        {:error, reason}
    end
  end

  defp push_summon_scroll(session, {:create, item}, character) do
    session
    |> push(Packets.InventoryItem.add_item({:create, item}, character))
    |> push(Packets.InventoryItem.mark_item_new(item))
  end

  defp push_summon_scroll(session, {:update, item}, _character) do
    session
    |> push(Packets.InventoryItem.update_item(item.id, item.amount))
    |> push(Packets.InventoryItem.mark_item_new(item))
  end

  defp push_summon_scroll(session, {:update_and_create, {_updated, _amount}, created}, character) do
    session
    |> push(Packets.InventoryItem.update_item(created.id, created.amount))
    |> push(Packets.InventoryItem.add_item({:create, created}, character))
    |> push(Packets.InventoryItem.mark_item_new(created))
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
