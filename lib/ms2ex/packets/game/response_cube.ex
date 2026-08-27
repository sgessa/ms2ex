defmodule Ms2ex.Packets.ResponseCube do
  import Ms2ex.Packets.PacketWriter

  @mode %{pickup: 0x11, drop: 0x12}
  @update_profile 0x14
  @return_map 0x22
  @design_rank_reward 0x27

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
