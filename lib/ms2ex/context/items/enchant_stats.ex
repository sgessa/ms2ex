defmodule Ms2ex.Items.EnchantStats do
  alias Ms2ex.{Item, Items, Enums}

  def get(%Item{} = item) do
    Items.Lua.get_enchant_values(item)
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn [attr_nr, value], acc ->
      if attr_nr == 0 do
        acc
      else
        attr = Enums.BasicStatType.get_key(attr_nr)
        stat = Items.Stat.build(attr, :rate, value, :basic)
        Map.put(acc, attr, stat)
      end
    end)
  end
end
