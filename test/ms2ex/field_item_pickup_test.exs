defmodule Ms2ex.FieldItemPickupTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field.Item
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @object_id 7
  @item_id 4_000_001

  setup do
    stub_metadata(%{
      "item:#{@item_id}" => %{
        limit: %{level: 10, transfer_type: 3},
        property: %{type: 1},
        slot_names: [5],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    character = insert_character()

    # pickup writes go through the character's inventory manager
    :ok = Managers.Inventory.start(character)

    Ecto.Adapters.SQL.Sandbox.allow(
      Ms2ex.Repo,
      self(),
      :erlang.whereis(:"inventories:#{character.id}")
    )

    on_exit(fn -> Managers.Inventory.stop(character.id) end)

    # the removal packets are broadcast on the field topic
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "field:1:channel:1")

    state = %{
      topic: :"field:1:channel:1",
      items: %{@object_id => field_item()}
    }

    %{character: character, state: state}
  end

  test "picking up a field item removes it by its object id", %{
    character: character,
    state: state
  } do
    state = Item.pickup_item(character, field_item(), state)

    # the field item is gone from the field state
    assert state.items == %{}

    # the removal packets name the real object id, not the fresh inventory row
    assert_received {:push, <<0x2D::little-16, 1::8, @object_id::little-32, _::binary>>}
    assert_received {:push, <<0x2C::little-16, @object_id::little-32>>}
  end

  defp field_item do
    %Schema.Item{
      object_id: @object_id,
      item_id: @item_id,
      amount: 1,
      rarity: 1,
      stats: %Types.ItemStats{}
    }
  end

  defp insert_character do
    account =
      Repo.insert!(%Schema.Account{
        username: "pickup_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Pickup#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    stats = Repo.insert!(%Schema.CharacterStats{character_id: character.id})
    %{character | stats: stats, sender_session_pid: self()}
  end
end
