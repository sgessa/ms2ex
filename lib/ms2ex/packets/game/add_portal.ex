defmodule Ms2ex.Packets.AddPortal do
  import Ms2ex.Packets.PacketWriter

  def bytes(portal) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(portal.id)
    |> put_bool(portal.visible?)
    |> put_bool(portal.enabled?)
    |> put_coord(portal.coord)
    |> put_coord(portal.rotation)
    |> put_coord()
    |> put_ustring()
    |> put_int(portal.target)
    |> put_int(portal.object_id)
    |> put_int()
    |> put_bool(portal.mini_map_visible?)
    |> put_long()
    |> put_byte()
    |> put_int()
    |> put_short()
    |> put_int()
    |> put_bool(false)
    |> put_ustring()
    |> put_ustring()
    |> put_ustring()
  end
end
