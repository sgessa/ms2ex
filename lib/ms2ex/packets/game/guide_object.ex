defmodule Ms2ex.Packets.GuideObject do
  @moduledoc """
  Guide objects are the client-side markers a player controls: the fishing
  bobber, construction cursor and skill guides.
  """

  import Ms2ex.Packets.PacketWriter

  @create 0x0
  @remove 0x1

  @type_fishing 0x1

  def create(guide) do
    __MODULE__
    |> build()
    |> put_byte(@create)
    |> put_short(@type_fishing)
    |> put_int(guide.object_id)
    |> put_long(guide.character_id)
    |> put_coord(guide.position)
    |> put_coord(guide.rotation)
  end

  def remove(guide) do
    __MODULE__
    |> build()
    |> put_byte(@remove)
    |> put_int(guide.object_id)
    |> put_long(guide.character_id)
  end
end
