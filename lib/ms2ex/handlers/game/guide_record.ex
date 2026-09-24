defmodule Ms2ex.GameHandlers.GuideRecord do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  # the client reports the last dismissed step of each guide pop-up; the
  # records persist so completed guides do not replay on the next login
  def handle(packet, session) do
    {count, packet} = get_int(packet)
    {records, _packet} = read_records(count, packet, %{})

    if records != %{} do
      :ok = Managers.CharacterConfig.merge_guide_records(session.character_id, records)
    end

    session
  end

  defp read_records(0, packet, acc), do: {acc, packet}

  defp read_records(count, packet, acc) do
    {guide_id, packet} = get_int(packet)
    {step, packet} = get_int(packet)
    read_records(count - 1, packet, Map.put(acc, guide_id, step))
  end
end
