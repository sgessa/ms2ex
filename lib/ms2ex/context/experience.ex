defmodule Ms2ex.Context.Experience do
  alias Ms2ex.{Context, ProtoMetadata.ExpTable, Schema}

  @max_level Schema.Character.max_level()
  def maybe_add_exp(%Schema.Character{level: lvl} = char, _exp) when lvl >= @max_level do
    {:ok, char}
  end

  def maybe_add_exp(%Schema.Character{level: level, exp: current_exp} = character, exp_gained) do
    {:ok, tnl} = ExpTable.to_next_level(level)
    total_exp = current_exp + exp_gained

    if total_exp >= tnl do
      diff = total_exp - tnl
      {:ok, character} = Context.Characters.update(character, %{level: level + 1, exp: 0})
      maybe_add_exp(character, diff)
    else
      Context.Characters.update(character, %{exp: total_exp})
    end
  end
end
