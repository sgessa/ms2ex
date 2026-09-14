defmodule Ms2ex.Managers.PartySearchServer do
  use GenServer

  alias Ms2ex.Types
  alias Ms2ex.Types.PartySearch

  @page_size 12
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  def call(message), do: GenServer.call(__MODULE__, message)
  def cast(message), do: GenServer.cast(__MODULE__, message)

  def init(:ok), do: {:ok, %{next_id: 1, listings: %{}}}

  def handle_call({:create, party, name, no_approval, size}, _from, state) do
    cond do
      lookup_party(state.listings, party.id) ->
        {:reply, {:error, :already_registered}, state}

      not valid_size?(size) or Enum.count(party.members) >= size ->
        {:reply, {:error, :max_member}, state}

      true ->
        listing = PartySearch.new(state.next_id, party, name, no_approval, size)
        broadcast(listing, :add)

        {:reply, {:ok, listing},
         %{
           state
           | next_id: state.next_id + 1,
             listings: Map.put(state.listings, listing.id, listing)
         }}
    end
  end

  def handle_call({:remove, listing_id}, _from, state) do
    case Map.pop(state.listings, listing_id) do
      {nil, _listings} ->
        {:reply, {:error, :not_found}, state}

      {listing, listings} ->
        broadcast(listing, :remove)
        {:reply, :ok, %{state | listings: listings}}
    end
  end

  def handle_call({:lookup, listing_id}, _from, state),
    do: {:reply, Map.get(state.listings, listing_id), state}

  def handle_call({:lookup_by_party, party_id}, _from, state),
    do: {:reply, lookup_party(state.listings, party_id), state}

  def handle_call({:fetch, search, sort, page}, _from, state) do
    entries =
      state.listings
      |> Map.values()
      |> Enum.filter(&available?/1)
      |> filter_search(search)
      |> sort_entries(sort)
      |> paginate(page)

    {:reply, entries, state}
  end

  def handle_cast({:update, party}, state) do
    case lookup_party(state.listings, party.id) do
      nil ->
        {:noreply, state}

      listing ->
        case Types.Party.get_leader(party) do
          nil ->
            broadcast(listing, :remove)
            {:noreply, %{state | listings: Map.delete(state.listings, listing.id)}}

          leader ->
            updated = %{
              listing
              | member_count: Enum.count(party.members),
                leader_account_id: leader.account_id,
                leader_character_id: leader.id,
                leader_name: leader.name,
                members: party.members
            }

            broadcast(updated, :add)
            {:noreply, %{state | listings: Map.put(state.listings, updated.id, updated)}}
        end
    end
  end

  defp lookup_party(listings, party_id),
    do:
      Enum.find_value(listings, fn {_id, listing} ->
        if listing.party_id == party_id, do: listing
      end)

  defp valid_size?(size),
    do: is_integer(size) and size > 0 and size <= Types.Party.max_members()

  defp available?(listing), do: listing.member_count < listing.size

  defp filter_search(entries, search) when search in [nil, ""], do: entries

  defp filter_search(entries, search),
    do: Enum.filter(entries, &String.contains?(String.downcase(&1.name), String.downcase(search)))

  defp sort_entries(entries, :most_members), do: Enum.sort_by(entries, & &1.member_count, :desc)
  defp sort_entries(entries, :least_members), do: Enum.sort_by(entries, & &1.member_count)
  defp sort_entries(entries, :oldest), do: Enum.sort_by(entries, & &1.created_at)
  defp sort_entries(entries, _sort), do: Enum.sort_by(entries, & &1.created_at, :desc)

  defp paginate(entries, page) when is_integer(page) and page > 0,
    do: Enum.slice(entries, (page - 1) * @page_size, @page_size)

  defp paginate(_entries, _page), do: []

  defp broadcast(listing, :add),
    do: notify_members(Ms2ex.Packets.PartySearch.add(listing), listing)

  defp broadcast(listing, :remove),
    do: notify_members(Ms2ex.Packets.PartySearch.remove(listing.id), listing)

  defp notify_members(packet, listing), do: Enum.each(listing.members, &notify_member(&1, packet))

  defp notify_member(%{online?: true, sender_session_pid: pid}, packet) when is_pid(pid),
    do: Ms2ex.Net.SenderSession.push(pid, packet)

  defp notify_member(_member, _packet), do: :ok
end
