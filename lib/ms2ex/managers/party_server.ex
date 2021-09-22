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

  def update_member(character) do
    call(character.party_id, {:update_member, character})
  end

  def remove_member(character) do
    call(character.party_id, {:remove_member, character})
  end

  def kick_member(party, character_id) do
    call(party.id, {:kick_member, character_id})
  end

  def start_vote_kick(party, character_id) do
    cast(party.id, {:start_vote_kick, character_id})
  end

  def start_ready_check(party) do
    cast(party.id, :start_ready_check)
  end

  def ready_check(party, character, response) do
    cast(party.id, {:ready_check, character, response})
  end

  def subscribe(party_id) do
    PubSub.subscribe(Ms2ex.PubSub, "party:#{party_id}")
  end

  def unsubscribe(party_id) do
    PubSub.unsubscribe(Ms2ex.PubSub, "party:#{party_id}")
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

  def handle_call({:remove_member, character}, _from, state) do
    broadcast(state.id, Packets.Party.member_left(character))
    state = Party.remove_member(state, character)

    member_online = Enum.find(state.members, & &1.online?)

    if Party.new?(state) or !member_online do
      disband(state)
      {:reply, :ok, state}
    else
      {:reply, :ok, maybe_find_new_leader(state, character, member_online)}
    end
  end

  def handle_call({:kick_member, character_id}, _from, state) do
    case Party.get_member(state, character_id) do
      nil ->
        {:reply, :error, state}

      character ->
        broadcast(state.id, Packets.Party.kick(character))

        state = Party.remove_member(state, character)

        if Party.new?(state) do
          disband(state)
          {:reply, {:ok, character}, state}
        else
          {:reply, {:ok, character}, state}
        end
    end
  end

  def handle_cast({:start_vote_kick, character_id}, state) do
    case Party.get_member(state, character_id) do
      nil ->
        {:reply, :error, state}

      _character ->
        # TODO send start vote kick packet
        {:reply, :ok, state}
    end
  end

  def handle_cast(:start_ready_check, state) do
    if Party.ready_check_in_progress?(state) do
      {:noreply, state}
    else
      broadcast(state.id, Packets.Party.start_ready_check(state))
      Process.send_after(self(), :end_ready_check, 20_000)
      {:noreply, state}
    end
  end

  def handle_cast({:ready_check, character, response}, state) do
    state = %{state | ready_check: [character.id | state.ready_check]}
    broadcast(state.id, Packets.Party.ready_check(character, response))

    if Enum.count(state.members) == Enum.count(state.ready_check) do
      broadcast(state.id, Packets.Party.end_ready_check())
      {:noreply, %{state | ready_check: []}}
    else
      {:noreply, state}
    end
  end

  def handle_info(:end_ready_check, state) do
    if Enum.count(state.members) != Enum.count(state.ready_check) do
      for m <- state.members, !Enum.member?(state.ready_check, m.id) do
        broadcast(state.id, Packets.Party.ready_check(m, false))
      end

      broadcast(state.id, Packets.Party.end_ready_check())

      {:noreply, %{state | ready_check: []}}
    else
      {:noreply, state}
    end
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

  defp disband(party) do
    send(self(), :shutdown)

    for m <- party.members, m.online? do
      send(m.session_pid, {:disband_party, m})
    end
  end

  defp call(party_id, args) do
    with pid when is_pid(pid) <- Process.whereis(:"party:#{party_id}") do
      GenServer.call(pid, args)
    end
  end

  defp cast(party_id, args) do
    with pid when is_pid(pid) <- Process.whereis(:"party:#{party_id}") do
      GenServer.cast(pid, args)
    end
  end
end
