defmodule Ms2ex.Context.AchievementsTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Context.Achievements
  alias Ms2ex.Schema

  test "lists achievements by owner" do
    {:ok, _achievement} =
      Achievements.create(%{
        owner_id: 999_998,
        achievement_id: 100,
        current_grade: 1,
        reward_grade: 1,
        category: 2,
        grades: %{"1" => 100}
      })

    assert [%Schema.Achievement{achievement_id: 100}] = Achievements.list(999_998)
    assert [] = Achievements.list(999_999)
  end

  test "updates mutable fields of an achievement row" do
    {:ok, achievement} =
      Achievements.create(%{
        owner_id: 999_998,
        achievement_id: 101,
        current_grade: 1,
        reward_grade: 1,
        category: 1,
        counter: 0,
        grades: %{}
      })

    {:ok, updated} =
      Achievements.update(achievement, %{counter: 5, grades: %{"1" => 200}, favorite: true})

    assert updated.counter == 5
    assert updated.grades == %{"1" => 200}
    assert updated.favorite
  end
end
