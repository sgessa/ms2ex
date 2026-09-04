defmodule Ms2ex.Packets.ItemBox do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @errors %{ok: 2, inventory_fail: 3, inventory_full: 4}

  def ok, do: @errors.ok

  def open(source_item_id, amount, error) do
    __MODULE__
    |> build()
    |> put_int(source_item_id)
    |> put_int(amount)
    |> put_int(error)
  end
end
