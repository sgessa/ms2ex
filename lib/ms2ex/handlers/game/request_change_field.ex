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

    if current_map_id == character.map_id do
      portals = Storage.Maps.get_portals(current_map_id)
      {src_portal_id, _packet} = get_int(packet)

      case find_portal(portals, src_portal_id) do
        %{target_map_id: dst_map_id} ->
          maybe_complete_tutorial(character, current_map_id)

          spawn_point = arrival_point(dst_map_id, current_map_id)

          Context.Field.change_field(
            character,
            dst_map_id,
            spawn_point.position,
            spawn_point.rotation
          )

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  defp handle_change_field(_mode, _packet, _session), do: :ok

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

      case Managers.Inventory.add_item(character, Context.Items.load_metadata(item)) do
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

  # the destination's portal leading back to the current map is the arrival
  # point; maps without a return portal use their default spawn point
  defp arrival_point(dst_map_id, current_map_id) do
    portal =
      dst_map_id
      |> Storage.Maps.get_portals()
      |> Enum.find(&(&1.target_map_id == current_map_id))

    portal || Storage.Maps.get_field_spawn(dst_map_id)
  end
end
