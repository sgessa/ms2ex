defmodule Ms2ex.Types.Tombstone do
  alias Ms2ex.Constants
  alias Ms2ex.Schema

  @type t :: %__MODULE__{}

  defstruct [
    :object_id,
    :hits_remaining,
    :total_hit_count,
    unknown1: 1,
    unknown2: false
  ]

  # tombstone hit count scales with the death count, capped by the server
  # table's hit-per-death and max-death constants
  def new(%Schema.Character{} = character, death_count) do
    per_death = Constants.get(:hit_per_dead_count) || 0
    max_deaths = Constants.get(:max_dead_count) || 0

    total_hit_count =
      if per_death > 0 and max_deaths > 0 do
        min(death_count * per_death, per_death * max_deaths)
      else
        per_death
      end

    %__MODULE__{
      object_id: character.object_id,
      total_hit_count: total_hit_count,
      hits_remaining: total_hit_count
    }
  end
end
