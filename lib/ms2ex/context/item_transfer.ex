defmodule Ms2ex.Context.ItemTransfer do
  @moduledoc """
  Item trade-state semantics: transfer flags and character binding.

  Contexts only deal with atoms: transfer types are `Enums.TransferType`
  keys (`:tradeable`, `:bind_on_loot`, ...) and transfer flags are lists of
  flag atoms (`[:trade, :split]`, `[:bind, :limit_trade]`, ...). The
  integer bitmask is a storage/packet concern handled by
  `Ms2ex.TransferFlags` and `Ms2ex.EctoTypes.TransferFlags`.

  Flags are derived from item metadata (transfer type, trade count, rarity
  vs trade-max rarity), mirroring the reference `GetTransferFlag` logic.
  Binding marks an item bound (zeroing remaining trades) when its transfer
  type requires it.
  """

  alias Ms2ex.Schema

  @bind_types [:bind_on_loot, :bind_on_equip, :bind_on_use, :bind_on_trade, :bind_pet]

  @doc """
  Sets the trade state from item metadata. Items with a tradeable transfer
  type, enough rarity headroom and a non-zero trade count stay tradeable;
  bind-on-loot/equip/use items start bind-flagged. Explicitly provided
  flags (e.g. from commands) are preserved.
  """
  @spec apply(Schema.Item.t()) :: Schema.Item.t()
  def apply(%Schema.Item{} = item) do
    tradable_count = get_in(item.metadata, [:property, :tradable_count]) || 0
    trade_max_rarity = get_in(item.metadata, [:limit, :trade_max_rarity]) || 0
    transfer_type = get_in(item.metadata, [:limit, :transfer_type]) || :tradeable
    rarity = item.rarity || 1

    %{
      item
      | transfer_flags:
          if(item.transfer_flags == [],
            do: flags(transfer_type, tradable_count <= 0, rarity < trade_max_rarity),
            else: item.transfer_flags
          ),
        remaining_trades: max(tradable_count, 0)
    }
  end

  @doc """
  Computes the transfer flags for a transfer type given whether the item
  has zero remaining trades and whether its rarity sits below the
  trade-max rarity.
  """
  @spec flags(atom(), boolean(), boolean()) :: [atom()]
  def flags(transfer_type, zero_trades, below_rarity) do
    case transfer_type do
      :tradeable -> tradable(zero_trades, below_rarity)
      :untradeable -> untradeable(zero_trades)
      :black_market_only -> black_market(zero_trades, below_rarity)
      type when type in @bind_types -> bind(zero_trades, below_rarity)
      _ -> []
    end
  end

  defp tradable(_zero_trades, true), do: [:trade, :split]
  defp tradable(true, false), do: []
  defp tradable(false, false), do: [:limit_trade]

  defp untradeable(true), do: []
  defp untradeable(false), do: [:limit_trade]

  defp black_market(_zero_trades, true), do: [:trade]
  defp black_market(true, false), do: []
  defp black_market(false, false), do: [:trade]

  defp bind(true, true), do: [:bind, :trade, :split]
  defp bind(true, false), do: [:bind]
  defp bind(false, _), do: [:bind, :limit_trade]
end
