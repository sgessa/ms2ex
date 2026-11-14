defmodule Ms2ex.PartyRecallTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Types
  import Ms2ex.Packets.PacketReader

  # Prompt pushes go through Net.SenderSession.push/2, a bare send of
  # {:push, packet}; pointing a member's session pid at the test process
  # makes every pushed packet directly assertable.

  test "start_recall prompts targets and stores the recall" do
    caster = member(1)
    target = member(2)

    party =
      Types.Party.create(caster)
      |> Types.Party.add_member(%{id: 2, online?: true})

    assert {:reply, {:ok, recall}, state} =
             PartyServer.handle_call({:start_recall, caster, [target]}, nil, party)

    assert_receive {:push, packet}
    assert {1, 0, "Leader", 30, deadline} = open_prompt(packet)
    assert deadline in Ms2ex.sync_ticks()..(Ms2ex.sync_ticks() + 60_000)

    assert recall.targets == [target]
    assert recall.summoner.id == 1
    assert state.recall == recall
  end

  test "start_recall is leader-only, single-flight, and needs targets" do
    caster = member(1)
    target = member(2)

    party =
      Types.Party.create(caster)
      |> Types.Party.add_member(%{id: 2, online?: true})

    assert {:reply, {:error, :not_leader}, ^party} =
             PartyServer.handle_call({:start_recall, member(2), [target]}, nil, party)

    assert {:reply, {:error, :no_targets}, ^party} =
             PartyServer.handle_call({:start_recall, caster, []}, nil, party)

    # candidates outside the party are filtered before the empty check
    assert {:reply, {:error, :no_targets}, ^party} =
             PartyServer.handle_call({:start_recall, caster, [member(9)]}, nil, party)

    assert {:reply, {:ok, _recall}, state} =
             PartyServer.handle_call({:start_recall, caster, [target]}, nil, party)

    assert {:reply, {:error, :recall_in_progress}, _state} =
             PartyServer.handle_call({:start_recall, caster, [target]}, nil, state)
  end

  test "accept validates the prompt, prunes the target, and clears on the last one" do
    caster = member(1)
    target = member(2)

    party =
      Types.Party.create(caster)
      |> Types.Party.add_member(%{id: 2, online?: true})
      |> then(fn party ->
        %{party | recall: %{id: make_ref(), summoner: caster, targets: [target], type: 0}}
      end)

    # a stale or forged caster name does not pull anyone
    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 2, 0, "NotTheCaster"}, nil, party)

    # wrong prompt type, unknown accepter, and the caster themselves are dropped
    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 2, 1, "Leader"}, nil, party)

    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 3, 0, "Leader"}, nil, party)

    assert {:reply, {:error, :no_recall}, ^party} =
             PartyServer.handle_call({:accept_recall, 1, 0, "Leader"}, nil, party)

    assert {:reply, {:ok, caster_id}, state} =
             PartyServer.handle_call({:accept_recall, 2, 0, "Leader"}, nil, party)

    assert caster_id == 1
    assert state.recall == nil
  end

  test "expiry closes the remaining prompts and clears the recall" do
    caster = member(1)
    target = member(2)

    party =
      Types.Party.create(caster)
      |> Types.Party.add_member(%{id: 2, online?: true})

    recall = %{id: make_ref(), summoner: caster, targets: [target], type: 0}
    party = %{party | recall: recall}

    assert {:noreply, state} = PartyServer.handle_info({:end_recall, recall.id}, party)

    assert_receive {:push, <<0xBE, 0x00, 0x0, 0x0>>}
    assert state.recall == nil

    # an unrelated expiry timer is ignored
    assert {:noreply, ^party} = PartyServer.handle_info({:end_recall, make_ref()}, party)
  end

  test "leaving members are pruned from the targets; an emptied recall clears" do
    caster = member(1)

    party =
      Types.Party.create(caster)
      |> Types.Party.add_member(%{id: 2, online?: true})
      |> Types.Party.add_member(%{id: 3, online?: true})

    recall = %{id: make_ref(), summoner: caster, targets: [member(2), member(3)], type: 0}
    party = %{party | recall: recall}

    assert {:reply, :ok, state} =
             PartyServer.handle_call({:remove_member, %{id: 2, online?: true}}, nil, party)

    assert [%{id: 3}] = state.recall.targets

    assert {:reply, :ok, state} =
             PartyServer.handle_call({:remove_member, %{id: 3, online?: true}}, nil, state)

    assert state.recall == nil
  end

  defp member(id, extra \\ []) do
    %{
      id: id,
      name: "Leader",
      online?: true,
      dead?: false,
      field_pid: self(),
      sender_session_pid: self(),
      map_id: 30
    }
    |> Map.merge(Map.new(extra))
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
