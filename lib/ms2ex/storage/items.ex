defmodule Ms2ex.Storage.Items do
  alias Ms2ex.Enums
  alias Ms2ex.Storage

  def get_meta(item_id) do
    Storage.get(:item, item_id)
    |> load_slots()
    |> load_transfer_type()
  end

  defp load_slots(%{slot_names: slots} = metadata) do
    slots = Enum.map(slots, &Enums.EquipSlot.get_key(&1))
    Map.put(metadata, :slots, slots)
  end

  # the ingest stores transfer_type as its integer value; contexts work with
  # the atom key, so translate once at the metadata boundary
  defp load_transfer_type(%{limit: %{transfer_type: transfer_type}} = metadata)
       when is_integer(transfer_type) do
    case Enum.find(Enums.TransferType.all_map(), fn {_key, value} -> value == transfer_type end) do
      nil -> metadata
      {key, _value} -> put_in(metadata, [:limit, :transfer_type], key)
    end
  end

  defp load_transfer_type(metadata), do: metadata
end
