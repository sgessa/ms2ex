defmodule Ms2ex.PartyServer do
  use GenServer

  alias Ms2ex.{Party, Packets}
  alias Phoenix.PubSub

  def broadcast(party_id, packet) do
    PubSub.broadcast(Ms2ex.PubSub, "party:#{party_id}", {:push, packet})
  end

  def lookup(nil), do: :error
  def lookup(pid) when is_pid(pid), do: GenServer.call(pid, :lookup)
  def lookup(party_id), do: call(party_id, :lookup)

  def disband_if_empty(party_id), do: call(party_id, :disband_if_empty)

  def add_member(party_id, character) do
    call(party_id, {:update_member, character})
  end

  def update_member(character) do
    call(character.party_id, {:update_member, character})
  end

  def subscribe(party_id) do
    PubSub.subscribe(Ms2ex.PubSub, "party:#{party_id}")
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

  def handle_call(:disband_if_empty, _from, state) do
    if Enum.count(state.members) == 1 do
      {:stop, :normal, state}
    else
      {:reply, {:error, :not_empty}, state}
    end
  end

  def handle_call({:update_member, member}, _from, state) do
    state =
      if Party.in_party?(state, member) do
        Party.update_member(state, member)
      else
        Party.add_member(state, member)
      end

    unless Party.new?(state) do
      broadcast(state.id, Packets.Party.update_member(member))
    end

    {:reply, {:ok, state}, state}
  end

  defp call(party_id, args) do
    with pid when is_pid(pid) <- Process.whereis(:"party:#{party_id}") do
      GenServer.call(pid, args)
    end
  end
end
