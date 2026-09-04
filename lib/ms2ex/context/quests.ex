defmodule Ms2ex.Context.Quests do
  @moduledoc """
  Quest persistence helpers.
  """

  import Ecto.Query

  alias Ms2ex.Repo
  alias Ms2ex.Schema.Character
  alias Ms2ex.Schema.CharacterQuest
  alias Ms2ex.Storage

  @spec get_all_quests(integer(), integer()) :: {map(), map()}
  def get_all_quests(account_id, character_id) do
    CharacterQuest
    |> where(
      [quest],
      (quest.owner_id == ^account_id and quest.is_account_quest == true) or
        (quest.owner_id == ^character_id and quest.is_account_quest == false)
    )
    |> Repo.all()
    |> Enum.map(&hydrate_quest/1)
    |> Enum.reduce({%{}, %{}}, fn quest, {account_quests, character_quests} ->
      if quest.is_account_quest do
        {Map.put(account_quests, quest.quest_id, quest), character_quests}
      else
        {account_quests, Map.put(character_quests, quest.quest_id, quest)}
      end
    end)
  end

  @spec create_quest(map()) :: {:ok, CharacterQuest.t()} | {:error, Ecto.Changeset.t()}
  def create_quest(attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.merge(%{completion_count: 0, end_time: 0}, fn _key, left, _right -> left end)

    %CharacterQuest{}
    |> CharacterQuest.changeset(attrs)
    |> Repo.insert()
    |> hydrate_result()
  end

  @spec update_quest(CharacterQuest.t(), map()) ::
          {:ok, CharacterQuest.t()} | {:error, Ecto.Changeset.t()}
  def update_quest(quest, attrs) do
    quest
    |> CharacterQuest.changeset(normalize_attrs(attrs))
    |> Repo.update()
    |> hydrate_result()
  end

  @spec delete_quest(integer(), integer(), boolean()) :: :ok
  def delete_quest(owner_id, quest_id, account_quest?) do
    CharacterQuest
    |> where(
      [quest],
      quest.owner_id == ^owner_id and quest.quest_id == ^quest_id and
        quest.is_account_quest == ^account_quest?
    )
    |> Repo.delete_all()

    :ok
  end

  @doc "Drops every persisted row of the given quests in one statement."
  @spec delete_quests(integer(), [integer()], boolean()) :: :ok
  def delete_quests(owner_id, quest_ids, account_quest?) do
    CharacterQuest
    |> where(
      [quest],
      quest.owner_id == ^owner_id and quest.quest_id in ^quest_ids and
        quest.is_account_quest == ^account_quest?
    )
    |> Repo.delete_all()

    :ok
  end

  @spec has_completed_quest?(Character.t(), integer()) :: boolean()
  def has_completed_quest?(character, quest_id) do
    case Storage.Quests.get_meta(quest_id) do
      nil ->
        false

      quest ->
        account_quest? = Storage.Quests.account_quest?(quest)
        owner_id = Storage.Quests.get_owner_id(character, quest)

        CharacterQuest
        |> where([record], record.owner_id == ^owner_id)
        |> where([record], record.quest_id == ^quest.id)
        |> where([record], record.state == :completed)
        |> where([record], record.is_account_quest == ^account_quest?)
        |> limit(1)
        |> Repo.one()
        |> is_nil()
        |> Kernel.not()
    end
  end

  @spec serialize_conditions(map()) :: map()
  def serialize_conditions(conditions) do
    Enum.into(conditions, %{}, fn {index, condition} ->
      counter =
        case condition do
          %{counter: counter} -> counter
          %{"counter" => counter} -> counter
          counter when is_integer(counter) -> counter
          _ -> 0
        end

      {index, counter}
    end)
  end

  defp hydrate_result({:ok, quest}), do: {:ok, hydrate_quest(quest)}
  defp hydrate_result(error), do: error

  defp hydrate_quest(quest) do
    metadata = Storage.Quests.get_meta(quest.quest_id)
    conditions = hydrate_conditions(quest.conditions, metadata)

    %{quest | metadata: metadata, conditions: conditions}
  end

  defp hydrate_conditions(conditions, %{conditions: metadata_conditions})
       when is_list(metadata_conditions) do
    metadata_conditions
    |> Enum.with_index()
    |> Enum.into(%{}, fn {metadata, index} ->
      {index, %{counter: load_counter(conditions, index), metadata: metadata}}
    end)
  end

  defp hydrate_conditions(_conditions, _metadata), do: %{}

  # Persisted rows hold counters keyed by condition index; rows written
  # before the counters-only format stored the whole condition — dig the
  # counter out of either shape.
  defp load_counter(conditions, index) do
    conditions
    |> Map.get(index)
    |> Kernel.||(Map.get(conditions, Integer.to_string(index)))
    |> counter_value()
  end

  defp counter_value(counter) when is_integer(counter), do: counter

  defp counter_value(full) when is_map(full) do
    Map.get(full, :counter) || Map.get(full, "counter") || 0
  end

  defp counter_value(_), do: 0

  defp normalize_attrs(attrs) do
    case Map.fetch(attrs, :conditions) do
      {:ok, conditions} -> Map.put(attrs, :conditions, serialize_conditions(conditions))
      :error -> attrs
    end
  end
end
