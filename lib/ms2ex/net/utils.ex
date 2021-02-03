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
end
