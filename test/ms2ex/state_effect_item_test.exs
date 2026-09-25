defmodule Ms2ex.StateEffectItemTest do
  use Ms2ex.DataCase, async: false
  use Mimic

  import Ms2ex.TestHelpers

  alias Ms2ex.Context

  # the auto-fishing voucher: its item skill casts the auto_fish buff effect
  @voucher_metadata %{
    skill_id: 90_000_596,
    skill_level: 1,
    property: %{tag: :none}
  }

  @skill_meta %{
    id: 90_000_596,
    levels: %{
      "1" => %{skills: [%{skills: [%{id: 100_000_017, level: 1}]}]}
    }
  }

  @effect_doc %{property: %{event_type: :auto_fish}}

  setup do
    stub_metadata(%{
      "item:20000589" => @voucher_metadata,
      "skill:90000596" => @skill_meta,
      "additional-effect:100000017_1" => @effect_doc
    })

    :ok
  end

  test "the fishing voucher resolves its auto-fish effect" do
    assert Context.Items.state_effects(@voucher_metadata) == [{100_000_017, 1}]
  end

  test "an item without an item skill resolves to nothing" do
    assert Context.Items.state_effects(%{property: %{tag: :none}}) == []
  end

  test "an item whose skill casts a plain buff resolves to nothing" do
    meta = %{skill_id: 90_000_001, skill_level: 1, property: %{tag: :none}}

    stub_metadata(%{
      "skill:90000001" => %{
        levels: %{"1" => %{skills: [%{skills: [%{id: 90_000_002, level: 1}]}]}}
      },
      "additional-effect:90000002_1" => %{property: %{event_type: :none}}
    })

    assert Context.Items.state_effects(meta) == []
  end

  test "a missing skill level resolves to nothing" do
    meta = %{skill_id: 90_000_596, skill_level: 9, property: %{tag: :none}}

    assert Context.Items.state_effects(meta) == []
  end
end
