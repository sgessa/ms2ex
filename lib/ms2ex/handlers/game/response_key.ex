defmodule Ms2ex.GameHandlers.ResponseKey do
  require Logger

  alias Ms2ex.{
    Characters,
    CharacterManager,
    Inventory,
    LoginHandlers,
    Net,
    Packets,
    PartyManager,
    PartyServer,
    SessionManager,
    Wallets,
    World,
    Storage
  }

  alias Ms2ex.Structs.Coord

  import Net.SenderSession, only: [push: 2, run: 2]
  import Packets.PacketReader
  import Ms2ex.GameHandlers.Helper.Session, only: [init_character: 1]

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    with {:ok, auth_data} = SessionManager.lookup(account_id),
         {:ok, %{account: account} = session} <-
           LoginHandlers.ResponseKey.verify_auth_data(auth_data, packet, session) do
      SessionManager.register(account.id, auth_data)
      run(session, fn -> World.subscribe() end)

      character =
        auth_data[:character_id]
        |> Characters.get()
        |> Characters.load_equips()
        |> Characters.preload([:friends, :stats])
        |> Characters.load_skills()
        |> Map.put(:channel_id, session.channel_id)
        |> Map.put(:session_pid, session.pid)
        |> Map.put(:sender_session_pid, session.sender_pid)

      tick = Ms2ex.sync_ticks()

      character = character |> set_spawn_position() |> maybe_set_party()

      CharacterManager.start(character)
      CharacterManager.monitor(character)

      character = Characters.preload(character, friends: :rcpt)
      init_character(character)

      titles = Characters.list_titles(character)

      account_wallet = Wallets.find(account)
      character_wallet = Wallets.find(character)

      %{friends: friends, field_id: field_id, position: position, rotation: rotation} = character

      send(self(), {:update, %{character_id: character.id, server_tick: tick}})

      session
      |> push(Packets.MoveResult.bytes())
      |> push(Packets.LoginRequired.bytes(account.id))
      |> push(Packets.Friend.start_list())
      |> push(Packets.Friend.load_list(friends))
      |> push(Packets.Friend.end_list(Enum.count(friends)))
      |> push(Packets.ResponseTimeSync.init(0x1, tick))
      |> push(Packets.ResponseTimeSync.init(0x3, tick))
      |> push(Packets.ResponseTimeSync.init(0x2, tick))
      |> push(Packets.RequestClientSyncTick.bytes(tick))
      |> push(Packets.DynamicChannel.bytes())
      |> push(Packets.ServerEnter.bytes(character, account_wallet, character_wallet))
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
      |> push(Packets.RequestFieldEnter.bytes(field_id, position, rotation))
      |> push_party(character)
    end
  end

  defp maybe_set_party(character) do
    case PartyManager.lookup(character) do
      {:ok, party_id} ->
        character = %{character | party_id: party_id}
        PartyServer.update_member(character)
        character

      _ ->
        character
    end
  end

  defp set_spawn_position(character) do
    spawn_point = Storage.MapEntity.Maps.get_spawn(character.field_id)

    spawn_point = %{
      position: struct(Coord, Map.get(spawn_point, :position, %{})),
      rotation: struct(Coord, Map.get(spawn_point, :rotation, %{}))
    }

    %{
      character
      | position: spawn_point.position,
        safe_position: spawn_point.position,
        rotation: spawn_point.rotation,
        online?: true
    }
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

  defp push_party(session, character) do
    party = PartyServer.lookup!(character.party_id)

    if party do
      push(session, Packets.Party.create(party, false))

      PartyServer.broadcast_from(
        session.sender_pid,
        party.id,
        Packets.Party.update_hitpoints(character)
      )

      for m <- party.members, m.id != character.id do
        push(session, Packets.Party.update_hitpoints(m))
      end
    end
  end
end
