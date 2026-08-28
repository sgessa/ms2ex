defmodule Ms2ex.Lua.ItemEnchant do
  alias Ms2ex.Context
  alias Ms2ex.Enums

  def get_values(item) do
    script = get_script("calcEnchantValues")

    {:ok, results} =
      :luaport.call(script, :calcEnchantBoostValues, [
        item.enchant_level,
        item_type(item),
        item.metadata.limit.level
      ])

    results
  end

  defp get_script(script_name) do
    path = Path.join(["priv", "scripts", "Functions", script_name])
    script_id = script_name |> Macro.underscore() |> String.to_atom()

    case :luaport.spawn(script_id, path) do
      {:ok, script, _args} -> script
      {:error, {:already_started, script}} -> script
    end
  end

  defp item_type(item) do
    item.item_id
    |> Context.ItemTypes.get_type_by_item_id()
    |> Enums.ItemType.get_value()
  end
end
