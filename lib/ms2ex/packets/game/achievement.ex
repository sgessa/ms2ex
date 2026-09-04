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
    |> put_achievement_status(achievement.grades, achievement.metadata.grades)
    |> put_achievement_completed(achievement.grades, achievement.metadata.grades)
    |> put_int(achievement.current_grade)
    |> put_int(achievement.reward_grade)
    |> put_bool(achievement.favorite)
    |> put_long(achievement.counter)
    |> put_int(map_size(achievement.grades))
    |> put_grades(achievement.grades)
  end

  defp put_achievement_status(packet, l, r) when map_size(l) == map_size(r),
    do: put_byte(packet, 3)

  defp put_achievement_status(packet, _, _),
    do: put_byte(packet, 2)

  defp put_achievement_completed(packet, l, r) when map_size(l) == map_size(r),
    do: put_int(packet, 1)

  defp put_achievement_completed(packet, _, _),
    do: put_int(packet, 0)

  defp put_grades(packet, grades) do
    grades = Enum.sort_by(grades, &elem(&1, 0))

    packet
    |> reduce(grades, fn {grade, acquired_at}, acc ->
      acc
      |> put_int(String.to_integer("#{grade}"))
      |> put_long(acquired_at)
    end)
  end
end
