defmodule Ms2ex.Packets.LoginResult do
  import Ms2ex.Packets.PacketWriter

  @modes %{success: 0x0, incorrect_id: 0x1, already_logged_in: 0x4}

  def success(account_id) do
    timestamp = DateTime.to_unix(DateTime.utc_now())

    __MODULE__
    |> build()
    |> put_byte(@modes.success)
    |> put_int()
    |> put_ustring()
    |> put_long(account_id)
    |> put_long(timestamp)
    |> put_int(Ms2ex.sync_ticks())
    |> put_byte()
    |> put_byte()
    |> put_int()
    |> put_long()
    |> put_int(0x2)
  end

  def error(code) do
    __MODULE__
    |> build()
    |> put_byte(Map.get(@modes, code))
    |> reduce(1..45, fn _, packet -> put_byte(packet) end)
  end
end
