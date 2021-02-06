defmodule Ms2ex.Packets.FieldAddUser do
  alias Ms2ex.Packets
  alias Ms2ex.Character

  import Packets.PacketWriter

  def bytes(character) do
    real_job_id = Character.real_job_id(character)
    flag_a = false

    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> Packets.CharacterList.put_character(character)
    |> put_int(Character.job_id(character))
    |> put_byte(0x1)
    |> put_int(real_job_id)
    |> Packets.Job.put_skills(character)
    |> put_coord(character.position)
    |> put_coord(character.rotation)
    |> put_byte()
    |> Packets.Field.put_total_stats(character.stats)
    |> put_byte()
    |> put_byte()
    |> put_int()
    |> put_long()
    |> put_long()
    |> put_bool(flag_a)
    |> put_int(0x1)
    |> Ms2ex.SkinColor.put_skin_color(character.skin_color)
    |> put_ustring(character.profile_url)
    |> put_bool(character.mount != nil)
    # TODO put_mount()
    |> put_int()
    |> put_time(DateTime.utc_now())
    |> put_int()
    |> put_int()
    |> put_encoded_appearance(character)
  end

  defp put_encoded_appearance(packet, character) do
    packet
    |> put_deflated(appearance(character))
    |> put_deflated(<<0x0>>)
    |> put_deflated(<<0x0>>)
    |> Packets.Job.put_passive_skills(character)
    |> put_int()
    |> put_int()
    |> put_byte()
    |> put_int()
    |> put_byte()
    |> put_byte()
    |> put_int(character.title_id)
    |> put_short(character.insignia_id)
    |> put_byte()
    |> put_int()
    |> put_byte()
    |> put_time()
    |> put_long(9_007_199_254_740_991)
    |> put_byte()
    |> put_int()
    |> put_int()
    |> put_short()
  end

  def appearance(character) do
    ""
    |> put_byte(length(character.equips))
    |> Packets.InventoryItem.put_equips(character.equips)
    |> put_byte(0x1)
    |> put_long()
    |> put_long()
    |> put_byte()
  end
end
