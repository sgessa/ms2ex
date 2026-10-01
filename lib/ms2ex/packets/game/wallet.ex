defmodule Ms2ex.Packets.Wallet do
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def update(wallet, type, delta \\ 0, overflow \\ 0)

  def update(wallet, :mesos, _delta, _overflow) do
    wallet
    |> Map.get(:mesos)
    |> Packets.Mesos.update()
  end

  def update(wallet, type, delta, _overflow)
      when type in [:merets, :game_merets, :event_merets] do
    Packets.Merets.update(wallet, delta)
  end

  # CurrencyToken: balance, applied delta, the overflow a clamped credit
  # produced (drives the client's loss notice)
  def update(wallet, type, delta, overflow) do
    amount = Map.get(wallet, type)

    __MODULE__
    |> build()
    |> put_byte(Context.Wallets.currency_type(type))
    |> put_long(amount)
    |> put_long(delta)
    |> put_int()
    |> put_long(overflow)
  end
end
