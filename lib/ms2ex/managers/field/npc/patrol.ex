defmodule Ms2ex.Managers.Field.Npc.Patrol do
  @moduledoc """
  Npc movement along patrol paths: story npcs walk named patrol paths
  (script move_npc) and stay at the last waypoint; the movement math also
  seeds the scripted-carry follow-dummy that `Managers.Field.Npc` spawns.
  """

  require Logger

  alias Ms2ex.Navigation
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @follow_speed 150

  @doc """
  Walks a story npc along a named patrol path (script move_npc): the walk
  streams through the control broadcast; loop patrols cycle their waypoints
  forever, and a non-loop patrol leaves the npc at the last waypoint.
  """
  def move_npc(state, spawn_id, path_name) do
    patrol = Map.get(state[:patrols] || %{}, path_name)

    case patrol do
      %{way_points: way_points} when way_points != [] ->
        state.npcs
        |> Enum.filter(fn {_object_id, npc} -> npc.spawn_point_id == spawn_id end)
        |> Enum.reduce(state, fn {object_id, npc}, state ->
          attach_patrol(state, object_id, npc, patrol)
        end)

      _ ->
        state
    end
  end

  # advances an npc along its patrol path; called on every control tick.
  # each authored waypoint is reached over a navmesh path so descents
  # follow ramps and stairs instead of a straight line through the air;
  # the last point of every leg is the authored waypoint itself
  def advance_patrol(%{patrol: nil} = npc, _now), do: npc
  def advance_patrol(%{patrol: %{waypoints: []}} = npc, _now), do: npc

  def advance_patrol(npc, now) do
    patrol = npc.patrol
    dt = max(now - Map.get(patrol, :last_at, now), 1)
    speed = Enum.at(patrol[:speeds] || [], patrol.index) || patrol.speed
    step = speed * dt / 1000.0

    {position, velocity, arrived?} =
      step_toward(npc.position, leg_target(patrol), step, speed, dt)

    patrol = Map.put(patrol, :last_at, now)

    if arrived? do
      advance_leg(%{npc | position: position}, patrol)
    else
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

  # the point the current leg is walking toward: the next point of the
  # navmesh path, or the authored waypoint once the path is consumed
  defp leg_target(patrol) do
    case Enum.at(patrol.path, patrol.path_index) do
      nil -> Enum.fetch!(patrol.waypoints, patrol.index)[:position]
      point -> point
    end
  end

  # a path point arrival continues the leg; consuming the whole path means
  # the authored waypoint is reached — a loop patrol cycles back to its
  # first waypoint, otherwise the next leg starts or the patrol resolves
  # its post-path behavior (story npcs return to their idle pose, follow
  # dummies despawn)
  defp advance_leg(npc, patrol) do
    last? = patrol.index + 1 >= length(patrol.waypoints)

    cond do
      Enum.at(patrol.path, patrol.path_index + 1) != nil ->
        patrol = Map.put(patrol, :path_index, patrol.path_index + 1)
        %{npc | patrol: patrol, send_control?: true}

      last? and patrol[:is_loop] != true ->
        finish_patrol(npc, patrol)

      true ->
        patrol = Map.put(patrol, :index, if(last?, do: 0, else: patrol.index + 1))
        # TODO: a waypoint carrying an arrive animation plays it as an emote
        # before the next leg departs (arrive_animation_time holds the beat)
        animation = Enum.at(patrol.animations, patrol.index) || npc.animation

        case start_leg(npc, patrol) do
          {:ok, patrol} ->
            %{npc | patrol: patrol, animation: animation, send_control?: true}

          :error ->
            finish_patrol(npc, patrol)
        end
    end
  end

  @doc """
  Resolves how the current authored waypoint is reached: over the navmesh
  graph, walking ramps and stairs instead of a straight line through the
  air. Returns `:error` when no connected route exists (unresolved nif
  props leave coverage gaps) — the caller then leaves the npc standing
  instead of walking a straight line that can float above the terrain.
  """
  def start_leg(%Types.FieldNpc{} = npc, patrol) do
    way_point = Enum.fetch!(patrol.waypoints, patrol.index)
    # patrol documents project positions as plain maps; the route query
    # needs a Coord
    target = to_coord(way_point[:position])
    authored_z = trunc(target.z * 100) / 100

    result =
      if way_point[:air_way_point] do
        {:ok, [target]}
      else
        Navigation.find_path(npc.map_id, npc.position, target)
      end

    case result do
      {:ok, path} ->
        # the authored waypoint terminates the leg: its final segment walks
        # to it exactly (never mesh-snapped), so the npc lands on the
        # choreography point even where the mesh coverage stops short of it
        Logger.debug(
          "[patrol] leg start npc=#{npc.object_id} waypoint=#{patrol.index + 1}/#{length(patrol.waypoints)} " <>
            "from=(#{trunc(npc.position.x)}, #{trunc(npc.position.y)}, #{trunc(npc.position.z * 100) / 100}) " <>
            "authored_z=#{authored_z} path_points=#{length(path) + 1} " <>
            "path_heights=#{inspect(Enum.map(path ++ [target], fn p -> trunc(p.z * 100) / 100 end), limit: 8)}"
        )

        {:ok,
         patrol
         |> Map.put(:path, path ++ [target])
         |> Map.put(:path_index, 1)}

      :error ->
        Logger.debug(
          "[patrol] leg start npc=#{npc.object_id} waypoint=#{patrol.index + 1}/#{length(patrol.waypoints)} " <>
            "authored_z=#{authored_z} no navmesh route"
        )

        :error
    end
  end

  defp attach_patrol(state, object_id, npc, patrol_doc) do
    if Navigation.has_navmesh?(npc.map_id) do
      attach_legs(state, object_id, npc, patrol_doc)
    else
      # patrols ride the navmesh; a map without one does not get silent
      # straight-line movement — generate the navmesh instead
      Logger.warning(
        "map " <>
          to_string(npc.map_id) <>
          " has no navmesh; npc " <> to_string(npc.npc.id) <> " will not patrol"
      )

      state
    end
  end

  defp attach_legs(state, object_id, npc, patrol_doc) do
    way_points = patrol_doc[:way_points]

    case leg_animations(npc, way_points) do
      nil ->
        # the model has no walk/run sequence; it stays put instead of
        # sliding across the field in its idle pose
        state

      animations ->
        patrol =
          %{
            waypoints: way_points,
            animations: animations,
            speeds: leg_speeds(npc, way_points, patrol_doc[:speed] || 0),
            is_loop: patrol_doc[:is_loop] == true,
            index: 0,
            speed: @follow_speed,
            last_at: Ms2ex.sync_ticks(),
            despawn_on_finish?: false
          }

        case start_leg(npc, patrol) do
          {:ok, patrol} ->
            npc = %{npc | animation: hd(animations), patrol: patrol, send_control?: true}
            put_in(state, [:npcs, object_id], npc)

          :error ->
            # no connected route to the first waypoint: the npc keeps its
            # post instead of walking a line that can leave the ground
            Logger.warning(
              "no navmesh route for npc " <>
                to_string(npc.npc.id) <>
                " on " <> to_string(npc.map_id) <> "; npc will not patrol"
            )

            state
        end
    end
  end

  # per-waypoint patrol speeds: Run_A legs run at the npc's run speed,
  # Walk_A legs at its walk speed, falling back to the shared default.
  # A patrol that carries its own speed scales air legs by half of it —
  # the flight pace the scripted paths author
  def leg_speeds(npc, way_points, patrol_speed \\ 0) do
    Enum.map(way_points, fn way_point ->
      speed = leg_speed(npc, way_point[:approach_animation])

      if way_point[:air_way_point] == true and patrol_speed > 0 do
        speed * patrol_speed / 2
      else
        speed
      end
    end)
  end

  def leg_speed(npc, approach_animation) do
    case approach_animation do
      "Run_A" -> npc_speed(npc, :run_speed)
      _ -> npc_speed(npc, :walk_speed)
    end
  end

  # npc ground speed for a gait (units/second) from the metadata's action
  # speeds. An explicit zero is meaningful — the mob is rooted and cannot
  # move (a model with no walk sequence stays put) — only absent metadata
  # falls back to the shared default
  def npc_speed(npc, gait) do
    case get_in(npc.npc.metadata, [:action, gait]) do
      speed when is_number(speed) and speed >= 0 -> speed * 1.0
      _ -> @follow_speed * 1.0
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
      Logger.debug(
        "[patrol] finished npc=#{npc.object_id} at (#{trunc(npc.position.x)}, #{trunc(npc.position.y)}, #{trunc(npc.position.z * 100) / 100})"
      )

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
  # the movement instead of snapping. a step that reaches the waypoint
  # lands exactly on it
  defp step_toward(pos, target, step, speed, _dt) do
    dx = Map.get(target, :x) - pos.x
    dy = Map.get(target, :y) - pos.y
    dz = Map.get(target, :z) - pos.z
    dist = :math.sqrt(dx * dx + dy * dy + dz * dz)

    if dist == 0 or dist <= step do
      {target, {0, 0, 0}, true}
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

  defp to_coord(%Types.Coord{} = coord), do: coord
  defp to_coord(pos) when is_map(pos), do: struct(Types.Coord, Map.to_list(pos))
  defp to_coord(_), do: %Types.Coord{}
end
