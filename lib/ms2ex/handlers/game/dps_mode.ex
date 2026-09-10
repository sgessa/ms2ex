defmodule Ms2ex.GameHandlers.DpsMode do
  alias Ms2ex.Managers
  alias Ms2ex.Managers.PartyServer

  import Ms2ex.Net.SenderSession, only: [run: 2]
  import Ms2ex.Packets.PacketReader

  def handle(packet, session) do
    {mode, _packet} = get_byte(packet)

      with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
        {:ok, party_id} <- party_id_for(character),
        {:ok, party} <- PartyServer.call(party_id, :lookup) do
      {:ok, party} = PartyServer.call(party.id, {:set_dps_mode, mode != 0})
      run(session, fn -> PartyServer.subscribe(party.id) end)
      Ms2ex.Net.SenderSession.push(session, Ms2ex.Packets.DpsStat.bytes(party))
    end

    session
  end

  defp party_id_for(%{party_id: party_id}) when is_integer(party_id), do: {:ok, party_id}
  defp party_id_for(character), do: Managers.PartyManager.lookup(character)
end
