defmodule Ms2ex.Packets.RecallUser do
  @behaviour Ms2ex.Packets.Spec

  import Ms2ex.Packets.PacketWriter

  @commands %{request: 0x4}

  # A summon request the client shows as a modal box: "{caster} wants to
  # summon you to their location", with accept/decline buttons; the box
  # closes itself after roughly twenty seconds. `type` is 0 for party
  # summons. The member's reply echoes `request_id`.
  def request(type, caster_name, request_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands[:request])
    |> put_byte(type)
    |> put_ustring(caster_name)
    |> put_int(request_id)
  end

  @impl true
  def commands, do: @commands

  @impl true
  def spec(0x4) do
    [
      type: :byte,
      caster_name: :ustring,
      request_id: :int
    ]
  end
end
