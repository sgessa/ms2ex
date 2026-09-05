defmodule Ms2ex.Packets.GuideObject do
  @moduledoc """
  Guide objects are the client-side markers a player controls: the fishing
  bobber, construction cursor and skill guides.
  """

  import Ms2ex.Packets.PacketWriter

  alias Ms2ex.Enums
  alias Ms2ex.Types

  @create 0x0
  @remove 0x1
  @sync 0x2

  def create(guide) do
    __MODULE__
    |> build()
    |> put_byte(@create)
    |> put_short(Enums.GuideObjectType.get_value(guide.type))
    |> put_int(guide.object_id)
    |> put_long(guide.character_id)
    |> put_coord(guide.position)
    |> put_coord(guide.rotation)
  end

  def remove(guide) do
    __MODULE__
    |> build()
    |> put_byte(@remove)
    |> put_int(guide.object_id)
    |> put_long(guide.character_id)
  end

  def sync(object_id, sync_states) do
    __MODULE__
    |> build()
    |> put_byte(@sync)
    |> put_int(object_id)
    |> put_byte(length(sync_states))
    |> reduce(sync_states, &Types.SyncState.put_state(&2, &1))
  end
end
