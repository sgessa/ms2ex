defmodule Ms2ex.CarryFinishTest do
  # the end-of-carry reposition is a pure field-state transition: the
  # character GenServer and the session push are stubbed out
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Net.SenderSession
  alias Ms2ex.Types

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "table:server.constants.xml" => %{talkable_distance: 150}
    })

    :ok
  end

  test "a finished carry repositions the player at the last waypoint facing the nearest npc" do
    character = %Ms2ex.Schema.Character{
      id: 77,
      object_id: 5,
      sender_session_pid: nil
    }

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      77, :lookup ->
        {:ok, character}

      %Ms2ex.Schema.Character{}, {:update, updated} ->
        send(self(), {:character_updated, updated})
        :ok
    end)

    Mimic.stub(SenderSession, :push, fn _character, packet ->
      send(self(), {:pushed, packet})
      :ok
    end)

    Mimic.stub(Ms2ex.Navigation, :valid_position?, fn _map_id, _position -> true end)

    dummy = %Types.FieldNpc{
      object_id: 99,
      follow_character_id: 77,
      patrol: %{
        waypoints: [
          %{position: %{x: 500, y: 0, z: 0}},
          %{position: %{x: 1000, y: 0, z: 0}}
        ]
      }
    }

    state = %{
      map_id: 52_000_101,
      players: %{77 => 5},
      npcs: %{
        99 => dummy,
        1 => %Types.FieldNpc{object_id: 1, position: %Types.Coord{x: 1100, y: 0, z: 0}},
        2 => %Types.FieldNpc{object_id: 2, position: %Types.Coord{x: 90_000, y: 0, z: 0}}
      }
    }

    state = Npc.finish_carry(state, dummy)

    # the player's new field position is tracked for the scene's next beat
    assert state.player_positions[77].position == %{x: 1000, y: 0, z: 0}

    # the server-side character takes the endpoint and the new facing
    assert_receive {:character_updated, updated}
    assert updated.position == %{x: 1000, y: 0, z: 0}
    # the npc at x +100 sits due east of the endpoint: yaw 90 degrees
    assert updated.rotation.z == 90.0

    # the client is snapped with a portal-style move
    assert_receive {:pushed, packet}
    assert is_binary(packet)
  end

  test "a carry with no npc near the endpoint leaves the player alone" do
    dummy = %Types.FieldNpc{
      object_id: 99,
      follow_character_id: 77,
      patrol: %{
        waypoints: [%{position: %{x: 1000, y: 0, z: 0}}]
      }
    }

    state = %{
      map_id: 52_000_101,
      players: %{77 => 5},
      npcs: %{
        99 => dummy,
        2 => %Types.FieldNpc{object_id: 2, position: %Types.Coord{x: 90_000, y: 0, z: 0}}
      }
    }

    assert Npc.finish_carry(state, dummy) == state
  end
end
