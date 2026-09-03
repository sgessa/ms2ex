defmodule Ms2ex.Packets.Achievement do
  import Ms2ex.Packets.PacketWriter

  @initialize 0x00
  @load 0x01
  @update 0x02
  @favorite 0x04

  def initialize do
    __MODULE__
    |> build()
    |> put_byte(@initialize)
  end

  def load(achievements) do
    __MODULE__
    |> build()
    |> put_byte(@load)
    |> put_int(length(achievements))
    |> reduce(achievements, fn achievement, packet ->
      packet
      |> put_int(achievement.achievement_id)
      |> put_int(1)
      |> put_achievement(achievement)
    end)
  end

  def update(achievement) do
    __MODULE__
    |> build()
    |> put_byte(@update)
    |> put_int(achievement.achievement_id)
    |> put_achievement(achievement)
  end

  def favorite(achievement) do
    __MODULE__
    |> build()
    |> put_byte(@favorite)
    |> put_int(achievement.achievement_id)
    |> put_bool(achievement.favorite)
  end

  defp put_achievement(packet, achievement) do
    packet
    |> put_byte(if(map_size(achievement.grades) == map_size(achievement.metadata.grades), do: 3, else: 2))
    |> put_int(if(map_size(achievement.grades) == map_size(achievement.metadata.grades), do: 1, else: 0))
    |> put_int(achievement.current_grade)
    |> put_int(achievement.reward_grade)
    |> put_bool(achievement.favorite)
    |> put_long(achievement.counter)
    |> put_int(map_size(achievement.grades))
    |> reduce(Enum.sort_by(achievement.grades, &elem(&1, 0)), fn {grade, acquired_at}, acc ->
      acc
      |> put_int(String.to_integer("#{grade}"))
      |> put_long(acquired_at)
    end)
  end
end
