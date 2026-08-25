defmodule Ms2ex.Packets.Wallet do
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def update(wallet, type, delta \\ 0)

  def update(wallet, :mesos, _delta) do
    wallet
    |> Map.get(:mesos)
    |> Packets.Mesos.update()
  end

  def update(wallet, type, delta) when type in [:merets, :game_merets, :event_merets] do
    Packets.Merets.update(wallet, delta)
  end

  def update(wallet, type, _delta) do
    amount = Map.get(wallet, type)

    __MODULE__
    |> build()
    |> put_byte(Context.Wallets.currency_type(type))
    |> put_long(amount)
    |> put_long(-1)
    |> put_short(52)
    |> put_long()
    |> put_short()
  end
end
