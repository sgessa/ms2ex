defmodule Ms2ex.Managers.Character.Mastery do
  @moduledoc """
  Life skill (mastery) state owned by the character process: the mastery
  value per type, how often each gathering recipe was harvested and which
  grade reward boxes were claimed.

  Everything is read from and written to memory; the row is only persisted
  on the periodic flush and on disconnect, so a gathering spree does not
  write one UPDATE per node.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @doc "Mastery values of a character, keyed by mastery type."
  def all(character) do
    case Map.get(character, :masteries) do
      masteries when is_map(masteries) -> masteries
      _ -> %{}
    end
  end

  @doc "Mastery value of a single type."
  def value(character, type), do: Map.get(all(character), type, 0)

  @doc "Mastery grade (level) a type has reached."
  def grade(character, type),
    do: Storage.Tables.MasteryRewards.grade(type, value(character, type))

  @doc "Gathering counts of a character, keyed by recipe id."
  def gathering_counts(character) do
    case Map.get(character, :gathering_counts) do
      counts when is_map(counts) -> counts
      _ -> %{}
    end
  end

  @doc "Claimed mastery grade reward boxes, keyed by reward box id."
  def rewards_claimed(character) do
    case Map.get(character, :mastery_rewards_claimed) do
      claimed when is_map(claimed) -> claimed
      _ -> %{}
    end
  end

  def claimed?(character, reward_box_id),
    do: Map.get(rewards_claimed(character), reward_box_id, false) == true

  def claim(character, reward_box_id) do
    character
    |> Map.put(:mastery_rewards_claimed, Map.put(rewards_claimed(character), reward_box_id, true))
    |> mark_dirty()
  end

  @doc """
  Adds mastery. The value never decreases and is capped at the type's
  maximum; the client is told the new value and grade changes feed the
  matching trophy/quest conditions.
  """
  def add(character, type, amount, opts \\ [])

  def add(character, type, amount, opts) when is_integer(amount) do
    start_value = value(character, type)
    start_grade = Storage.Tables.MasteryRewards.grade(type, start_value)

    new_value =
      (start_value + amount)
      |> max(start_value)
      |> min(Enums.MasteryType.maximum(type))

    if new_value == start_value do
      character
    else
      character =
        character
        |> Map.put(:masteries, Map.put(all(character), type, new_value))
        |> mark_dirty()

      push(character, Packets.Mastery.update_mastery(type, new_value))

      new_grade = Storage.Tables.MasteryRewards.grade(type, new_value)
      delta_grade = new_grade - start_grade + if(start_value == 0, do: 1, else: 0)

      notify_grade_change(character, type, new_grade, delta_grade)
      notify_exp_increase(character, type, new_value - start_value, opts)

      character
    end
  end

  def add(character, _type, _amount, _opts), do: character

  @doc "Bumps the harvest counter of a gathering recipe."
  def count_gather(character, recipe_id) do
    counts = gathering_counts(character)

    character
    |> Map.put(:gathering_counts, Map.update(counts, recipe_id, 1, &(&1 + 1)))
    |> mark_dirty()
  end

  @doc "Persists the mastery state when it changed since the last flush."
  def flush(%{mastery_dirty?: true} = character) do
    attrs = %{
      masteries: all(character),
      gathering_counts: gathering_counts(character),
      mastery_rewards_claimed: rewards_claimed(character),
      fish_album: Managers.Character.Fishing.album(character)
    }

    case Context.Characters.persist(character, attrs) do
      {:ok, updated} -> Map.put(updated, :mastery_dirty?, false)
      _ -> character
    end
  end

  def flush(character), do: character

  defp mark_dirty(character), do: Map.put(character, :mastery_dirty?, true)

  # a grade loss only refreshes the client's grade trophy; a gain feeds the
  # per-skill trophies
  defp notify_grade_change(_character, _type, _grade, 0), do: :ok

  defp notify_grade_change(character, type, _grade, delta) when delta < 0 do
    update_conditions(character, :set_mastery_grade, 1, Enums.MasteryType.get_value(type))
  end

  defp notify_grade_change(character, :fishing, grade, _delta),
    do: update_conditions(character, :fisher_grade, 1, grade)

  defp notify_grade_change(character, :music, _grade, delta),
    do: update_conditions(character, :music_play_grade, delta, 0)

  defp notify_grade_change(character, type, _grade, _delta),
    do: update_conditions(character, :mastery_grade, 1, Enums.MasteryType.get_value(type))

  defp notify_exp_increase(character, :music, delta_exp, opts) do
    update_conditions(
      character,
      :music_play_instrument_mastery,
      delta_exp,
      Keyword.get(opts, :instrument_category, 0)
    )
  end

  defp notify_exp_increase(_character, _type, _delta_exp, _opts), do: :ok

  defp update_conditions(character, type, counter, code_long) do
    Managers.Quest.update_conditions(character.id, type, counter, "", 0, "", code_long)
  end
end
