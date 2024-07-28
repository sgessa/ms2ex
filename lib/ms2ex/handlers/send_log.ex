defmodule Ms2ex.Handlers.SendLog do
  require Logger

  import Ms2ex.Packets.PacketReader

  def handle(packet, session) do
    {_, packet} = get_byte(packet)
    handle_mod(packet)
    session
  end

  def handle_mod(<<0x1, _::bytes>>), do: :ok

  def handle_mod(<<_mode, packet::bytes>>) do
    msg = read_msg(packet)
    if byte_size(msg) > 0, do: Logger.warning("[CLIENT] #{msg}")
  end

  def read_msg(packet, builder \\ "")

  def read_msg(packet, builder) when byte_size(packet) > 2 do
    {msg, packet} = get_ustring(packet)

    msg
    |> String.contains?("exception")
    |> maybe_read_exception(builder, msg, packet)
  end

  def read_msg(_packet, builder), do: builder

  def maybe_read_exception(true, _builder, msg, packet) do
    {debug, _packet} = get_ustring(packet)
    Logger.error("[CLIENT] #{msg}: #{debug}")
    ""
  end

  def maybe_read_exception(false, builder, msg, packet) do
    read_msg(packet, builder <> msg)
  end
end
