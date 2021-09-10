defmodule Ms2ex.PartyServer do
  use GenServer

  alias Ms2ex.{Party, Packets}

  def lookup(pid) when is_pid(pid), do: GenServer.call(pid, :lookup)
  def lookup(party_id), do: call(party_id, :lookup)

  def update_member(character) do
    call(character.party_id, {:update_member, character})
  end

  def start(leader) do
    GenServer.start(__MODULE__, leader)
  end

  def init(leader) do
    party = Party.create(leader)
    Process.register(self(), :"party:#{party.id}")
    {:ok, party}
  end

  def handle_call(:lookup, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:update_member, member}, _from, state) do
    if index = Enum.find_index(state.members, &(&1.id == member.id)) do
      members = List.update_at(state.members, index, fn _ -> member end)

      for m <- members, m.id != member.id do
        send(m.session_pid, {:push, Packets.Party.update_member(member)})
      end

      state = %{state | members: members}
      {:reply, {:ok, state}, state}
    else
      {:reply, {:ok, state}, state}
    end
  end

  defp call(party_id, args) do
    with pid when is_pid(pid) <- Process.whereis(:"party:#{party_id}") do
      GenServer.call(pid, args)
    end
  end
end
