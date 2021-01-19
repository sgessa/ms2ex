defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  require Logger

  alias Ms2ex.{Field, Net, Packets}
  alias Ms2ex.InventoryItems, as: Items

  # import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

  def handle(_packet, %{character: character} = session) do
    # {_, _packet} = get_int(packet)

    character = Items.load_equips(character)
    session = Map.put(session, :character, character)
    {:ok, field_pid} = Field.find_or_create(session)

    # item =
    #   Items.add_item(character, %Item{item_id: 40_100_001, slot_type: :none, tab_type: :catalyst})

    # item2 =
    #   Items.add_item(character, %Item{item_id: 40_100_001, slot_type: :none, tab_type: :catalyst})

    # item3 =
    #   Items.add_item(character, %Item{
    #     item_id: 20_302_228,
    #     amount: 3,
    #     slot_type: :none,
    #     tab_type: :misc
    #   })

    # const hotbar = session.player.gameOptions.getHotbarById(0);

    # if (hotbar) {
    #     session.send(KeyTablePacket.sendHotbars(session.player.gameOptions));
    # }

    session
    |> Map.put(:field_pid, field_pid)
    # |> push(Packets.ItemInventory.add_item(item))
    # |> push(Packets.ItemInventory.add_item(item2))
    # |> push(Packets.ItemInventory.add_item(item3))

    |> push(Packets.PlayerStats.bytes(character))
    |> push(Packets.StatPoints.bytes(character))
    |> push(Packets.Emotion.bytes())
  end
end
