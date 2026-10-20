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
    opcode_hex = inspect(opcode, base: :hex)
    text = "#{tag(direction)} #{name} (#{opcode_hex}): #{Net.Utils.stringify_packet(packet)}"

    text = append_decoded(text, direction, opcode, packet)

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

  # The decoder ships for dev/test only; when present, packets with a
  # layout are logged with their decoded fields appended.
  defp append_decoded(text, direction, opcode, packet)
       when is_integer(opcode) and direction in [:send, :recv] do
    if Code.ensure_loaded?(Ms2ex.Packets.Decoder) do
      append_decoded_fields(text, direction, opcode, packet)
    else
      text
    end
  end

  defp append_decoded_fields(text, direction, opcode, packet) do
    case Ms2ex.Packets.Decoder.decode(direction, <<opcode::little-16, packet::binary>>) do
      %{fields: fields, command: command, rest: rest} when fields != %{} ->
        leftover = if rest == <<>>, do: "", else: " (#{byte_size(rest)} undecoded bytes)"
        command = if command, do: " #{command}", else: ""
        text <> "\n  decoded#{command}: #{inspect(fields)}" <> leftover

      _ ->
        text
    end
  end

  defp append_decoded(text, _direction, _opcode, _packet), do: text

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
