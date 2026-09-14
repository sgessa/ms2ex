defmodule Ms2ex.GameHandlers.UseItem do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.GameHandlers.Helper.ItemBox
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {item_uid, packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         %Schema.Item{} = item <- item_for_use(character, item_uid),
         item <- Context.Items.load_metadata(item) do
      case maybe_skip_tutorial(session, character, item) do
        :skipped ->
          session

        :continue ->
          dispatch_item_use(session, character, item, packet)
      end
    end
  end

  # Party Summon Scroll purchase
  defp item_for_use(character, 0) do
    character
    |> Managers.Inventory.all()
    |> Enum.find(&(&1.item_id == 20_300_053 and &1.amount > 0))
  end

  defp item_for_use(character, item_uid), do: Managers.Inventory.get(character, item_uid)

  # the job tutorial's skip item teleports a character standing on the
  # tutorial's start field straight to the skip destination
  defp maybe_skip_tutorial(session, character, item) do
    tutorial = Storage.Tables.Jobs.tutorial(character.job)

    with %{skip_item: skip_item, skip_field: skip_field, start_field: start_field}
         when skip_item > 0 and skip_field > 0 <- tutorial,
         true <- item.item_id == skip_item,
         true <- character.map_id == start_field do
      spawn_point = Storage.Maps.get_spawn(skip_field)
      consumed_item = Managers.Inventory.consume(item)

      push(session, Packets.InventoryItem.consume(consumed_item))

      Managers.Field.change_field(
        character,
        skip_field,
        spawn_point.position,
        spawn_point.rotation
      )

      :skipped
    else
      _ -> :continue
    end
  end

  defp dispatch_item_use(session, character, item, packet) do
    case item.metadata.function_name do
      "ChatEmoticonAdd" -> add_emoticon(session, character, item, packet)
      "VIPCoupon" -> use_premium_coupon(session, character, item)
      "RecallParty" -> recall_party(session, character, item)
      "AddAdditionalEffect" -> add_additional_effect(session, character, item)
      "OpenItemBox" -> ItemBox.open(session, character, item, 1, -1)
      "OpenItemBoxWithKey" -> ItemBox.open(session, character, item, 1, -1)
      "SelectItemBox" -> select_box(session, character, item, packet)
      _ -> maybe_use_bait(session, character, item)
    end
  end

  defp use_premium_coupon(session, character, item) do
    was_active = Context.PremiumMemberships.active?(character.account_id)

    with {:ok, period_hours} <- premium_coupon_period(item),
         {:ok, membership} <-
           Context.PremiumMemberships.extend_coupon(character.account_id, period_hours),
         consumed_item <- Managers.Inventory.consume(item) do
      push(session, Packets.InventoryItem.consume(consumed_item))
      code = if was_active, do: "s_vip_coupon_extend_msg", else: "s_vip_coupon_new_msg"
      push(session, Packets.Notice.message(code, 1 + 4))
      push(session, Packets.PremiumClub.activate(character, membership))

      Managers.Character.call(
        character,
        {:update, %{character | premium_time: DateTime.to_unix(membership.expires_at)}}
      )

      apply_premium_buffs(character)
    end

    session
  end

  defp recall_party(session, character, item) do
    consumed_item = Managers.Inventory.consume(item)
    push(session, Packets.InventoryItem.consume(consumed_item))

    recall_online_members(character)

    session
  end

  defp recall_online_members(character) do
    with {:ok, party} <- Managers.PartyServer.call(character.party_id, :lookup) do
      Enum.each(party.members, &recall_member(&1, character))
    end
  end

  defp recall_member(member, character) do
    with {:ok, live_member} <- Managers.Character.call(member.id, :lookup),
         true <- live_member.id != character.id,
         true <- Map.get(live_member, :online?, false),
         false <- Map.get(live_member, :dead?, false),
         true <- live_member.map_id != character.map_id do
      Managers.Field.change_field(
        live_member,
        character.map_id,
        character.position,
        character.rotation
      )
    end
  end

  defp premium_coupon_period(%Schema.Item{metadata: %{function_parameters: parameters}})
       when is_binary(parameters) do
    case Regex.run(~r/<v\s+period="(\d+)"\s*\/?\s*>/, parameters) do
      [_, period] -> {:ok, String.to_integer(period)}
      _ -> :error
    end
  end

  defp premium_coupon_period(_item), do: :error

  defp apply_premium_buffs(character) do
    Enum.each(Storage.Tables.PremiumClub.buffs(), fn {_id, %{id: buff_id, level: level}} ->
      Managers.Field.add_effect_buff(character, buff_id, level)
    end)
  end

  defp maybe_use_bait(session, character, %{metadata: %{property: %{tag: :fishing_lure}}} = item) do
    case Context.Fishing.use_bait_item(character, item) do
      :ok -> session
      _ -> session
    end
  end

  defp maybe_use_bait(session, _character, _item), do: session

  # the picked entry index arrives as a string after the item uid
  defp select_box(session, character, item, packet) do
    {index_str, _packet} = get_ustring(packet)

    index =
      case Integer.parse(index_str) do
        {value, _rest} -> value
        :error -> -1
      end

    ItemBox.open(session, character, item, 1, index)
  end

  defp add_emoticon(session, character, item, _packet) do
    sticker_group_id = item.metadata.function_param

    with {:ok, _} <- Context.ChatStickers.add(character, sticker_group_id) do
      consumed_item = Managers.Inventory.consume(item)

      session
      |> push(Packets.ChatSticker.add(item.item_id, sticker_group_id))
      |> push(Packets.InventoryItem.consume(consumed_item))
    end
  end

  defp add_additional_effect(session, character, item) do
    with parameters when is_binary(parameters) <- item.metadata[:function_parameters],
         [effect_id, effect_level] <- parse_effect_params(parameters),
         :ok <-
           Managers.Field.add_effect_buff(character, effect_id, effect_level) do
      consumed_item = Managers.Inventory.consume(item)
      push(session, Packets.InventoryItem.consume(consumed_item))
    else
      _ -> session
    end
  end

  defp parse_effect_params(parameters) do
    case String.split(parameters, ",") do
      [effect_id, effect_level] ->
        with {effect_id, ""} <- Integer.parse(effect_id),
             {effect_level, ""} <- Integer.parse(effect_level) do
          [effect_id, effect_level]
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
