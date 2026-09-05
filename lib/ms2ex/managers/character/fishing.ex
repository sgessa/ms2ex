defmodule Ms2ex.Managers.Character.Fishing do
  @moduledoc """
  Fishing state owned by the character process: the active rod, the water
  tiles it reaches, the fish currently biting and the fish album.

  The album is persisted alongside the mastery state on the periodic flush.
  """

  @doc "Fish album, keyed by fish id."
  def album(character) do
    case Map.get(character, :fish_album) do
      album when is_map(album) -> album
      _ -> %{}
    end
  end

  @doc "The active fishing session, or nil when the player is not fishing."
  def session(character), do: Map.get(character, :fishing)

  def start_session(character, fishing), do: Map.put(character, :fishing, fishing)

  def stop_session(character), do: Map.put(character, :fishing, nil)

  @doc "Stores which tile is being fished and which fish is biting."
  def bite(character, tile, fish_id, fight_game?) do
    case session(character) do
      nil ->
        character

      fishing ->
        Map.put(character, :fishing, %{
          fishing
          | tile: tile,
            fish_id: fish_id,
            fight_game?: fight_game?
        })
    end
  end

  def clear_minigame(character) do
    case session(character) do
      nil -> character
      fishing -> Map.put(character, :fishing, %{fishing | fight_game?: false})
    end
  end

  @doc "Tracks where the player dragged the bobber."
  def move_guide(character, position, rotation) do
    case session(character) do
      nil ->
        character

      %{guide: guide} = fishing ->
        guide = %{guide | position: position, rotation: rotation}
        Map.put(character, :fishing, %{fishing | guide: guide})
    end
  end

  @doc """
  Records a catch in the album. Returns the updated character, the album
  entry and whether this was the first catch of that kind.
  """
  def record_catch(character, fish_id, size, prize?) do
    album = album(character)
    existing = Map.get(album, fish_id)

    entry =
      case existing do
        nil ->
          %{
            fish_id: fish_id,
            total_caught: 1,
            total_prize: bool_to_int(prize?),
            largest_size: size
          }

        entry ->
          %{
            entry
            | total_caught: entry.total_caught + 1,
              total_prize: entry.total_prize + bool_to_int(prize?),
              largest_size: max(entry.largest_size, size)
          }
      end

    character =
      character
      |> Map.put(:fish_album, Map.put(album, fish_id, entry))
      |> Map.put(:mastery_dirty?, true)

    {character, entry, is_nil(existing)}
  end

  defp bool_to_int(true), do: 1
  defp bool_to_int(_prize?), do: 0
end
