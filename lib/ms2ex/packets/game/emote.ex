defmodule Ms2ex.Packets.Emote do
  import Ms2ex.Packets.PacketWriter

  @modes %{load: 0x0, learn: 0x1, use: 0x2}

  def load(emotes) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_int(length(emotes))
    |> reduce(emotes, fn emote_id, packet ->
      packet
      |> put_int(emote_id)
      |> put_int(0x1)
      |> put_long(0x0)
    end)
  end

  def learn(emote_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.learn)
    |> put_int(emote_id)
    |> put_int(1)
    |> put_long()
  end

  def use(character, emote_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.use)
    |> put_int(character.object_id)
    |> put_int(emote_id)
  end
end
