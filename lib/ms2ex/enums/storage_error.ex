defmodule Ms2ex.Enums.StorageError do
  use Ms2ex.Enum, %{
    invalid_count: 10,
    invalid_store_type: 12,
    store_full: 13,
    expand_max: 14,
    cannot_charge_merat: 15,
    binditem: 16,
    binditem_store_out: 17,
    deposit_invalid_money: 19,
    deposit_max_money: 20,
    code: 255
  }
end
