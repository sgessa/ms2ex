defmodule Ms2ex.Packets.Wedding do
  import Ms2ex.Packets.PacketWriter

  @update_marriage 0x0
  @update_hall 0x1

  # unmarried: default/empty marriage and hall records
  def update_marriage do
    __MODULE__
    |> build()
    |> put_byte(@update_marriage)
    |> put_long(0)
    |> put_byte(0)
    |> put_long(0)
    |> put_long(0)
    |> put_partner()
    |> put_partner()
    |> put_long(0)
    |> put_ustring()
    |> put_ustring()
    |> put_ustring()
    |> put_ustring()
    |> put_int(0)
  end

  def update_hall do
    __MODULE__
    |> build()
    |> put_byte(@update_hall)
    |> put_long(0)
    |> put_int(0)
    |> put_int(0)
    |> put_long(0)
    |> put_bool(false)
    |> put_long(0)
    |> put_long(0)
    |> put_ustring()
    |> put_ustring()
    |> put_long(0)
    |> put_long(0)
    |> put_long(0)
    |> put_long(0)
    |> put_long(0)
    |> put_int(0)
    |> put_int(0)
  end

  defp put_partner(packet) do
    packet
    |> put_long(0)
    |> put_long(0)
    |> put_ustring()
    |> put_bool(true)
  end
end
