defmodule Ms2ex.BadgeTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Enums.BadgeType
  alias Ms2ex.Types.Item

  describe "badge_type/1" do
    test "maps reference badge id groups" do
      assert Item.badge_type(70_100_000) == :pet_skin
      assert Item.badge_type(70_100_001) == :transparency
      assert Item.badge_type(70_100_002) == :auto_gather
      assert Item.badge_type(70_200_001) == :chat_bubble
      assert Item.badge_type(70_300_001) == :name_tag
      assert Item.badge_type(70_400_001) == :damage
      assert Item.badge_type(70_500_001) == :tombstone
      assert Item.badge_type(70_600_001) == :swim_tube
      assert Item.badge_type(70_700_001) == :fishing
      assert Item.badge_type(70_800_001) == :buddy
      assert Item.badge_type(70_900_001) == :effect
    end

    test "unknown ids are not treated as badges" do
      assert Item.badge_type(20_300_607) == :none
      assert BadgeType.get_value(Item.badge_type(20_300_607)) == 0
    end
  end
end
