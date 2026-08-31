defmodule Ms2ex.Net.PacketLog do
  @moduledoc """
  Optional raw packet dump to disk for debugging client flows. Set `PACKET_LOG`
  to a file path to enable; without it every call is a no-op. When enabled,
  every packet is written regardless of the console `skip_packet_logs` filter.
  """

  alias Ms2ex.Net
  alias Ms2ex.Packets

  require Logger

  def log(direction, opcode, packet) do
    name = Packets.opcode_to_name(direction, opcode)
    text = "#{tag(direction)} #{name}: #{Net.Utils.stringify_packet(packet)}"

    if name not in Net.Utils.conf()[:skip_packet_logs] do
      to_stdout(direction, text)
    end

    with path when is_binary(path) <- Application.get_env(:ms2ex, :packet_log_file) do
      File.write(path, text <> "\n", [:append, :utf8])
    end

    :ok
  rescue
    _ -> :ok
  end

  defp tag(:send), do: "[SEND]"
  defp tag(:recv), do: "[RECV]"

  defp to_stdout(:send, text) do
    Logger.debug(IO.ANSI.format([:magenta, text]))
  end

  defp to_stdout(:recv, text) do
    Logger.debug(text)
  end
end
