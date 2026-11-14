defmodule Ms2ex.PartyRecallTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Types
  import Ms2ex.Packets.PacketReader

  # Prompt pushes go through Net.SenderSession.push/2, a bare send of
  # {:push, packet}; the recall targets carry the test process as their
  # session pid, making every pushed packet directly assertable.

  test "start_recall prompts targets and stores the recall" do
    party = party_with_member(2)

    assert {:reply, {:ok, recall}, state} =
             PartyServer.handle_call({:start_recall, caster(), [target(2)]}, nil, party)

    assert_receive {:push, packet}
    assert {1, 1, "Leader", 30, deadline} = open_prompt(packet)
    now = System.system_time(:second)
    assert deadline in (now - 1)..(now + 61)

    assert recall.targets == [target(2)]
    assert recall.summoner == %{id: 1, name: "Leader"}
    assert state.recall == recall
  end

  test "start_recall is leader-only, single-flight, and needs targets" do
    party = party_with_member(2)

    assert {:reply, {:error, :not_leader}, ^party} =
             PartyServer.handle_call({:start_recall, caster(id: 2), [target(2)]}, nil, party)

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

  test "accept validates the prompt, prunes the target, and clears on the last one" do
    party = party_with_member(2)

    party =
      then(party, fn party ->
        %{party | recall: recall(targets: [target(2)])}
      end)

    # a stale or forged caster name does not pull anyone
    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 2, 0, "NotTheCaster"}, nil, party)

    # wrong prompt slot, unknown accepter, and the caster themselves are dropped
    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 2, 0, "Leader"}, nil, party)

    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 3, 0, "Leader"}, nil, party)

    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 1, 0, "Leader"}, nil, party)

    assert {:reply, {:ok, caster_id}, state} =
             PartyServer.handle_call({:accept_recall, 2, 1, "Leader"}, nil, party)

    assert caster_id == 1
    assert state.recall == nil
  end

  test "expiry closes the remaining prompts and clears the recall" do
    party = party_with_member(2)
    party = %{party | recall: recall(targets: [target(2)])}

    assert {:noreply, state} =
             PartyServer.handle_info({:end_recall, party.recall.id}, party)

    # opcode 0xBE RECALL_SCROLL, then close + party slot
    assert_receive {:push, <<0xBE, 0x00, 0x0, 0x1>>}
    assert state.recall == nil

    # an unrelated expiry timer is ignored
    assert {:noreply, ^party} =
             PartyServer.handle_info({:end_recall, make_ref()}, party)
  end

  test "leaving members are pruned from the targets; an emptied recall clears" do
    party =
      Types.Party.create(caster())
      |> Types.Party.add_member(%{id: 2, online?: true})
      |> Types.Party.add_member(%{id: 3, online?: true})
      |> then(fn party ->
        %{party | recall: recall(targets: [target(2), target(3)])}
      end)

    assert {:reply, :ok, state} =
             PartyServer.handle_call({:remove_member, %{id: 2, online?: true}}, nil, party)

    assert [%{id: 3}] = state.recall.targets

    assert {:reply, :ok, state} =
             PartyServer.handle_call({:remove_member, %{id: 3, online?: true}}, nil, state)

    assert state.recall == nil
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

  defp party_with_member(member_id) do
    Types.Party.create(caster())
    |> Types.Party.add_member(%{id: member_id, online?: true})
  end

  defp recall(attrs) do
    %{id: make_ref(), summoner: %{id: 1, name: "Leader"}, targets: [], type: 0}
    |> Map.merge(Map.new(attrs))
  end

  defp open_prompt(packet) do
    # opcode 0xBE RECALL_SCROLL, then the open prompt layout
    <<0xBE, 0x00, payload::binary>> = packet
    {mode, payload} = get_byte(payload)
    {type, payload} = get_byte(payload)
    {name, payload} = get_ustring(payload)
    {_stored_a, payload} = get_int(payload)
    {map_id, payload} = get_int(payload)
    {_stored_b, payload} = get_int(payload)
    {deadline, ""} = get_long(payload)

    {mode, type, name, map_id, deadline}
  end
end
