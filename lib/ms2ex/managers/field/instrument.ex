defmodule Ms2ex.Managers.Field.Instrument do
  alias Ms2ex.Managers.Field

  @doc """
  Spawns an instrument for its owner. A character can only hold one
  instrument at a time, so an existing one is replaced.
  """
  def add(instrument, state) do
    {object_id, state} = Field.next_local_id(state)
    instrument = %{instrument | object_id: object_id}

    {instrument, put_in(state, [:instruments, instrument.owner_character_id], instrument)}
  end

  def get(character_id, state), do: Map.get(state.instruments, character_id)

  def remove(character_id, state),
    do: update_in(state, [:instruments], &Map.delete(&1, character_id))
end
