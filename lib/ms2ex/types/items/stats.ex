defmodule Ms2ex.Items.Stats do
  alias Ms2ex.{Item, Items}

  defstruct constants: %{},
            statics: %{},
            randoms: %{},
            enchants: %{},
            limit_break_enchants: %{}

  def create(%Item{rarity: rarity}) when is_nil(rarity) or rarity == 0 or rarity > 6 do
    %__MODULE__{}
  end

  def create(%Item{metadata: meta} = item) do
    pick_id = meta.option.pick_id
    lvl_factor = meta.option.level_factor

    constants = Items.ConstantStats.get(item, pick_id, lvl_factor)
    statics = Items.StaticStats.get(item, pick_id, lvl_factor)
    randoms = Items.RandomStats.get(item)

    enchants =
      if item.enchant_level > 0 do
        Items.EnchantStats.get(item)
      else
        %{}
      end

    %__MODULE__{
      constants: constants,
      statics: statics,
      randoms: randoms,
      enchants: enchants,
      limit_break_enchants: %{}
    }
  end
end
