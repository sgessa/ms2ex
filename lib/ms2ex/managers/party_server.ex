defmodule Ms2ex.PartyServer do
  use GenServer

  alias Ms2ex.{Packets, Party, PartyManager}
  alias Phoenix.PubSub

  require Logger, as: L

  def broadcast(nil, _packet), do: :error

  def broadcast(party_id, packet) do
    PubSub.broadcast(Ms2ex.PubSub, "party:#{party_id}", {:push, packet})
  end

  def broadcast_from(_pid, nil, _packet), do: :error

  def broadcast_from(sender_pid, party_id, packet) do
    PubSub.broadcast_from(Ms2ex.PubSub, sender_pid, "party:#{party_id}", {:push, packet})
  end

  def lookup(nil), do: :error
  def lookup(pid) when is_pid(pid), do: GenServer.call(pid, :lookup)
  def lookup(party_id), do: call(party_id, :lookup)

  def lookup!(nil), do: nil

  def lookup!(party_id) do
    case call(party_id, :lookup) do
      {:ok, party} -> party
      _ -> nil
    end
  end

  def member_offline(character) do
    call(character.party_id, {:member_offline, character})
  end

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

    L.debug(fn -> "NEW PARTY CREATED WITH ID: #{party.id}" end)

    {:ok, party}
  end

  def handle_call(:lookup, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:member_offline, character}, _from, state) do
    state = update_member(state, character)
    member_online = Enum.find(state.members, & &1.online?)

    if member_online do
      broadcast(state.id, Packets.Party.logout_notice(character))
      state = maybe_find_new_leader(state, character, member_online)
      {:reply, :ok, state}
    else
      send(self(), :shutdown)
      {:reply, :ok, state}
    end
  end

  def handle_call({:update_member, character}, _from, state) do
    state = update_member(state, character)

    unless Party.new?(state) do
      broadcast(state.id, Packets.Party.update_member(character))
    end

    {:reply, {:ok, state}, state}
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  defp update_member(party, member) do
    if Party.in_party?(party, member) do
      Party.update_member(party, member)
    else
      PartyManager.register(party, member)
      Party.add_member(party, member)
    end
  end

  defp maybe_find_new_leader(party, character, new_leader) do
    if character.id == party.leader_id do
      broadcast(party.id, Packets.Party.set_leader(new_leader))
      %{party | leader_id: new_leader.id}
    else
      party
    end
  end

  defp call(party_id, args) do
    with pid when is_pid(pid) <- Process.whereis(:"party:#{party_id}") do
      GenServer.call(pid, args)
    end
  end
end
