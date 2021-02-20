defmodule Ms2ex.GameHandlers.UseItem do
  alias Ms2ex.{Inventory, Metadata, Packets, World}
  alias Ms2ex.GameHandlers.Helper.ItemBox

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  @open 0x0
  @select_item 0x1

  def handle(packet, session) do
    {item_uid, packet} = get_long(packet)
    {item_type, packet} = get_short(packet)

    with {:ok, character} <- World.get_character(session.world, session.character_id),
         %Inventory.Item{} = item <- Inventory.get(character, item_uid),
         item <- Metadata.Items.load(item),
         consumed_item <- Inventory.consume(item) do
      session
      |> push(Packets.InventoryItem.consume(consumed_item))
      |> open_box(item_type, item.metadata.content, packet)
    else
      _ -> session
    end
  end

  defp open_box(session, @open, content, _packet) do
    {:ok, character} = World.get_character(session.world, session.character_id)
    ItemBox.open(session, character, content)
  end

  defp open_box(session, @select_item, content, packet) do
    {index, _packet} = get_short(packet)
    index = index - 0x30

    if index < 0 do
      session
    else
      {:ok, character} = World.get_character(session.world, session.character_id)
      item = Enum.at(content, index)
      ItemBox.add_item(session, character, item)
    end
  end
end
