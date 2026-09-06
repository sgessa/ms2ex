defmodule Ms2ex.Packets.SetCraftMode do
  import Ms2ex.Packets.PacketWriter

  @commands %{stop: 0x0, plot: 0x1, liftable: 0x2}

  # broadcast when a player exits craft/liftable mode; also emitted on death so
  # clients clear any craft pose before the corpse is posed
  def stop(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
    |> put_byte(@commands.stop)
  end

  # shows a player carrying a liftable prop (quest carry sequences)
  def liftable(object_id, item_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
    |> put_byte(@commands.liftable)
    |> put_int(item_id)
    |> put_long()
    |> put_long()
    |> put_bool(false)
    |> put_int(2)
  end
end
