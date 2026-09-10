defmodule Ms2ex.Managers.PartyServer do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "party", key: :id

  alias Ms2ex.Packets
  alias Ms2ex.Managers
  alias Ms2ex.Managers.PartyManager
  alias Ms2ex.Types
  alias Phoenix.PubSub

  def broadcast(nil, _packet), do: :error

  def broadcast(party_id, packet),
    do: PubSub.broadcast(Ms2ex.PubSub, "party:#{party_id}", {:push, packet})

  def broadcast_from(_pid, nil, _packet), do: :error

  def broadcast_from(sender_pid, party_id, packet),
    do: PubSub.broadcast_from(Ms2ex.PubSub, sender_pid, "party:#{party_id}", {:push, packet})

  def call(nil, _message), do: :error

  def record_damage(character, damage) do
    case party_id_for(character) do
      {:ok, party_id} -> cast(party_id, {:record_damage, character.id, damage})
      :error -> :ok
    end
  end

  def subscribe(party_id),
    do: PubSub.subscribe(Ms2ex.PubSub, "party:#{party_id}")

  def unsubscribe(party_id),
    do: PubSub.unsubscribe(Ms2ex.PubSub, "party:#{party_id}")

  def start(leader),
    do: GenServer.start(__MODULE__, leader)

  def init(leader) do
    party = Types.Party.create(leader)
    Process.register(self(), :"party:#{party.id}")
    {:ok, party}
  end

  def handle_call(:lookup, _from, state),
    do: {:reply, {:ok, state}, state}

  def handle_call({:set_dps_mode, enabled?}, _from, state) do
    state = %{state | dps_enabled?: enabled?, dps_damage: %{}}

    if enabled?, do: send(self(), :dps_tick)

    {:reply, {:ok, state}, state}
  end

  def handle_call({:member_offline, character}, _from, state) do
    state = update_member(state, character)

    case Enum.find(state.members, & &1.online?) do
      nil ->
        send(self(), :shutdown)
        {:reply, :ok, state}

      member_online ->
        broadcast(state.id, Packets.Party.logout_notice(character))
        state = maybe_find_new_leader(state, character, member_online)
        {:reply, :ok, state}
    end
  end

  def handle_call({:update_member, character}, _from, state) do
    state = update_member(state, character)

    if !Types.Party.new?(state),
      do: broadcast(state.id, Packets.Party.update_member(character))

    {:reply, {:ok, state}, state}
  end

  def handle_call({:remove_member, character}, _from, state) do
    broadcast(state.id, Packets.Party.member_left(character))
    state = Types.Party.remove_member(state, character)

    member_online = Enum.find(state.members, & &1.online?)

    if Types.Party.new?(state) or !member_online do
      disband(state)
      {:reply, :ok, state}
    else
      {:reply, :ok, maybe_find_new_leader(state, character, member_online)}
    end
  end

  def handle_call({:kick_member, character_id}, _from, state) do
    case Types.Party.get_member(state, character_id) do
      nil ->
        {:reply, :error, state}

      character ->
        broadcast(state.id, Packets.Party.kick(character))

        state = Types.Party.remove_member(state, character)

        if Types.Party.new?(state) do
          disband(state)
          {:reply, {:ok, character}, state}
        else
          {:reply, {:ok, character}, state}
        end
    end
  end

  def handle_cast({:start_vote_kick, requestor, target_id}, %{vote_kick: nil} = state) do
    target = Types.Party.get_member(state, target_id)
    voters = Enum.reject(state.members, &(&1.id == target_id))

    cond do
      is_nil(target) ->
        {:noreply, state}

      not Types.Party.in_party?(state, requestor) ->
        {:noreply, state}

      requestor.id == target_id ->
        {:noreply, state}

      true ->
        vote = %{
          id: make_ref(),
          initiator_id: requestor.id,
          target: target,
          voters: Enum.map(voters, & &1.id),
          approvals: [requestor.id],
          disapprovals: [],
          votes_needed: ceil(Enum.count(voters) / 2)
        }

        packet = Packets.Party.start_vote(vote)

        for member <- voters,
            Map.get(member, :online?, false),
            is_pid(Map.get(member, :sender_session_pid)) do
          Ms2ex.Net.SenderSession.push(member.sender_session_pid, packet)
        end

        Process.send_after(self(), {:end_vote_kick, vote.id}, 20_000)
        {:noreply, %{state | vote_kick: vote}}
    end
  end

  def handle_cast({:start_vote_kick, _requestor, _target_id}, state), do: {:noreply, state}

  def handle_cast(:start_ready_check, state) do
    if Types.Party.ready_check_in_progress?(state) do
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

  def handle_cast({:vote_kick, character, response}, %{vote_kick: vote} = state) do
    cond do
      not Enum.member?(vote.voters, character.id) ->
        {:noreply, state}

      Enum.member?(vote.approvals, character.id) or Enum.member?(vote.disapprovals, character.id) ->
        {:noreply, state}

      true ->
        vote =
          if response do
            %{vote | approvals: [character.id | vote.approvals]}
          else
            %{vote | disapprovals: [character.id | vote.disapprovals]}
          end

        broadcast(state.id, Packets.Party.ready_check(character, response))
        handle_vote_result(state, vote)
    end
  end

  def handle_cast({:vote_kick, _character, _response}, state), do: {:noreply, state}

  def handle_cast({:set_dps_mode, enabled?}, state) do
    {:noreply, set_dps_mode(state, enabled?)}
  end

  def handle_cast({:record_damage, character_id, damage}, state) when damage > 0 do
    if state.dps_enabled? do
      dps_damage = Map.update(state.dps_damage, character_id, damage, &(&1 + damage))
      {:noreply, %{state | dps_damage: dps_damage}}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:record_damage, _character_id, _damage}, state), do: {:noreply, state}

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

  def handle_info(:dps_tick, %{dps_enabled?: true} = state) do
    broadcast(state.id, Packets.DpsStat.bytes(state))
    Process.send_after(self(), :dps_tick, 1_000)
    {:noreply, state}
  end

  def handle_info(:dps_tick, state), do: {:noreply, state}

  def handle_info({:end_vote_kick, vote_id}, %{vote_kick: %{id: vote_id}} = state) do
    broadcast(state.id, Packets.Party.end_vote())
    {:noreply, %{state | vote_kick: nil}}
  end

  def handle_info({:end_vote_kick, _vote_id}, state), do: {:noreply, state}

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  defp update_member(party, member) do
    if Types.Party.in_party?(party, member) do
      Types.Party.update_member(party, member)
    else
      PartyManager.register(party, member)
      Types.Party.add_member(party, member)
    end
  end

  defp party_id_for(%{party_id: party_id}) when is_integer(party_id), do: {:ok, party_id}
  defp party_id_for(character), do: PartyManager.lookup(character)

  defp handle_vote_result(state, vote) do
    cond do
      Enum.count(vote.approvals) >= vote.votes_needed ->
        state = kick_voted_member(state, vote.target)
        broadcast(state.id, Packets.Party.end_vote())
        {:noreply, %{state | vote_kick: nil}}

      Enum.count(vote.approvals) + Enum.count(vote.disapprovals) >= Enum.count(vote.voters) ->
        broadcast(state.id, Packets.Party.end_vote())
        {:noreply, %{state | vote_kick: nil}}

      true ->
        {:noreply, %{state | vote_kick: vote}}
    end
  end

  defp set_dps_mode(state, enabled?) do
    state = %{state | dps_enabled?: enabled?, dps_damage: %{}}

    if enabled?, do: send(self(), :dps_tick)

    state
  end

  defp kick_voted_member(state, target) do
    broadcast(state.id, Packets.Party.kick(target))

    if Map.get(target, :online?, false) and is_pid(Map.get(target, :sender_session_pid)),
      do: send(target.sender_session_pid, {:kick_party, state.id, target})

    Managers.Character.call(target, {:update, %{target | party_id: nil}})
    state = Types.Party.remove_member(state, target)

    case Enum.find(state.members, &Map.get(&1, :online?, false)) do
      nil -> state
      new_leader -> maybe_find_new_leader(state, target, new_leader)
    end
  end

  defp maybe_find_new_leader(party, character, new_leader) when character.id == party.leader_id do
    broadcast(party.id, Packets.Party.set_leader(new_leader))
    %{party | leader_id: new_leader.id}
  end

  defp maybe_find_new_leader(party, _character, _new_leader), do: party

  defp disband(party) do
    send(self(), :shutdown)

    for m <- party.members, m.online? do
      send(m.sender_session_pid, {:disband_party, m})
    end
  end
end
