defmodule Ms2ex.Storage.Items.PickOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.Items.Options.Pick

  field :items, 1, repeated: true, type: Pick

  @table :item_option_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-item-option-pick-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: id, stats: stats} <- list.items do
      :ets.insert(@table, {id, stats})
    end
  end

  def lookup(id, rarity) do
    case :ets.lookup(@table, id) do
      [{_id, stats}] ->
        Enum.find(stats, &(&1.rarity == rarity))

      _ ->
        nil
    end
  end
end
