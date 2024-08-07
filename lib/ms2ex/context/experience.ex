defmodule Ms2ex.Context.Experience do
  alias Ms2ex.{Context, ProtoMetadata.ExpTable, Schema, Constants}

  def maybe_add_exp(%Schema.Character{level: level, exp: current_exp} = character, exp_gained) do
    if level >= Constants.get(:character_max_level) do
      {:ok, character}
    else
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
end
