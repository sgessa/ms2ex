defmodule Ms2ex.Packets.FieldProperty do
  alias Ms2ex.Enums
  import Ms2ex.Packets.PacketWriter

  @modes %{
    load: 0x0,
    add: 0x1,
    remove: 0x2
  }

  defp bytes() do
    __MODULE__
    |> build()
  end

  def add(property) do
    bytes()
    |> put_byte(@modes.add)
    |> put_property(property)
  end

  def load(properties \\ []) do
    bytes()
    |> put_byte(@modes.load)
    |> put_int(length(properties))
    |> reduce(properties, &put_property(&2, &1))
  end

  def remove(property) do
    bytes()
    |> put_byte(@modes.remove)
    |> put_byte(Enums.FieldProperty.get_value(property))
  end

  # the concert property names the performer and when the stage frees up
  defp put_property(packet, {:music_concert, character_id, end_tick}) do
    packet
    |> put_byte(Enums.FieldProperty.get_value(:music_concert))
    |> put_long(character_id)
    |> put_int(end_tick)
  end

  defp put_property(packet, property) when is_atom(property) do
    packet
    |> put_byte(Enums.FieldProperty.get_value(property))
    |> put_bool(true)
  end
end
