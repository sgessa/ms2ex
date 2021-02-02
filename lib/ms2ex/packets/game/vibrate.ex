defmodule Ms2ex.Packets.Vibrate do
  import Ms2ex.Packets.PacketWriter

  def bytes(character, entity_id, some_id, obj_id, flag, client_ticks) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_string(entity_id)
    |> put_long(some_id)
    |> put_int(obj_id)
    |> put_int(flag)
    |> put_short_coord(character.position)
    |> put_int(client_ticks)
    |> put_string()
    |> put_byte()
  end
end
