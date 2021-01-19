defmodule Ms2ex.Packets.Fishing do
  import Ms2ex.Packets.PacketWriter

  @modes %{load_log: 0x7}

  def load_log() do
    __MODULE__
    |> build()
    |> put_byte(@modes.load_log)
    |> put_int()
  end
end
