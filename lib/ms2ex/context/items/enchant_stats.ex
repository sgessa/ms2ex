defmodule Ms2ex.Items.EnchantStats do
  alias Ms2ex.{Item, Items, ProtoMetadata}

  def get(%Item{} = item) do
    script =
      case :luaport.spawn(:calc_enchant_values, "priv/scripts/Functions/calcEnchantValues") do
        {:ok, script, _args} -> script
        {:error, {:already_started, script}} -> script
      end

    {:ok, results} =
      :luaport.call(script, String.to_atom("calcEnchantBoostValues"), [
        item.enchant_level,
        Items.Type.value(Items.type(item)),
        item.level
      ])

    results
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn [attr_nr, value], acc ->
      if attr_nr == 0 do
        acc
      else
        attr = ProtoMetadata.Items.StatAttribute.key(attr_nr)
        stat = Items.Stat.build(attr, :value, value, :basic)
        Map.put(acc, attr, stat)
      end
    end)
  end
end
