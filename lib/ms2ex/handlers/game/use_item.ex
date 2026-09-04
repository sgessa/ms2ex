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
         %Schema.Item{} = item <- Managers.Inventory.get(character, item_uid),
         item <- Context.Items.load_metadata(item) do
      case maybe_skip_tutorial(session, character, item) do
        :skipped ->
          session

        :continue ->
          dispatch_item_use(session, character, item, packet)
      end
    end
  end

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

      Context.Field.change_field(
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
      "AddAdditionalEffect" -> add_additional_effect(session, character, item)
      "OpenItemBox" -> ItemBox.open(session, character, item, 1, -1)
      "OpenItemBoxWithKey" -> ItemBox.open(session, character, item, 1, -1)
      "SelectItemBox" -> select_box(session, character, item, packet)
      _ -> session
    end
  end

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
           Context.Field.call(character, {:add_effect_buff, effect_id, effect_level, character}) do
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
