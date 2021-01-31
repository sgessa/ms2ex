defmodule Ms2ex.Packets.AddPortal do
  alias Ms2ex.Metadata.MapPortal

  import Ms2ex.Packets.PacketWriter

  def bytes(portal) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(portal.id)
    |> put_bool(MapPortal.has_flag?(portal, :visible))
    |> put_bool(MapPortal.has_flag?(portal, :enabled))
    |> put_coord(portal.coord)
    |> put_coord(portal.rotation)
    |> put_coord()
    |> put_ustring()
    |> put_int(portal.target)
    |> put_int(portal.object_id)
    |> put_int()
    |> put_bool(MapPortal.has_flag?(portal, :minimap_visible))
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
