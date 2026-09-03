defmodule Ms2ex.Storage.Quests do
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @spec get_meta(integer()) :: map() | nil
  def get_meta(quest_id) when is_integer(quest_id) do
    Storage.get(:quest, quest_id)
  end

  def get_meta(_quest_id), do: nil

  @spec get_all() :: [map()]
  def get_all() do
    index_ids()
    |> Enum.map(&get_meta/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec get_quests_by_npc(integer()) :: [map()]
  def get_quests_by_npc(npc_id) do
    indexed_quests(:by_npc, npc_id)
  end

  @spec get_quests_by_type(atom()) :: [map()]
  def get_quests_by_type(type) do
    indexed_quests(:by_type, type)
  end

  @spec get_quests_by_chapter(integer()) :: [map()]
  def get_quests_by_chapter(chapter_id) do
    indexed_quests(:by_chapter, chapter_id)
  end

  @spec auto_start_quests() :: [map()]
  def auto_start_quests() do
    index_list(:auto_start_ids)
    |> hydrate_quests()
  end

  @spec account_quest?(map()) :: boolean()
  def account_quest?(quest) do
    get_in(quest, [:basic, :account]) > 0
  end

  @spec get_owner_id(Schema.Character.t(), map()) :: integer()
  def get_owner_id(character, quest) do
    if account_quest?(quest) do
      character.account_id
    else
      character.id
    end
  end

  defp indexed_quests(bucket, key) do
    bucket
    |> index_lookup(key)
    |> hydrate_quests()
  end

  defp hydrate_quests(quest_ids) do
    quest_ids
    |> Enum.map(&get_meta/1)
    |> Enum.reject(&is_nil/1)
  end

  defp index_ids do
    index_list(:ids)
  end

  defp index_lookup(bucket, key) do
    index = index()
    values = Map.get(index, bucket, %{})
    Map.get(values, key) || Map.get(values, normalize_index_key(key)) || []
  end

  defp index_list(key) do
    index()
    |> Map.get(key, [])
  end

  defp normalize_index_key(key) when is_integer(key), do: Integer.to_string(key)
  defp normalize_index_key(key), do: key

  defp index do
    Storage.get(:quest, "index") || %{}
  end
end
