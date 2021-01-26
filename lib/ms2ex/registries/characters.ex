defmodule Ms2ex.Registries.Characters do
  @table_name :character_registry

  def lookup(character_ids) when is_list(character_ids) do
    :ets.select(@table_name, for(key <- character_ids, do: {{key, :_}, [], [:"$_"]}))
  end

  def lookup(character_id) do
    case :ets.lookup(@table_name, character_id) do
      [{_id, character} | _] -> {:ok, character}
      _ -> :error
    end
  end

  def lookup_by_name(name) do
    case :ets.lookup(@table_name, "names:#{name}") do
      [{_name, character_id} | _] -> lookup(character_id)
      _ -> :error
    end
  end

  def update(character) do
    if :ets.insert(@table_name, {character.id, character}) do
      character
    else
      :error
    end
  end

  def register_name(%{id: id, name: name}) do
    :ets.insert(@table_name, {"names:#{name}", id})
  end

  def start() do
    :ets.new(@table_name, [:public, :set, :named_table])
  end
end
