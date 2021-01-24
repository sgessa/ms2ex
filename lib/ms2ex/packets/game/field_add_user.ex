defmodule Ms2ex.Packets.FieldAddUser do
  alias Ms2ex.Packets
  alias Ms2ex.Users.Character

  import Packets.PacketWriter

  def bytes(character) do
    real_job_id = Character.real_job_id(character)
    flag_a = false

    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> Packets.CharacterList.put_character(character)
    |> put_int(Character.job_id(character))
    |> put_tiny(0x1)
    |> put_int(real_job_id)
    |> Packets.Job.put_skills(character)
    |> put_coord(character.position)
    |> put_coord(character.rotation)
    |> put_byte()
    |> Packets.Field.put_total_stats(Packets.PlayerStats.stats())
    |> put_byte()
    |> put_byte()
    |> put_int()
    |> put_long()
    |> put_long()
    |> put_bool(flag_a)
    |> put_int(0x1)
    |> put_skin_color(character.skin_color)
    |> put_ustring(character.profile_url)
    |> put_bool(character.mount != nil)
    # TODO put_mount()
    |> put_int()
    |> put_time(DateTime.utc_now())
    |> put_int()
    |> put_int()
    |> put_bool(true)
    |> put_encoded_appearance(character)
  end

  defp put_encoded_appearance(packet, character) do
    appear = appearance(character)

    packet
    |> put_deflated(appear, byte_size(appear))
    |> put_byte()
    |> put_deflated(<<0x1>>, 1)
    |> put_byte()
    |> put_deflated(<<0x1>>, 1)
    |> Packets.Field.put_passive_skills()
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
    |> put_tiny(length(character.equips))
    |> Packets.ItemInventory.put_equips(character.equips)
    |> put_tiny(0x1)
    |> put_long()
    |> put_long()
    |> put_byte()
  end
end
