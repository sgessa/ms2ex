defmodule Ms2ex.LiftableExpiryTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field.Liftable

  @topic "liftable-expiry-test"

  defp placed(finish_at) do
    %{
      uuid: "4_66051",
      item_id: 30_000_856,
      count: 1,
      state: :default,
      grid: {1, 1, 1},
      object_id: 501,
      item_lifetime: 0,
      finish_time: 500,
      finish_at: finish_at,
      mask_quest_id: "",
      mask_quest_state: "",
      effect_quest_id: "40002720",
      effect_quest_state: "1",
      react_effect: true
    }
  end

  defp state_with(quests) do
    %{topic: @topic, liftables: quests, held_liftables: %{}}
  end

  test "expired placed props are removed with cube and liftable frames" do
    now = System.monotonic_time(:millisecond)
    expired = placed(now - 1)
    fresh = placed(now + 60_000)

    state = state_with(%{"4_66051" => expired, "4_other" => fresh})

    Phoenix.PubSub.subscribe(Ms2ex.PubSub, @topic)
    state = Liftable.expire_placed(state)

    # the expired prop is gone, the fresh one stays
    assert Map.keys(state.liftables) == ["4_other"]

    # the visual cube and the liftable entry are both removed
    assert_receive {:push,
                    <<0x6B::little-16, 0x0C, 0, 501::little-32, 501::little-32, 1, 1, 1, 0, 0>>}

    assert_receive {:push, <<0x75::little-16, 0x4, len::little-16, uuid::binary-size(len)>>}
    assert uuid == "4_66051"
  end

  test "fresh placed props and staged liftables are untouched" do
    now = System.monotonic_time(:millisecond)

    state =
      state_with(%{
        "4_66051" => placed(now + 60_000),
        "staged" => %{uuid: "staged", item_id: 1, count: 3, state: :default}
      })

    state = Liftable.expire_placed(state)

    assert Map.keys(state.liftables) == ["4_66051", "staged"]
    refute_receive {:push, _}
  end

  test "staged liftables never expire regardless of counters" do
    state =
      state_with(%{
        "staged" => %{uuid: "staged", item_id: 1, count: 0, state: :removed}
      })

    state = Liftable.expire_placed(state)

    assert Map.keys(state.liftables) == ["staged"]
    refute_receive {:push, _}
  end
end
