defmodule Ms2ex.Packets.Party do
  import Ms2ex.Packets.PacketWriter

  alias Ms2ex.{Enums, Packets}

  def notice(notice_name, character) do
    notice_code = Enums.PartyNotice.get_value(notice_name)

    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_byte(notice_code)
    |> put_ustring(character.name)
  end

  def join(character) do
    __MODULE__
    |> build()
    |> put_byte(0x2)
    |> Packets.CharacterList.put_character(character)
    |> put_int()
    |> Packets.Job.put_skills(character)
    |> put_long()
  end

  def leave(character) do
    __MODULE__
    |> build()
    |> put_byte(0x3)
    |> put_long(character.id)
    # 1 = current character leaving
    |> put_byte(1)
  end

  def member_left(character) do
    __MODULE__
    |> build()
    |> put_byte(0x3)
    |> put_long(character.id)
    # 0 = other member leaving
    |> put_byte(0)
  end

  def kick(character) do
    __MODULE__
    |> build()
    |> put_byte(0x4)
    |> put_long(character.id)
  end

  def login_notice(character) do
    __MODULE__
    |> build()
    |> put_byte(0x5)
    |> Packets.CharacterList.put_character(character)
    |> put_long()
    |> put_int()
    |> put_short()
    |> put_byte()
  end

  def logout_notice(character) do
    __MODULE__
    |> build()
    |> put_byte(0x6)
    |> put_long(character.id)
  end

  def disband() do
    __MODULE__
    |> build()
    |> put_byte(0x7)
  end

  def set_leader(leader) do
    __MODULE__
    |> build()
    |> put_byte(0x8)
    |> put_long(leader.id)
  end

  def invite(character) do
    __MODULE__
    |> build()
    |> put_byte(0xB)
    |> put_ustring(character.name)
    |> put_int(character.party_id)
  end

  def create(party, send_notification? \\ true) do
    __MODULE__
    |> build()
    |> put_byte(0x9)
    |> put_bool(send_notification?)
    |> put_int(party.id)
    |> put_long(party.leader_id)
    |> put_byte(Enum.count(party.members))
    |> reduce(party.members, fn member, packet ->
      packet
      |> put_bool(!member.online?)
      |> Packets.CharacterList.put_character(member)
      |> put_dungeon_info()
    end)
    |> put_byte()
    |> put_int()
    |> put_byte()
    |> put_byte()
    |> put_byte()
  end

  def update_member(character) do
    __MODULE__
    |> build()
    |> put_byte(0xD)
    |> put_long(character.id)
    |> Packets.CharacterList.put_character(character)
    |> put_dungeon_info()
  end

  def update_hitpoints(character) do
    __MODULE__
    |> build()
    |> put_byte(0x13)
    |> put_long(character.id)
    |> put_long(character.account_id)
    |> put_int(character.stats.hp_max)
    |> put_int(character.stats.hp_cur)
    |> put_short()
  end

  def join_request(character) do
    __MODULE__
    |> build()
    |> put_byte(0x2C)
    |> put_ustring(character.name)
  end

  def start_ready_check(party) do
    __MODULE__
    |> build()
    |> put_byte(0x2F)
    |> put_byte(2)
    |> put_int(Enum.count(party.ready_check))
    |> put_long(DateTime.to_unix(DateTime.utc_now()) + Ms2ex.sync_ticks())
    |> put_int(Enum.count(party.members))
    |> reduce(party.members, fn m, packet ->
      put_long(packet, m.id)
    end)
    |> put_int()
    |> put_long(party.leader_id)
    |> put_int()
  end

  def ready_check(character, resp) do
    __MODULE__
    |> build()
    |> put_byte(0x30)
    |> put_long(character.id)
    |> put_bool(resp)
  end

  def end_ready_check() do
    __MODULE__
    |> build()
    |> put_byte(0x31)
  end

  defp put_dungeon_info(packet) do
    packet
    |> put_int(1)
    |> put_int()
    |> put_byte()
  end
end
