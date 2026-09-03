defmodule Ms2ex.Context.ItemEnchantStats do
  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Formulas.ItemEnchant
  alias Ms2ex.Schema
  alias Ms2ex.Types

  def get(%Schema.Item{} = item) do
    ItemEnchant.values(item.enchant_level, item_type(item), item.metadata.limit.level)
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn [attr_nr, value], acc ->
      if attr_nr == 0 do
        acc
      else
        attr = Enums.BasicStatType.get_key(attr_nr)
        stat = Types.ItemStat.build(attr, :rate, value, :basic)
        Map.put(acc, attr, stat)
      end
    end)
  end

  defp item_type(item),
    do:
      item.item_id
      |> Context.ItemTypes.get_type_by_item_id()
      |> Enums.ItemType.get_value()
end
