defmodule Ms2ex.GameHandlers.Party do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Packets
  alias Ms2ex.Schema
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
         {:ok, _party} <- PartyServer.call(character.party_id, :lookup) do
      case party_summon_item(character) do
        %Schema.Item{} = item ->
          recall_party(session, character, item)

        nil ->
          purchase_and_recall_party(session, character)
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
      Context.Wallets.debit(character, :merets, @party_summon_price)
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

  defp purchase_and_recall_party(session, character) do
    with item when not is_nil(item) <- Context.Items.drop_item(@party_summon_scroll_id, 1, 1),
        {:ok, result} <- purchase_party_summon(session, character, item),
        %Schema.Item{} = purchased_item <- purchased_item(result) do
      recall_party(session, character, purchased_item)
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

  defp recall_party(session, character, item) do
    consumed_item = Managers.Inventory.consume(item)
    push(session, Packets.InventoryItem.consume(consumed_item))

    with {:ok, party} <- PartyServer.call(character.party_id, :lookup) do
      Enum.each(party.members, &recall_member(&1, character))
    end

    session
  end

  defp recall_member(member, character) do
    with {:ok, live_member} <- Managers.Character.call(member.id, :lookup),
         true <- live_member.id != character.id,
         true <- Map.get(live_member, :online?, false),
         false <- Map.get(live_member, :dead?, false),
         true <- is_pid(Map.get(live_member, :field_pid)),
         true <- live_member.map_id != character.map_id do
      Managers.Field.change_field(
        live_member,
        character.map_id,
        character.position,
        character.rotation
      )
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
