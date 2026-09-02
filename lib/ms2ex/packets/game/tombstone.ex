defmodule Ms2ex.Packets.Tombstone do
  import Ms2ex.Packets.PacketWriter

  # a player's tombstone state: how many hits remain before a teammate can
  # revive them. unknown1 is 1 when hit by a user, unknown2 when a pet revives.
  def bytes(tombstone) do
    __MODULE__
    |> build()
    |> put_int(tombstone.object_id)
    |> put_byte(tombstone.hits_remaining)
    |> put_byte(tombstone.total_hit_count)
    |> put_int(Map.get(tombstone, :unknown1, 1))
    |> put_bool(Map.get(tombstone, :unknown2, false))
  end
end
