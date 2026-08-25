defmodule Ms2ex.Packets.FieldPickupItem do
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Packets.PacketWriter

  # mesos carry a long amount, stamina an int amount, every other item
  # none at all
  def bytes(character, item) do
    __MODULE__
    |> build()
    |> put_bool(true)
    |> put_int(item.object_id)
    |> put_int(character.object_id)
    |> put_amount(item)
  end

  defp put_amount(packet, item) do
    cond do
      Context.Items.mesos?(item) -> put_long(packet, item.amount)
      Context.Items.stamina?(item) -> put_int(packet, item.amount)
      true -> packet
    end
  end
end
