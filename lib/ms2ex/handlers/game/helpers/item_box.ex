defmodule Ms2ex.GameHandlers.Helper.ItemBox do
  alias Ms2ex.{Context, Inventory, Packets, Schema, Wallets}

  import Ms2ex.Net.SenderSession, only: [push: 2]

  def open(session, _character, []), do: session

  def open(session, character, contents) do
    drop_groups = contents |> Enum.map(& &1.drop_group) |> Enum.uniq()
    one_group? = if length(drop_groups) == 1, do: true, else: false

    if one_group? do
      handle_one_group(session, character, contents)
    else
      Enum.reduce(contents, session, fn content, session ->
        %{metadata: %{jobs: jobs}} =
          Context.Items.load_metadata(%Schema.Item{item_id: content.id})

        if character.job in jobs or :none in jobs do
          add_item(session, character, content)
        else
          session
        end
      end)
    end
  end

  defp handle_one_group(session, character, [%{smart_drop_rate: smart_drop_rate} | _] = contents) do
    handle_smart_drop_rate(session, smart_drop_rate, character, contents)
  end

  defp handle_smart_drop_rate(session, 0, character, contents) do
    content = Enum.random(contents)
    add_item(session, character, content)
  end

  defp handle_smart_drop_rate(session, 100, character, contents) do
    Enum.reduce(contents, session, fn content, session ->
      %{metadata: %{jobs: jobs}} = Context.Items.load_metadata(%Schema.Item{item_id: content.id})

      if character.job in jobs or :none in jobs do
        add_item(session, character, content)
      else
        session
      end
    end)
  end

  defp handle_smart_drop_rate(session, smart_drop_rate, character, contents) do
    success = Enum.random(0..100) > smart_drop_rate

    contents =
      Enum.filter(contents, fn content ->
        %{metadata: %{jobs: jobs}} =
          Context.Items.load_metadata(%Schema.Item{item_id: content.id})

        if success do
          character.job in jobs or :none in jobs
        else
          character.job not in jobs or :none in jobs
        end
      end)

    content = Enum.random(contents)
    add_item(session, character, content)
  end

  def add_item(session, _character, nil), do: session

  def add_item(session, character, content) do
    session
    |> process_item(character, content.id, content)
    |> process_item(character, content.id2, content)
  end

  defp process_item(session, character, id, content) when id != 0 do
    if currency?(id) do
      handle_currency(session, character, id, content)
    else
      handle_items(session, character, id, content)
    end
  end

  defp process_item(session, _character, _id, _content), do: session

  @currency_id_prefix "9"
  defp currency?(id) do
    id
    |> to_string()
    |> String.starts_with?(@currency_id_prefix)
  end

  defp handle_currency(session, character, id, content) do
    cond do
      merets?(id) -> add_currency(session, character, :merets, content)
      mesos?(id) -> add_currency(session, character, :mesos, content)
      true -> session
    end
  end

  @merets_ids [90_000_004, 90_000_011, 90_000_011, 90_000_015, 90_000_016]
  defp merets?(id), do: Enum.member?(@merets_ids, id)

  @mesos_id 90_000_011
  defp mesos?(id), do: id == @mesos_id

  defp add_currency(session, character, currency, content) do
    amount = Enum.random(content.min_amount..content.max_amount)

    case Wallets.update(character, currency, amount) do
      {:ok, wallet} ->
        push(session, Packets.Wallet.update(wallet, currency))

      _ ->
        session
    end
  end

  defp handle_items(session, character, id, content) do
    amount = Enum.random(content.min_amount..content.max_amount)
    rarity = content.rarity
    enchant_lvl = content.enchant_level

    item = %Schema.Item{item_id: id, rarity: rarity, amount: amount, enchant_level: enchant_lvl}
    item = Context.Items.load_metadata(item)

    case Inventory.add_item(character, item) do
      {:ok, result} -> push(session, Packets.InventoryItem.add_item(result))
      _ -> session
    end
  end
end
