defmodule Ms2ex.GameHandlers.RequestChangeField do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_change_field(mode, packet, session)
  end

  defp handle_change_field(0x0, packet, session) do
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    {current_map_id, packet} = get_int(packet)

    portals = Storage.Maps.get_portals(current_map_id)
    {src_portal_id, _packet} = get_int(packet)

    case find_portal(portals, src_portal_id) do
      nil ->
        :ok

      %{enable: false} = portal ->
        push(
          character,
          Packets.Notice.message_box_text("Cannot use disabled portal: #{portal.id}")
        )

      portal ->
        maybe_complete_tutorial(character, current_map_id)
        maybe_remove_portal(portal, character)
        leave_through(portal, character, current_map_id)
    end
  end

  defp handle_change_field(_mode, _packet, _session), do: :ok

  # TODO: portal passwords are not verified (home portals prompt for one)

  # portal types whose handling needs systems ms2ex does not have yet behave
  # as plain field portals for now:
  # TODO: dungeon portals (DungeonReturnToLobby, DungeonEnter, LeaveDungeon)
  # once dungeons exist
  # TODO: housing portals (InHome, FieldToHome) once residences exist
  # TODO: Event portals removed once their capacity is reached

  # the target portal on this map is the destination: the client teleports
  # in place (the packet drops the player 25 units above the anchor)
  defp leave_through(%{target_map_id: current_map_id} = portal, character, current_map_id) do
    case Storage.Maps.get_portal(current_map_id, portal.target_portal_id) do
      %{position: position, rotation: rotation} ->
        character = %{character | position: position}
        Managers.Character.call(character, {:update, character})
        Managers.Field.user_position(character, position)
        push(character, Packets.UserMoveByPortal.bytes(character, position, rotation))

      _ ->
        :ok
    end
  end

  # a portal without a target is an exit: it sends the character back to
  # their return map (guide and dungeon exits work this way — the map's
  # trigger script only opens the portal, the destination is not its own)
  defp leave_through(%{target_map_id: 0}, character, _current_map_id) do
    row = Context.Characters.get(character.id)

    row.map_id
    |> return_map()
    |> case do
      nil -> :ok
      map_id -> Managers.Field.change_field(character, map_id)
    end
  end

  defp leave_through(%{target_map_id: dst_map_id} = portal, character, _current_map_id) do
    case arrival_point(portal, dst_map_id) do
      %{position: position, rotation: rotation} ->
        Managers.Field.change_field(character, dst_map_id, position, rotation)

      nil ->
        push(character, Packets.RequestFieldEnter.error())
    end
  end

  # the destination's arrival anchor is the src portal's designated target
  # portal; maps without it (or that cannot be entered) fail the move
  defp arrival_point(portal, dst_map_id) do
    if Storage.Maps.get_meta(dst_map_id) do
      Storage.Maps.get_portal(dst_map_id, portal.target_portal_id) ||
        Storage.Maps.get_field_spawn(dst_map_id)
    end
  end

  # one-shot quest portals vanish after use
  @portal_quest 6

  defp maybe_remove_portal(%{id: id, type: type}, character) when type == @portal_quest,
    do: Managers.Field.remove_portal(character, id)

  defp maybe_remove_portal(_portal, _character), do: :ok

  # pre-existing characters can carry a slot that predates the return-map
  # rule; falling back to a busy hub beats being stranded
  @default_return_map_id 2_000_062

  defp return_map(0), do: @default_return_map_id

  defp return_map(map_id) do
    if Storage.Maps.get_meta(map_id), do: map_id, else: @default_return_map_id
  end

  # walking out of the job's tutorial start field at level 1 completes the
  # tutorial: the reward items are granted and the tutorial's maps and taxis
  # unlock. The unlock lists double as the once-only latch
  defp maybe_complete_tutorial(character, from_map) do
    with %{start_field: start_field, rewards: rewards} = tutorial when rewards != [] <-
           Storage.Tables.Jobs.tutorial(character.job),
         true <- character.level == 1,
         true <- from_map == start_field,
         :ok <- grant_tutorial_rewards(character, tutorial) do
      unlock_tutorial_maps_and_taxis(character, tutorial)
    else
      _ -> :ok
    end
  end

  defp grant_tutorial_rewards(character, tutorial) do
    Enum.each(tutorial.rewards, fn entry ->
      item = Context.Items.init(entry.id, %{amount: entry.count, rarity: entry.rarity})

      case Managers.Inventory.add_item_or_mail(character, Context.Items.load_metadata(item)) do
        {:ok, {_status, inventory_item} = result} ->
          push(character, Packets.InventoryItem.add_item(result, character))
          push(character, Packets.InventoryItem.mark_item_new(inventory_item))

        _ ->
          :ok
      end
    end)

    :ok
  end

  defp unlock_tutorial_maps_and_taxis(character, tutorial) do
    # TODO: while every exit portal stays enabled (no trigger runtime), all
    # jobs leave through the portal to the skip destination and the client
    # discovers that map's taxi on entry anyway, so this credit is mostly
    # redundant. It matters once the tutorial's per-job exit portals open
    # only the job's route (knights never visit the destination hub).
    discovered_maps = Enum.uniq(character.discovered_maps ++ tutorial[:open_maps])

    new_taxis = Enum.reject(tutorial[:open_taxis], &Enum.member?(character.taxis, &1))
    taxis = Enum.uniq(character.taxis ++ new_taxis)

    {:ok, character} =
      Context.Characters.update(character, %{discovered_maps: discovered_maps, taxis: taxis})

    Managers.Character.call(character, {:update, character})

    Enum.each(new_taxis, fn map_id ->
      push(character, Packets.Taxi.discover(map_id))
    end)
  end

  defp find_portal(portals, portal_id) do
    Enum.find(portals, &(&1.id == portal_id))
  end
end
