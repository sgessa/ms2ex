defmodule Ms2ex.Net.PacketLog do
  @moduledoc """
  Optional raw packet dump to disk for debugging client flows. Set `PACKET_LOG`
  to a file path to enable; without it every call is a no-op. When enabled,
  every packet is written regardless of the console `skip_packet_logs` filter.
  """

  def log(line) do
    with path when is_binary(path) <- System.get_env("PACKET_LOG") do
      File.write(path, line <> "\n", [:append, :utf8])
    end

    :ok
  rescue
    _ -> :ok
  end
end
