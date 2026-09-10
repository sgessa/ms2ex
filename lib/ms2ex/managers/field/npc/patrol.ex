defmodule Ms2ex.Managers.Field.Npc.Patrol do
  @moduledoc """
  Npc movement along patrol paths: story npcs walk named patrol paths
  (script move_npc) and stay at the last waypoint; the movement math also
  seeds the scripted-carry follow-dummy that `Managers.Field.Npc` spawns.
  """

  require Logger

  alias Ms2ex.Storage
  alias Ms2ex.Types

  @follow_speed 150

  @doc """
  Walks a story npc along a named patrol path (script move_npc): the walk
  streams through the control broadcast and the npc stays at the last
  waypoint when the path ends.
  """
  def move_npc(state, spawn_id, path_name) do
    patrol = Map.get(state[:patrols] || %{}, path_name)

    case patrol do
      %{way_points: way_points} when way_points != [] ->
        waypoints = Enum.map(way_points, & &1[:position])

        state.npcs
        |> Enum.filter(fn {_object_id, npc} -> npc.spawn_point_id == spawn_id end)
        |> Enum.reduce(state, fn {object_id, npc}, state ->
          attach_patrol(state, object_id, npc, waypoints, way_points)
        end)

      _ ->
        state
    end
  end

  # advances an npc along its patrol path; called on every control tick
  def advance_patrol(%{patrol: nil} = npc, _now), do: npc
  def advance_patrol(%{patrol: %{waypoints: []}} = npc, _now), do: npc

  def advance_patrol(npc, now) do
    patrol = npc.patrol
    dt = max(now - Map.get(patrol, :last_at, now), 1)
    waypoint = Enum.fetch!(patrol.waypoints, patrol.index)
    step = patrol.speed * dt / 1000.0

    {position, velocity, arrived?} = step_toward(npc.position, waypoint, step, patrol.speed, dt)
    patrol = Map.put(patrol, :last_at, now)

    cond do
      arrived? and patrol.index + 1 >= length(patrol.waypoints) ->
        finish_patrol(npc, patrol)

      arrived? ->
        patrol = Map.put(patrol, :index, patrol.index + 1)
        animation = Enum.at(patrol.animations, patrol.index) || npc.animation

        %{npc | patrol: patrol, animation: animation, send_control?: true}

      true ->
        rotation = face_move_direction(npc.rotation, velocity)

        %{
          npc
          | position: position,
            velocity: velocity,
            rotation: rotation,
            send_control?: true,
            patrol: patrol
        }
    end
  end

  defp attach_patrol(state, object_id, npc, waypoints, way_points) do
    case leg_animations(npc, way_points) do
      nil ->
        # the model has no walk/run sequence; it stays put instead of
        # sliding across the field in its idle pose
        state

      animations ->
        patrol = %{
          waypoints: waypoints,
          animations: animations,
          index: 0,
          speed: @follow_speed,
          last_at: System.monotonic_time(:millisecond),
          despawn_on_finish?: false
        }

        npc = %{npc | animation: hd(animations), patrol: patrol, send_control?: true}
        put_in(state, [:npcs, object_id], npc)
    end
  end

  # per-waypoint walk sequences: each waypoint's approach animation
  # resolved against the npc model's animation table, falling back to the
  # model's Walk_A / Run_A. nil when the model has no locomotion sequence
  # at all
  def leg_animations(%Types.FieldNpc{} = npc, way_points) do
    model = npc.npc.metadata.model.name

    walk = sequence_id(model, "Walk_A") || sequence_id(model, "Run_A")

    if is_nil(walk) do
      Logger.warning("npc model " <> to_string(model) <> " has no walk animation")
      nil
    else
      Enum.map(way_points, fn way_point ->
        sequence_id(model, way_point[:approach_animation]) || walk
      end)
    end
  end

  # end of the scripted path: follow dummies (carrying the player) despawn
  # and release the guide hold; story npcs on a move_npc stay where they
  # stopped and return to their idle pose
  defp finish_patrol(npc, patrol) do
    if Map.get(patrol, :despawn_on_finish?, false) do
      send(self(), :release_guide_hold)
      Process.send_after(self(), {:remove_npc, npc}, 0)
      %{npc | patrol: nil}
    else
      %{
        npc
        | patrol: nil,
          velocity: {0, 0, 0},
          animation: idle_animation_id(npc),
          send_control?: true
      }
    end
  end

  defp idle_animation_id(npc), do: sequence_id(npc.npc.metadata.model.name, "Idle_A") || 255

  # actors face along their move direction: yaw from the horizontal
  # velocity, degrees. With the front axis stored negated in the transform
  # (M21 = -x, M22 = -y), a move direction (dx, dy) yields
  # yaw = atan2(dx, -dy). A zero velocity (waypoint arrival) keeps the
  # last heading
  defp face_move_direction(rotation, {vx, vy, _vz}) when vx != 0 or vy != 0 do
    yaw = :math.atan2(vx, -vy) * 180 / :math.pi()
    %{rotation | z: yaw}
  end

  defp face_move_direction(rotation, _velocity), do: rotation

  # full 3D step toward the waypoint (waypoints carry ground heights); the
  # velocity is what the control packet reports so the client interpolates
  # the movement instead of snapping
  defp step_toward(pos, target, step, speed, _dt) do
    dx = Map.get(target, :x) - pos.x
    dy = Map.get(target, :y) - pos.y
    dz = Map.get(target, :z) - pos.z
    dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist == 0 or dist <= step do
      {Map.put(pos, :z, Map.get(target, :z)), {0, 0, 0}, true}
    else
      vx = dx / dist * speed
      vy = dy / dist * speed
      vz = dz / dist * speed

      position = %{
        pos
        | x: pos.x + dx / dist * step,
          y: pos.y + dy / dist * step,
          z: pos.z + dz / dist * step
      }

      {position, {vx, vy, vz}, false}
    end
  end

  defp sequence_id(model, name), do: Storage.Animations.sequence_id(model, name)
end
