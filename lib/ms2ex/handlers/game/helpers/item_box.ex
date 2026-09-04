defmodule Ms2ex.GameHandlers.Helper.ItemBox do
  @moduledoc """
  Item box opening: resolves the box's function parameters against the
  server drop tables, rolls the contents for the opening character, grants
  them, and consumes the box (plus any key items) per open.

  Mirrors the reference ItemBoxManager: OpenItemBox (drop tables plus an
  optional direct item), SelectItemBox (player picks an entry by index
  from one drop group) and OpenItemBoxWithKey (consumes key items). The
  reference mails rewards that do not fit the inventory; there is no mail
  system yet, so a failed grant stops the open with the inventory-full
  error and leaves the remaining boxes unopened.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  import Ms2ex.Net.SenderSession, only: [push: 2]

  # function parameter layouts (reference ItemBoxManager.Open)
  #   OpenItemBox:        globalDropBoxId, unknownId, itemId, dropBoxId, requiredAmount?
  #   SelectItemBox:      dropGroupId, dropBoxId
  #   OpenItemBoxWithKey: keyItemId, keyAmount, itemId, _, _, dropBoxId
  @type_param_positions %{
    "OpenItemBox" => %{global_box: 0, item_id: 2, box_id: 3, required_amount: 4},
    "SelectItemBox" => %{group: 0, box_id: 1},
    "OpenItemBoxWithKey" => %{key_item_id: 0, key_amount: 1, item_id: 2, box_id: 5}
  }

  @error_ok 2
  @error_inventory_fail 3
  @error_inventory_full 4

  @doc """
  Opens `count` copies of the box, pushing an `ItemBox.Open` response with
  the number of successful opens and the resulting error code.
  """
  def open(session, character, %Schema.Item{} = item, count, index)
      when is_integer(count) and count > 0 do
    type = item.metadata.function_name
    positions = Map.get(@type_param_positions, type)
    params = parse_params(item.metadata.function_parameters)

    {error, box_count, session} =
      open_box(session, character, item, type, params, positions, count, index)

    push(session, Packets.ItemBox.open(item.item_id, box_count, error))
  end

  def open(session, _character, _item, _count, _index), do: session

  # an unknown function type cannot be opened
  defp open_box(_session, _character, _item, _type, _params, nil, _count, _index),
    do: {@error_inventory_fail, 0, nil}

  # the player picks an entry by index from the box's drop group; each open
  # grants the picked entry and consumes one box
  defp open_box(session, character, item, "SelectItemBox", params, positions, count, index) do
    if index < 0 do
      {@error_inventory_fail, 0, session}
    else
      group = param(params, positions.group, -1)
      box_id = param(params, positions.box_id, 0)

      iterate(session, count, fn ->
        open_select(session, character, item, box_id, group, index)
      end)
    end
  end

  # each open consumes the key items alongside the box
  defp open_box(session, character, item, "OpenItemBoxWithKey", params, positions, count, _index) do
    key_item_id = param(params, positions.key_item_id, 0)
    key_amount = param(params, positions.key_amount, 1)

    cond do
      key_item_id == 0 ->
        {@error_inventory_fail, 0, session}

      not owns_amount?(character, key_item_id, key_amount * count) ->
        {@error_inventory_fail, 0, session}

      true ->
        key_box = fn ->
          open_with_key(session, character, item, params, positions, key_item_id, key_amount)
        end

        iterate(session, count, key_box)
    end
  end

  # requiredAmount gates how many boxes one open consumes (default 1)
  defp open_box(session, character, item, "OpenItemBox", params, positions, count, _index) do
    required_amount = param(params, positions.required_amount, 1)

    box_id = param(params, positions.box_id, 0)

    cond do
      required_amount > -1 and
          not owns_amount?(character, item.item_id, max(required_amount, 1) * count) ->
        {@error_inventory_fail, 0, session}

      box_id > 0 and not Ms2ex.Storage.Tables.IndividualDropItem.has_entries?(box_id) ->
        {@error_inventory_fail, 0, session}

      true ->
        open_plain_boxes(
          session,
          character,
          item,
          params,
          positions,
          count,
          required_amount,
          box_id
        )
    end
  end

  defp open_box(session, _character, _item, _type, _params, _positions, _count, _index),
    do: {@error_inventory_fail, 0, session}

  # runs `count` opens; the fun performs one open and returns :ok |
  # {:error, code}; the first failure stops the remaining opens
  defp iterate(session, count, fun) do
    Enum.reduce_while(1..count, {@error_ok, 0, session}, fn _open, {_error, box_count, session} ->
      case fun.() do
        :ok ->
          {:cont, {@error_ok, box_count + 1, session}}

        {:error, code} ->
          {:halt, {code, box_count, session}}
      end
    end)
  end

  # ---- grants: each returns :ok | {:error, code} ----

  defp open_key_boxes(session, character, item, params, positions, count, key_item_id, key_amount) do
    iterate(session, count, fn ->
      open_with_key(session, character, item, params, positions, key_item_id, key_amount)
    end)
  end

  defp open_plain_boxes(
         session,
         character,
         item,
         params,
         positions,
         count,
         required_amount,
         box_id
       ) do
    iterate(session, count, fn ->
      open_plain(session, character, item, params, positions, required_amount, box_id)
    end)
  end

  # one open of each box type; every step returns :ok | {:error, code} and
  # a failed step short-circuits the with, stopping the remaining opens

  defp open_select(session, character, item, box_id, group, index) do
    with :ok <- grant_select(session, character, box_id, group, index) do
      consume(session, character, item, 1)
    end
  end

  defp open_with_key(session, character, item, params, positions, key_item_id, key_amount) do
    with :ok <- consume_key(session, character, key_item_id, key_amount),
         :ok <- grant_direct_item(session, character, param(params, positions.item_id, 0)),
         :ok <- grant_box(session, character, param(params, positions.box_id, 0)) do
      consume(session, character, item, 1)
    end
  end

  defp open_plain(session, character, item, params, positions, required_amount, box_id) do
    with :ok <- consume(session, character, item, max(required_amount, 1)),
         :ok <- grant_direct_item(session, character, param(params, positions.item_id, 0)),
         :ok <- grant_global(session, character, param(params, positions.global_box, 0)) do
      grant_box(session, character, box_id)
    end
  end

  # rolls one open of the individual drop box and grants every rolled item;
  # a box without drop groups cannot be opened
  defp grant_box(session, character, box_id) when box_id > 0 do
    if Ms2ex.Storage.Tables.IndividualDropItem.has_entries?(box_id) do
      box_id
      |> Context.Drops.individual_items(character, character.map_id)
      |> grant_items(session, character)
    else
      {:error, @error_inventory_fail}
    end
  end

  defp grant_box(_session, _character, _box_id), do: :ok

  defp grant_global(session, character, global_box_id) when global_box_id > 0 do
    global_box_id
    |> Context.Drops.global_items(character.level, character.map_id)
    |> grant_items(session, character)
  end

  defp grant_global(_session, _character, _global_box_id), do: :ok

  # select boxes: the picked ordinal is granted without requirement filters
  defp grant_select(session, character, box_id, group, index) do
    box_id
    |> Context.Drops.individual_items(character, character.map_id, index: index, group: group)
    |> grant_items(session, character)
  end

  defp grant_direct_item(session, character, item_id) when item_id > 0 do
    case Context.Items.drop_item(item_id, 1, 1) do
      %Schema.Item{} = item -> grant_items(session, character, [item])
      nil -> {:error, @error_inventory_fail}
    end
  end

  defp grant_direct_item(_session, _character, _item_id), do: :ok

  defp grant_items(items, session, character) do
    Enum.reduce_while(items, :ok, fn item, acc ->
      case add_item(session, character, item) do
        :ok -> {:cont, acc}
        {:error, _code} = error -> {:halt, error}
      end
    end)
  end

  # currency drops become wallet or experience updates instead of items
  defp add_item(session, character, %Schema.Item{item_id: item_id, amount: amount} = item) do
    cond do
      exp_orb?(item_id) ->
        Managers.Character.cast(character, {:earn_exp, amount})
        :ok

      currency_type(item_id) ->
        add_currency(session, character, currency_type(item_id), amount)

      true ->
        case Managers.Inventory.add_item(character, item) do
          {:ok, result} ->
            push(session, Packets.InventoryItem.add_item(result, character))
            Managers.Quest.notify_item_acquired(character, added_item(result))
            :ok

          _ ->
            {:error, @error_inventory_full}
        end
    end
  end

  defp add_currency(_session, character, currency, amount) do
    case Context.Wallets.update(character, currency, amount) do
      {:ok, _wallet} -> :ok
      _ -> {:error, @error_inventory_fail}
    end
  end

  # the created or updated stack an add result carries (the update_and_create
  # split carries the created overflow stack last)
  defp added_item(result), do: elem(result, tuple_size(result) - 1)

  # ---- consumption: returns :ok | {:error, code} ----

  defp consume(session, _character, item, amount) do
    case Managers.Inventory.consume(item, amount) do
      {:update, _item} = consumed ->
        push(session, Packets.InventoryItem.consume(consumed))
        :ok

      {:delete, _item} = consumed ->
        push(session, Packets.InventoryItem.consume(consumed))
        :ok

      _ ->
        {:error, @error_inventory_fail}
    end
  end

  defp consume_key(session, character, key_item_id, key_amount) do
    case find_carried(character, key_item_id) do
      %Schema.Item{} = key_item -> consume(session, character, key_item, key_amount)
      nil -> {:error, @error_inventory_fail}
    end
  end

  defp owns_amount?(character, item_id, amount) do
    case find_carried(character, item_id) do
      %Schema.Item{amount: owned} -> owned >= amount
      nil -> false
    end
  end

  defp find_carried(character, item_id) do
    character
    |> Managers.Inventory.list_items()
    |> Enum.find(&(&1.item_id == item_id))
  end

  # ---- function parameters ----

  defp parse_params(nil), do: []

  defp parse_params(parameters) when is_binary(parameters) do
    parameters
    |> String.split(",")
    |> Enum.map(fn param ->
      case Integer.parse(String.trim(param)) do
        {value, ""} -> value
        _ -> 0
      end
    end)
  end

  defp param(params, position, default) when position != nil do
    Enum.at(params, position, default)
  end

  defp param(_params, nil, default), do: default

  # ---- currency drops (reference InventoryManager.AddCurrency) ----

  @currency_types %{
    90_000_001 => :mesos,
    90_000_002 => :mesos,
    90_000_003 => :mesos,
    90_000_004 => :merets,
    90_000_006 => :valor_tokens,
    90_000_013 => :rues,
    90_000_014 => :havi_fruits,
    90_000_016 => :merets,
    90_000_017 => :trevas,
    90_000_020 => :merets
  }

  defp exp_orb?(90_000_008), do: true
  defp exp_orb?(_), do: false

  defp currency_type(item_id), do: Map.get(@currency_types, item_id)

  # TODO spirit (90000009) and stamina (90000010) orbs need stat updates
end
