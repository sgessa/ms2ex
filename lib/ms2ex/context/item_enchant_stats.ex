defmodule Ms2ex.Context.ItemEnchantStats do
  alias Ms2ex.{Enums, Lua, Schema, Types}

  def get(%Schema.Item{} = item) do
    item
    |> Lua.Items.get_enchant_values()
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
end
