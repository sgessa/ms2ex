defmodule Ms2ex.Managers.Field.Portal do
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  def load(map_id, base_id) do
    map_id
    |> Storage.Maps.get_portals()
    |> Enum.reduce({base_id, %{}}, fn portal, {counter, portals} ->
      object_id = counter + 1
      portal = Map.put(portal, :object_id, object_id)
      {object_id, Map.put(portals, portal.id, portal)}
    end)
  end

  @doc "Drops a used portal from the field and tells the clients it is gone."
  def remove(state, portal_id) do
    case Map.get(state.portals, portal_id) do
      %{} ->
        Managers.Field.broadcast(state.topic, Packets.AddPortal.remove(portal_id))
        %{state | portals: Map.delete(state.portals, portal_id)}

      _ ->
        state
    end
  end
end
