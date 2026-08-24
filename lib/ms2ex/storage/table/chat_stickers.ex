defmodule Ms2ex.Storage.Tables.ChatStickers do
  alias Ms2ex.Storage

  @spec lookup(pos_integer()) :: {:ok, %{id: integer(), group_id: integer()}} | :error
  def lookup(sticker_id) do
    :table
    |> Storage.get("chatemoticon.xml")
    |> get_in([:table, :entries, to_string(sticker_id)])
    |> case do
      nil -> :error
      sticker -> {:ok, sticker}
    end
  end
end
