defmodule Ms2ex.Context.HotBars do
  @moduledoc """
  Context module for hot bar-related operations.

  This module provides functions for managing
  character hot bars and quick slots.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  import Ecto.Query, except: [update: 2]

  @doc """
  Gets a hot bar by the given attributes.

  ## Examples

      iex> get_by(%{character_id: 1, id: 1})
      %Schema.HotBar{}

      iex> get_by(%{character_id: 999})
      nil
  """
  @spec get_by(map()) :: Schema.HotBar.t() | nil
  def get_by(attrs), do: Repo.get_by(Schema.HotBar, attrs)

  @doc """
  Lists all hot bars for a given character.

  Returns hot bars ordered by ID.

  ## Examples

      iex> list(character)
      [%Schema.HotBar{}, %Schema.HotBar{}, ...]
  """
  @spec list(Schema.Character.t()) :: [Schema.HotBar.t()]
  def list(%Schema.Character{id: character_id}) do
    Schema.HotBar
    |> where([hb], hb.character_id == ^character_id)
    |> order_by(asc: :id)
    |> Repo.all()
  end

  @doc """
  Moves a quick slot to a new target position in a hot bar.

  If there's already a quick slot at the target position, the slots are swapped.
  If the target position is invalid, returns an error.

  ## Examples

      iex> move_quick_slot(hot_bar, quick_slot, 3)
      {:ok, %Schema.HotBar{}}

      iex> move_quick_slot(hot_bar, quick_slot, -1)
      :error
  """
  @spec move_quick_slot(Schema.HotBar.t(), Types.QuickSlot.t(), integer()) ::
          {:ok, Schema.HotBar.t()} | {:error, Ecto.Changeset.t()} | :error
  def move_quick_slot(hot_bar, quick_slot, target) do
    if valid_target_slot?(target) do
      add_or_swap(hot_bar, quick_slot, target)
    else
      :error
    end
  end

  @doc """
  Removes a quick slot from a hot bar.

  Finds the quick slot by skill ID and item UID and replaces it with an empty slot.

  ## Parameters

    * `hot_bar` - The hot bar to modify
    * `skill_id` - The skill ID to find
    * `item_uid` - The item UID to find

  ## Examples

      iex> remove_quick_slot(hot_bar, 10500, "item123")
      {:ok, %Schema.HotBar{}}

      iex> remove_quick_slot(hot_bar, 99999, "nonexistent")
      :error
  """
  @spec remove_quick_slot(Schema.HotBar.t(), integer(), String.t() | nil) ::
          {:ok, Schema.HotBar.t()} | {:error, Ecto.Changeset.t()} | :error
  def remove_quick_slot(hot_bar, skill_id, item_uid) do
    target_idx = find_quick_slot_index(hot_bar, skill_id, item_uid)

    if valid_target_slot?(target_idx) do
      slots = List.update_at(hot_bar.quick_slots, target_idx, fn _ -> %Types.QuickSlot{} end)

      hot_bar
      |> Schema.HotBar.changeset(%{quick_slots: slots})
      |> Repo.update()
    else
      :error
    end
  end

  defp add_or_swap(hot_bar, quick_slot, target) do
    slots =
      if src_slot_idx = find_quick_slot_index(hot_bar, quick_slot.skill_id, quick_slot.item_uid) do
        src_slot = Enum.at(hot_bar.quick_slots, target)
        List.update_at(hot_bar.quick_slots, src_slot_idx, fn _ -> src_slot end)
      else
        hot_bar.quick_slots
      end

    slots = List.update_at(slots, target, fn _ -> quick_slot end)

    hot_bar
    |> Schema.HotBar.changeset(%{quick_slots: slots})
    |> Repo.update()
  end

  defp find_quick_slot_index(hot_bar, skill_id, item_uid) do
    Enum.find_index(hot_bar.quick_slots, &(&1.skill_id == skill_id && &1.item_uid == item_uid))
  end

  defp valid_target_slot?(target) do
    !(target < 0 or target >= Schema.HotBar.max_quick_slots())
  end

  # Characters without a saved layout get their active hot bar filled with
  # the job's learned active skills: learned in-battle skills above the 10M
  # id range, placed in a fixed slot order on the active bar, then persisted.
  @slot_order [4, 5, 6, 7, 0, 1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]

  @spec update_hotbar_skills(Schema.Character.t(), [Schema.HotBar.t()]) :: [Schema.HotBar.t()]
  def update_hotbar_skills(%Schema.Character{} = character, hot_bars) do
    skill_ids = learned_active_skill_ids(character)
    active_index = Enum.find_index(hot_bars, & &1.active) || 0

    updated =
      List.update_at(hot_bars, active_index, fn hot_bar ->
        %{hot_bar | quick_slots: fill_slots(hot_bar.quick_slots, skill_ids)}
      end)

    Enum.each(updated, &save_hot_bar/1)
    updated
  end

  defp learned_active_skill_ids(%Schema.Character{
         skill_tabs: tabs,
         active_skill_tab_id: active_id
       })
       when is_list(tabs) do
    case Enum.find(tabs, &(&1.id == active_id)) do
      %Schema.SkillTab{skills: skills} when is_list(skills) ->
        skills
        |> Enum.filter(&learned_active_skill?(&1))
        |> Enum.map(& &1.skill_id)
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp learned_active_skill_ids(_character), do: []

  defp learned_active_skill?(skill) do
    skill.level > 0 and skill.skill_id > 10_000_000 and skill_in_battle?(skill.skill_id)
  end

  defp skill_in_battle?(skill_id) do
    case Storage.Skills.get_meta(skill_id) do
      %{state: %{in_battle: in_battle}} -> in_battle
      _ -> false
    end
  end

  defp fill_slots(slots, skill_ids) do
    Enum.reduce(skill_ids, slots, &assign_free_slot(&2, &1))
  end

  defp assign_free_slot(slots, skill_id) do
    if Enum.any?(slots, &(&1.skill_id == skill_id)) do
      slots
    else
      do_assign(slots, free_slot_index(slots), skill_id)
    end
  end

  defp free_slot_index(slots) do
    Enum.find(@slot_order, fn index ->
      case Enum.at(slots, index) do
        %{skill_id: skill_id} -> skill_id in [nil, 0]
        _ -> false
      end
    end)
  end

  defp do_assign(slots, nil, _skill_id), do: slots

  defp do_assign(slots, index, skill_id) do
    List.update_at(slots, index, fn _slot -> %Types.QuickSlot{skill_id: skill_id} end)
  end

  defp save_hot_bar(hot_bar) do
    hot_bar
    |> Schema.HotBar.changeset(%{quick_slots: hot_bar.quick_slots})
    |> Repo.update()
  end
end
