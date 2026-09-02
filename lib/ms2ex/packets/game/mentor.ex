defmodule Ms2ex.Packets.Mentor do
  import Ms2ex.Packets.PacketWriter

  @my_list 0x3
  @unknown12 0xC

  # no mentees/mentors registered
  def load do
    __MODULE__
    |> build()
    |> put_byte(@my_list)
    |> put_int(0)
  end

  def unknown12 do
    __MODULE__
    |> build()
    |> put_byte(@unknown12)
    |> put_int(0)
    |> put_int(0)
    |> put_int(0)
    |> put_int(0)
  end
end
