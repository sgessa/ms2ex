defmodule Ms2ex.Packets.FieldAddNpc do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def add_npc(npc) do
    branches = 0

    __MODULE__
    |> build()
    |> put_int(npc.object_id)
    |> put_int(npc.id)
    |> put_coord(npc.position)
    |> put_coord()
    |> put_npc_stats()
    |> put_byte()
    |> put_short(branches)
    |> put_long()
    |> put_byte()
    |> put_int(0x1)
    |> put_int()
    |> put_byte()
  end

  defp put_npc_stats(packet) do
    flag = 0x23

    packet
    |> put_byte(flag)
    # if flag != 0x1
    |> put_long(0x5)
    |> put_int()
    |> put_long(0x5)
    |> put_int()
    |> put_long(0x5)
    |> put_int()
  end

  def add_mob(%{is_boss?: true} = mob) do
    branches = 0

    __MODULE__
    |> build()
    |> put_int(mob.object_id)
    |> put_int(mob.id)
    |> put_coord(mob.spawn)
    |> put_coord()
    |> put_string(mob.model)
    |> put_mob_stats(mob)
    |> put_long()
    |> put_long()
    |> put_int()
    |> put_byte()
    |> put_int(branches)
    |> put_long()
    |> put_byte()
    |> put_int(0x1)
    |> put_int()
    |> put_byte()
  end

  def add_mob(mob) do
    branches = 0

    __MODULE__
    |> build()
    |> put_int(mob.object_id)
    |> put_int(mob.id)
    |> put_coord(mob.spawn)
    |> put_coord()
    |> put_mob_stats(mob)
    |> put_byte()
    |> put_int(branches)
    |> put_long()
    |> put_byte()
    |> put_int(0x1)
    |> put_int()
    |> put_byte()
  end

  defp put_mob_stats(packet, mob) do
    flag = 0x23

    packet
    |> put_byte(flag)
    |> put_long(mob.stats.hp.total)
    |> put_int()
    |> put_long(mob.stats.hp.min)
    |> put_int()
    |> put_long(mob.stats.hp.max)
    |> put_int()
  end
end
