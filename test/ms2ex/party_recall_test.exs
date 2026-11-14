defmodule Ms2ex.PartyRecallTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Packets
  alias Ms2ex.Types
  import Ms2ex.Packets.PacketReader

  # Summon request pushes go through Net.SenderSession.push/2, a bare send
  # of {:push, packet}; the recall targets carry the test process as their
  # session pid, making every pushed packet directly assertable.

  test "start_recall prompts targets and stores the request" do
    party = party_with_member(2)

    assert {:reply, {:ok, recall}, state} =
             PartyServer.handle_call({:start_recall, caster(), [target(2)]}, nil, party)

    assert_receive {:push, packet}
    assert {4, 0, "Leader", request_id} = open_request(packet)
    assert request_id == recall.id

    assert recall.targets == [target(2)]
    assert recall.summoner == %{id: 1, name: "Leader"}
    assert state.recall == recall
  end

  test "start_recall requires membership, is single-flight, and needs targets" do
    party = party_with_member(2)

    assert {:reply, {:error, :not_member}, ^party} =
             PartyServer.handle_call({:start_recall, caster(id: 9), [target(2)]}, nil, party)

    assert {:reply, {:error, :no_targets}, ^party} =
             PartyServer.handle_call({:start_recall, caster(), []}, nil, party)

    # candidates outside the party are filtered before the empty check
    assert {:reply, {:error, :no_targets}, ^party} =
             PartyServer.handle_call({:start_recall, caster(), [target(9)]}, nil, party)

    assert {:reply, {:ok, _recall}, state} =
             PartyServer.handle_call({:start_recall, caster(), [target(2)]}, nil, party)

    assert {:reply, {:error, :recall_in_progress}, _state} =
             PartyServer.handle_call({:start_recall, caster(), [target(2)]}, nil, state)
  end

  test "accept validates the request id, prunes the target, and clears on the last one" do
    party = party_with_member(2)
    party = %{party | recall: request(targets: [target(2)])}

    # a forged or stale request id does not pull anyone
    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:recall_reply, 2, party.recall.id + 1, true}, nil, party)

    # an unknown accepter and the caster themselves are dropped
    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:recall_reply, 3, party.recall.id, true}, nil, party)

    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:recall_reply, 1, party.recall.id, true}, nil, party)

    assert {:reply, {:ok, caster_id}, state} =
             PartyServer.handle_call({:recall_reply, 2, party.recall.id, true}, nil, party)

    assert caster_id == 1
    assert state.recall == nil
  end

  test "decline and busy replies prune the target; an emptied request clears" do
    party =
      party_with_members([2, 3])
      |> then(fn party ->
        %{party | recall: request(targets: [target(2), target(3)])}
      end)

    assert {:reply, {:error, :declined}, state} =
             PartyServer.handle_call({:recall_reply, 2, party.recall.id, false}, nil, party)

    assert [%{id: 3}] = state.recall.targets

    assert {:noreply, state} =
             PartyServer.handle_cast({:recall_busy, 3, "Leader"}, state)

    assert state.recall == nil

    # a busy reply naming another caster leaves the request alone
    assert {:noreply, ^state} = PartyServer.handle_cast({:recall_busy, 2, "SomeoneElse"}, state)
  end

  test "expiry retires the pending request without pushing anything" do
    party = party_with_member(2)
    party = %{party | recall: request(targets: [target(2)])}

    assert {:noreply, state} = PartyServer.handle_info({:end_recall, party.recall.id}, party)
    assert state.recall == nil
    refute_received {:push, _packet}
  end

  test "a stale expiry timer does not clear a newer request" do
    party = party_with_member(2)
    stale_id = 1234
    party = %{party | recall: request(id: 5678, targets: [target(2)])}

    assert {:noreply, state} = PartyServer.handle_info({:end_recall, stale_id}, party)
    assert state.recall == party.recall
  end

  test "leaving members are pruned from the targets; an emptied request clears" do
    party =
      party_with_members([2, 3])
      |> then(fn party ->
        %{party | recall: request(targets: [target(2), target(3)])}
      end)

    assert {:reply, :ok, state} =
             PartyServer.handle_call({:remove_member, %{id: 2, online?: true}}, nil, party)

    assert [%{id: 3}] = state.recall.targets

    assert {:reply, :ok, state} =
             PartyServer.handle_call({:remove_member, %{id: 3, online?: true}}, nil, state)

    assert state.recall == nil
  end

  test "the request packet carries the party type, caster name and request id" do
    packet = Packets.RecallUser.request(0, "enki", 1234)

    assert <<0x8E, 0x00, payload::binary>> = packet
    assert {4, 0, "enki", 1234} = open_request(packet)
  end

  defp caster(attrs \\ []) do
    %{
      id: 1,
      name: "Leader",
      map_id: 30,
      online?: true,
      sender_session_pid: self()
    }
    |> Map.merge(Map.new(attrs))
  end

  defp target(id), do: %{id: id, sender_session_pid: self()}

  defp party_with_member(member_id), do: party_with_members([member_id])

  defp party_with_members(member_ids) do
    Enum.reduce(member_ids, Types.Party.create(caster()), fn id, party ->
      Types.Party.add_member(party, %{id: id, online?: true})
    end)
  end

  defp request(attrs) do
    %{id: 1234, summoner: %{id: 1, name: "Leader"}, targets: [], type: 0}
    |> Map.merge(Map.new(attrs))
  end

  defp open_request(packet) do
    # opcode 0x8E RECALL_USER, then the request layout
    <<0x8E, 0x00, payload::binary>> = packet
    {mode, payload} = get_byte(payload)
    {type, payload} = get_byte(payload)
    {name, payload} = get_ustring(payload)
    {request_id, ""} = get_int(payload)

    {mode, type, name, request_id}
  end
end
