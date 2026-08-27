defmodule Ms2ex.EquipsTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # BindOnEquip staff metadata (item 15260310 from the dev seed)
    :ets.insert(
      :metadata,
      {"item:15260310",
       {:ok,
        %{
          limit: %{
            level: 70,
            gender: 2,
            job_recommends: [30],
            transfer_type: 3,
            trade_max_rarity: 4
          },
          property: %{type: 1, ride: 0, tradable_count: 1},
          slot_names: [5, 4],
          option: %{constant_id: 15_260_310, pick_id: 0, static_id: 0, random_id: 0}
        }}}
    )

    :ok
  end

  test "equipping a BindOnEquip item persists the bound state" do
    account = Repo.insert!(%Schema.Account{username: "equip_test", password_hash: "x"})

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "EquipTester",
        job: :knight,
        map_id: 1,
        skin_color: {}
      })

    staff = Context.Items.init(15_260_310, %{rarity: 5, amount: 1})
    {:ok, {:create, item}} = Context.Inventory.add_item(character, staff)
    assert item.is_bound == false

    {:ok, equipped} = Context.Equips.equip(item |> Context.Items.load_metadata(), :RH)
    assert equipped.is_bound == true

    reloaded = Repo.get(Schema.Item, item.id)
    assert reloaded.is_bound == true
    assert reloaded.remaining_trades == 0
    assert reloaded.location == :equipment
  end
end
