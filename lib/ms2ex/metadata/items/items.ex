defmodule Ms2ex.Metadata.Item do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :name, 2, type: :string
  field :tab, 3, enum: true, type: Ms2ex.Metadata.Items.InventoryTab
  field :slots, 4, enum: true, repeated: true, type: Ms2ex.Metadata.Items.EquipSlot
  field :medal_slot, 5, enum: true, type: Ms2ex.Metadata.Items.MedalSlot
  field :rarity, 8, type: :int32
  field :gem, 9, type: Ms2ex.Metadata.Items.Gem
  field :ugc, 10, type: Ms2ex.Metadata.Items.Ugc
  field :life, 11, type: Ms2ex.Metadata.Items.Life
  field :pet, 12, type: Ms2ex.Metadata.Items.Pet
  field :basic, 13, type: Ms2ex.Metadata.Items.Basic
  field :limits, 14, type: Ms2ex.Metadata.Items.Limit
  field :skill, 15, type: Ms2ex.Metadata.Items.Skill
  field :fusion, 16, type: Ms2ex.Metadata.Items.Fusion
  field :install, 17, type: Ms2ex.Metadata.Items.Install
  field :property, 18, type: Ms2ex.Metadata.Items.Property
  field :customize, 19, type: Ms2ex.Metadata.Items.Customize
  field :function_data, 20, type: Ms2ex.Metadata.Items.Function
  field :options, 21, type: Ms2ex.Metadata.Items.Options
  field :music, 22, type: Ms2ex.Metadata.Items.Music
  field :housing, 23, type: Ms2ex.Metadata.Items.Housing
  field :shop, 24, type: Ms2ex.Metadata.Items.Shop
  field :break_rewards, 25, repeated: true, type: Ms2ex.Metadata.Items.BreakReward
  field :additional_effect, 24, type: Ms2ex.Metadata.Items.AdditionalEffect
end

defmodule Ms2ex.Metadata.Items do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Item

  field :items, 1, repeated: true, type: Item

  @table :item_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-item-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: item_id} = metadata <- list.items do
      :ets.insert(@table, {item_id, metadata})
    end
  end

  def load(%{metadata: nil} = item) do
    case lookup(item.item_id) do
      {:ok, meta} ->
        rarity = item.rarity || meta.rarity
        %{item | metadata: meta, rarity: rarity}

      :error ->
        item
    end
  end

  def load(item), do: item

  def lookup(item_id) do
    case :ets.lookup(@table, item_id) do
      [{_id, %Item{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end
