defmodule Ms2ex.GameHandlers.UseItem do
  alias Ms2ex.{Item, Items}
  alias Ms2ex.{CharacterManager, ChatStickers, Inventory, Packets}
  alias Ms2ex.GameHandlers.Helper.ItemBox

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {item_uid, packet} = get_long(packet)
    # {item_type, packet} = get_short(packet)

    with {:ok, character} <- CharacterManager.lookup(session.character_id),
         %Item{} = item <- Inventory.get(character, item_uid),
         item <- Items.load_metadata(item) do
      # session
      # |> open_box(item_type, item.metadata.content, packet)
      case item.metadata.function_name do
        "ChatEmoticonAdd" -> add_emoticon(session, character, item, packet)
        "OpenItemBox" -> open_box(session, character, item, packet)
        "SelectItemBox" -> select_item(session, character, item, packet)
        _ -> session
      end
    end
  end

  defp add_emoticon(session, character, item, _packet) do
    sticker_group_id = item.metadata.function_param

    with {:ok, _} <- ChatStickers.add(character, sticker_group_id) do
      consumed_item = Inventory.consume(item)

      session
      |> push(Packets.ChatSticker.add(item.item_id, sticker_group_id))
      |> push(Packets.InventoryItem.consume(consumed_item))
    end
  end

  defp open_box(session, character, item, _packet) do
    consumed_item = Inventory.consume(item)

    session
    |> ItemBox.open(character, item.metadata.content)
    |> push(Packets.InventoryItem.consume(consumed_item))
  end

  defp select_item(session, character, item, packet) do
    {index, _packet} = get_short(packet)
    index = index - 0x30

    contents = item.metadata.content

    if not (index < 0 or Enum.empty?(contents)) do
      consumed_item = Inventory.consume(item)
      selected_item = Enum.at(contents, index)

      session
      |> ItemBox.add_item(character, selected_item)
      |> push(Packets.InventoryItem.consume(consumed_item))
    end
  end
end
