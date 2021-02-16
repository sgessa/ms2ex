defmodule Ms2ex.Packets.Wallet do
  alias Ms2ex.{Packets, Wallet}

  import Packets.PacketWriter

  def update(wallet, :mesos) do
    wallet
    |> Map.get(:mesos)
    |> Packets.Mesos.update()
  end

  def update(wallet, type) when type in [:merets, :game_merets, :event_merets] do
    wallet
    |> Map.get(type)
    |> Packets.Merets.update()
  end

  def update(wallet, type) do
    amount = Map.get(wallet, type)

    __MODULE__
    |> build()
    |> put_byte(Wallet.currency_type(type))
    |> put_long(amount)
    |> put_long(-1)
    |> put_short(52)
    |> put_long()
    |> put_short()
  end
end
