defmodule Ms2ex.FieldItemDespawnTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers.Field.Item

  @object_id 9
  @topic "field:2:channel:1"

  setup do
    # the sweep broadcast rides the field topic
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, @topic)
    :ok
  end

  test "the drop timer sweeps the item and tells the field" do
    state = Item.despawn(@object_id, state())

    assert state.items == %{}
    assert_received {:push, <<0x2C::little-16, @object_id::little-32>>}
  end

  test "an already-picked-up item makes the timer a no-op" do
    state = %{state() | items: %{}}

    assert Item.despawn(@object_id, state) == state
    refute_received {:push, _}
  end

  defp state do
    %{
      topic: @topic,
      items: %{
        @object_id => %{
          object_id: @object_id,
          item_id: 4_000_001,
          amount: 1,
          position: %{x: 0.0, y: 0.0, z: 0.0}
        }
      }
    }
  end
end
