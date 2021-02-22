defmodule Ms2ex.Packets.ResponseCube do
  import Ms2ex.Packets.PacketWriter

  @mode %{pickup: 0x11, drop: 0x12}

  def pickup(character, weapon_id, coord) do
    __MODULE__
    |> build()
    |> put_byte(@mode.pickup)
    |> put_byte()
    |> put_int(character.object_id)
    |> put_sbyte_coord(coord)
    |> put_byte()
    |> put_int(weapon_id)
    # TODO find object ID?
    |> put_int(Enum.random(1..2_147_483_647))
  end

  def drop(character) do
    __MODULE__
    |> build()
    |> put_byte(@mode.drop)
    |> put_byte()
    |> put_int(character.object_id)
  end
end
