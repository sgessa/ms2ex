defmodule Ms2ex.Storage.Items.ConstantOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Items

  field :items, 1, repeated: true, type: Items.ConstantOptionId

  @table :item_constant_option_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-item-option-constant-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: id, options: options} <- list.items do
      :ets.insert(@table, {id, options})
    end
  end

  def lookup(option_id, rarity) do
    case :ets.lookup(@table, option_id) do
      [{_id, options}] ->
        Enum.find(options, &(&1.rarity == rarity))

      _ ->
        nil
    end
  end
end
