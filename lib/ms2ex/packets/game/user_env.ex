defmodule Ms2ex.Packets.UserEnv do
  import Ms2ex.Packets.PacketWriter

  @modes %{start_list: 0x0, set_titles: 0x2, end_list: 0x4}

  def set_titles(titles) do
    __MODULE__
    |> build()
    |> put_byte(@modes.set_titles)
    |> put_int(length(titles))
    |> reduce(titles, fn title_id, packet ->
      put_int(packet, title_id)
    end)
  end

  def set_mode(mode, integers \\ 1) do
    __MODULE__
    |> build()
    |> put_byte(mode)
    |> put_zeroes(integers)
  end

  defp put_zeroes(packet, integers) when integers > 0 do
    packet
    |> put_int()
    |> put_zeroes(integers - 1)
  end

  defp put_zeroes(packet, _integers), do: packet
end
