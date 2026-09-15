defmodule Ms2ex.Enums.ItemInventoryError do
  use Ms2ex.Enum, %{
    invalid_count: 12,
    inventory_full: 13,
    cannot_charge_meret: 34,
    invalid_slot: 37,
    not_active_tab: 38
  }
end
