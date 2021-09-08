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

  def load_list(friends) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_int(Enum.count(friends))
    |> reduce(friends, &put_friend(&2, &1))
  end

  def end_list(friend_count) do
    __MODULE__
    |> build()
    |> put_byte(0x13)
    |> put_int(friend_count)
  end

  def add_to_list(friend) do
    __MODULE__
    |> build()
    |> put_byte(0x9)
    |> put_friend(friend)
  end

  def remove(friend) do
    __MODULE__
    |> build()
    |> put_byte(0x7)
    |> put_byte()
    |> put_long(friend.shared_id)
    |> put_long(friend.rcpt.account_id)
    |> put_long(friend.rcpt.id)
    |> put_ustring(friend.rcpt.name)
  end

  def accept(shared_id, rcpt) do
    __MODULE__
    |> build()
    |> put_byte(0x3)
    |> put_byte()
    |> put_long(shared_id)
    |> put_long(rcpt.id)
    |> put_long(rcpt.account_id)
    |> put_ustring(rcpt.name)
  end

  def decline(shared_id) do
    __MODULE__
    |> build()
    |> put_byte(0x4)
    |> put_byte()
    |> put_long(shared_id)
  end

  def cancel(shared_id) do
    __MODULE__
    |> build()
    |> put_byte(0x11)
    |> put_byte()
    |> put_long(shared_id)
  end

  def update(friend) do
    __MODULE__
    |> build()
    |> put_byte(0x8)
    |> put_friend(friend)
  end

  def block(friend) do
    __MODULE__
    |> build()
    |> put_byte(0x5)
    |> put_byte()
    |> put_long(friend.shared_id)
    |> put_ustring(friend.rcpt.name)
    |> put_ustring(friend.block_reason)
  end

  def unblock(shared_id) do
    __MODULE__
    |> build()
    |> put_byte(0x6)
    |> put_byte()
    |> put_long(shared_id)
  end

  def presence_notification(shared_id, rcpt) do
    friend_online? =
      case Ms2ex.World.get_character_by_name(rcpt.name) do
        {:ok, _} -> true
        _ -> false
      end

    __MODULE__
    |> build()
    |> put_byte(0xE)
    |> put_bool(friend_online?)
    |> put_long(shared_id)
    |> put_ustring(rcpt.name)
  end

  def accept_notification(shared_id) do
    __MODULE__
    |> build()
    |> put_byte(0xB)
    |> put_long(shared_id)
  end

  defp put_friend(packet, friend) do
    real_job_id = Character.real_job_id(friend.rcpt)

    friend_online? =
      case Ms2ex.World.get_character_by_name(friend.rcpt.name) do
        {:ok, _} -> true
        _ -> false
      end

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
    |> put_bool(friend.is_request)
    |> put_bool(friend.status == :pending)
    |> put_bool(friend.status == :blocked)
    |> put_bool(friend_online?)
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
