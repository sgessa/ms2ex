defmodule Ms2ex.Metadata.Insignia do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:id, :type, :title_id]

  field :id, 1, type: :int32
  field :type, 2, type: :string
  field :title_id, 3, type: :int32
end

defmodule Ms2ex.Metadata.Insignias do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Insignia

  defstruct [:items]

  field :items, 1, repeated: true, type: Insignia

  @table :insignia_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-insignia-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: item_id} = metadata <- list.items do
      :ets.insert(@table, {item_id, metadata})
    end
  end

  def lookup(skill_id) do
    case :ets.lookup(@table, skill_id) do
      [{_id, %Insignia{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end
