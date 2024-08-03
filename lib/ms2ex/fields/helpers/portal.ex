defmodule Ms2ex.Fields.Helpers.Portal do
  alias Ms2ex.Storage

  def load(map_id, counter) do
    map_id
    |> Storage.Maps.get_portals()
    |> Enum.reduce({counter, %{}}, fn portal, {counter, portals} ->
      portal = Map.put(portal, :object_id, counter)
      {counter + 1, Map.put(portals, portal.id, portal)}
    end)
  end
end
