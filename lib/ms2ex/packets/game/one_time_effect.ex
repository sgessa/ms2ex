defmodule Ms2ex.Packets.OneTimeEffect do
  import Ms2ex.Packets.PacketWriter

  # full-screen overlay effect for cinematic transitions (fade-in etc.)
  def apply(id, enable, path) do
    base =
      __MODULE__
      |> build()
      |> put_int(id)
      |> put_bool(enable)

    if enable, do: put_ustring(base, path), else: base
  end
end
