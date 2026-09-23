defmodule Ms2ex.Types.KeyBind do
  import Ms2ex.Packets.{PacketReader, PacketWriter}

  @type t :: %__MODULE__{}
  defstruct key_code: 0, option_type: 0, option_guid: 0, unknown1: 0, priority: 0

  def get_key_bind(packet) do
    {key_code, packet} = get_int(packet)
    {option_type, packet} = get_int(packet)
    {option_guid, packet} = get_long(packet)
    {unknown1, packet} = get_int(packet)
    {priority, packet} = get_byte(packet)

    bind = %__MODULE__{
      key_code: key_code,
      option_type: option_type,
      option_guid: option_guid,
      unknown1: unknown1,
      priority: priority
    }

    {bind, packet}
  end

  def put_key_bind(packet, bind) do
    packet
    |> put_int(bind.key_code)
    |> put_int(bind.option_type)
    |> put_long(bind.option_guid)
    |> put_int(bind.unknown1)
    |> put_byte(bind.priority)
  end
end
