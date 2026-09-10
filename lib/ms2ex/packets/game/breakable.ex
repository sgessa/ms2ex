defmodule Ms2ex.Packets.Breakable do
  import Ms2ex.Packets.PacketWriter

  # commands
  @batch_update 0x0

  @doc """
  Announces the field's breakable objects to a joining player. Breakables
  toggle between shown/hidden/broken states as trigger scripts drive them.
  """
  def load(breakables) do
    update(breakables)
  end

  @doc """
  Applies a state/visible change to a batch of breakable objects. Each entry
  carries the map entity uuid the client knows the object by, plus its state
  byte and visibility.
  """
  def update(entries) do
    __MODULE__
    |> build()
    |> put_byte(@batch_update)
    |> put_int(length(entries))
    |> then(
      &Enum.reduce(entries, &1, fn entry, packet ->
        packet
        |> put_string(entry.uuid)
        |> put_byte(entry.state)
        |> put_bool(entry.visible)
        |> put_int(0)
        |> put_int(0)
      end)
    )
  end

  def load_empty do
    build(__MODULE__)
    |> put_byte(0x0)
    |> put_int(0)
  end
end
