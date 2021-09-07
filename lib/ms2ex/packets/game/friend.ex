defmodule Ms2ex.Packets.Friend do
  alias Ms2ex.Character

  import Ms2ex.Packets.PacketWriter

  @notices %{
    request_sent: 0x0,
    char_not_found: 0x1,
    request_already_sent: 0x2,
    already_friends: 0x3,
    cannot_add_self: 0x4,
    cannot_send_request: 0x5,
    cannot_block: 0x6,
    cannot_add_friends: 0x7,
    rcpt_cannot_add_friends: 0x8,
    declined_request: 0x9
  }

  def notice(notice_name, rcpt_name) do
    notice_code = Map.get(@notices, notice_name)

    __MODULE__
    |> build()
    |> put_byte(0x2)
    |> put_byte(notice_code)
    |> put_ustring(rcpt_name)
    |> put_ustring()
  end

  def start_list() do
    __MODULE__
    |> build()
    |> put_byte(0xF)
  end

  def end_list() do
    __MODULE__
    |> build()
    |> put_byte(0x13)
    |> put_int(0)
  end

  def add_to_list(friend, rcpt_online?) do
    __MODULE__
    |> build()
    |> put_byte(0x9)
    |> put_friend(friend, rcpt_online?)
  end

  defp put_friend(packet, friend, rcpt_online?) do
    real_job_id = Character.real_job_id(friend.rcpt)

    packet
    |> put_long(friend.shared_id)
    |> put_long(friend.rcpt_id)
    |> put_long(friend.rcpt.account_id)
    |> put_ustring(friend.rcpt.name)
    |> put_ustring(friend.message)
    |> put_short()
    # rcpt home map id
    |> put_int(0)
    |> put_int(real_job_id)
    |> put_int(Character.job_id(friend.rcpt))
    |> put_short(friend.rcpt.level)
    |> put_bool(friend.status == :accepted)
    |> put_bool(friend.status == :pending)
    |> put_bool(friend.status == :blocked)
    |> put_bool(rcpt_online?)
    |> put_byte()
    |> put_long(DateTime.to_unix(friend.inserted_at))
    |> put_ustring(friend.rcpt.profile_url)
    |> put_ustring(friend.rcpt.motto)
    |> put_ustring(friend.block_reason)
    |> put_int()
    |> put_int()
    |> put_int()
    # home name
    |> put_ustring()
    |> put_long()
    |> reduce(friend.rcpt.trophies, fn trophy, packet -> put_int(packet, trophy) end)
  end
end
