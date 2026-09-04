defmodule Ms2ex.GameHandlers.ResponseKey do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.LoginHandlers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Managers.PartyManager
  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Managers.Session
  alias Ms2ex.Storage

  import Net.SenderSession, only: [push: 2, run: 2]
  import Packets.PacketReader
  import Ms2ex.GameHandlers.Helper.Session, only: [init_character: 1]

  def handle(packet, session) do
    {account_id, packet} = get_long(packet)

    with {:ok, auth_data} <- Session.lookup(account_id),
         {:ok, %{account: account} = session} <-
           LoginHandlers.ResponseKey.verify_auth_data(auth_data, packet, session) do
      Session.register(account.id, auth_data)
      run(session, fn -> Context.World.subscribe() end)

      character =
        auth_data[:character_id]
        |> Context.Characters.get()
        |> Map.put(:channel_id, session.channel_id)
        |> Map.put(:session_pid, session.pid)
        |> Map.put(:sender_session_pid, session.sender_pid)

      # the inventory manager must own the item rows before anything reads
      # them: every Context.Inventory/Equips call below goes through it
      :ok = Managers.Inventory.start(character)

      character =
        character
        |> Map.put(:equips, Managers.Inventory.list_equips(character))
        |> Context.Characters.preload([:friends, :stats])
        |> Context.Characters.load_skills()

      tick = Ms2ex.sync_ticks()

      character = character |> set_spawn_position() |> maybe_set_party()

      # the object id must exist before ServerEnter is built: the client reads
      # its own id from that packet and derives its session identity from it
      character =
        if character.object_id == 0 do
          %{character | object_id: Managers.GlobalCounter.get_and_increment()}
        else
          character
        end

      character = %{character | trophies: Context.Achievements.trophy_counts(character)}

      Managers.Character.start(character)
      Managers.Character.call(character, :monitor)

      character = Context.Characters.preload(character, friends: :rcpt)
      init_character(character)

      titles = Context.Characters.list_titles(character)

      account_wallet = Context.Wallets.find(account)
      character_wallet = Context.Wallets.find(character)

      %{friends: friends, map_id: map_id, position: position, rotation: rotation} = character

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
      |> push_achievements(character)
      |> push(Packets.SyncNumber.bytes())
      |> push(Packets.Prestige.bytes(character))
      |> push_inventory_tab(character, Managers.Inventory.list_tabs(character))
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
      |> push(Packets.InGameRank.load())
      |> push(Packets.RequestFieldEnter.bytes(map_id, position, rotation))
      |> push(Packets.HomeCommand.load(account.id))
      |> push(Packets.Mentor.load())
      |> push(Packets.Mentor.unknown12())
      |> push(Packets.Mail.notify())
      |> push(Packets.World.bytes())
      |> push_party(character)
    end
  end

  defp push_achievements(session, character) do
    Context.Achievements.load(character)
    session
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
    spawn_point = Storage.Maps.get_spawn(character.map_id)

    %{
      character
      | position: spawn_point.position,
        safe_position: spawn_point.position,
        rotation: spawn_point.rotation,
        online?: true
    }
  end

  defp push_inventory_tab(session, _character, []), do: session

  defp push_inventory_tab(session, character, [inventory_tab | tabs]) do
    items = Managers.Inventory.list_tab_items(inventory_tab.character_id, inventory_tab.tab)

    session
    |> push(Packets.InventoryItem.reset_tab(inventory_tab.tab))
    |> push(Packets.InventoryItem.load_tab(inventory_tab.tab, inventory_tab.slots))
    |> push(Packets.InventoryItem.load_items(inventory_tab.tab, items, character))
    |> push_inventory_tab(character, tabs)
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
