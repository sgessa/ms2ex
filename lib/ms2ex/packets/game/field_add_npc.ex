defmodule Ms2ex.Packets.FieldAddNpc do
  alias Ms2ex.{Mob, Packets}

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

  def add_mob(%Mob{boss?: true} = mob) do
    branches = 0

    __MODULE__
    |> build()
    |> put_int(mob.object_id)
    |> put_int(mob.id)
    |> put_coord(mob.position)
    |> put_coord(mob.rotation)
    |> put_string(mob.model)
    |> Packets.Stats.put_default_mob_stats(mob)
    |> put_byte()
    |> put_long()
    |> put_long()
    |> put_int()
    |> put_byte()
    |> put_int(branches)
    # TODO put branches
    |> put_long()
    |> put_byte()
    |> put_int(0x1)
    |> put_int()
    |> put_byte()
  end

  def add_mob(%Mob{} = mob) do
    __MODULE__
    |> build()
    |> put_int(mob.object_id)
    |> put_int(mob.id)
    |> put_coord(mob.position)
    |> put_coord(mob.rotation)
    |> Packets.Stats.put_default_mob_stats(mob)
    |> put_long()
    |> put_int()
    |> put_int(0xE)
    |> put_int()
    |> put_byte()
  end
end
