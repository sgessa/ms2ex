defmodule Ms2ex.Packets.FieldAddPet do
  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Packets.PacketWriter

  def add_pet(%Types.FieldPet{} = field_pet) do
    npc = field_pet.npc

    __MODULE__
    |> build()
    |> put_int(field_pet.object_id)
    |> put_int(field_pet.skin_id)
    |> put_int(npc.id)
    |> put_coord(field_pet.position)
    |> put_coord(field_pet.rotation)
    |> put_float(field_pet.scale)
    |> put_int(field_pet.owner_object_id)
    |> put_npc_stats(field_pet)
    |> put_long(field_pet.item.id)
    |> put_byte()
    |> put_short(npc.metadata.basic.level)
    |> put_short(field_pet.taming_rank)
    |> put_int()
    |> put_ustring(Types.FieldPet.name(field_pet))
  end

  def remove_pet(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
  end

  # the pet renders with the npc's health/attack-speed stat triple; the
  # client indexes stat triples as [Total, Base, Current]
  defp put_npc_stats(packet, field_pet) do
    health = field_pet.stats.health
    attack_speed = field_pet.stats.attack_speed

    packet
    |> put_byte(0x23)
    |> put_long(health.total)
    |> put_int(trunc(attack_speed.total))
    |> put_long(health.base)
    |> put_int(trunc(attack_speed.base))
    |> put_long(health.current)
    |> put_int(trunc(attack_speed.current))
  end
end
