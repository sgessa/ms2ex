defmodule Ms2ex.Storage.Items do
  alias Ms2ex.Storage.Metadata
  alias Ms2ex.Enums

  def get_meta(item_id) do
    Metadata.get(:item, item_id)
    |> load_slots()
  end

  defp load_slots(%{slot_names: slots} = metadata) do
    slots = Enum.map(slots, &Enums.EquipSlot.get_value(&1))
    Map.put(metadata, :slots, slots)
  end
end
