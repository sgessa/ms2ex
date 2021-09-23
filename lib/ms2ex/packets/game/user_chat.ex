defmodule Ms2ex.Packets.UserChat do
  alias Ms2ex.{Chat, Packets, SystemNotice}

  import Packets.PacketWriter

  def bytes(type, character, msg) do
    type_id = Keyword.get(Chat.Type.__enum_map__(), type)

    __MODULE__
    |> build()
    |> put_long(character.account_id)
    |> put_long(character.id)
    |> put_ustring(character.name)
    |> put_byte
    |> put_ustring(msg)
    |> put_int(type_id)
    |> put_byte()
    |> put_int(character.channel_id)
    |> put_data(type, character)
    |> put_byte()
  end

  def error(character, type, error) do
    type_id = Keyword.get(Chat.Type.__enum_map__(), type)
    error_id = SystemNotice.from_name(error)

    __MODULE__
    |> build()
    |> put_long()
    |> put_long()
    |> put_ustring(character.name)
    |> put_byte(0x1)
    |> put_int(error_id)
    |> put_int(type_id)
    |> put_byte()
    |> put_int(character.channel_id)
    |> put_byte()
  end

  defp put_data(packet, :whisper_from, _character), do: put_ustring(packet, "???")

  defp put_data(packet, :club, _character), do: put_long(packet)

  defp put_data(packet, :super, character), do: put_int(packet, character.super_chat_id)

  defp put_data(packet, _type, _character), do: packet
end
