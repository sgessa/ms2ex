defmodule Ms2ex.Net.Utils do
  def peername(socket) do
    {:ok, {inet, port}} = :inet.peername(socket)
    inet = inet |> Tuple.to_list() |> Enum.map(&to_string/1) |> Enum.join(".")
    "#{inet}:#{port}"
  end

  def stringify_packet(packet) do
    packet
    |> Base.encode16()
    |> String.codepoints()
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(" ")
  end

  def conf() do
    conf = Application.fetch_env!(:ms2ex, Ms2ex)
    version = conf[:version] || 12

    %{
      skip_packet_logs: conf[:skip_packet_logs] || [],
      version: version,
      block_iv: conf[:initial_block_iv] || version
    }
  end
end
