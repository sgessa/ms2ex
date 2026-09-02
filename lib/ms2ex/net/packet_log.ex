defmodule Ms2ex.Net.Logger do
  @moduledoc """
  Optional raw packet dump to disk for debugging client flows. Set `PACKET_LOG`
  to a file path to enable; without it every call is a no-op. When enabled,
  every packet is written regardless of the console `skip_packet_logs` filter.
  """

  require Logger

  alias Ms2ex.Net
  alias Ms2ex.Packets

  def log(direction, opcode, packet) do
    name = Packets.opcode_to_name(direction, opcode)
    opcode = inspect(opcode, base: :hex)
    text = "#{tag(direction)} #{name} (#{opcode}): #{Net.Utils.stringify_packet(packet)}"

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

  def client_report(msg) do
    with path when is_binary(path) <- Application.get_env(:ms2ex, :packet_log_file) do
      msg = "[CLIENT] #{msg}"
      File.write(path, msg <> "\n", [:append, :utf8])
    end
  end

  defp tag(:send), do: "[SEND]"
  defp tag(:recv), do: "[RECV]"

  defp to_stdout(:send, text), do: Logger.debug(IO.ANSI.format([:magenta, text]))
  defp to_stdout(:recv, text), do: Logger.debug(text)
end
