defmodule Ms2ex.GameHandlers.FileHash do
  require Logger

  import Ms2ex.Packets.PacketReader

  def handle(packet, _session) do
    config = Application.get_env(:ms2ex, Ms2ex)

    {_, packet} = get_int(packet)
    {filename, packet} = get_string(packet)
    {md5, _packet} = get_string(packet)

    Logger.info("Hash for #{filename}: #{md5}")

    if md5 != config[:hash] do
      Logger.error("File Hash does not match")
    end
  end
end
