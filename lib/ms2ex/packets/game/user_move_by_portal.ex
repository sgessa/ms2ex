defmodule Ms2ex.Packets.UserMoveByPortal do
  @moduledoc """
  Scripted portal moves (`move_user`): the player is dropped 25 units
  above the target anchor so the client settles onto the ground instead
  of clipping into it.
  """

  import Ms2ex.Packets.PacketWriter

  def bytes(character, position, rotation \\ nil) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_coord(drop_in(position))
    |> put_coord(rotation || %{x: 0.0, y: 0.0, z: 0.0})
    |> put_bool(false)
  end

  # the reference's MoveByPortal always offsets the target 25 units up
  defp drop_in(%{z: z} = position), do: %{position | z: z + 25}
end
