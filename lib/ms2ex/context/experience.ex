defmodule Ms2ex.Experience do
  alias Ms2ex.{Character, Characters, Metadata.ExpTable}

  @max_level Character.max_level()
  def maybe_add_exp(%Character{level: lvl} = char, _exp) when lvl >= @max_level do
    {:ok, char}
  end

  def maybe_add_exp(%Character{level: level, exp: current_exp} = character, exp_gained) do
    {:ok, tnl} = ExpTable.to_next_level(level)
    total_exp = current_exp + exp_gained

    if total_exp >= tnl do
      diff = total_exp - tnl
      {:ok, character} = Characters.update(character, %{level: level + 1, exp: 0})
      maybe_add_exp(character, diff)
    else
      Characters.update(character, %{exp: total_exp})
    end
  end
end
