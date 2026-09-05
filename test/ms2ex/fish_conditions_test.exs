defmodule Ms2ex.FishConditionsTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Managers.Quest.Conditions

  defp condition(type, codes, target) do
    %{
      type: type,
      value: 1,
      codes: %{range: nil, strings: [], integers: codes},
      target: %{range: nil, strings: [], integers: target}
    }
  end

  defp matches?(condition, fish_id, map_id) do
    Conditions.metadata_matches?(condition, "", map_id, "", fish_id)
  end

  describe "fish conditions" do
    test "a fish-gated trophy only counts its own fish" do
      for type <- [:fish, :fish_collect, :fish_big, :fish_goldmedal, :fish_fail] do
        condition = condition(type, [10_000_045], [])

        assert matches?(condition, 10_000_045, 2000),
               "#{type} should count the fish it is gated on"

        refute matches?(condition, 11_000_067, 2000),
               "#{type} should ignore every other fish"
      end
    end

    test "a map-gated trophy only counts catches in that map" do
      condition = condition(:fish, [11_000_054], [2_000_017])

      assert matches?(condition, 11_000_054, 2_000_017)
      refute matches?(condition, 11_000_054, 2_000_267)
    end

    test "an ungated trophy counts every fish anywhere" do
      condition = condition(:fish_goldmedal, [], [])

      assert matches?(condition, 10_000_045, 2000)
      assert matches?(condition, 11_000_067, 3000)
    end
  end
end
