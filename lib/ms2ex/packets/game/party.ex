defmodule Ms2ex.Packets.Party do
  import Ms2ex.Packets.PacketWriter

  alias Ms2ex.Packets

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

  def join_request(character) do
    __MODULE__
    |> build()
    |> put_byte(0x2C)
    |> put_ustring(character.name)
  end

  @notices %{
    accepted_invite: 0x1,
    not_leader: 0x4,
    party_already_made: 0x5,
    refused_invite: 0x9,
    invite_self: 0xB,
    not_response_invite: 0xC,
    unable_to_invite: 0xD,
    cannot_accept_invite: 0xE,
    user_already_received_request: 0xF,
    entry_requirements_not_met: 0x10,
    min_level_not_met: 0x11,
    min_score_not_met: 0x12,
    full_party: 0x13,
    recruiting_listing_deleted: 0x16,
    outdated_recruitment_listing: 0x17,
    insufficient_merets: 0x18,
    invite_already_received: 0x1C,
    unable_to_reset_dungeon: 0x1D,
    unable_to_invite_in_dungeon_boss: 0x1E,
    party_not_found: 0x1F,
    request_to_join: 0x20,
    another_request_in_progress: 0x21,
    insufficient_memmber_count_for_kick_vote: 0x22,
    kick_vote_cooldown: 0x23,
    unable_to_kick_in_dungeon_boss: 0x26,
    unable_to_kick_in_mushking_royale: 0x27,
    leader_only_request: 0x28,
    member_disconnected: 0x29,
    member_in_dungeon: 0x2A,
    currently_matching: 0x2B,
    member_offline: 0x2D,
    member_in_mushking_royale: 0x30,
    mushking_royale_max_squad: 0x31
  }

  def notice(notice_name, character) do
    notice_code = Map.get(@notices, notice_name)

    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_byte(notice_code)
    |> put_ustring(character.name)
  end

  defp put_dungeon_info(packet) do
    packet
    |> put_int(1)
    |> put_int()
    |> put_byte()
  end
end
