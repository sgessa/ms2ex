defmodule Ms2ex.Managers.Quest.Rewards do
  @moduledoc """
  Quest reward helpers.

  Reward delivery is split so callers can make quest completion and item
  grants atomic:

    * `prepare/2` resolves and filters a reward document into grantable items
      (no writes)
    * `grant_items/2` performs the inventory writes; call it inside the
      caller's transaction so a failure rolls back the quest state change
    * `deliver/3` fires the post-commit effects (experience, currency
      updates and inventory packets)
  """

  alias Ms2ex.Managers.Inventory
  alias Ms2ex.Context.Items
  alias Ms2ex.Context.Wallets
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @doc """
  Resolves a reward document into grantable items: zero-filled entries and
  items without projected metadata are dropped, job-gated items are matched
  against the character's job. Performs no writes.
  """
  def prepare(character, reward) do
    job_items = filter_job_items(reward.essential_job_items, character)
    items = Enum.filter(reward.essential_items ++ job_items, &grantable?/1)

    %{items: items}
  end

  @doc """
  Inserts the prepared items into the character's inventory. Must run inside
  a `Repo.transaction` so a failing grant rolls back the surrounding quest
  state change. Returns `{:ok, inventory results}` for post-commit delivery.
  """
  def grant_items(character, %{items: items}) do
    results =
      Enum.map(items, fn reward_item ->
        metadata = Storage.Items.get_meta(reward_item.id)

        item =
          Items.init(reward_item.id, %{amount: reward_item.amount, rarity: reward_item.rarity})

        case Inventory.add_item(character, %{item | metadata: metadata}) do
          {:ok, result} ->
            # the bare add result ({:create, item} / {:update, item}) is what
            # post-commit delivery serializes into add-item packets
            Managers.Quest.notify_item_acquired(character, added_item(result))
            result

          other ->
            Repo.rollback({:reward_item_failed, reward_item.id, other})
        end
      end)

    {:ok, results}
  end

  @doc """
  Post-commit delivery: experience through the character manager (it owns the
  live exp/level state), currency wallet updates, and the inventory packets
  for the granted items.
  """
  def deliver(character, reward, results) do
    grant_exp(character, reward.exp)
    grant_currencies(character, reward)
    Enum.each(results, &maybe_push_inventory_result(character, &1))

    :ok
  end

  defp grant_exp(_character, exp) when exp <= 0, do: :ok
  defp grant_exp(character, exp), do: Managers.Character.cast(character.id, {:earn_exp, exp})

  defp grant_currencies(character, reward) do
    maybe_add_currency(character, :mesos, reward.meso)
    maybe_add_currency(character, :trevas, reward.treva)
    maybe_add_currency(character, :rues, reward.rue)
  end

  defp maybe_add_currency(_character, _currency, amount) when amount <= 0, do: :ok

  defp maybe_add_currency(character, currency, amount),
    do: Wallets.update(character, currency, amount)

  defp maybe_push_inventory_result(%{session_pid: nil}, _result), do: :ok

  defp maybe_push_inventory_result(character, {_status, inventory_item} = result) do
    push(character, Packets.InventoryItem.add_item(result, character))
    push(character, Packets.InventoryItem.mark_item_new(inventory_item))
  end

  defp grantable?(%{id: id}) when id <= 0, do: false

  defp grantable?(%{id: id}) do
    case Storage.Items.get_meta(id) do
      nil -> false
      _metadata -> true
    end
  end

  defp grantable?(_reward_item), do: false

  defp filter_job_items([], _character), do: []

  defp filter_job_items(items, character) do
    job_id = Enums.Job.get_value(character.job)

    Enum.filter(items, fn reward_item ->
      case Storage.Items.get_meta(reward_item.id) do
        %{limit: %{job_recommends: []}} ->
          true

        %{limit: %{job_recommends: recommends}} ->
          Enum.member?(recommends, 0) or Enum.member?(recommends, job_id)

        # zero-filled / unresolvable reward entries are not grantable
        _ ->
          false
      end
    end)
  end

  # the created or updated stack an add result carries (the update_and_create
  # split carries the created overflow stack last)
  defp added_item(result), do: elem(result, tuple_size(result) - 1)
end
