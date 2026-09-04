defmodule Ms2ex.Storage.FieldMissionTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Storage.Tables.FieldMission

  import Ms2ex.TestHelpers

  setup do
    stub_metadata(%{
      "table:fieldmission.xml" => %{
        table: %{
          entries: %{
            "5" => %{mission_count: 5, stat_points: 0},
            "10" => %{mission_count: 10, stat_points: 3}
          }
        }
      }
    })

    :ok
  end

  test "returns the highest reached exploration milestone" do
    assert FieldMission.reached_progress(0) == 0
    assert FieldMission.reached_progress(5) == 5
    assert FieldMission.reached_progress(9) == 5
    assert FieldMission.reached_progress(10) == 10
  end
end
