defmodule Ms2ex.Storage.Achievements do
  alias Ms2ex.Storage

  def get(achievement_id) when is_integer(achievement_id),
    do: Storage.get(:achievement, achievement_id)

  def for_condition(condition_type) do
    Storage.get(:achievement, "index")
    |> Map.get(condition_type, [])
    |> Enum.map(&get/1)
    |> Enum.reject(&is_nil/1)
  end
end
