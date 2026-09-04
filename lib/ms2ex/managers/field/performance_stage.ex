defmodule Ms2ex.Managers.Field.PerformanceStage do
  @moduledoc """
  The Queenstown concert stage: one player (or their party) holds the stage
  at a time, announced to the field as the `music_concert` field property so
  clients light up the stage and show the performance timer.

  The stage is released when the performer ends it, leaves the map, or the
  performance runs out of time.
  """

  alias Ms2ex.Context
  alias Ms2ex.Packets

  @map_id 2_000_064
  @max_duration :timer.minutes(10)

  # entering and leaving the stage go through the map's stage portals
  @enter_portal_id 802
  @exit_portal_id 803

  @spec stage?(map()) :: boolean()
  def stage?(%{map_id: @map_id}), do: true
  def stage?(_state), do: false

  def start(character, state) do
    cond do
      not stage?(state) ->
        state

      state.performance ->
        state

      true ->
        end_tick = Ms2ex.sync_ticks() + @max_duration
        timer = Process.send_after(self(), {:end_performance, character.id}, @max_duration)

        Context.Field.broadcast(
          state.topic,
          Packets.FieldProperty.add({:music_concert, character.id, end_tick})
        )

        %{state | performance: %{character_id: character.id, end_tick: end_tick, timer: timer}}
    end
  end

  @doc """
  Releases the stage at the performer's request; the scheduled expiry is
  dropped along with it.
  """
  def stop(character_id, state) do
    case state.performance do
      %{character_id: ^character_id, timer: timer} ->
        Process.cancel_timer(timer)
        clear(state)

      _ ->
        state
    end
  end

  @doc """
  Releases the stage without the performer asking: the performance ran out of
  time or its owner left the map.
  """
  def release(character_id, state) do
    case state.performance do
      %{character_id: ^character_id} -> clear(state)
      _ -> state
    end
  end

  @doc """
  Active properties for a joining player, so they see a performance that
  started before they entered the map.
  """
  def properties(%{performance: %{character_id: character_id, end_tick: end_tick}}),
    do: [{:music_concert, character_id, end_tick}]

  def properties(_state), do: []

  @doc """
  Toggles the performer between the audience floor and the stage. The client
  sends a single command for both directions.
  """
  def toggle_stage(character, state) do
    on_stage? = MapSet.member?(state.stage, character.id)
    portal_id = if on_stage?, do: @exit_portal_id, else: @enter_portal_id

    with true <- stage?(state),
         %{} = portal <- Map.get(state.portals, portal_id) do
      move_to(character, portal)

      stage =
        if on_stage?,
          do: MapSet.delete(state.stage, character.id),
          else: MapSet.put(state.stage, character.id)

      %{state | stage: stage}
    else
      _ -> state
    end
  end

  def leave(character_id, state) do
    state = release(character_id, state)
    %{state | stage: MapSet.delete(state.stage, character_id)}
  end

  defp clear(state) do
    Context.Field.broadcast(state.topic, Packets.FieldProperty.remove(:music_concert))
    %{state | performance: nil}
  end

  defp move_to(character, portal) do
    character = %{character | position: portal.position}
    Ms2ex.Managers.Character.call(character, {:update, character})
    Context.Field.broadcast(character, Packets.MoveCharacter.bytes(character, portal.position))
  end
end
