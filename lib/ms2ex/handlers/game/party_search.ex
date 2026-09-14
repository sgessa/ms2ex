defmodule Ms2ex.GameHandlers.PartySearch do
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Managers.PartySearchServer
  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Packets

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2, run: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)

    case mode do
      0 -> add(packet, session)
      1 -> remove(session)
      2 -> load(packet, session)
      _ -> session
    end
  end

  defp add(packet, session) do
    {name, packet} = get_ustring(packet)
    {no_approval, packet} = get_bool(packet)
    {size, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, party} <- ensure_party(session, character),
         true <- party.leader_id == character.id,
         {:ok, _listing} <-
           PartySearchServer.call({:create, party, name, no_approval, size}) do
      :ok
    else
      false -> push(session, Packets.PartySearch.error(:not_chief))
      {:error, reason} -> push(session, Packets.PartySearch.error(reason))
      _ -> push(session, Packets.PartySearch.error(:server_db))
    end

    session
  end

  defp remove(session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, party} <- PartyServer.call(character.party_id, :lookup),
         true <- party.leader_id == character.id,
         listing when not is_nil(listing) <-
           PartySearchServer.call({:lookup_by_party, party.id}),
         :ok <- PartySearchServer.call({:remove, listing.id}) do
      :ok
    else
      false -> push(session, Packets.PartySearch.error(:not_chief))
      nil -> push(session, Packets.PartySearch.error(:not_find_recruit))
      _ -> push(session, Packets.PartySearch.error(:server_db))
    end

    session
  end

  defp load(packet, session) do
    {_unknown, packet} = get_int(packet)
    {_unknown, packet} = get_int(packet)
    {sort, packet} = get_byte(packet)
    {search, packet} = get_ustring(packet)
    {page, packet} = get_int(packet)
    {_unknown, _packet} = get_int(packet)

    if Enums.PartySearchSort.get_key(sort) != :invalid_enum do
      entries =
        PartySearchServer.call({:fetch, search, Enums.PartySearchSort.get_key(sort), page})

      push(session, Packets.PartySearch.load(entries))
    else
      push(session, Packets.PartySearch.error(:invalid_type))
    end

    session
  end

  defp ensure_party(_session, character) when is_integer(character.party_id) do
    PartyServer.call(character.party_id, :lookup)
  end

  defp ensure_party(session, character) do
    {:ok, party} = Managers.PartyManager.create(character)
    updated = %{character | party_id: party.id}
    Managers.Character.call(updated, {:update, updated})
    run(session, fn -> PartyServer.subscribe(party.id) end)
    push(session, Packets.Party.create(party))
    {:ok, party}
  end
end
