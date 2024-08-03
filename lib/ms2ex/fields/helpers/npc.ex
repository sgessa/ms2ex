defmodule Ms2ex.Fields.Helpers.Npc do
  alias Ms2ex.Storage
  alias Ms2ex.Types

  def load(map_id, counter) do
    {counter, npc_spawns, npcs} =
      map_id
      |> Storage.Maps.get_npc_spawns()
      |> Enum.reduce({counter, %{}, %{}}, fn npc_spawn, {counter, npc_spawns, npcs} ->
        {counter, npc_spawns} =
          if Map.get(npc_spawn, :regen_check_time, 0) > 0 do
            counter = counter + 1
            {counter, Map.put(npc_spawns, counter, npc_spawn)}
          else
            {counter, npc_spawns}
          end

        {counter, group_npcs} = build_npcs_from_spawn_group(npc_spawn, counter)
        npcs = Map.merge(npcs, group_npcs)

        {counter, npc_spawns, npcs}
      end)

    {counter, npc_spawns, select_friendly_npcs(npcs), select_mob_npcs(npcs)}
  end

  defp build_npcs_from_spawn_group(group, object_counter) do
    spawn_point_id = object_counter

    Enum.reduce(group.npc_list, {object_counter, %{}}, fn npc_entry, {counter, npc_group_list} ->
      metadata = Storage.Npcs.get_meta(npc_entry.npc_id)

      {counter, npcs} = clone_npcs(counter, spawn_point_id, group, npc_entry, metadata)
      {counter, Map.merge(npc_group_list, npcs)}
    end)
  end

  # Skip when NPC Metadata is missing
  defp clone_npcs(object_counter, _spawn_point_id, _spawn_group, _npc_entry, nil) do
    {object_counter, %{}}
  end

  defp clone_npcs(object_counter, spawn_point_id, spawn_group, npc_entry, metadata) do
    Enum.reduce(1..npc_entry.count, {object_counter, %{}}, fn _, {object_counter, npcs} ->
      npc = Types.Npc.new(%{id: npc_entry.npc_id, metadata: metadata})
      position = struct(Types.Coord, Map.get(spawn_group, :position, %{}))
      rotation = struct(Types.Coord, Map.get(spawn_group, :rotation, %{}))
      object_counter = object_counter + 1

      field_npc =
        %Types.FieldNpc{}
        |> Map.put(:id, object_counter)
        |> Map.put(:spawn_point_id, spawn_point_id)
        |> Map.put(:npc, npc)
        |> Map.put(:animation, 255)
        |> Map.put(:position, position)
        |> Map.put(:rotation, rotation)
        |> Map.put(:object_id, object_counter)

      {object_counter, Map.put(npcs, object_counter, field_npc)}
    end)
  end

  defp select_friendly_npcs(npcs) do
    Enum.filter(npcs, fn {_, field_npc} ->
      friendly = field_npc.npc.metadata.basic[:friendly] || 0
      friendly > 0
    end)
  end

  defp select_mob_npcs(npcs) do
    Enum.filter(npcs, fn {_, field_npc} ->
      friendly = field_npc.npc.metadata.basic[:friendly] || 0
      !friendly || friendly == 0
    end)
  end
end
