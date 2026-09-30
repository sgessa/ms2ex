defmodule Ms2ex.QuestMapleGuideTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Managers
  alias Ms2ex.Types.Coord

  import Ms2ex.TestHelpers

  @guide_map_id 52_000_063
  @portal_position %{x: 1.0, y: 2.0, z: 3.0}
  @portal_rotation %{x: 0.0, y: 0.0, z: 90.0}

  @guide_entries %{
    "1" => %{
      category: 7,
      required_level: 12,
      quest_id: 90_000_640,
      required_map_id: 2_000_001,
      go_to_map_id: @guide_map_id,
      go_to_portal_id: 0
    },
    "2" => %{
      category: 1,
      required_level: 10,
      quest_id: 90_000_650,
      required_map_id: 0,
      go_to_map_id: @guide_map_id,
      go_to_portal_id: 1
    },
    # leads to the private residence; home migration is not implemented yet
    "3" => %{
      category: 9,
      required_level: 25,
      quest_id: 90_000_690,
      required_map_id: 0,
      go_to_map_id: 62_000_000,
      go_to_portal_id: 1
    }
  }

  setup do
    stub_metadata(%{
      "table:learningquest.xml" => %{table: %{entries: @guide_entries}},
      "map:#{@guide_map_id}" => %{
        portals: [
          %{
            id: 1,
            position: @portal_position,
            rotation: @portal_rotation
          }
        ]
      }
    })

    Mimic.stub(Ms2ex.Managers.Character, :lookup, fn _id -> {:ok, %{id: 1, level: 30}} end)

    Mimic.stub(Ms2ex.Managers.Field, :change_field, fn _character, map_id ->
      send(self(), {:change_field, map_id, :default_spawn})
      :ok
    end)

    Mimic.stub(Ms2ex.Managers.Field, :change_field, fn _character, map_id, position, rotation ->
      send(self(), {:change_field, map_id, position, rotation})
      :ok
    end)

    %{state: %{character_id: 1, character_quests: %{}, account_quests: %{}}}
  end

  test "unknown guide id is a no-op", %{state: state} do
    assert {:reply, :ok, ^state} =
             Managers.Quest.handle_call({:maple_guide, 999}, {self(), make_ref()}, state)

    refute_received {:change_field, _, _}
  end

  test "a character below the guide's level is not moved", %{state: state} do
    Mimic.stub(Ms2ex.Managers.Character, :lookup, fn _id -> {:ok, %{id: 1, level: 11}} end)

    assert {:reply, :ok, ^state} =
             Managers.Quest.handle_call({:maple_guide, 1}, {self(), make_ref()}, state)

    refute_received {:change_field, _, _}
  end

  test "a character who completed the guide's quest is not moved", %{state: state} do
    state = put_in(state, [:character_quests, 90_000_640], %{state: :completed})

    assert {:reply, :ok, ^state} =
             Managers.Quest.handle_call({:maple_guide, 1}, {self(), make_ref()}, state)

    refute_received {:change_field, _, _}
  end

  test "a started guide quest does not block the guide", %{state: state} do
    state = put_in(state, [:character_quests, 90_000_640], %{state: :started})

    assert {:reply, :ok, _state} =
             Managers.Quest.handle_call({:maple_guide, 1}, {self(), make_ref()}, state)

    assert_received {:change_field, @guide_map_id, :default_spawn}
  end

  test "moves the character to the guide's portal", %{state: state} do
    assert {:reply, :ok, _state} =
             Managers.Quest.handle_call({:maple_guide, 2}, {self(), make_ref()}, state)

    assert_received {:change_field, @guide_map_id, position, rotation}
    assert position == struct(Coord, @portal_position)
    assert rotation == struct(Coord, @portal_rotation)
  end

  test "falls back to the map's default spawn when the guide's portal does not exist", %{
    state: state
  } do
    assert {:reply, :ok, _state} =
             Managers.Quest.handle_call({:maple_guide, 1}, {self(), make_ref()}, state)

    assert_received {:change_field, @guide_map_id, :default_spawn}
  end

  test "a guide leading to the private residence is not moved yet", %{state: state} do
    assert {:reply, :ok, ^state} =
             Managers.Quest.handle_call({:maple_guide, 3}, {self(), make_ref()}, state)

    refute_received {:change_field, _, _}
  end
end
