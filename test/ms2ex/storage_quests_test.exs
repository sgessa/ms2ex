defmodule Ms2ex.Storage.QuestsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Storage.Quests

  import Ms2ex.TestHelpers

  setup do
    stub_metadata(%{
      "quest:index" => %{
        ids: [1001, 1002],
        auto_start_ids: [1002],
        by_npc: %{2001 => [1001], 2002 => [1001, 1002]},
        by_type: %{epic_quest: [1001], world_quest: [1002]},
        by_chapter: %{10 => [1001], 11 => [1002]}
      },
      "quest:1001" => %{
        id: 1001,
        basic: %{
          start_npc: 2001,
          complete_npc: 2002,
          type: :epic_quest,
          chapter_id: 10,
          account: 0
        }
      },
      "quest:1002" => %{
        id: 1002,
        basic: %{start_npc: 0, complete_npc: 2002, type: :world_quest, chapter_id: 11, account: 1}
      }
    })

    :ok
  end

  test "loads all quests from the projected quest index" do
    assert Enum.map(Quests.get_all(), & &1.id) == [1001, 1002]
  end

  test "looks up quests by npc through the projected index" do
    assert Enum.map(Quests.get_quests_by_npc(2002), & &1.id) == [1001, 1002]
  end

  test "looks up quests by type through the projected index" do
    assert Enum.map(Quests.get_quests_by_type(:epic_quest), & &1.id) == [1001]
  end

  test "looks up quests by chapter through the projected index" do
    assert Enum.map(Quests.get_quests_by_chapter(11), & &1.id) == [1002]
  end

  test "returns projected auto-start quests" do
    assert Enum.map(Quests.auto_start_quests(), & &1.id) == [1002]
  end
end
