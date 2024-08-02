defmodule Ms2ex.Types.ItemStats do
  alias Ms2ex.{Context, Schema, Storage}

  defstruct constants: %{},
            statics: %{},
            randoms: %{},
            enchants: %{},
            limit_break_enchants: %{}

  def create(%Schema.Item{rarity: rarity}) when is_nil(rarity) or rarity == 0 or rarity > 6 do
    %__MODULE__{}
  end

  def create(%Schema.Item{metadata: meta} = item) do
    pick_id = meta.option.pick_id
    pick_options = Storage.Tables.ItemOptions.find_pick(pick_id, item.rarity)

    constants = Context.ItemConstantStats.get(item, pick_options)
    statics = Context.ItemStaticStats.get(item, pick_options)
    randoms = Context.ItemRandomStats.get(item)

    enchants =
      if item.enchant_level > 0 do
        Context.ItemEnchantStats.get(item)
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
