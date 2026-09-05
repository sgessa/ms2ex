defmodule Ms2ex.Enums.FishingError do
  @moduledoc "Error codes the client renders for fishing actions."

  use Ms2ex.Enum, %{
    none: 0,
    s_fishing_error_notexist_water: 1,
    s_fishing_error_invalid_item: 2,
    s_fishing_error_lack_mastery: 3,
    s_fishing_error_notexist_fish: 5,
    s_fishing_error_fishingrod_mastery: 6,
    s_fishing_error_inventory_full: 7,
    s_fishing_error_ugcmap: 8,
    s_fishing_error_system_error: 9
  }
end
