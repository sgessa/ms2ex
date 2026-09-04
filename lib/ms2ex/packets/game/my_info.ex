defmodule Ms2ex.Packets.MyInfo do
  alias Ms2ex.Enums

  import Ms2ex.Packets.PacketWriter

  def update_motto(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_ustring(character.motto)
    |> put_int(Enums.MyInfoError.get_value(:none))
    |> put_ustring()
  end

  def error(message) do
    __MODULE__
    |> build()
    |> put_int()
    |> put_ustring()
    |> put_int(Enums.MyInfoError.get_value(:custom_message))
    |> put_ustring(message)
  end
end
