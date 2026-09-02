defmodule Ms2ex.Packets.Trigger do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @load 0x2

  # empty trigger list sent once at field load; the client uses it to
  # finalize trigger/ui state before combat UI (boss HP bar) is considered
  def load(triggers \\ []) do
    __MODULE__
    |> build()
    |> put_byte(@load)
    |> put_int(length(triggers))
  end
end
