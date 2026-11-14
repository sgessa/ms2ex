defmodule Ms2ex.PartyRecallTest do
  # The manager tests stub the shared Managers.Character and
  # Net.SenderSession modules, so they cannot run concurrently with each other.
  use ExUnit.Case, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Types
  import Ms2ex.Packets.PacketReader

  # A recall starts from the party menu and prompts every eligible member:
  # online, alive, in a field, and not already on the caster's field.
  test "start_recall prompts eligible members and records them as targets" do
    caster_field = spawn(fn -> Process.sleep(200) end)
    member_field = spawn(fn -> Process.sleep(200) end)
    leader = live_character(1, caster_field)

    party =
      Types.Party.create(leader)
      |> Types.Party.add_member(%{id: 2, online?: true})
      |> Types.Party.add_member(%{id: 3, online?: true})
      |> Types.Party.add_member(%{id: 4, online?: false})
      |> Types.Party.add_member(%{id: 5, online?: true})

    stub_character_lookups(%{
      1 => leader,
      2 => live_character(2, member_field),
      # dead members are not prompted
      3 => live_character(3, member_field, dead?: true),
      # members already on the caster's field are not prompted
      5 => live_character(5, caster_field)
    })

    Mimic.stub(Net.SenderSession, :push, fn pid, packet ->
      send(self(), {:pushed, pid, packet})
    end)

    assert {:noreply, state} =
             Managers.PartyServer.handle_cast({:start_recall, leader}, party)

    assert [{target_pid, packet}] = collect_pushed()
    assert target_pid == member_field
    assert {1, 0, "Leader", 30, deadline} = open_prompt(packet)
    assert deadline in Ms2ex.sync_ticks()..(Ms2ex.sync_ticks() + 60_000)

    assert [%{id: 2}] = state.recall.targets
    assert state.recall.summoner.id == 1
  end

  test "start_recall is leader-only and stores no recall without eligible members" do
    field_pid = spawn(fn -> Process.sleep(200) end)
    leader = live_character(1, field_pid)
    member = live_character(2, field_pid)

    party =
      Types.Party.create(leader)
      |> Types.Party.add_member(%{id: 2, online?: true})

    stub_character_lookups(%{1 => leader, 2 => member})

    Mimic.stub(Net.SenderSession, :push, fn pid, packet ->
      send(self(), {:pushed, pid, packet})
    end)

    assert {:noreply, state} =
             Managers.PartyServer.handle_cast({:start_recall, %{id: 2, online?: true}}, party)

    assert state.recall == nil
    assert collect_pushed() == []

    # the only other member is already on the caster's field
    assert {:noreply, state} = Managers.PartyServer.handle_cast({:start_recall, leader}, party)
    assert state.recall == nil
    assert collect_pushed() == []
  end

  test "accept pulls the accepter to the caster's field and clears the last prompt" do
    field_pid = spawn(fn -> Process.sleep(200) end)
    leader = live_character(1, field_pid)
    member = live_character(2, field_pid)

    party =
      Types.Party.create(leader)
      |> Types.Party.add_member(%{id: 2, online?: true})
      |> then(fn party ->
        %{party | recall: %{id: make_ref(), summoner: leader, targets: [member], type: 0}}
      end)

    stub_character_lookups(%{1 => leader, 2 => member})

    # a stale or forged caster name does not pull anyone
    assert {:reply, {:error, :no_recall}, state} =
             Managers.PartyServer.handle_call(
               {:accept_recall, member, 0, "NotTheCaster"},
               nil,
               party
             )

    assert state.recall != nil

    assert {:reply, {:ok, caster}, state} =
             Managers.PartyServer.handle_call(
               {:accept_recall, member, 0, "Leader"},
               nil,
               party
             )

    assert caster.id == 1
    assert state.recall == nil
  end

  test "expiry closes the remaining prompts and clears the recall" do
    field_pid = spawn(fn -> Process.sleep(200) end)
    leader = live_character(1, field_pid)
    member = live_character(2, field_pid)

    party =
      Types.Party.create(leader)
      |> Types.Party.add_member(%{id: 2, online?: true})

    recall = %{id: make_ref(), summoner: leader, targets: [member], type: 0}
    party = %{party | recall: recall}

    Mimic.stub(Net.SenderSession, :push, fn pid, packet ->
      send(self(), {:pushed, pid, packet})
    end)

    assert {:noreply, state} = Managers.PartyServer.handle_info({:end_recall, recall.id}, party)

    assert [{pid, packet}] = collect_pushed()
    assert pid == field_pid
    # opcode 0xBE RECALL_SCROLL, then close + type
    assert <<0xBE, 0x00, 0x0, 0x0>> = packet
    assert state.recall == nil

    # an unrelated expiry timer is ignored
    assert {:noreply, ^party} =
             Managers.PartyServer.handle_info({:end_recall, make_ref()}, party)
  end

  defp live_character(id, session_pid, extra \\ []) do
    %{
      id: id,
      name: "Leader",
      online?: true,
      dead?: false,
      field_pid: session_pid,
      sender_session_pid: session_pid,
      map_id: 30
    }
    |> Map.merge(Map.new(extra))
  end

  defp stub_character_lookups(live_map) do
    Mimic.stub(Managers.Character, :call, fn target_or_id, :lookup ->
      id = if is_integer(target_or_id), do: target_or_id, else: target_or_id.id
      Map.fetch(live_map, id)
    end)
  end

  defp collect_pushed, do: collect_pushed([])

  defp collect_pushed(acc) do
    receive do
      {:pushed, pid, packet} -> collect_pushed([{pid, packet} | acc])
    after
      50 -> Enum.reverse(acc)
    end
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
