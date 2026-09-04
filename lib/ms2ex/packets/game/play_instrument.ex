defmodule Ms2ex.Packets.PlayInstrument do
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketWriter

  @modes %{
    start_improvise: 0x0,
    improvise: 0x1,
    stop_improvise: 0x2,
    start_score: 0x3,
    stop_score: 0x4,
    leave_ensemble: 0x6,
    compose_score: 0x8,
    remaining_uses: 0x9,
    view_score: 0xA,
    fireworks: 0xE
  }

  def start_improvise(instrument) do
    __MODULE__
    |> build()
    |> put_byte(@modes.start_improvise)
    |> put_int(instrument.object_id)
    |> put_int(instrument.owner_id)
    |> put_coord(instrument.position)
    |> put_int(instrument.metadata.midi_id)
    |> put_int(instrument.metadata.percussion_id)
  end

  # a midi note as sent by the client: unknown byte, note, then volume
  def improvise(instrument, <<note::bytes-size(4)>>) do
    __MODULE__
    |> build()
    |> put_byte(@modes.improvise)
    |> put_int(instrument.object_id)
    |> put_int(instrument.owner_id)
    |> put_bytes(note)
  end

  def stop_improvise(instrument) do
    __MODULE__
    |> build()
    |> put_byte(@modes.stop_improvise)
    |> put_int(instrument.object_id)
    |> put_int(instrument.owner_id)
  end

  def start_score(instrument, score) do
    __MODULE__
    |> build()
    |> put_byte(@modes.start_score)
    |> put_bool(custom?(score))
    |> put_int(instrument.object_id)
    |> put_int(instrument.owner_id)
    |> put_coord(instrument.position)
    |> put_int(instrument.start_tick)
    |> put_int(instrument.metadata.midi_id)
    |> put_int(instrument.metadata.percussion_id)
    |> put_bool(instrument.ensemble?)
    |> put_score(score)
  end

  def stop_score(instrument) do
    __MODULE__
    |> build()
    |> put_byte(@modes.stop_score)
    |> put_int(instrument.object_id)
    |> put_int(instrument.owner_id)
  end

  def leave_ensemble() do
    __MODULE__
    |> build()
    |> put_byte(@modes.leave_ensemble)
  end

  def remaining_uses(score_uid, remaining) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remaining_uses)
    |> put_long(score_uid)
    |> put_int(remaining)
  end

  def compose_score(score, character) do
    __MODULE__
    |> build()
    |> put_byte(@modes.compose_score)
    |> put_long(score.id)
    |> Packets.InventoryItem.put_item(score, character)
  end

  def view_score(score_uid, mml) do
    __MODULE__
    |> build()
    |> put_byte(@modes.view_score)
    |> put_long(score_uid)
    |> put_string(mml)
  end

  def fireworks(object_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.fireworks)
    |> put_int(object_id)
  end

  # composed scores travel as their raw mml, preset ones as the client-side
  # score file name
  defp put_score(packet, score) do
    case custom_mml(score) do
      nil -> put_ustring(packet, file_name(score))
      mml -> put_string(packet, mml)
    end
  end

  defp custom?(score), do: custom_mml(score) != nil

  defp custom_mml(%{data: %{music: %{mml: mml, author_id: author_id}}})
       when is_binary(mml) and author_id != 0,
       do: mml

  defp custom_mml(_score), do: nil

  defp file_name(%{metadata: %{music: %{file_name: file_name}}}) when is_binary(file_name),
    do: file_name

  defp file_name(_score), do: ""
end
