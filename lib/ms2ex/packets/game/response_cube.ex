defmodule Ms2ex.Packets.ResponseCube do
  import Ms2ex.Packets.PacketWriter

  @mode %{pickup: 0x11, drop: 0x12, place_cube: 0x0A, remove_cube: 0x0C}
  @update_profile 0x14
  @return_map 0x22
  @design_rank_reward 0x27

  # the error notice rides the buy-plot command with a ugc-map error code
  @error 0x02

  def error(code) do
    __MODULE__
    |> build()
    |> put_byte(@error)
    |> put_byte(code)
  end

  # the player lifts an object weapon: clients show the held item and start
  # the container's respawn timer (the tick the weapon returns at)
  def pickup(character, item_id, {x, y, z}, respawn_at) do
    __MODULE__
    |> build()
    |> put_byte(@mode.pickup)
    |> put_byte()
    |> put_int(character.object_id)
    |> put_sbyte(x)
    |> put_sbyte(y)
    |> put_sbyte(z)
    # the Vector3B struct is 4 bytes wide (one padding byte), matching the
    # client's serializer
    |> put_byte(0)
    |> put_int(item_id)
    |> put_int(respawn_at)
  end

  # the visual of a placed cube (or dropped liftable prop) at a grid tile
  def place_liftable(object_id, item_id, {x, y, z}, rotation) do
    __MODULE__
    |> build()
    |> put_byte(@mode.place_cube)
    |> put_byte(0)
    |> put_int(object_id)
    |> put_int(object_id)
    |> put_int(0)
    |> put_int(0)
    |> put_sbyte(x)
    |> put_sbyte(y)
    |> put_sbyte(z)
    # the Vector3B struct is 4 bytes wide (one padding byte), matching the
    # client's serializer
    |> put_byte(0)
    |> put_long(0)
    |> put_int(item_id)
    |> put_long(0)
    |> put_long(0)
    |> put_bool(false)
    |> put_bool(true)
    |> put_float(rotation)
    |> put_int(0)
    |> put_bool(false)
  end

  # the placed prop's visual cube leaves the field (liftable expiry or
  # re-pickup)
  def remove_cube(object_id, {x, y, z}) do
    __MODULE__
    |> build()
    |> put_byte(@mode.remove_cube)
    |> put_byte(0)
    |> put_int(object_id)
    |> put_int(object_id)
    |> put_sbyte(x)
    |> put_sbyte(y)
    |> put_sbyte(z)
    # the Vector3B struct is 4 bytes wide (one padding byte), matching the
    # client's serializer
    |> put_byte(0)
    |> put_bool(false)
  end

  def drop(character) do
    __MODULE__
    |> build()
    |> put_byte(@mode.drop)
    |> put_byte()
    |> put_int(character.object_id)
  end

  def design_rank_reward(account_id) do
    __MODULE__
    |> build()
    |> put_byte(@design_rank_reward)
    |> put_long(account_id)
    |> put_long(0)
    |> put_long(0)
    |> put_long(0)
    |> put_int(0)
  end

  def update_profile(character) do
    __MODULE__
    |> build()
    |> put_byte(@update_profile)
    |> put_int(character.object_id)
    |> put_int(62_000_000)
    |> put_int(0)
    |> put_int(0)
    |> put_int(0)
    |> put_ustring(character.home_name)
    |> put_long(0)
    |> put_long(0)
    |> put_bool(false)
  end

  def return_map(map_id) do
    __MODULE__
    |> build()
    |> put_byte(@return_map)
    |> put_int(map_id)
  end
end
