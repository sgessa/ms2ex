defmodule Ms2ex.Context.Items do
  import Bitwise

  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @spec init(integer(), map()) :: Schema.Item.t()
  def init(id, attrs \\ %{}) do
    %Schema.Item{} = item = struct(Schema.Item, Map.merge(%{item_id: id}, attrs))

    item
    |> load_metadata()
    |> set_stats()
    |> set_level()
    |> set_transfer()
  end

  @doc """
  Builds a field-drop item from a drop table entry. Rolls rarity from the
  caller when present; a non-positive rarity falls back to the item's
  constant option, else rank 1. Returns `nil` when the item has no metadata.
  """
  @spec drop_item(integer(), integer(), integer()) :: Schema.Item.t() | nil
  def drop_item(item_id, rarity, amount) do
    case Storage.get(:item, item_id) do
      %{slot_names: _} = metadata ->
        init(item_id, %{rarity: resolve_rarity(rarity, metadata), amount: amount})

      _ ->
        nil
    end
  end

  defp resolve_rarity(rarity, _metadata) when rarity > 0, do: rarity

  defp resolve_rarity(_, %{option: %{constant_id: constant}}) when constant in 1..6,
    do: constant

  defp resolve_rarity(_, _), do: 1

  @spec set_level(Schema.Item.t()) :: Schema.Item.t()
  def set_level(%Schema.Item{metadata: metadata} = item) do
    %{item | level: metadata.limit.level}
  end

  @spec set_stats(Schema.Item.t()) :: Schema.Item.t()
  def set_stats(%Schema.Item{} = item) do
    %{item | stats: Types.ItemStats.create(item)}
  end

  @transfer_trade 4
  @transfer_split 2
  @transfer_bind 8
  @transfer_limit_trade 16

  # Sets the trade state from item metadata. Items with a tradeable transfer
  # type, enough rarity headroom and a non-zero trade count stay tradeable;
  # bind-on-loot/equip/use items start bind-flagged.
  defp set_transfer(%Schema.Item{metadata: metadata} = item) do
    tradable_count = get_in(metadata, [:property, :tradable_count]) || 0
    trade_max_rarity = get_in(metadata, [:limit, :trade_max_rarity]) || 0
    transfer_type = get_in(metadata, [:limit, :transfer_type]) || 0
    rarity = item.rarity || 1

    zero_trades = tradable_count <= 0
    below_rarity = rarity < trade_max_rarity

    %{
      item
      | transfer_flags: transfer_flags(transfer_type, zero_trades, below_rarity),
        remaining_trades: max(tradable_count, 0)
    }
  end

  defp transfer_flags(0, zero_trades, below_rarity), do: tradable_flags(zero_trades, below_rarity)
  defp transfer_flags(1, zero_trades, _), do: untradeable_flags(zero_trades)

  defp transfer_flags(6, zero_trades, below_rarity),
    do: black_market_flags(zero_trades, below_rarity)

  defp transfer_flags(type, zero_trades, below_rarity) when type in [2, 3, 4, 5, 7],
    do: bind_flags(zero_trades, below_rarity)

  defp transfer_flags(_, _, _), do: 0

  defp tradable_flags(_zero_trades, true), do: @transfer_trade ||| @transfer_split
  defp tradable_flags(true, false), do: 0
  defp tradable_flags(false, false), do: @transfer_limit_trade

  defp untradeable_flags(true), do: 0
  defp untradeable_flags(false), do: @transfer_limit_trade

  defp black_market_flags(_zero_trades, true), do: @transfer_trade
  defp black_market_flags(true, false), do: 0
  defp black_market_flags(false, false), do: @transfer_trade

  defp bind_flags(true, true), do: @transfer_bind ||| @transfer_trade ||| @transfer_split
  defp bind_flags(true, false), do: @transfer_bind
  defp bind_flags(false, _), do: @transfer_bind ||| @transfer_limit_trade

  @meso_ids [90_000_001, 90_000_002, 90_000_003]
  def mesos?(%Schema.Item{item_id: id}) when id in @meso_ids, do: true
  def mesos?(%Schema.Item{}), do: false
  def mesos(amount), do: init(List.first(@meso_ids), %{amount: amount})

  @meret_ids [90_000_004, 90_000_011, 90_000_015, 90_000_016]
  def merets?(%Schema.Item{item_id: id}) when id in @meret_ids, do: true
  def merets?(%Schema.Item{}), do: false
  def merets(amount), do: init(List.first(@meret_ids), %{amount: amount})

  @valor_token_id 90_000_006
  def valor_token?(%Schema.Item{item_id: @valor_token_id}), do: true
  def valor_token?(%Schema.Item{}), do: false
  def valor_token(amount), do: init(@valor_token_id, %{amount: amount})

  @rue_id 90_000_013
  def rue?(%Schema.Item{item_id: @rue_id}), do: true
  def rue?(%Schema.Item{}), do: false
  def rue(amount), do: init(@rue_id, %{amount: amount})

  @havi_fruit_id 90_000_014
  def havi_fruit?(%Schema.Item{item_id: @havi_fruit_id}), do: true
  def havi_fruit?(%Schema.Item{}), do: false
  def havi_fruit(amount), do: init(@havi_fruit_id, %{amount: amount})

  @sp_id 90_000_009
  def sp?(%Schema.Item{item_id: @sp_id}), do: true
  def sp?(%Schema.Item{}), do: false
  def sp(amount), do: init(@sp_id, %{amount: amount})

  @stamina_id 90_000_010
  def stamina?(%Schema.Item{item_id: @stamina_id}), do: true
  def stamina?(%Schema.Item{}), do: false
  def stamina(amount), do: init(@stamina_id, %{amount: amount})

  @accessory_slots [:FH, :EA, :PD, :BE, :RI]
  def accessory?(%Schema.Item{} = item) do
    Enum.any?(item.metadata.slots, &(&1 in @accessory_slots))
  end

  @armor_slots [:CP, :CL, :GL, :SH, :MT]
  def armor?(%Schema.Item{} = item) do
    Enum.any?(item.metadata.slots, &(&1 in @armor_slots))
  end

  @weapon_slots [:LH, :RH, :OH]
  def weapon?(%Schema.Item{} = item) do
    Enum.any?(item.metadata.slots, &(&1 in @weapon_slots))
  end

  @spec load_metadata(Schema.Item.t()) :: Schema.Item.t()
  def load_metadata(%Schema.Item{item_id: id} = item) do
    %{item | metadata: Storage.Items.get_meta(id)}
  end
end
