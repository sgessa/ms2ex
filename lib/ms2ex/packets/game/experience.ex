defmodule Ms2ex.Packets.Experience do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(exp_gained, total_exp, rest_exp) do
    __MODULE__
    |> build()
    |> put_byte()
    |> put_int(exp_gained)
    |> put_int()
    |> put_short()
    |> put_long(total_exp)
    |> put_long(rest_exp)
    |> put_int()
    |> put_byte()
  end
end
