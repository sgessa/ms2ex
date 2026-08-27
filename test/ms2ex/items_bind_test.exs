defmodule Ms2ex.ItemsBindTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Context

  setup do
    for key <- [
          "table:itemoptionpick.xml",
          "table:itemoptionconstant.xml",
          "table:itemoptionstatic.xml",
          "table:itemoptionrandom.xml"
        ] do
      :ets.insert(:metadata, {key, {:ok, %{table: %{}}}})
    end

    :ok
  end

  defp bind_item(type, on) do
    id = 910_000_001 + type

    :ets.insert(
      :metadata,
      {"item:#{id}",
       {:ok,
        %{
          limit: %{level: 1, transfer_type: type, trade_max_rarity: 4},
          slot_names: [],
          property: %{tradable_count: 0},
          option: %{constant_id: 1}
        }}}
    )

    item = Context.Items.init(id, %{rarity: 1, amount: 1})
    Context.Items.bind_if_needed(item, on)
  end

  test "BindOnLoot items bind when looted" do
    bound = bind_item(2, :loot)
    assert bound.is_bound == true
    assert bound.remaining_trades == 0
  end

  test "BindOnLoot items also bind when equipped" do
    assert bind_item(2, :equip).is_bound == true
  end

  test "BindOnEquip items only bind when equipped" do
    assert bind_item(3, :loot).is_bound == false
    assert bind_item(3, :equip).is_bound == true
  end

  test "tradeable items never bind" do
    assert bind_item(0, :loot).is_bound == false
  end
end
