defmodule Ms2ex.Managers.Field.Npc do
  alias Ms2ex.Storage
  alias Ms2ex.Managers
  alias Ms2ex.Types

  def load_npc_spawns(state) do
    state.map_id
    |> Storage.Maps.get_npc_spawns()
    |> Enum.each(fn npc_spawn ->
      npc_ids =
        npc_spawn.npc_list
        |> Enum.map(&List.duplicate([&1.npc_id], &1.count))
        |> List.flatten()

      send(self(), {:add_npc_spawn, npc_spawn, npc_ids})
    end)
  end

  def load_mob_spawns(state) do
    state.map_id
    |> Storage.Maps.get_mob_spawns()
    |> Enum.each(fn mob_spawn ->
      send(self(), {:add_npc_spawn, mob_spawn, mob_spawn.npc_ids})
    end)
  end

  def load_spawn(state, npc_spawn, npc_ids) do
    spawn_point_id = state.counter + 1
    npc_spawn = Map.put(npc_spawn, :id, spawn_point_id)

    state =
      if npc_spawn[:regen_check_time] > 0 || npc_spawn[:population] > 0 do
        put_in(state, [:npc_spawns, spawn_point_id], npc_spawn)
      else
        state
      end

    Enum.each(npc_ids, fn npc_id ->
      send(self(), {:add_npc, npc_id, npc_spawn})
    end)

    %{state | counter: spawn_point_id}
  end

  def load_npc(state, npc_id, npc_spawn) do
    metadata = Storage.Npcs.get_meta(npc_id)
    npc = Types.Npc.new(%{id: npc_id, metadata: metadata})
    object_id = state.counter + 1

    field_npc =
      Types.FieldNpc.new(%{
        object_id: object_id,
        spawn_point_id: npc_spawn[:id],
        npc: npc,
        position: npc_spawn[:position],
        rotation: npc_spawn[:rotation],
        field: state.topic
      })

    {:ok, pid} = Managers.FieldNpc.start(field_npc)

    state
    |> Map.put(:counter, object_id)
    |> put_in([:npcs, object_id], pid)
  end

  def remove_npc(field_npc, state) do
    npcs = Map.delete(state.npcs, field_npc.object_id)
    %{state | npcs: npcs}
  end
end
