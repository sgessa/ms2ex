defmodule Ms2ex.Managers.Field.Npc.Idle do
  @moduledoc """
  Mob idle behavior between fights: while out of battle a mob follows its
  weighted idle routines — standing, playing a bore emote, or walking to a
  random walkable point inside its `move_area` around the spawn point. A
  mob without a move area (or without locomotion) stays at its post.

  The routines come from the npc's `action.actions` weighted list (each
  entry names an animation sequence and a probability): `Idle_*` keeps the
  mob standing, `Bore_*` plays the sequence once as an emote, and
  `Walk_*` / `Run_*` walk a wander leg. Wander movement rides the battle
  walk machinery through the `:wander` battle mode.
  """

  alias Ms2ex.Managers.Field.Npc.{Battle, Patrol}
  alias Ms2ex.Navigation
  alias Ms2ex.Storage
  alias Ms2ex.Types

  # a stand holds for about this long before the next routine is rolled
  @stand_ms 1_000
  # a bore emote without a recorded beat plays for this long
  @emote_fallback_ms 4_000

  @type t :: %{
          task: :stand | :emote,
          until: integer()
        }

  @doc """
  Advances one idle mob: a stand or emote holds until its beat elapses,
  then the next routine is rolled from the metadata's weighted actions.
  """
  def tick(%Types.FieldNpc{type: :mob, dead?: false, patrol: nil} = npc, now) do
    case npc.idle do
      %{task: :stand, until: until} when now >= until -> pick_routine(npc, now)
      %{task: :emote, until: until} when now >= until -> start_stand(npc, now)
      %{task: _task} -> npc
      _ -> start_stand(npc, now)
    end
  end

  def tick(npc, _now), do: npc

  @doc """
  Ends a completed wander leg: back to standing, without touching health
  or attacker tags (only the trip home heals).
  """
  def arrive(npc) do
    npc
    |> Map.put(:battle, nil)
    |> Map.put(:velocity, {0, 0, 0})
    |> start_stand(Ms2ex.sync_ticks())
  end

  # -- routines -----------------------------------------------------------------

  defp pick_routine(npc, now) do
    case weighted_routine(npc) do
      name when is_binary(name) ->
        cond do
          String.contains?(name, "Bore_") ->
            start_emote(npc, name, now)

          String.starts_with?(name, "Walk_") or String.starts_with?(name, "Run_") ->
            start_wander(npc, name, now)

          # Idle_* and unknown routines keep the mob at its post
          true ->
            start_stand(npc, now)
        end

      _ ->
        start_stand(npc, now)
    end
  end

  defp start_stand(npc, now) do
    animation = npc.idle_sequence_id || npc.animation

    if npc.animation == animation and npc.velocity == {0, 0, 0} do
      %{npc | idle: %{task: :stand, until: now + @stand_ms}}
    else
      %{
        npc
        | idle: %{task: :stand, until: now + @stand_ms},
          animation: animation,
          velocity: {0, 0, 0},
          send_control?: true
      }
    end
  end

  defp start_emote(npc, routine, now) do
    model = get_in(npc.npc.metadata, [:model, :name])

    with id when is_integer(id) <- sequence_id(npc, routine),
         ms when is_integer(ms) and ms > 0 <- emote_ms(model, routine) do
      npc = Types.FieldNpc.play_emote(npc, id, ms, now)
      %{npc | idle: %{task: :emote, until: now + ms}}
    else
      _ -> start_stand(npc, now)
    end
  end

  # the bore emote's beat: the sequence's natural playback length
  defp emote_ms(model, name) do
    case Storage.Animations.sequence_time(model, name) do
      seconds when is_number(seconds) and seconds > 0 -> trunc(seconds * 1000)
      _ -> @emote_fallback_ms
    end
  end

  # a wander leg: a random walkable point inside the move area around the
  # spawn point, walked at the routine's gait. Mobs without a move area, or
  # without any locomotion speed, stay at their post
  defp start_wander(npc, routine, now) do
    move_area = get_in(npc.npc.metadata, [:action, :move_area]) || 0

    if move_area > 0 and wander_speed(npc, routine) > 0.0 do
      case Navigation.random_point_around(npc.map_id, npc.origin, move_area) do
        nil ->
          start_stand(npc, now)

        goal ->
          npc
          |> Map.put(:battle, Battle.wander_battle(goal, now))
          |> Map.put(:idle, nil)
          |> Map.put(:velocity, {0, 0, 0})
          |> Map.put(:animation, wander_animation(npc, routine))
          |> Map.put(:send_control?, true)
      end
    else
      start_stand(npc, now)
    end
  end

  defp wander_animation(npc, routine) do
    sequence_id(npc, routine) || sequence_id(npc, "Walk_A") || npc.animation
  end

  # the wander leg's pace: the routine's gait, falling back to the other
  # gait (a walk-only mob may be told to Run_ and vice versa)
  defp wander_speed(npc, routine) do
    gait = if String.starts_with?(routine, "Run_"), do: :run_speed, else: :walk_speed
    other = if gait == :run_speed, do: :walk_speed, else: :run_speed

    case Patrol.npc_speed(npc, gait) do
      speed when speed > 0.0 -> speed
      _ -> Patrol.npc_speed(npc, other)
    end
  end

  defp weighted_routine(npc) do
    actions = get_in(npc.npc.metadata, [:action, :actions]) || []

    total =
      Enum.reduce(actions, 0, fn action, acc -> acc + max(action[:probability] || 0, 0) end)

    if total > 0, do: roll(actions, total)
  end

  defp roll(actions, total) do
    target = :rand.uniform(total)

    Enum.reduce_while(actions, 0, fn action, acc ->
      weight = max(action[:probability] || 0, 0)

      if acc + weight >= target and weight > 0 do
        {:halt, action[:name]}
      else
        {:cont, acc + weight}
      end
    end)
  end

  defp sequence_id(npc, name),
    do: Storage.Animations.sequence_id(get_in(npc.npc.metadata, [:model, :name]), name)
end
