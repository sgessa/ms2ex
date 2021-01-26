defmodule Ms2ex.Packets.UserChat do
  import Ms2ex.Packets.PacketWriter

  def bytes({type, type_id}, character, msg) do
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
    |> put_data(type)
    |> put_byte()
  end

  defp put_data(packet, :whisper_from), do: put_ustring(packet, "???")

  defp put_data(packet, _type), do: packet
end
