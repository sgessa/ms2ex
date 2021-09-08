defmodule Ms2ex.GameHandlers.ResponseKey do
  require Logger

  alias Ms2ex.{Characters, Inventory, LoginHandlers, Metadata, Net, Packets, Sessions, World}

  import Net.Session, only: [push: 2]
  import Packets.PacketReader
  import Ms2ex.GameHandlers.Helper.Session, only: [init_character: 1]

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    with {:ok, auth_data} = Sessions.lookup(account_id),
         {:ok, %{account: account} = session} <-
           LoginHandlers.ResponseKey.verify_auth_data(auth_data, packet, session) do
      Sessions.register(account.id, auth_data)

      character =
        auth_data[:character_id]
        |> Characters.get()
        |> Characters.load_equips()
        |> Characters.preload([:friends, :stats])
        |> Map.put(:channel_id, session.channel_id)
        |> Map.put(:session_pid, session.pid)

      World.monitor_character(character)

      tick = Ms2ex.sync_ticks()

      {:ok, map} = Metadata.Maps.lookup(character.map_id)
      spawn = List.first(map.spawns)

      character = %{
        character
        | position: spawn.coord,
          rotation: spawn.rotation,
          safe_position: spawn.coord,
          online?: true
      }

      World.update_character(character)

      character = Characters.preload(character, friends: :rcpt)
      %{friends: friends, map_id: map_id, position: position, rotation: rotation} = character

      init_character(character)

      titles = Characters.list_titles(character)
      wallet = Characters.get_wallet(character)

      session
      |> Map.put(:character_id, character.id)
      |> push(Packets.MoveResult.bytes())
      |> push(Packets.LoginRequired.bytes(account.id))
      |> push(Packets.Friend.start_list())
      |> push(Packets.Friend.load_list(friends))
      |> push(Packets.Friend.end_list(Enum.count(friends)))
      |> push(Packets.ResponseTimeSync.init(0x1, tick))
      |> push(Packets.ResponseTimeSync.init(0x3, tick))
      |> push(Packets.ResponseTimeSync.init(0x2, tick))
      |> Map.put(:server_tick, tick)
      |> push(Packets.RequestClientSyncTick.bytes(tick))
      |> push(Packets.DynamicChannel.bytes())
      |> push(Packets.ServerEnter.bytes(session.channel_id, character, wallet))
      |> push(Packets.SyncNumber.bytes())
      |> push(Packets.Prestige.bytes(character))
      |> push_inventory_tab(Inventory.list_tabs(character))
      |> push(Packets.MarketInventory.count(0))
      |> push(Packets.MarketInventory.start_list())
      |> push(Packets.MarketInventory.end_list())
      |> push(Packets.FurnishingInventory.start_list())
      |> push(Packets.FurnishingInventory.end_list())
      |> push(Packets.UserEnv.set_titles(titles))
      |> push(Packets.UserEnv.set_mode(0x4))
      |> push(Packets.UserEnv.set_mode(0x5))
      |> push(Packets.UserEnv.set_mode(0x8, 2))
      |> push(Packets.UserEnv.set_mode(0x9))
      |> push(Packets.UserEnv.set_mode(0xA))
      |> push(Packets.UserEnv.set_mode(0xC))
      |> push(Packets.Fishing.load_log())
      |> push(Packets.KeyTable.request())
      |> push(Packets.FieldEntrance.bytes())
      |> push(Packets.RequestFieldEnter.bytes(map_id, position, rotation))
    else
      _ -> session
    end
  end

  defp push_inventory_tab(session, []), do: session

  defp push_inventory_tab(session, [inventory_tab | tabs]) do
    items = Inventory.list_tab_items(inventory_tab.character_id, inventory_tab.tab)

    session
    |> push(Packets.InventoryItem.reset_tab(inventory_tab.tab))
    |> push(Packets.InventoryItem.load_tab(inventory_tab.tab, inventory_tab.slots))
    |> push(Packets.InventoryItem.load_items(inventory_tab.tab, items))
    |> push_inventory_tab(tabs)
  end
end
