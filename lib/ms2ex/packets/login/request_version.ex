defmodule Ms2ex.Packets.RequestVersion do
  alias Ms2ex.Packets
  alias Ms2ex.Crypto.{RecvCipher, SendCipher}

  import Packets.PacketWriter

  def build(version, %RecvCipher{} = recv, %SendCipher{} = sender, block_iv) do
    type = 0

    ""
    |> put_short(0x1)
    |> put_int(version)
    |> put_int(recv.iv)
    |> put_int(sender.iv)
    |> put_int(block_iv)
    |> put_byte(type)
  end
end
