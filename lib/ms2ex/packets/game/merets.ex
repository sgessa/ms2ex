defmodule Ms2ex.Packets.Merets do
  import Ms2ex.Packets.PacketWriter

  # balances first, then the delta that drives the client-side gain toast
  def update(wallet, delta \\ 0) do
    __MODULE__
    |> build()
    |> put_long(Map.get(wallet, :merets) || 0)
    |> put_long()
    |> put_long(Map.get(wallet, :game_merets) || 0)
    |> put_long()
    |> put_long(delta)
  end
end
