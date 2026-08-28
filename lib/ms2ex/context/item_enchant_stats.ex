defmodule Ms2ex.Context.ItemEnchantStats do
  alias Ms2ex.Enums
  alias Ms2ex.Lua.ItemEnchant
  alias Ms2ex.Schema
  alias Ms2ex.Types

  def get(%Schema.Item{} = item) do
    item
    |> ItemEnchant.get_values()
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn [attr_nr, value], acc ->
      if attr_nr == 0 do
        acc
      else
        attr = Enums.BasicStatType.get_key(attr_nr)
        stat = Types.ItemStat.build(attr, :flat, value, :basic)
        Map.put(acc, attr, stat)
      end
    end)
  end
end
