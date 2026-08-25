defmodule Ms2ex.Managers.Field.Portal do
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
end
