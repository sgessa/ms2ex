defmodule Ms2ex.Packets.GroupChat do
  import Ms2ex.Packets.PacketWriter

  @mode %{
    update: 0x0,
    create: 0x1,
    invite: 0x2,
    join: 0x3,
    leave: 0x4,
    update_members: 0x6,
    leave_notice: 0x7,
    login_notice: 0x8,
    logout_notice: 0x9,
    chat: 0xA,
    error: 0xD
  }

  def update(group_chat) do
    __MODULE__
    |> build()
    |> put_byte(@mode.update)
    |> put_int(group_chat.id)
    |> put_byte(length(group_chat.members))
    |> reduce(group_chat.members, fn m, packet ->
      packet
      |> put_byte(0x1)
      |> Ms2ex.Packets.CharacterList.put_character(m)
    end)
  end

  def create(group_chat) do
    __MODULE__
    |> build()
    |> put_byte(@mode.create)
    |> put_int(group_chat.id)
  end

  def invite(character, rcpt, group_chat) do
    __MODULE__
    |> build()
    |> put_byte(@mode.invite)
    |> put_ustring(character.name)
    |> put_ustring(rcpt.name)
    |> put_int(group_chat.id)
  end

  def join(character, rcpt, group_chat) do
    __MODULE__
    |> build()
    |> put_byte(@mode.join)
    |> put_ustring(character.name)
    |> put_ustring(rcpt.name)
    |> put_int(group_chat.id)
  end

  def leave(group_chat) do
    __MODULE__
    |> build()
    |> put_byte(@mode.leave)
    |> put_int(group_chat.id)
  end

  def update_members(group_chat, new_member) do
    __MODULE__
    |> build()
    |> put_byte(@mode.update_members)
    |> put_int(group_chat.id)
    |> put_ustring(new_member.name)
    |> put_byte(0x1)
    |> Ms2ex.Packets.CharacterList.put_character(new_member)
  end

  def leave_notice(group_chat, character) do
    __MODULE__
    |> build()
    |> put_byte(@mode.leave_notice)
    |> put_int(group_chat.id)
    |> put_byte()
    |> put_ustring(character.name)
  end

  def chat(group_chat, sender, msg) do
    __MODULE__
    |> build()
    |> put_byte(@mode.chat)
    |> put_int(group_chat.id)
    |> put_ustring(sender.name)
    |> put_ustring(msg)
  end

  def error(error, character, rcpt_name) do
    __MODULE__
    |> build()
    |> put_byte(@mode.error)
    |> put_byte(0x2)
    |> put_int(error)
    |> put_ustring(character.name)
    |> put_ustring(rcpt_name)
  end
end
