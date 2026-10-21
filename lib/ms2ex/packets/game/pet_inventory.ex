defmodule Ms2ex.Packets.PetInventory do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Packets

  import Packets.PacketWriter

  @commands %{
    add: 0x0,
    remove: 0x1,
    update: 0x2,
    move: 0x3,
    load: 0x4,
    reset: 0x6
  }

  @impl true
  def commands, do: @commands

  @impl true
  def spec(command) do
    case command do
      0x0 ->
        [
          item_id: :int,
          item_uid: :long,
          slot: :short,
          rarity: :int,
          _name: :ustring,
          _item: {:bytes, 0}
        ]

      0x1 ->
        [item_uid: :long]

      0x2 ->
        [item_uid: :long, amount: :int]

      0x3 ->
        [dst_uid: :long, src_slot: :short, src_uid: :long, dst_slot: :short]

      0x4 ->
        [count: :short, _items: {:bytes, 0}]

      0x6 ->
        []

      _ ->
        []
    end
  end

  # the pet's item bag contents: the pet item rows it holds
  def load(items, character) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@commands.load)
      |> put_short(length(items))

    Enum.reduce(items, packet, fn item, packet ->
      packet
      |> put_int(item.item_id)
      |> put_long(item.id)
      |> put_short(item.inventory_slot)
      |> put_int(item.rarity)
      |> put_ustring()
      |> Packets.InventoryItem.put_item(item, character)
    end)
  end
end
