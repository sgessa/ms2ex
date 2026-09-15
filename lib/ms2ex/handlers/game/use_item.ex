defmodule Ms2ex.GameHandlers.UseItem do
  alias Ms2ex.Managers
  alias Ms2ex.Enums
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
    dispatch_item_use(item.metadata.function_name, session, character, item, packet)
  end

  defp dispatch_item_use("ChatEmoticonAdd", session, character, item, packet),
    do: add_emoticon(session, character, item, packet)

  defp dispatch_item_use("VIPCoupon", session, character, item, _packet),
    do: use_premium_coupon(session, character, item)

  defp dispatch_item_use("TitleScroll", session, character, item, _packet),
    do: use_title_scroll(session, character, item)

  defp dispatch_item_use("StoryBook", session, character, item, _packet),
    do: use_story_book(session, character, item)

  defp dispatch_item_use("QuestScroll", session, character, item, _packet),
    do: use_quest_scroll(session, character, item)

  defp dispatch_item_use("ExpandInven", session, character, item, _packet),
    do: use_inventory_expansion(session, character, item)

  defp dispatch_item_use("RecallParty", session, character, item, _packet),
    do: recall_party(session, character, item)

  defp dispatch_item_use("AddAdditionalEffect", session, character, item, _packet),
    do: add_additional_effect(session, character, item)

  defp dispatch_item_use(function, session, character, item, _packet)
       when function in ["OpenItemBox", "OpenItemBoxWithKey"],
       do: ItemBox.open(session, character, item, 1, -1)

  defp dispatch_item_use("SelectItemBox", session, character, item, packet),
    do: select_box(session, character, item, packet)

  defp dispatch_item_use(_function, session, character, item, _packet),
    do: maybe_use_bait(session, character, item)

  defp use_title_scroll(session, character, item) do
    with {title_id, ""} <- Integer.parse(item.metadata.function_parameters || ""),
         false <- title_id in Context.Characters.list_titles(character),
         {:ok, _title} <- Context.Characters.learn_title(character, title_id),
         consumed_item <- Managers.Inventory.consume(item) do
      push(session, Packets.UserEnv.add_title(title_id))
      push(session, Packets.InventoryItem.consume(consumed_item))
    else
      _ -> :ok
    end

    session
  end

  defp use_story_book(session, _character, item) do
    with {story_book_id, ""} <- Integer.parse(item.metadata.function_parameters || ""),
         consumed_item <- Managers.Inventory.consume(item) do
      push(session, Packets.StoryBook.load(story_book_id))
      push(session, Packets.InventoryItem.consume(consumed_item))
    else
      _ -> :ok
    end

    session
  end

  defp use_quest_scroll(session, character, item) do
    quest_ids = quest_scroll_ids(item.metadata.function_parameters)

    if quest_ids != [] do
      results = Enum.map(quest_ids, &start_quest(character, &1))

      if Enum.all?(results, &match?({:ok, _}, &1)) do
        consumed_item = Managers.Inventory.consume(item)
        push(session, Packets.InventoryItem.consume(consumed_item))
        push(session, Packets.ItemUse.quest_scroll(item.item_id))
      end
    end

    session
  end

  defp use_inventory_expansion(session, character, item) do
    case parse_inventory_expansion(item.metadata.function_parameters) do
      {amount, tab} when amount > 0 and not is_nil(tab) ->
        case Managers.Inventory.expand_tab(character, tab, amount) do
          %Schema.InventoryTab{slots: slots} ->
            consumed_item = Managers.Inventory.consume(item)

            session
            |> push(Packets.ItemUse.expand_inventory())
            |> push(Packets.InventoryItem.load_tab(tab, slots))
            |> push(Packets.InventoryItem.consume(consumed_item))

          _ ->
            push(session, Packets.ItemUse.max_inventory())
        end

      _ ->
        session
    end
  end

  defp quest_scroll_ids(parameters) when is_binary(parameters) do
    case Regex.run(~r/questID[=:]([^,;]+)/i, parameters, capture: :all_but_first) do
      [ids] -> parse_ids(ids)
      _ -> parse_ids(parameters)
    end
  end

  defp quest_scroll_ids(_parameters), do: []

  defp parse_ids(ids),
    do: ids |> String.split([",", "|"], trim: true) |> Enum.flat_map(&parse_id/1)

  defp parse_id(id) do
    case Integer.parse(String.trim(id)) do
      {value, ""} -> [value]
      _ -> []
    end
  end

  defp start_quest(character, quest_id) do
    case Storage.Quests.get_meta(quest_id) do
      quest when is_map(quest) -> Managers.Quest.start(character, quest)
      _ -> {:error, :quest_not_found}
    end
  end

  defp parse_inventory_expansion(parameters) when is_binary(parameters) do
    case String.split(parameters, ",", trim: true) do
      [amount, tab] ->
        with {amount, ""} <- Integer.parse(String.trim(amount)),
             tab when not is_nil(tab) <- inventory_tab(String.trim(tab)) do
          {amount, tab}
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_inventory_expansion(_parameters), do: nil

  defp inventory_tab(tab) do
    case %{
           "game" => :gear,
           "mastery" => :life_skill,
           "summon" => :mount,
           "misc" => :misc,
           "skin" => :outfit,
           "gem" => :gemstone,
           "material" => :catalyst,
           "quest" => :quest,
           "life" => :fishing_music,
           "coin" => :currency,
           "pet" => :pets,
           "activeSkill" => :consumable,
           "badge" => :badge,
           "piece" => :fragment
         }[tab] do
      nil ->
        case Integer.parse(tab) do
          {value, ""} -> Enums.InventoryTab.get_key(value)
          _ -> :invalid_enum
        end

      value ->
        value
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
