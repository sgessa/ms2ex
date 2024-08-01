defmodule Ms2ex.Storage.Items do
  alias Ms2ex.{Enums, Storage}

  def get_meta(item_id) do
    Storage.get(:item, item_id)
    |> load_slots()
  end

  defp load_slots(%{slot_names: slots} = metadata) do
    slots = Enum.map(slots, &Enums.EquipSlot.get_key(&1))
    Map.put(metadata, :slots, slots)
  end
end
