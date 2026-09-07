defmodule Ms2ex.Packets.PlaySystemSound do
  import Ms2ex.Packets.PacketWriter

  # plays a client-side system sound; trigger scripts fire these inside
  # trigger boxes (guide pop-ups, UI chimes) or field-wide
  def system(sound) do
    __MODULE__
    |> build()
    |> put_ustring(sound)
  end
end
