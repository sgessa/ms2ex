defmodule Ms2ex.Context.ItemTransfer do
  @moduledoc """
  Item trade-state semantics: transfer flags and character binding.

  Flags are derived from item metadata (transfer type, trade count, rarity
  vs trade-max rarity), mirroring the reference `GetTransferFlag` logic.
  Binding marks an item bound (zeroing remaining trades) when its transfer
  type requires it.
  """

  alias Ms2ex.Enums.TransferType
  alias Ms2ex.Schema
  alias Ms2ex.TransferFlags

  @tradeable TransferType.get_value(:tradeable)
  @untradeable TransferType.get_value(:untradeable)
  @black_market_only TransferType.get_value(:black_market_only)

  @bind_types [
    TransferType.get_value(:bind_on_loot),
    TransferType.get_value(:bind_on_equip),
    TransferType.get_value(:bind_on_use),
    TransferType.get_value(:bind_on_trade),
    TransferType.get_value(:bind_pet)
  ]

  @doc """
  Sets the trade state from item metadata. Items with a tradeable transfer
  type, enough rarity headroom and a non-zero trade count stay tradeable;
  bind-on-loot/equip/use items start bind-flagged.
  """
  @spec apply(Schema.Item.t()) :: Schema.Item.t()
  def apply(%Schema.Item{} = item) do
    tradable_count = get_in(item.metadata, [:property, :tradable_count]) || 0
    trade_max_rarity = get_in(item.metadata, [:limit, :trade_max_rarity]) || 0
    transfer_type = get_in(item.metadata, [:limit, :transfer_type]) || 0
    rarity = item.rarity || 1

    %{
      item
      | transfer_flags: flags(transfer_type, tradable_count <= 0, rarity < trade_max_rarity),
        remaining_trades: max(tradable_count, 0)
    }
  end

  @doc """
  Binds an item to a character when its transfer type requires it and the
  bind flag is set. On-loot binding applies to BindOnLoot items; on-equip
  binding also covers BindOnEquip. The owner is the holding character.
  """
  @spec bind_if_needed(Schema.Item.t(), :loot | :equip) :: Schema.Item.t()
  def bind_if_needed(%Schema.Item{} = item, on \\ :loot) do
    transfer_type = get_in(item.metadata, [:limit, :transfer_type]) || 0

    binds? =
      case on do
        :loot ->
          transfer_type == TransferType.get_value(:bind_on_loot)

        :equip ->
          transfer_type in [
            TransferType.get_value(:bind_on_loot),
            TransferType.get_value(:bind_on_equip)
          ]
      end

    if binds? && bind_flagged?(item) do
      %{item | is_bound: true, remaining_trades: 0}
    else
      item
    end
  end

  @doc "Whether the item carries the bind transfer flag."
  @spec bind_flagged?(Schema.Item.t()) :: boolean()
  def bind_flagged?(%Schema.Item{transfer_flags: flags}),
    do: TransferFlags.has_flag?(flags, :bind)

  @doc """
  Computes the transfer flags for a transfer type given whether the item
  has zero remaining trades and whether its rarity sits below the
  trade-max rarity.
  """
  @spec flags(integer(), boolean(), boolean()) :: integer()
  def flags(transfer_type, zero_trades, below_rarity) do
    case transfer_type do
      @tradeable -> tradable(zero_trades, below_rarity)
      @untradeable -> untradeable(zero_trades)
      @black_market_only -> black_market(zero_trades, below_rarity)
      type when type in @bind_types -> bind(zero_trades, below_rarity)
      _ -> 0
    end
  end

  defp tradable(_zero_trades, true), do: set_flags([:tradeable, :splittable])
  defp tradable(true, false), do: 0
  defp tradable(false, false), do: set_flags([:limit_trade])

  defp untradeable(true), do: 0
  defp untradeable(false), do: set_flags([:limit_trade])

  defp black_market(_zero_trades, true), do: set_flags([:tradeable])
  defp black_market(true, false), do: 0
  defp black_market(false, false), do: set_flags([:tradeable])

  defp bind(true, true), do: set_flags([:bind, :tradeable, :splittable])
  defp bind(true, false), do: set_flags([:bind])
  defp bind(false, _), do: set_flags([:bind, :limit_trade])

  defp set_flags(flags), do: TransferFlags.set(flags) || 0
end
