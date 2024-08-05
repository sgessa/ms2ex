defmodule Ms2ex.Managers.Field.Npc do
  alias Ms2ex.Storage
  alias Ms2ex.Types

  def load(map_id, counter, field) do
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

        {counter, group_npcs} = build_npcs_from_spawn_group(npc_spawn, counter, field)
        npcs = Map.merge(npcs, group_npcs)

        {counter, npc_spawns, npcs}
      end)

    {counter, npc_spawns, npcs}
  end

  defp build_npcs_from_spawn_group(group, object_counter, field) do
    spawn_point_id = object_counter

    Enum.reduce(group.npc_list, {object_counter, %{}}, fn npc_entry, {counter, npc_group_list} ->
      metadata = Storage.Npcs.get_meta(npc_entry.npc_id)

      {counter, npcs} =
        clone_npcs(counter, spawn_point_id, group, npc_entry, field, metadata)

      {counter, Map.merge(npc_group_list, npcs)}
    end)
  end

  # Skip when NPC Metadata is missing
  defp clone_npcs(object_counter, _spawn_point_id, _spawn_group, _npc_entry, _field, nil) do
    {object_counter, %{}}
  end

  defp clone_npcs(object_counter, spawn_point_id, spawn_group, npc_entry, field, metadata) do
    Enum.reduce(1..npc_entry.count, {object_counter, %{}}, fn _, {object_counter, npcs} ->
      npc = Types.Npc.new(%{id: npc_entry.npc_id, metadata: metadata})
      object_counter = object_counter + 1

      field_npc =
        Types.FieldNpc.new(%{
          object_id: object_counter,
          spawn_point_id: spawn_point_id,
          npc: npc,
          position: spawn_group[:position],
          rotation: spawn_group[:rotation],
          field: field
        })

      send(self(), {:add_npc, field_npc})

      {object_counter, Map.put(npcs, object_counter, field_npc)}
    end)
  end

  def remove_npc(field_npc, state) do
    npcs = Map.delete(state.npcs, field_npc.object_id)
    %{state | npcs: npcs}
  end
end
