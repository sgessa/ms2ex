defmodule Ms2ex.Packets.CharacterList do
  alias Ms2ex.{Packets, Schema, Enums, Types}

  import Packets.PacketWriter

  @modes %{
    add: 0x0,
    append: 0x1,
    start_list: 0x3,
    end_list: 0x4
  }

  def add_entries(characters) do
    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_byte(length(characters))
    |> put_entries(characters)
  end

  def append(character) do
    __MODULE__
    |> build()
    |> put_byte(@modes.append)
    |> put_entries([character])
  end

  def start_list() do
    __MODULE__
    |> build()
    |> put_byte(@modes.start_list)
  end

  def end_list() do
    __MODULE__
    |> build()
    |> put_byte(@modes.end_list)
    |> put_bool(false)
  end

  defp put_entries(packet, []), do: packet

  defp put_entries(packet, [character | characters]) do
    badges = []

    packet
    |> put_character(character)
    |> put_ustring(character.profile_url)
    |> put_long()
    |> put_byte(length(character.equips))
    |> Packets.InventoryItem.put_equips(character.equips)
    |> put_byte(length(badges))
    |> put_badges(badges)
    |> put_bool(false)
    # TODO unknown bool logic
    |> put_entries(characters)
  end

  def put_character(packet, character) do
    real_job_id = Enums.Job.get_value(character.job)
    gender = Enums.Gender.get_value(character.gender)

    packet
    |> put_long(character.account_id)
    |> put_long(character.id)
    |> put_ustring(character.name)
    |> put_byte(gender)
    |> put_byte(0x1)
    |> put_long()
    |> put_int()
    |> put_int(character.map_id)
    |> put_int(character.map_id)
    |> put_int()
    |> put_short(character.level)
    |> put_short()
    |> put_int(real_job_id)
    |> put_int(Schema.Character.job_id(character))
    |> put_int()
    |> put_int()
    |> put_short()
    |> put_long()
    |> put_long()
    |> put_long()
    |> put_int()
    |> put_coord()
    |> put_int()
    |> Types.SkinColor.put_skin_color(character.skin_color)
    |> put_time(character.inserted_at)
    |> reduce(character.trophies, fn trophy, packet -> put_int(packet, trophy) end)
    |> put_long()
    |> put_ustring(character.guild_name)
    |> put_ustring(character.motto)
    |> put_ustring(character.profile_url)
    |> put_byte(length(character.clubs))
    |> put_clubs(character.clubs)
    |> put_byte()
    |> put_bytes(String.duplicate(<<0x0>>, 12 * 4))
    |> put_ustring()
    |> put_long(character.unknown_id)
    |> put_long(2000)
    |> put_long(3000)
    |> put_counter(0)
    |> put_byte()
    |> put_byte()
    |> put_long()
    |> put_int()
    |> put_int()
    |> put_time()
    |> put_int(character.prestige_level)
    |> put_time()
    |> put_counter(0)
    |> put_counter(0)
    |> put_short()
    |> put_long()
  end

  defp put_badges(packet, []), do: packet

  # TODO
  defp put_badges(packet, [_b | badges]) do
    packet
    |> put_byte()
    |> put_int()
    |> put_long()
    |> put_int()
    |> put_badges(badges)
  end

  defp put_counter(packet, counter) do
    packet
    |> put_int(counter)
    |> reduce([], fn _, packet -> put_long(packet) end)
  end

  defp put_clubs(packet, []), do: packet

  defp put_clubs(packet, [c | clubs]) do
    packet
    |> put_club(c)
    |> put_clubs(clubs)
  end

  defp put_club(packet, %{name: name, unknown_bool: true}) do
    packet
    |> put_bool(true)
    |> put_long()
    |> put_ustring(name)
  end

  defp put_club(packet, _club), do: put_bool(packet, false)
end
