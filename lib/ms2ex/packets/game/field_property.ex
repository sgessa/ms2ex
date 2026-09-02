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
    |> put_byte(Enums.FieldProperty.get_value(property))
    |> put_bool(true)
  end

  def load(properties \\ []) do
    bytes()
    |> put_byte(@modes.load)
    |> put_int(length(properties))
  end

  def remove(property) do
    bytes()
    |> put_byte(@modes.remove)
    |> put_byte(Enums.FieldProperty.get_value(property))
  end
end
