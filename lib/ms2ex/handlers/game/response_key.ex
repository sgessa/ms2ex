defmodule Ms2ex.GameHandlers.ResponseKey do
  require Logger

  alias Ms2ex.{Characters, Net, Packets, Protobuf, Users}

  import Net.SessionHandler, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    account_id
    |> Net.SessionRegistry.lookup()
    |> verify_auth_data(packet, session)
  end

  defp verify_auth_data({:ok, session_data}, packet, session) do
    {token_a, packet} = get_int(packet)
    {token_b, _packet} = get_int(packet)

    with true <- token_a == session_data.token_a,
         true <- token_b == session_data.token_b do
      account = Users.get(session_data[:account_id])

      character =
        session_data[:character_id]
        |> Characters.get()
        |> Characters.load_equips()

      Logger.info(
        "Authorized connection to World #{session.name} for Account #{account.username}"
      )

      tick = Ms2ex.sync_ticks()

      inventory_tab_keys = Map.keys(Protobuf.InventoryTab.mapping())

      inventory_tabs =
        Enum.map(inventory_tab_keys, fn key ->
          Map.get(Protobuf.InventoryTab.mapping(), key)
        end)

      session
      |> Map.put(:account, account)
      |> Map.put(:character, character)
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
      _ -> verify_auth_data(false, packet, session)
    end
  end

  defp verify_auth_data(_session_data, _packet, session) do
    Logger.error("Unauthorized Connection to Channel Server")
    session
  end

  defp push_inventory_tab(session, []), do: session

  defp push_inventory_tab(session, [tab | tabs]) do
    session
    |> push(Packets.ItemInventory.reset(tab))
    |> push(Packets.ItemInventory.load(tab))
    |> push_inventory_tab(tabs)
  end
end
