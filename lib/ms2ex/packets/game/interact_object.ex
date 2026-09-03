defmodule Ms2ex.Packets.InteractObject do
  @moduledoc """
  Interact-object frames: field objects the client renders and lets players
  interact with (weeds, telescopes, gathering nodes, ...).
  """

  import Ms2ex.Packets.PacketWriter

  # InteractState
  @state_normal 0x00
  @state_reactable 0x01
  @state_hidden 0x02

  # InteractType
  @type_mesh 0x01
  @type_telescope 0x02
  @type_ui 0x03
  @type_display 0x05
  @type_gathering 0x06

  # commands
  @update 0x04
  @interact 0x05
  @load 0x08
  @add 0x09

  @doc "Broadcasts an object's state change (normal / reactable / hidden)."
  def update(object) do
    __MODULE__
    |> build()
    |> put_byte(@update)
    |> put_string(object.uuid)
    |> put_byte(state_byte(object))
    |> put_byte(type_byte(object))
  end

  @doc """
  Announces the field's interact objects to a joining player. The client only
  enables interaction tooltips for objects announced through this frame.
  """
  def load(objects) do
    __MODULE__
    |> build()
    |> put_byte(@load)
    |> put_int(length(objects))
    |> then(
      &Enum.reduce(objects, &1, fn object, packet ->
        packet
        |> put_string(object.uuid)
        |> put_byte(state_byte(object))
        |> put_byte(type_byte(object))
        |> maybe_put_gather_count(object)
      end)
    )
  end

  @doc """
  Announces a dynamically spawned object (ad balloon, treasure chest) with its
  full rendering data.
  """
  def add(object) do
    __MODULE__
    |> build()
    |> put_byte(@add)
    |> put_string(object.uuid)
    |> put_byte(@state_reactable)
    |> put_byte(type_byte(object))
    |> put_int(object.id)
    |> put_coord(object.position)
    |> put_coord(object.rotation)
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
    |> put_float(1.0)
    |> put_bool(false)
  end

  @doc "Plays the interaction animation for an object on every client."
  def interact(object) do
    __MODULE__
    |> build()
    |> put_byte(@interact)
    |> put_string(object.uuid)
    |> put_byte(type_byte(object))
  end

  defp maybe_put_gather_count(packet, %{type: :gathering}),
    do: put_int(packet, 10)

  defp maybe_put_gather_count(packet, _object), do: packet

  defp state_byte(%{state: :hidden}), do: @state_hidden
  defp state_byte(%{state: :reactable}), do: @state_reactable
  defp state_byte(_object), do: @state_normal

  defp type_byte(%{type: :telescope}), do: @type_telescope
  defp type_byte(%{type: :ui}), do: @type_ui
  defp type_byte(%{type: :display}), do: @type_display
  defp type_byte(%{type: :gathering}), do: @type_gathering
  defp type_byte(_object), do: @type_mesh
end
