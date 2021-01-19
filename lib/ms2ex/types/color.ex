defmodule Ms2ex.ItemColor do
  import Ms2ex.Packets.PacketWriter

  def build(primary, secondary, terziary, index), do: {primary, secondary, terziary, index}

  def put_item_color(packet, {p, s, t, idx}) do
    packet
    |> put_color(p)
    |> put_color(s)
    |> put_color(t)
    |> put_int(idx)
  end
end

defmodule Ms2ex.SkinColor do
  def build(primary, secondary), do: {primary, secondary}
end

defmodule Ms2ex.Color do
  def build(blue, green, red, alpha), do: {blue, green, red, alpha}
end
