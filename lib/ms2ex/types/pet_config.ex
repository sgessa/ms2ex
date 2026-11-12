defmodule Ms2ex.Types.PetConfig do
  @moduledoc """
  Per-pet auto-behaviour config the client edits while the pet is summoned:
  potion auto-use thresholds and the loot pickup filter. Held in the pet
  manager while summoned; defaults apply until the client sends updates.
  """

  @type t :: %__MODULE__{}

  defstruct potion_config: [],
            loot_config: %{
              mesos?: true,
              merets?: true,
              other?: true,
              currency?: true,
              equipment?: true,
              consumable?: true,
              gemstone?: true,
              dropped?: true,
              rarity: 1,
              enabled?: false
            }

  @type potion :: %{
          index: integer(),
          threshold: float(),
          item_id: integer()
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}
end
