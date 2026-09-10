defmodule Ms2ex.PartyDpsTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets
  import Ms2ex.Packets.PacketReader

  test "DpsStat uses the DPS opcode and includes every party member total" do
    party = %{
      members: [%{id: 101}, %{id: 202}],
      dps_damage: %{101 => 12_345, 202 => 678}
    }

    packet = Packets.DpsStat.bytes(party)

    assert <<0x88, 0x00, 2::little-signed-32, 101::little-signed-64, 12_345::little-signed-64,
             202::little-signed-64, 678::little-signed-64>> =
             packet
  end

  test "party DPS starts disabled and empty" do
    party = Ms2ex.Types.Party.create(%{id: 101})

    assert party.dps_enabled? == false
    assert party.dps_damage == %{}
  end

  test "party DPS records damage after the meter is enabled" do
    leader = %{id: System.unique_integer([:positive])}
    {:ok, pid} = Ms2ex.Managers.PartyServer.start(leader)
    on_exit(fn -> Process.exit(pid, :kill) end)

    {:ok, party} = GenServer.call(pid, :lookup)
    Ms2ex.Managers.PartyServer.cast(party.id, {:set_dps_mode, true})
    Ms2ex.Managers.PartyServer.record_damage(%{id: leader.id, party_id: party.id}, 500)

    {:ok, state} = Ms2ex.Managers.PartyServer.call(party.id, :lookup)

    assert state.dps_enabled?
    assert state.dps_damage == %{leader.id => 500}
  end

  test "repeated DPS mode requests do not reset accumulated party damage" do
    leader = %{id: System.unique_integer([:positive])}
    {:ok, pid} = Ms2ex.Managers.PartyServer.start(leader)
    on_exit(fn -> Process.exit(pid, :kill) end)

    {:ok, party} = GenServer.call(pid, :lookup)
    {:ok, _party} = Ms2ex.Managers.PartyServer.call(party.id, {:set_dps_mode, true})
    Ms2ex.Managers.PartyServer.record_damage(%{id: leader.id, party_id: party.id}, 500)
    {:ok, _party} = Ms2ex.Managers.PartyServer.call(party.id, {:set_dps_mode, true})

    {:ok, state} = Ms2ex.Managers.PartyServer.call(party.id, :lookup)
    assert state.dps_damage == %{leader.id => 500}
  end

  test "start vote packet includes voters and target" do
    vote = %{
      initiator_id: 101,
      target: %{id: 404, name: "Target"},
      voters: [101, 202, 303],
      approvals: [101],
      disapprovals: [],
      votes_needed: 2
    }

    packet = Ms2ex.Packets.Party.start_vote(vote)

    <<opcode::little-unsigned-16, command, type, counter::little-signed-32,
      _timestamp::little-signed-64, packet::binary>> = packet

    assert opcode == 0x54
    assert command == 0x2F
    assert type == 1
    assert counter == 0

    {voter_count, packet} = get_int(packet)
    assert voter_count == 3

    {voter_ids, packet} =
      Enum.map_reduce(1..voter_count, packet, fn _, packet -> get_long(packet) end)

    assert voter_ids == [101, 202, 303]

    {approval_count, packet} = get_int(packet)
    assert approval_count == 1
    {101, packet} = get_long(packet)
    {disapproval_count, packet} = get_int(packet)
    assert disapproval_count == 0
    {101, packet} = get_long(packet)
    {404, packet} = get_long(packet)
    {"Target", packet} = get_ustring(packet)
    {2, <<>>} = get_byte(packet)
  end

  test "vote kick removes the target after the approval threshold" do
    members =
      for id <- [101, 202, 303, 404] do
        %{id: id, name: "Member #{id}", online?: false}
      end

    [leader, voter, _other, target] = members
    {:ok, pid} = Ms2ex.Managers.PartyServer.start(leader)
    on_exit(fn -> Process.exit(pid, :kill) end)

    {:ok, party} = GenServer.call(pid, :lookup)
    members = Enum.map(members, &Map.put(&1, :party_id, party.id))
    :sys.replace_state(pid, fn state -> %{state | members: members} end)

    Ms2ex.Managers.PartyServer.cast(party.id, {:start_vote_kick, leader, target.id})
    {:ok, voting_party} = Ms2ex.Managers.PartyServer.call(party.id, :lookup)
    assert voting_party.vote_kick.votes_needed == 2

    Ms2ex.Managers.PartyServer.cast(party.id, {:vote_kick, voter, true})
    {:ok, updated_party} = Ms2ex.Managers.PartyServer.call(party.id, :lookup)

    assert updated_party.vote_kick == nil
    assert Ms2ex.Types.Party.get_member(updated_party, target.id) == nil
  end

  test "a rejected vote ends after every voter responds" do
    members =
      for id <- [101, 202, 303, 404] do
        %{id: id, name: "Member #{id}", online?: false}
      end

    [leader, voter, other_voter, target] = members
    {:ok, pid} = Ms2ex.Managers.PartyServer.start(leader)
    on_exit(fn -> Process.exit(pid, :kill) end)

    {:ok, party} = GenServer.call(pid, :lookup)
    members = Enum.map(members, &Map.put(&1, :party_id, party.id))
    :sys.replace_state(pid, fn state -> %{state | members: members} end)

    Ms2ex.Managers.PartyServer.cast(party.id, {:start_vote_kick, leader, target.id})
    Ms2ex.Managers.PartyServer.cast(party.id, {:vote_kick, voter, false})
    Ms2ex.Managers.PartyServer.cast(party.id, {:vote_kick, other_voter, false})

    {:ok, state} = Ms2ex.Managers.PartyServer.call(party.id, :lookup)
    assert state.vote_kick == nil
    assert Ms2ex.Types.Party.get_member(state, target.id)
  end

  test "kicking the leader promotes an online party member" do
    members =
      for id <- [101, 202, 303, 404] do
        %{id: id, name: "Member #{id}", online?: true}
      end

    [leader, voter, other_voter, target] = members
    {:ok, pid} = Ms2ex.Managers.PartyServer.start(leader)
    on_exit(fn -> Process.exit(pid, :kill) end)

    {:ok, party} = GenServer.call(pid, :lookup)
    members = Enum.map(members, &Map.put(&1, :party_id, party.id))
    :sys.replace_state(pid, fn state -> %{state | members: members} end)

    Ms2ex.Managers.PartyServer.cast(party.id, {:start_vote_kick, voter, leader.id})
    Ms2ex.Managers.PartyServer.cast(party.id, {:vote_kick, other_voter, true})

    {:ok, state} = Ms2ex.Managers.PartyServer.call(party.id, :lookup)
    assert state.leader_id == voter.id
    assert Ms2ex.Types.Party.get_member(state, leader.id) == nil
    assert Ms2ex.Types.Party.get_member(state, target.id)
  end
end
