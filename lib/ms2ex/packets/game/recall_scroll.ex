defmodule Ms2ex.Packets.RecallScroll do
  @behaviour Ms2ex.Packets.Spec

  import Ms2ex.Packets.PacketWriter

  @commands %{close: 0x0, open: 0x1}

  # Popup asking a party/guild/wedding member to follow the caster. `deadline`
  # is a server-tick timestamp (same clock as the client's time sync); the
  # client counts it down and turns red in the last ten seconds. The two
  # unnamed ints are stored by the client but never rendered.
  def open(type, caster_name, map_id, deadline) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:open])
    |> put_byte(type)
    |> put_ustring(caster_name)
    |> put_int()
    |> put_int(map_id)
    |> put_int()
    |> put_long(deadline)
  end

  def close(type) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:close])
    |> put_byte(type)
  end

  @impl true
  def commands, do: @commands

  @impl true
  def spec(0x1) do
    [
      type: :byte,
      caster_name: :ustring,
      _stored_a: :int,
      map_id: :int,
      _stored_b: :int,
      deadline: :long
    ]
  end

  def spec(0x0), do: [type: :byte]
end
