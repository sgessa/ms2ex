defmodule Ms2ex.GameHandlers.ResponseKey do
  require Logger

  alias Ms2ex.{Characters, LoginHandlers, Metadata, Net, Packets, Registries}

  import Net.SessionHandler, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    with {:ok, auth_data} = Registries.Sessions.lookup(account_id),
         {:ok, %{account: account} = session} <-
           LoginHandlers.ResponseKey.verify_auth_data(auth_data, packet, session) do
      character =
        auth_data[:character_id]
        |> Characters.get()
        |> Characters.load_equips()
        |> Map.put(:channel_id, session.channel_id)
        |> Map.put(:session_pid, session.pid)
        |> Registries.Characters.update()

      Registries.Characters.register_name(character)

      tick = Ms2ex.sync_ticks()

      inventory_tab_keys = Map.keys(Metadata.InventoryTab.mapping())

      inventory_tabs =
        Enum.map(inventory_tab_keys, fn key ->
          Map.get(Metadata.InventoryTab.mapping(), key)
        end)

      session
      |> Map.put(:character_id, character.id)
      |> push(Packets.MoveResult.bytes())
      |> push(Packets.LoginRequired.bytes(account.id))
      |> push(Packets.BuddyList.start_list())
      |> push(Packets.BuddyList.end_list())
      |> push(Packets.ResponseTimeSync.init(0x1, tick))
      |> push(Packets.ResponseTimeSync.init(0x3, tick))
      |> push(Packets.ResponseTimeSync.init(0x2, tick))
      |> Map.put(:server_tick, tick)
      |> push(Packets.RequestClientSyncTick.bytes(tick))
      |> push(Packets.DynamicChannel.bytes())
      |> push(Packets.ServerEnter.bytes(session.channel_id, character))
      |> push(Packets.SyncNumber.bytes())
      |> push(Packets.Prestige.bytes(character))
      |> push_inventory_tab(inventory_tabs)
      |> push(Packets.MarketInventory.count(0))
      |> push(Packets.MarketInventory.start_list())
      |> push(Packets.MarketInventory.end_list())
      |> push(Packets.FurnishingInventory.start_list())
      |> push(Packets.FurnishingInventory.end_list())
      |> push(Packets.UserEnv.set_titles())
      |> push(Packets.UserEnv.set_mode(0x4))
      |> push(Packets.UserEnv.set_mode(0x5))
      |> push(Packets.UserEnv.set_mode(0x8, 2))
      |> push(Packets.UserEnv.set_mode(0x9))
      |> push(Packets.UserEnv.set_mode(0xA))
      |> push(Packets.UserEnv.set_mode(0xC))
      |> push(Packets.Fishing.load_log())
      |> push(Packets.KeyTable.request())
      |> push(Packets.FieldEntrance.bytes())
      |> push(Packets.RequestFieldEnter.bytes(character))
    else
      _ -> session
    end
  end

  defp push_inventory_tab(session, []), do: session

  defp push_inventory_tab(session, [tab | tabs]) do
    session
    |> push(Packets.ItemInventory.reset(tab))
    |> push(Packets.ItemInventory.load(tab))
    |> push_inventory_tab(tabs)
  end
end
