defmodule Ms2ex.Packets.RecallScroll do
  @behaviour Ms2ex.Packets.Spec

  import Ms2ex.Packets.PacketWriter

  @commands %{close: 0x0, open: 0x1}

  # Popup asking a guild/party/wedding member to follow the caster. `slot`
  # selects which notify clip the client renders and which notice string it
  # shows (0 guild, 1 party, 2 wedding). `deadline` is unix seconds on the
  # client's server-time clock (synced via the time-sync packet); the client
  # counts it down and turns red in the last ten seconds. The two unnamed
  # ints are stored by the client but never rendered.
  def open(slot, caster_name, map_id, deadline) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:open])
    |> put_byte(slot)
    |> put_ustring(caster_name)
    |> put_int()
    |> put_int(map_id)
    |> put_int()
    |> put_long(deadline)
  end

  def close(slot) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:close])
    |> put_byte(slot)
  end

  @impl true
  def commands, do: @commands

  @impl true
  def spec(0x1) do
    [
      slot: :byte,
      caster_name: :ustring,
      _stored_a: :int,
      map_id: :int,
      _stored_b: :int,
      deadline: :long
    ]
  end

  def spec(0x0), do: [slot: :byte]
end
