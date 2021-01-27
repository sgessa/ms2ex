defmodule Ms2ex.ItemColor do
  alias Ms2ex.Color

  import Ms2ex.Packets.{PacketReader, PacketWriter}

  def build(primary, secondary, terziary, index), do: {primary, secondary, terziary, index}

  def get_item_color(packet) do
    {p, packet} = Color.get_color(packet)
    {s, packet} = Color.get_color(packet)
    {t, packet} = Color.get_color(packet)
    {idx, packet} = get_int(packet)
    {{p, s, t, idx}, packet}
  end

  def put_item_color(packet, {p, s, t, idx}) do
    packet
    |> Color.put_color(p)
    |> Color.put_color(s)
    |> Color.put_color(t)
    |> put_int(idx)
  end
end

defmodule Ms2ex.SkinColor do
  alias Ms2ex.Color

  def build(primary, secondary), do: {primary, secondary}

  def get_skin_color(packet) do
    {primary, packet} = Color.get_color(packet)
    {secondary, packet} = Color.get_color(packet)
    {{primary, secondary}, packet}
  end

  def put_skin_color(packet, {primary, secondary}) do
    packet
    |> Color.put_color(primary)
    |> Color.put_color(secondary)
  end
end

defmodule Ms2ex.Color do
  def build(blue, green, red, alpha), do: {blue, green, red, alpha}

  import Ms2ex.Packets.{PacketReader, PacketWriter}

  def get_color(packet) do
    {blue, packet} = get_byte(packet)
    {green, packet} = get_byte(packet)
    {red, packet} = get_byte(packet)
    {alpha, packet} = get_byte(packet)
    {{blue, green, red, alpha}, packet}
  end

  def put_color(packet, {blue, green, red, alpha}) do
    packet
    |> put_byte(blue)
    |> put_byte(green)
    |> put_byte(red)
    |> put_byte(alpha)
  end
end
