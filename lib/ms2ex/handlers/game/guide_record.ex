defmodule Ms2ex.GameHandlers.GuideRecord do
  alias Ms2ex.Context
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  # the client reports the last dismissed step of each guide pop-up; the
  # records persist so completed guides do not replay on the next login
  def handle(packet, session) do
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    {count, packet} = get_int(packet)
    {records, _packet} = read_records(count, packet, %{})

    if records != %{} do
      guide_records = Map.merge(guide_records(character), records)

      {:ok, character} = Context.Characters.update(character, %{guide_records: guide_records})
      Managers.Character.call(character, {:update, character})
    end

    session
  end

  defp read_records(0, packet, acc), do: {acc, packet}

  defp read_records(count, packet, acc) do
    {guide_id, packet} = get_int(packet)
    {step, packet} = get_int(packet)
    read_records(count - 1, packet, Map.put(acc, guide_id, step))
  end

  defp guide_records(%{guide_records: records}) when is_map(records), do: records
  defp guide_records(_character), do: %{}
end
