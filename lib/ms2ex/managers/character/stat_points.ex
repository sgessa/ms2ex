defmodule Ms2ex.Managers.Character.StatPoints do
  alias Ms2ex.Context
  alias Ms2ex.Context.StatPoints
  alias Ms2ex.Packets
  alias Ms2ex.Types.AttributePointSource

  import Ms2ex.Net.SenderSession, only: [push: 2]

  def add_stat_point(character, source, amount) do
    source = if is_atom(source), do: source, else: AttributePointSource.get_key(source)

    with true <- source in AttributePointSource.all(),
         sources <- Map.update(character.stat_point_sources, source, amount, &(&1 + amount)),
         {:ok, _} <-
           Context.Characters.update_stat_points(
             character,
             sources,
             character.stat_point_allocation
           ) do
      character = %{character | stat_point_sources: sources}
      push(character, Packets.StatPoints.sources(sources))
      {:ok, character}
    else
      _ -> :error
    end
  end

  defp can_allocate?(character, stat, current, total) do
    limit = Application.get_env(:ms2ex, :constants)[:stat_point_limits] |> Map.get(stat, 100)
    used = character.stat_point_allocation |> Map.values() |> Enum.sum()

    cond do
      used >= total ->
        {:error, :insufficent_ap}

      current >= limit ->
        {:error, :limit_reached}

      true ->
        :ok
    end
  end

  def allocate(character, attribute) do
    with {:ok, stat} <- StatPoints.attribute(attribute),
         current <- Map.get(character.stat_point_allocation, stat, 0),
         total <- character.stat_point_sources |> Map.values() |> Enum.sum(),
         :ok <- can_allocate?(character, stat, current, total),
         allocation <- Map.put(character.stat_point_allocation, stat, current + 1),
         {:ok, _} <-
           Context.Characters.update_stat_points(
             character,
             character.stat_point_sources,
             allocation
           ) do
      character = StatPoints.apply_attribute(character, stat, 1)
      character = %{character | stat_point_allocation: allocation}
      Context.Field.broadcast(character, Packets.Stats.update_char_stats(character, stat))
      push(character, Packets.StatPoints.allocation(allocation, total))
      {:ok, character}
    else
      {:error, :limit_reached} ->
        push(character, Packets.Notice.message("s_char_info_limit_stat_point"))
        :error

      _ ->
        :error
    end
  end

  def reset(character) do
    total = character.stat_point_sources |> Map.values() |> Enum.sum()

    case Context.Characters.update_stat_points(character, character.stat_point_sources, %{}) do
      {:ok, _} ->
        character =
          Enum.reduce(character.stat_point_allocation, character, fn {stat, amount}, char ->
            char = StatPoints.apply_attribute(char, stat, -amount)
            Context.Field.broadcast(char, Packets.Stats.update_char_stats(char, stat))
            char
          end)

        character = %{character | stat_point_allocation: %{}}
        push(character, Packets.StatPoints.allocation(%{}, total))
        push(character, Packets.Notice.message("s_char_info_reset_stat_pointsuccess_msg"))
        {:ok, character}

      {:error, _} ->
        :error
    end
  end
end
