defmodule Ms2ex.HotBarSkillsTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  setup do
    account =
      Repo.insert!(%Schema.Account{
        username: "hb_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Hb#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    tab = Context.Skills.add_tab(character, %{name: "Build 1"}) |> then(fn {:ok, t} -> t end)

    character = %{character | skill_tabs: [tab], active_skill_tab_id: tab.id}

    empty = List.duplicate(%Types.QuickSlot{}, 25)

    hot_bars = [
      Repo.insert!(%Schema.HotBar{character_id: character.id, active: true, quick_slots: empty}),
      Repo.insert!(%Schema.HotBar{character_id: character.id, active: false, quick_slots: empty})
    ]

    %{character: character, hot_bars: hot_bars}
  end

  test "a fresh character's active hot bar fills with learned active skills", %{
    character: character,
    hot_bars: hot_bars
  } do
    assert fresh_hot_bars?(hot_bars)

    filled = Context.HotBars.update_hotbar_skills(character, hot_bars)
    active = Enum.find(filled, & &1.active)
    bound = Enum.filter(active.quick_slots, &(&1.skill_id > 0))

    # the knight's learned in-battle skills land on the active bar
    refute bound == []
    assert Enum.all?(bound, &(&1.skill_id > 10_000_000 and &1.skill_id < 20_000_000))
    assert Enum.uniq(Enum.map(bound, & &1.skill_id)) == Enum.map(bound, & &1.skill_id)
  end

  # mirrors what the field-enter handler checks before deciding to seed
  defp fresh_hot_bars?(hot_bars) do
    Enum.all?(hot_bars, fn hot_bar ->
      Enum.all?(hot_bar.quick_slots, &(&1.skill_id in [nil, 0]))
    end)
  end
end
