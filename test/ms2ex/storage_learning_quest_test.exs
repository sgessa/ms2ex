defmodule Ms2ex.Storage.LearningQuestTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Storage.Tables.LearningQuest

  import Ms2ex.TestHelpers

  setup do
    stub_metadata(%{
      "table:learningquest.xml" => %{
        table: %{
          entries: %{
            "1" => %{
              category: 7,
              required_level: 12,
              quest_id: 90_000_640,
              required_map_id: 2_000_001,
              go_to_map_id: 52_000_063,
              go_to_portal_id: 0
            }
          }
        }
      }
    })

    :ok
  end

  test "returns the entry for a guide id" do
    assert LearningQuest.get(1) == %{
             category: 7,
             required_level: 12,
             quest_id: 90_000_640,
             required_map_id: 2_000_001,
             go_to_map_id: 52_000_063,
             go_to_portal_id: 0
           }
  end

  test "returns nil for an unknown guide id" do
    assert LearningQuest.get(999) == nil
  end
end
