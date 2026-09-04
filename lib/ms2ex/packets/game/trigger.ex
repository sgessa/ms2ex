defmodule Ms2ex.Packets.Trigger do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    load: 0x2,
    update: 0x3,
    ui: 0x8
  }

  @ui_modes %{
    guide: 0x1
  }

  # Sent once at field load: the client finalizes trigger/ui state from the
  # object list before combat UI (boss HP bar) is considered. Meshes already
  # dropped by opened gates join as hidden entries.
  def load(meshes \\ []) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_int(length(meshes))
    |> reduce(meshes, fn mesh, packet -> put_mesh(packet, false, mesh) end)
  end

  # Notifies the client that a map trigger mesh changed state — e.g. a
  # barrier mesh dropping once its guard mobs are dead.
  def update_mesh(visible, mesh) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update)
    |> put_mesh(visible, mesh)
  end

  def hide_mesh(mesh), do: update_mesh(false, mesh)

  # advances the client's guide widget to the given step — e.g. the tutorial
  # ui moving on to "head to the exit" once the barrier drops
  def guide_event(event_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.ui)
    |> put_byte(@ui_modes.guide)
    |> put_int(event_id)
  end

  # minimap_invisible is the mesh's own flag carried verbatim
  defp put_mesh(packet, visible, %{id: id, minimap_invisible: minimap, scale: scale}) do
    packet
    |> put_int(id)
    |> put_bool(visible)
    |> put_bool(minimap)
    |> put_int()
    |> put_ustring()
    |> put_float(scale)
  end
end
