defmodule Ms2ex.Storage.Scripts do
  @moduledoc """
  NPC / quest talk-script metadata lookups (`script:<id>` documents).

  NPC scripts are keyed by npc id, quest scripts by quest id.
  """

  alias Ms2ex.Storage

  @spec get_meta(integer()) :: map() | nil
  def get_meta(id) when is_integer(id) do
    Storage.get(:script, id)
  end

  def get_meta(_id), do: nil

  @doc """
  Finds the first state in `lower_bound..upper_bound` (matching the quest
  script state-id convention: 100s accept, 200s progress, 300s complete).
  """
  @spec quest_state(map() | nil, integer(), integer()) :: map() | nil
  def quest_state(script, lower_bound, upper_bound) do
    states =
      case script do
        %{states: states} when is_map(states) -> states
        _ -> %{}
      end

    states
    |> Enum.map(fn {key, state} -> {parse_int(key), state} end)
    |> Enum.filter(fn {id, _state} -> is_integer(id) and id in lower_bound..upper_bound end)
    |> Enum.sort_by(fn {id, _state} -> id end)
    |> case do
      [{_id, state} | _] -> state
      [] -> nil
    end
  end

  @doc """
  Lists states of the given script-type atom (`:quest`, `:script`, `:select`,
  `:job`), sorted by state id.
  """
  @spec states_of_type(map() | nil, atom()) :: [map()]
  def states_of_type(script, type) do
    script
    |> states()
    |> Enum.filter(fn state -> state[:type] == type end)
    |> Enum.sort_by(& &1[:id])
  end

  @spec states(map() | nil) :: [map()]
  def states(script) do
    case script do
      %{states: states} when is_map(states) ->
        states
        |> Enum.map(fn {key, state} -> Map.put(state, :id, parse_int(key) || state[:id]) end)

      _ ->
        []
    end
  end

  defp parse_int(key) when is_integer(key), do: key

  defp parse_int(key) when is_binary(key) do
    case Integer.parse(key) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(_key), do: nil
end
