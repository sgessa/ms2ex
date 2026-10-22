defmodule Ms2ex.Managers.Field.Npc.Movement do
  @moduledoc """
  The pathed-walk engine shared by every field walker: mobs chasing a
  target, trips home, idle wander legs and summoned pets all advance
  along navmesh routes through here.

  `walk_chase_route/4` is the step function — re-paths when the route is
  stale (consumed, target drifted, cadence due), advances along it for
  the time elapsed, extends a consumed route in the same tick so a run
  never stutters into a stand, and presents the result as locomotion
  (run while real progress is made, idle otherwise). `stand/4` holds
  position facing a target, announcing itself only when something
  actually changed.
  """

  alias Ms2ex.Navigation
  alias Ms2ex.Storage
  alias Ms2ex.Types

  # minimum spacing between path re-computations while chasing
  @repath_interval_ms 500
  # re-path early when the target has moved this far from the pathed goal
  @repath_target_drift 150
  # movement is integrated over at most this window; a long stall (process
  # hiccup, actor standing at range) never becomes one giant teleport step
  @max_step_ms 200

  # -- public primitives -------------------------------------------------------------

  @doc "Hold position facing the target; marks dirty only on a real change."
  def stand(npc, battle, target_position, now) do
    was_moving = npc.velocity != {0, 0, 0}
    rotation = face_toward(npc.position, target_position, npc.rotation)
    animation = stand_animation(npc, battle, now)
    anim_changed? = animation != npc.animation

    npc = %{
      npc
      | battle: %{battle | path: nil, path_index: 1, goal: nil, last_move_at: now},
        velocity: {0, 0, 0},
        animation: animation
    }

    if was_moving or rotation != npc.rotation or anim_changed? do
      %{npc | rotation: rotation, send_control?: true}
    else
      npc
    end
  end

  @doc """
  One pathed-walk step toward the target position: stale routes re-path,
  consumed routes extend in the same tick (a stand tick makes the client
  restart the walk animation and drop interpolation, which reads as
  flicker and micro-teleports), and the presentation follows real
  movement — progress runs, no progress idles.
  """
  def walk_chase_route(npc, battle, target_position, now) do
    stale? =
      battle.path == nil or
        square_distance(battle.goal, target_position) > square(@repath_target_drift) or
        now >= battle.next_repath_at

    battle =
      if stale? do
        repath(npc, battle, target_position, now)
      else
        battle
      end

    case battle.path do
      nil ->
        # no walkable route right now (e.g. the player is on another
        # navmesh island): hold until the next re-path window
        {%{npc | battle: %{battle | last_move_at: now}, velocity: {0, 0, 0}}, []}

      path ->
        before = npc.position
        {npc, battle} = advance(npc, battle, path, now)

        {npc, _} =
          if battle.path == nil do
            extend_path(npc, battle, target_position, now)
          else
            # mid-path: the run continues on the next tick — the updated battle
            # (last_move_at, path index) must merge back into the npc or the
            # next tick's step budget balloons to the max-step clamp
            {%{npc | battle: battle}, []}
          end

        {present_locomotion(npc, before), []}
    end
  end

  @doc "An actor with any locomotion speed can move; one with neither is rooted."
  def stationary?(npc), do: chase_speed(npc) == 0.0

  @doc """
  Actors face along their move direction: yaw from the horizontal
  direction, degrees. With the front axis stored negated in the transform
  (M21 = -x, M22 = -y), a direction (dx, dy) yields yaw = atan2(dx, -dy).
  A zero-length direction keeps the current heading.
  """
  def face_toward(%Types.Coord{} = from, %Types.Coord{} = to, current) do
    dx = to.x - from.x
    dy = to.y - from.y

    if dx == 0 and dy == 0 do
      current
    else
      yaw = :math.atan2(dx, -dy) * 180 / :math.pi()
      %{current | z: yaw}
    end
  end

  # -- internals -----------------------------------------------------------------

  defp stand_animation(npc, battle, now) do
    cond do
      battle.cast -> npc.animation
      swing_tailing?(battle, now) -> npc.animation
      true -> combat_idle_id(npc)
    end
  end

  defp swing_tailing?(battle, now),
    do: is_integer(battle.swing_until) and now < battle.swing_until

  defp combat_idle_id(npc) do
    sequence_id(npc, "Attack_Idle_A") || sequence_id(npc, "Idle_A") || npc.animation
  end

  defp chase_speed(npc) do
    case speed(npc, :run_speed) do
      speed when speed > 0.0 -> speed
      _ -> speed(npc, :walk_speed)
    end
  end

  defp speed(npc, gait) do
    alias Ms2ex.Managers.Field.Npc.Patrol
    Patrol.npc_speed(npc, gait)
  end

  defp extend_path(npc, battle, target_position, now) do
    battle = repath(npc, battle, target_position, now)

    case battle.path do
      nil ->
        # still no route (throttled): hold until the next re-path window
        {%{npc | battle: battle, velocity: {0, 0, 0}}, []}

      path ->
        {npc, battle} = advance(npc, battle, path, now)
        {%{npc | battle: battle}, []}
    end
  end

  # moved this tick: the run continues; stationary: settle into the idle
  # pose and announce it so clients drop the run animation
  defp present_locomotion(npc, before) do
    dx = npc.position.x - before.x
    dy = npc.position.y - before.y

    if dx * dx + dy * dy > 1.0 do
      start_running(npc)
    else
      idle = sequence_id(npc, "Idle_A")

      case idle do
        nil -> npc
        id when id == npc.animation -> npc
        id -> %{npc | animation: id, send_control?: true}
      end
    end
  end

  defp start_running(npc) do
    run = sequence_id(npc, "Run_A") || sequence_id(npc, "Walk_A")

    case run do
      nil -> npc
      id when id == npc.animation -> npc
      id -> %{npc | animation: id, send_control?: true}
    end
  end

  defp repath(npc, battle, target_position, now) do
    case Navigation.find_path(npc.map_id, npc.position, target_position) do
      {:ok, path} ->
        # index 1: point 0 is the actor's own snapped position
        %{
          battle
          | path: path,
            path_index: 1,
            goal: target_position,
            next_repath_at: now + @repath_interval_ms,
            no_route_since: nil
        }

      {:partial, path} ->
        # the target sits on another mesh island: pursue the partial route
        # as far as the ground allows
        %{
          battle
          | path: path,
            path_index: 1,
            goal: target_position,
            next_repath_at: now + @repath_interval_ms,
            no_route_since: battle.no_route_since || now
        }

      :error ->
        %{
          battle
          | path: nil,
            next_repath_at: now + @repath_interval_ms,
            no_route_since: battle.no_route_since || now
        }
    end
  end

  # advances along the path for the time elapsed since the last move; several
  # waypoints may be consumed within one tick when they are close together
  defp advance(npc, battle, path, now) do
    dt = (now - battle.last_move_at) |> max(1) |> min(@max_step_ms)
    speed = chase_speed(npc)
    budget = speed * dt / 1000.0

    battle = %{battle | last_move_at: now}
    walk_segments(npc, battle, path, budget, speed)
  end

  defp walk_segments(npc, battle, path, budget, speed) do
    case Enum.at(path, battle.path_index) do
      nil ->
        # path consumed without getting in range (short path): clear it so
        # the next tick re-paths
        {%{npc | velocity: {0, 0, 0}}, %{battle | path: nil}}

      waypoint ->
        step = step_toward(npc.position, waypoint, budget, speed)

        case Navigation.snap_to_floor(npc.map_id, step.position) do
          nil ->
            # no walkable surface for this step: hold position; movement
            # rides the navmesh or it does not happen
            {%{npc | velocity: {0, 0, 0}}, battle}

          snapped ->
            commit_step(npc, battle, path, waypoint, snapped, step, speed)
        end
    end
  end

  defp commit_step(npc, battle, _path, waypoint, snapped, %{kind: :moving} = step, _speed) do
    npc = move_step(npc, snapped, waypoint, step.velocity)
    {npc, battle}
  end

  defp commit_step(npc, battle, path, waypoint, snapped, %{kind: :arrived} = step, speed) do
    battle = %{battle | path_index: battle.path_index + 1}

    # keep the run flowing through the corner: aim the velocity at the
    # next waypoint instead of announcing a stand between segments
    npc =
      move_step(
        npc,
        snapped,
        waypoint,
        carry_velocity(snapped, path, battle.path_index, speed)
      )

    if step.leftover > 0 do
      walk_segments(npc, battle, path, step.leftover, speed)
    else
      {npc, battle}
    end
  end

  defp move_step(npc, position, waypoint, velocity) do
    %{
      npc
      | position: position,
        velocity: velocity,
        rotation: face_toward(position, waypoint, npc.rotation),
        send_control?: true
    }
  end

  # keeps the velocity streaming across corners: aims at the next waypoint
  # when one follows, zero only at the end of the path
  defp carry_velocity(from, path, index, speed) do
    case Enum.at(path, index) do
      nil ->
        {0.0, 0.0, 0.0}

      next ->
        dx = next.x - from.x
        dy = next.y - from.y
        dz = next.z - from.z
        dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist == 0 do
          {0.0, 0.0, 0.0}
        else
          {dx / dist * speed, dy / dist * speed, dz / dist * speed}
        end
    end
  end

  defp step_toward(position, target, budget, speed) do
    dx = target.x - position.x
    dy = target.y - position.y
    dz = target.z - position.z
    dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist <= budget do
      arrived = %Types.Coord{x: target.x, y: target.y, z: target.z}

      %{kind: :arrived, position: arrived, velocity: {0.0, 0.0, 0.0}, leftover: budget - dist}
    else
      ux = dx / dist
      uy = dy / dist
      uz = dz / dist

      moved = %Types.Coord{
        x: position.x + ux * budget,
        y: position.y + uy * budget,
        z: position.z + uz * budget
      }

      %{
        kind: :moving,
        position: moved,
        velocity: {ux * speed, uy * speed, uz * speed},
        leftover: 0
      }
    end
  end

  defp square(v) when is_number(v), do: v * v

  defp square_distance(%Types.Coord{} = a, %Types.Coord{} = b) do
    dx = a.x - b.x
    dy = a.y - b.y
    dz = a.z - b.z
    dx * dx + dy * dy + dz * dz
  end

  defp sequence_id(npc, name) do
    Storage.Animations.sequence_id(get_in(npc.npc.metadata, [:model, :name]), name)
  end
end
