defmodule Ms2ex.ItemBoxTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.{Context, Managers, Repo, Schema}
  alias Ms2ex.GameHandlers.Helper.ItemBox

  @box_id 30_000_999
  @empty_box_id 30_000_998
  @select_box_id 30_000_997
  @drop_box_id 44_000_001
  @empty_drop_box_id 44_000_099
  @select_drop_box_id 44_000_002
  @reward_a 47_900_768
  @reward_b 47_900_769

  defp drop_entry(item_ids, count) do
    %{
      ids: item_ids,
      weight: 100,
      proper_job_weight: 100,
      improper_job_weight: 100,
      drop_count: %{min: count, max: count},
      rarities: [],
      enchant_level: 0,
      announce: false,
      bind: false,
      map_ids: [],
      quest_id: 0
    }
  end

  defp drop_group(items) do
    %{
      group_id: 1,
      smart_drop_rate: 0,
      min_level: 0,
      drop_counts: [%{count: 1, probability: 100}],
      items: items
    }
  end

  defp item_meta(function_name \\ nil, function_parameters \\ nil) do
    %{
      limit: %{level: 0},
      property: %{type: 3, stack_limit: 100},
      slot_names: [],
      option: %{constant_id: 0},
      function_name: function_name,
      function_parameters: function_parameters,
      content: []
    }
  end

  defp reward_meta do
    %{
      limit: %{level: 0},
      property: %{type: 1},
      stack_limit: 100,
      slot_names: [11],
      option: %{constant_id: 0}
    }
  end

  setup do
    stub_metadata(%{
      "item:#{@box_id}" => item_meta("OpenItemBox", "0,0,0,#{@drop_box_id}"),
      "item:#{@empty_box_id}" => item_meta("OpenItemBox", "0,0,0,#{@empty_drop_box_id}"),
      "item:#{@select_box_id}" => item_meta("SelectItemBox", "1,#{@select_drop_box_id}"),
      "item:#{@reward_a}" => reward_meta(),
      "item:#{@reward_b}" => reward_meta(),
      "table:individualdropitem.xml" => %{
        table: %{
          entries: %{
            "#{@drop_box_id}" => %{
              "1" => drop_group([drop_entry([@reward_a, 0], 2)])
            },
            "#{@select_drop_box_id}" => %{
              "1" =>
                drop_group([
                  drop_entry([@reward_a, 0], 1),
                  drop_entry([@reward_b, 0], 1)
                ])
            }
          }
        }
      }
    })

    account =
      Repo.insert!(%Schema.Account{
        username: "box_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Box#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    :ok = Managers.Inventory.start(character)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), :erlang.whereis(:"inventories:#{character.id}"))
    on_exit(fn -> Managers.Inventory.stop(character.id) end)

    %{character: %{character | sender_session_pid: self()}}
  end

  test "opening grants the drop table contents and consumes the box", %{character: character} do
    box = add_box(character, @box_id, 1)

    ItemBox.open(character, character, box, 1, -1)

    # the box is consumed and the rolled reward is in the bag
    refute Managers.Inventory.get(character, box.id)

    reward = find_item(character, @reward_a)
    assert reward.amount == 2

    # the client learns the open succeeded through the ItemBox packet
    assert_received {:push, <<0xAE::little-16, @box_id::little-32, 1::little-32, 2::little-32>>}
  end

  test "a box without drop table content fails and stays in the bag", %{character: character} do
    box = add_box(character, @empty_box_id, 1)

    ItemBox.open(character, character, box, 1, -1)

    assert Managers.Inventory.get(character, box.id)

    assert_received {:push,
                     <<0xAE::little-16, @empty_box_id::little-32, 0::little-32, 3::little-32>>}
  end

  test "multi-open consumes and grants once per box", %{character: character} do
    box = add_box(character, @box_id, 3)

    ItemBox.open(character, character, box, 3, -1)

    refute Managers.Inventory.get(character, box.id)
    reward = find_item(character, @reward_a)
    assert reward.amount == 6

    assert_received {:push, <<0xAE::little-16, @box_id::little-32, 3::little-32, 2::little-32>>}
  end

  test "select boxes grant the picked entry only", %{character: character} do
    box = add_box(character, @select_box_id, 1)

    # index 1 selects the second entry (reward b)
    ItemBox.open(character, character, box, 1, 1)

    refute Managers.Inventory.get(character, box.id)
    assert find_item(character, @reward_b).amount == 1
    refute find_item(character, @reward_a)
  end

  defp add_box(character, item_id, amount) do
    item = Context.Items.init(item_id, %{rarity: 1, amount: amount})
    {:ok, {:create, item}} = Managers.Inventory.add_item(character, item)
    item
  end

  defp find_item(character, item_id) do
    character
    |> Managers.Inventory.list_items()
    |> Enum.find(&(&1.item_id == item_id))
  end
end
