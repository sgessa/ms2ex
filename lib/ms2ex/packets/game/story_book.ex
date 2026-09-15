defmodule Ms2ex.Packets.StoryBook do
  import Ms2ex.Packets.PacketWriter

  def load(story_book_id) do
    __MODULE__
    |> build()
    |> put_int(story_book_id)
  end
end
