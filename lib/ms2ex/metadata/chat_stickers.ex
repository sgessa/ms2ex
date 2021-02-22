defmodule Ms2ex.Metadata.ChatSticker do
  use Protobuf, syntax: :proto3

  defstruct [:sticker_id, :group_id, :category_id]

  field :sticker_id, 1, type: :int32
  field :group_id, 2, type: :int32
  field :category_id, 3, type: :int32
end

defmodule Ms2ex.Metadata.ChatStickers do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.ChatSticker

  defstruct [:items]

  field :items, 1, repeated: true, type: ChatSticker

  @table :chat_sticker_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-chat-sticker-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{sticker_id: id} = meta <- list.items do
      :ets.insert(@table, {id, meta})
    end
  end

  def lookup(sticker_id) do
    case :ets.lookup(@table, sticker_id) do
      [{_id, %ChatSticker{} = meta}] -> {:ok, meta}
      _ -> :error
    end
  end
end
