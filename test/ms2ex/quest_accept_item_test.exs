defmodule Ms2ex.QuestAcceptItemTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Quest.Conditions
  alias Ms2ex.Storage

  # a delivery quest: accepting it grants the pudding, and completing it
  # requires holding that pudding (item_exist). The accept flow updates the
  # item_add/item_exist counters per granted item; this covers the update
  # mechanics those pushes rely on.
  @quest_id 2_100_045
  @pudding_id 2_000_023

  @quest_metadata %{
    id: @quest_id,
    name: "accept item test",
    basic: %{
      type: :world_quest,
      chapter_id: 0,
      complete_npc: 11_000_350,
      event_tag: "",
      auto_start: false,
      disabled: false
    },
    conditions: [
      %{type: :item_exist, value: 1, codes: %{range: nil, strings: [], integers: [@pudding_id]}}
    ]
  }

  setup do
    stub_metadata(%{"quest:#{@quest_id}" => @quest_metadata})
    :ok
  end

  test "item_add/item_exist updates satisfy an item_exist delivery condition" do
    quest = started_quest()

    assert Conditions.all_met?(quest) == false

    # the accept grant pushes both updates for the granted item
    updated =
      quest
      |> Conditions.update(:item_add, 1, "", 0, "", @pudding_id)
      |> Conditions.update(:item_exist, 1, "", 0, "", @pudding_id)

    assert Conditions.all_met?(updated)
  end

  test "item_exist only counts the matching item id" do
    quest = started_quest()

    updated = Conditions.update(quest, :item_exist, 1, "", 0, "", 2_000_099)

    assert Conditions.all_met?(updated) == false
  end

  # the manager state carries only the condition counters; documents
  # resolve from ETS by quest id
  defp started_quest do
    quest_doc = Storage.get(:quest, @quest_id)

    counters =
      quest_doc
      |> Map.get(:conditions, [])
      |> Enum.with_index()
      |> Map.new(fn {_condition, index} -> {index, 0} end)

    %{
      id: @quest_id,
      quest_id: @quest_id,
      state: :started,
      start_time: :os.system_time(:second),
      conditions: counters
    }
  end
end
