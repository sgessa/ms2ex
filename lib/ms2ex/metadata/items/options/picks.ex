defmodule Ms2ex.Metadata.Items.Options.Pick do
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :picks, 2, repeated: true, type: Ms2ex.Metadata.Items.Options.PickStat
end

defmodule Ms2ex.Metadata.Items.Options.Picks do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Items.Options.Pick

  field :items, 1, repeated: true, type: Pick

  @table :item_option_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-item-option-pick-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: id} = meta <- list.items do
      :ets.insert(@table, {id, meta})
    end
  end

  def lookup(id, rarity) do
    case :ets.lookup(@table, id) do
      [{_id, options}] ->
        Enum.find(options, &(&1.rarity == rarity))

      _ ->
        nil
    end
  end
end
