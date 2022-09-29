defmodule Ms2ex.Items.Stats do
  alias Ms2ex.{Item, Items}

  defstruct constants: %{},
            statics: %{},
            randoms: %{},
            enchants: %{},
            limit_break_enchants: %{}

  def create(%Item{rarity: rarity}) when rarity == 0 or rarity > 6 do
    %__MODULE__{}
  end

  def create(%Item{metadata: meta} = item) do
    option_id = meta.options.id
    lvl_factor = meta.options.level_factor

    constants = Items.ConstantStats.get(item, option_id, lvl_factor)
    statics = Items.StaticStats.get(item, option_id, lvl_factor)
    randoms = Items.RandomStats.get(item)

    enchants = %{}
    if item.enchant_level > 0 do
      # TODO get enchants
      %{}
    else
      %{}
    end

    %__MODULE__{constants: constants, statics: statics, randoms: randoms, enchants: enchants}
  end
end
