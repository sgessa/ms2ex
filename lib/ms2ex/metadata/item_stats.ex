defmodule Ms2ex.Metadata.ItemAttribute do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :str, 0
  field :dex, 1
  field :int, 2
  field :luk, 3
  field :hp, 4
  field :hp_regen, 5
  field :hp_inv, 6
  field :sp, 7
  field :sp_regen, 8
  field :sp_inv, 9
  field :ep, 10
  field :ep_regen, 11
  field :ep_inv, 12
  field :attk_speed, 13
  field :move_speed, 14
  field :attk, 15
  field :evasion, 16
  field :crit_rate, 17
  field :crit_dmg, 18
  field :crit_evasion, 19
  field :defense, 20
  field :perfect_guard, 21
  field :jump_height, 22
  field :phys_attk, 23
  field :mag_attk, 24
  field :phys_res, 25
  field :mag_res, 26
  field :min_attk, 27
  field :max_attk, 28
  field :damage, 29
  field :unknown, 30
  field :piercing, 31
  field :mount_speed, 32
  field :bonus_attk, 33
  field :pet_bonus_attk, 34
end

defmodule Ms2ex.Metadata.ItemStat do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:item_id, :constants, :static, :random]

  field :type, 1, enum: true, type: Ms2ex.Metadata.ItemAttribute
  field :value, 2, type: :int32
  field :percentage, 3, type: :float
end

defmodule Ms2ex.Metadata.ItemOption do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:grade, :slots, :multiply_factor, :stats]

  field :rarity, 1, type: :int32
  field :slots, 2, type: :int32
  field :multiply_factor, 3, type: :float
  field :stats, 4, repeated: true, type: Ms2ex.Metadata.ItemStat
end

defmodule Ms2ex.Metadata.ItemStats do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:item_id, :constants, :static, :random]

  field :item_id, 1, type: :int32
  field :basic_attributes, 2, repeated: true, type: Ms2ex.Metadata.ItemOption
  field :static, 3, repeated: true, type: Ms2ex.Metadata.ItemOption
  field :bonus_attributes, 4, repeated: true, type: Ms2ex.Metadata.ItemOption

  @table :item_stats_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-item-stats-metadata"]
      |> Path.join()
      |> File.read!()
      |> Ms2ex.Metadata.ItemStatList.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{item_id: item_id} = metadata <- list.stats do
      :ets.insert(@table, {item_id, metadata})
    end
  end

  def lookup(item_id) do
    case :ets.lookup(@table, item_id) do
      [{_id, %__MODULE__{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end

defmodule Ms2ex.Metadata.ItemStatList do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.ItemStats

  defstruct [:stats]

  field :stats, 1, repeated: true, type: ItemStats
end
