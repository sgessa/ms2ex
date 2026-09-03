defmodule Ms2ex.Managers.Field.InteractObject do
  @moduledoc """
  Interact-object lifecycle: objects start Normal, become Reactable on the
  first tick, and flip back to Normal when a player interacts. Exhausted
  objects (react count reached) hide permanently, unless a hide delay is
  configured. Normal objects return to Reactable after their reset time.
  """

  alias Ms2ex.Context
  alias Ms2ex.Net.SenderSession
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @infinity :infinity

  def load(map_id) do
    map_id
    |> Storage.Maps.get_interact_objects()
    |> Map.new(fn object -> {object.uuid, enrich(object)} end)
  end

  defp enrich(object) do
    meta = Storage.Tables.InteractObjects.get(object.id)

    object
    |> Map.put(:state, :normal)
    |> Map.put(:next_tick, now())
    |> Map.put(:reacts_left, reacts_left(meta))
    |> Map.put(:time, Map.get(meta || %{}, :time, %{}))
  end

  defp reacts_left(%{react_count: count}) when count > 0, do: count
  defp reacts_left(_meta), do: @infinity

  @doc """
  Completes an interaction with an object. Only Reactable objects can be
  interacted with; the animation goes to the interacting player while the
  state transition is broadcast to the whole field.
  """
  def react(%Schema.Character{} = character, uuid, state) do
    case Map.get(state.interactable, uuid) do
      nil ->
        {:error, state}

      %{state: :reactable} = object ->
        object = transition_on_react(object, now())
        SenderSession.push(character, Packets.InteractObject.interact(object))
        Context.Field.broadcast(state.topic, Packets.InteractObject.update(object))

        interactable = Map.put(state.interactable, uuid, object)
        {:ok, object.id, %{state | interactable: interactable}}

      _object ->
        {:error, state}
    end
  end

  defp transition_on_react(object, tick) do
    %{time: time, reacts_left: reacts_left} = object
    reset = Map.get(time, :reset, 0)
    hide = Map.get(time, :hide, 0)
    reacts_left = dec_reacts_left(reacts_left)

    if reacts_left == :infinity or reacts_left > 0 do
      %{object | state: :normal, reacts_left: reacts_left, next_tick: tick + reset}
    else
      if hide > 0 do
        %{object | state: :normal, reacts_left: reacts_left, next_tick: tick + hide}
      else
        %{object | state: :hidden, reacts_left: reacts_left, next_tick: nil}
      end
    end
  end

  defp dec_reacts_left(@infinity), do: @infinity
  defp dec_reacts_left(count), do: count - 1

  @doc "Flips objects whose cooldown elapsed (Normal -> Reactable or Hidden)."
  def tick(%{interactable: interactable} = state) when map_size(interactable) > 0 do
    tick = now()

    interactable =
      Map.new(interactable, fn {uuid, object} ->
        case due_transition(object, tick) do
          nil ->
            {uuid, object}

          object ->
            Context.Field.broadcast(state.topic, Packets.InteractObject.update(object))
            {uuid, object}
        end
      end)

    %{state | interactable: interactable}
  end

  def tick(state), do: state

  defp due_transition(%{next_tick: next_tick}, _tick) when next_tick in [nil, 0], do: nil

  defp due_transition(%{next_tick: next_tick} = object, tick) when tick >= next_tick do
    %{state: state, time: time, reacts_left: reacts_left} = object
    reset = Map.get(time, :reset, 0)

    if state == :normal and reset > 0 do
      if reacts_left == :infinity or reacts_left > 0 do
        %{object | state: :reactable, next_tick: nil}
      else
        %{object | state: :hidden, next_tick: nil}
      end
    else
      %{object | next_tick: nil}
    end
  end

  defp due_transition(_object, _tick), do: nil

  defp now, do: System.monotonic_time(:millisecond)
end
