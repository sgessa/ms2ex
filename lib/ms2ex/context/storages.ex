defmodule Ms2ex.Context.Storages do
  @moduledoc """
  Persists the per-account bank storage: stored mesos and slot expansion
  (`Schema.AccountStorage`) and its item rows. Storage items live in
  `inventory_items` owned by the account (`character_id` nil, `account_id`
  set), so they never collide with character inventory queries.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ecto.Query, except: [update: 2]

  @item_fields [
    :account_id,
    :item_id,
    :amount,
    :color,
    :data,
    :equip_slot,
    :enchant_level,
    :gacha_dismantle_id,
    :inventory_slot,
    :inventory_tab,
    :is_bound,
    :is_locked,
    :limit_break_level,
    :location,
    :rarity,
    :remaining_trades,
    :stats,
    :transfer_flags,
    :ugc,
    :unlocks_at
  ]

  def get_info(account_id) do
    Repo.get(Schema.AccountStorage, account_id)
  end

  def create_info(account_id) do
    %Schema.AccountStorage{account_id: account_id}
    |> Repo.insert()
  end

  def save_info(%Schema.AccountStorage{} = storage) do
    storage
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.force_change(:mesos, storage.mesos)
    |> Ecto.Changeset.force_change(:expand, storage.expand)
    |> Repo.update()
  end

  def list_items(account_id) do
    Schema.Item
    |> where([i], i.account_id == ^account_id)
    |> order_by([i], i.inventory_slot)
    |> Repo.all()
  end

  def create_item(%Schema.Item{} = item) do
    item
    |> Schema.Item.changeset(Map.take(Map.from_struct(item), @item_fields))
    |> Repo.insert()
  end

  def delete_item(%Schema.Item{} = item), do: Repo.delete(item)

  def update_item_slot(item_id, slot) do
    Schema.Item
    |> where([i], i.id == ^item_id)
    |> Repo.update_all(set: [inventory_slot: slot])

    :ok
  end

  def update_amount(item_id, delta) do
    Schema.Item
    |> where([i], i.id == ^item_id)
    |> Repo.update_all(inc: [amount: delta])

    :ok
  end
end
