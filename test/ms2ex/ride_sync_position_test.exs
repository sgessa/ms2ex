defmodule Ms2ex.RideSyncPositionTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.GameHandlers.RideSync
  alias Ms2ex.Types.Coord

  # one ride-sync segment: walk state (relabeled to riding server-side),
  # no flags, animation 0, position (100, 200, 30), followed by the segment's
  # client and server tick ints
  @segment <<2, 0, 0, 100, 0, 200, 0, 30, 0, 90, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
             0, 1, 0, 0, 0, 2, 0, 0, 0>>

  setup do
    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      _id, :lookup -> {:ok, mounted_character()}
      _character, {:update, _updated} -> :ok
    end)

    Mimic.stub(Ms2ex.Managers.Field, :broadcast_from, fn _character, _packet, _pid -> :ok end)

    Mimic.stub(Ms2ex.Managers.Field, :user_position, fn _character, position ->
      send(self(), {:user_position, position})
    end)

    Mimic.stub(Ms2ex.Managers.Quest, :update_conditions, fn _id,
                                                            _type,
                                                            _counter,
                                                            _ts,
                                                            _tl,
                                                            _cs,
                                                            _cl ->
      :ok
    end)

    %{packet: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 1>> <> @segment}
  end

  test "feeds the rider's position to the field's trigger conditions", %{packet: packet} do
    RideSync.handle(packet, %{character_id: 1, sender_pid: self()})

    assert_received {:user_position, %Coord{x: 100, y: 200, z: 30}}
  end

  test "an unmounted character's sync does not feed trigger positions", %{packet: packet} do
    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      _id, :lookup ->
        {:ok, %{id: 1, object_id: 2_000_000, map_id: 52_000_063, mount: nil, position: %Coord{}}}

      _character, {:update, _updated} ->
        :ok
    end)

    RideSync.handle(packet, %{character_id: 1, sender_pid: self()})

    refute_received {:user_position, _position}
  end

  defp mounted_character do
    %{
      id: 1,
      object_id: 2_000_000,
      map_id: 52_000_063,
      mount: %{last_position: %Coord{x: 0, y: 0, z: 0}, ride_distance: 0},
      position: %Coord{x: 0, y: 0, z: 0}
    }
  end
end
