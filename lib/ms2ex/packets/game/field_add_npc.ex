defmodule Ms2ex.Packets.FieldAddNpc do
  alias Ms2ex.{Packets, Types}

  import Packets.PacketWriter

  def add_npc(field_npc) do
    npc = field_npc.npc

    __MODULE__
    |> build()
    |> put_int(field_npc.object_id)
    |> put_int(field_npc.npc.id)
    |> put_coord(field_npc.position)
    |> put_coord(field_npc.rotation)
    |> put_model(npc)
    |> put_npc_stats()
    |> put_bool(field_npc.dead?)
    # TODO: Put buffs
    |> put_short(0)
    # TODO: UID for Pet NPC
    |> put_long()
    |> put_byte()
    |> put_int(npc.metadata.basic.level)
    |> put_int()
    |> put_byte()
    |> put_boss(npc)
    |> put_bool(false)
  end

  defp put_model(packet, %Types.Npc{boss?: true} = npc) do
    put_string(packet, npc.metadata.model.name)
  end

  defp put_model(packet, _npc), do: packet

  defp put_boss(packet, %Types.Npc{boss?: true}) do
    packet
    # EffectStr
    |> put_ustring()
    # Buff count
    |> put_int(0)
    # TODO: Put buffs
    |> put_int()
  end

  defp put_boss(packet, _npc), do: packet

  defp put_npc_stats(packet) do
    flag = 0x23

    packet
    |> put_byte(flag)
    |> put_long(0x5)
    |> put_int()
    |> put_long(0x5)
    |> put_int()
    |> put_long(0x5)
    |> put_int()
  end
end
