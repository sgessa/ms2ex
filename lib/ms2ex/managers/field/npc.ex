defmodule Ms2ex.Managers.Field.Npc do
  alias Ms2ex.Storage

  def load_npc_spawns(state) do
    state.map_id
    |> Storage.Maps.get_npc_spawns()
    |> Enum.each(fn npc_spawn ->
      send(self(), {:add_npc_spawn, npc_spawn})
    end)
  end

  def remove_npc(field_npc, state) do
    npcs = Map.delete(state.npcs, field_npc.object_id)
    %{state | npcs: npcs}
  end
end
