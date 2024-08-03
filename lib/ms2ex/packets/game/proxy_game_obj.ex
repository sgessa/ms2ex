defmodule Ms2ex.Packets.ProxyGameObj do
  alias Ms2ex.{Schema, Packets}

  import Bitwise
  import Packets.PacketWriter

  @modes %{
    load_player: 0x3,
    update_player: 0x5,
    load_npc: 0x6,
    remove_npc: 0x7
  }

  @updates %{
    none: 0,
    type1: 1,
    move: 2,
    type3: 4,
    type4: 8,
    type5: 16,
    type6: 32,
    animate: 64
  }

  def load_player(character) do
    real_job_id = Schema.Character.real_job_id(character)

    __MODULE__
    |> build()
    |> put_byte(@modes.load_player)
    |> put_int(character.object_id)
    |> put_long(character.account_id)
    |> put_long(character.id)
    |> put_ustring(character.name)
    |> put_ustring(character.profile_url)
    |> put_ustring(character.motto)
    |> put_byte()
    |> put_coord(character.position)
    |> put_short(character.level)
    |> put_short(real_job_id)
    |> put_int(Schema.Character.job_id(character))
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_ustring(character.home_name)
    |> put_int()
    |> put_short()
    |> reduce(character.trophies, fn trophy, packet -> put_int(packet, trophy) end)
  end

  def update_player(character) do
    flag = flag(:move) ||| flag(:animate)

    packet =
      __MODULE__
      |> build()
      |> put_byte(@modes.update_player)
      |> put_int(character.object_id)
      |> put_byte(flag)

    packet =
      if has_bit?(flag, :type1) do
        put_byte(packet)
      else
        packet
      end

    packet =
      if has_bit?(flag, :move) do
        put_coord(packet, character.position)
      else
        packet
      end

    packet =
      if has_bit?(flag, :type3) do
        put_short(packet)
      else
        packet
      end

    packet =
      if has_bit?(flag, :type4) do
        packet
        |> put_short()
        |> put_int()
      else
        packet
      end

    packet =
      if has_bit?(flag, :type5) do
        put_ustring(packet, "Unknown")
      else
        packet
      end

    packet =
      if has_bit?(flag, :type6) do
        put_int(packet)
      else
        packet
      end

    if has_bit?(flag, :animate) do
      put_short(packet, character.animation)
    else
      packet
    end
  end

  def load_npc(field_npc) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load_npc)
    |> put_int(field_npc.object_id)
    |> put_int(field_npc.npc.id)
    |> put_bool(field_npc.dead?)
    |> put_int(field_npc.spawn_point_id)
    |> put_coord(field_npc.position)
  end

  def remove_npc(npc) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove_npc)
    |> put_int(npc.object_id)
  end

  defp has_bit?(flag, bit), do: (flag &&& flag(bit)) != 0

  defp flag(flag), do: Map.get(@updates, flag)
end
