defmodule Ms2ex.Packets.Wallet do
  alias Ms2ex.{Packets, Wallet}

  import Packets.PacketWriter

  def update(:mesos, amount) do
    Packets.Mesos.update(amount)
  end

  def update(type, amount) when type in [:merets, :game_merets, :event_merets] do
    Packets.Merets.update(amount)
  end

  def update(type, amount) do
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
