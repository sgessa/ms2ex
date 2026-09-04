defmodule Ms2ex.Context.AchievementsTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Context.Achievements
  alias Ms2ex.Schema

  test "counts an owner once when account and character ids are equal" do
    owner_id = 999_999
    character = %Schema.Character{id: owner_id, account_id: owner_id}

    {:ok, _achievement} =
      Achievements.create(%{
        owner_id: owner_id,
        achievement_id: 100,
        current_grade: 1,
        reward_grade: 1,
        category: 2,
        grades: %{"1" => 100}
      })

    assert Achievements.trophy_counts(character) == [0, 1, 0]
  end
end
