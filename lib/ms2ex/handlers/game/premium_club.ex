defmodule Ms2ex.GameHandlers.PremiumClub do
  require Logger

  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Open
  defp handle_mode(0x1, _packet, session) do
    push(
      session,
      Packets.PremiumClub.load_claimed(Context.PremiumMemberships.claimed(session.account.id))
    )
  end

  # Claim Items
  defp handle_mode(0x2, packet, session) do
    {benefit_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         true <- Context.PremiumMemberships.active?(session.account.id),
         %{item_id: item_id, amount: amount, rarity: rarity} <-
           Storage.Tables.PremiumClub.benefit(benefit_id),
         true <- benefit_id not in Context.PremiumMemberships.claimed(session.account.id),
         %Schema.Item{} = item <- Context.Items.drop_item(item_id, rarity, amount),
         {:ok, result} <- Managers.Inventory.add_item(character, item),
         {:ok, _claimed} <- Context.PremiumMemberships.claim(session.account.id, benefit_id) do
      session
      |> push(Packets.PremiumClub.claim_item(benefit_id))
      |> push(inventory_packet(result, character))
    else
      reason ->
        Logger.warning("Premium Club purchase rejected: #{inspect(reason)}")
        :ok
    end
  end

  # Open Purchase Window
  defp handle_mode(0x3, _packet, session) do
    push(session, Packets.PremiumClub.show_purchase_window())
  end

  # Purchase Membership
  defp handle_mode(0x4, packet, session) do
    {package_id, _packet} = get_int(packet)

    with %{
           disabled: false,
           start_date: start_date,
           end_date: end_date,
           price: price,
           period: period,
           bonus_items: bonus_items
         } <- Storage.Tables.PremiumClub.package(package_id),
         true <- available?(start_date, end_date),
         {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         was_active <- Context.PremiumMemberships.active?(character.account_id),
         {:ok, {_wallet, membership}} <-
           Context.PremiumMemberships.purchase(character, price, period) do
      deliver_bonus_items(character, bonus_items)

      apply_premium_buffs(character)
      notify_membership_change(character, membership, was_active)
      sync_premium_time(character, membership)

      session
      |> push(Packets.PremiumClub.purchase_membership(package_id))
    else
      _ -> :ok
    end
  end

  defp available?(start_date, end_date) do
    now = DateTime.to_unix(DateTime.utc_now())
    (start_date == 0 or now >= start_date) and (end_date == 0 or now <= end_date)
  end

  defp deliver_bonus_items(character, items) do
    Enum.each(items, &deliver_bonus_item(character, &1))
  end

  defp deliver_bonus_item(character, %{
         item_id: item_id,
         amount: amount,
         rarity: rarity,
         period: period
       }) do
    item = Context.Items.drop_item(item_id, rarity, amount)

    if item, do: deliver_item(character, expire_item(item, period))
  end

  defp expire_item(item, period) when period > 0,
    do: %{item | expires_at: DateTime.add(DateTime.utc_now(), period, :day)}

  defp expire_item(item, _period), do: item

  defp deliver_item(character, item) do
    case Managers.Inventory.add_item(character, item) do
      {:ok, result} ->
        push(character, Packets.InventoryItem.add_item(result, character))
        push(character, Packets.InventoryItem.mark_item_new(new_inventory_item(result)))

      _ ->
        Context.Mails.send_system_mail(character.id, "", "50000000", items: [item])
    end
  end

  defp apply_premium_buffs(character) do
    {:ok, character} = Managers.Character.call(character.id, :lookup)

    Enum.each(Storage.Tables.PremiumClub.buffs(), fn {_id, %{id: buff_id, level: level}} ->
      Context.Field.call(character, {:add_effect_buff, buff_id, level, character})
    end)

    case Managers.PartyServer.lookup(character.party_id) do
      {:ok, party} ->
        Enum.each(party.members, &apply_party_buff(character, &1))

      _ ->
        :ok
    end
  end

  defp apply_party_buff(_character, %{id: id}) when id == nil, do: :ok

  defp apply_party_buff(character, %{id: id}) when id != character.id do
    with {:ok, member} <- Managers.Character.call(id, :lookup) do
      Context.Field.call(member, {:add_effect_buff_for, 100_000_045, 1, character, member})
    end
  end

  defp apply_party_buff(_character, _member), do: :ok

  defp notify_membership_change(character, membership, was_active) do
    code = if was_active, do: "s_vip_coupon_extend_msg", else: "s_vip_coupon_new_msg"
    push(character, Packets.Notice.message(code, 1 + 4))
    push(character, Packets.PremiumClub.activate(character, membership))
  end

  defp sync_premium_time(character, membership) do
    Managers.Character.call(
      character,
      {:update, %{character | premium_time: DateTime.to_unix(membership.expires_at)}}
    )
  end

  defp new_inventory_item({_status, item}), do: item

  defp inventory_packet({:create, item}, character),
    do: Packets.InventoryItem.add_item({:create, item}, character)

  defp inventory_packet({:update, item}, _character),
    do: Packets.InventoryItem.update_item(item.id, item.amount)

  defp inventory_packet({:update_and_create, {_updated, _amount}, created}, character),
    do: Packets.InventoryItem.add_item({:create, created}, character)
end
