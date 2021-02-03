defmodule Ms2ex.Hair do
  import Ms2ex.Packets.{PacketReader, PacketWriter}

  @position_length 24

  defstruct [
    :back_length,
    :front_length,
    back_position: String.duplicate(<<0x0>>, @position_length),
    front_position: String.duplicate(<<0x0>>, @position_length)
  ]

  def get_hair(packet) do
    {back_length, packet} = get_int(packet)
    {back_pos, packet} = get_bytes(packet, @position_length)
    {front_length, packet} = get_int(packet)
    {front_pos, packet} = get_bytes(packet, @position_length)

    {%__MODULE__{
       back_length: back_length,
       back_position: back_pos,
       front_length: front_length,
       front_position: front_pos
     }, packet}
  end

  def put_hair(packet, %__MODULE__{} = hair) do
    packet
    |> put_int(hair.back_length)
    |> put_bytes(hair.back_position)
    |> put_int(hair.front_length)
    |> put_bytes(hair.front_position)
  end
end
