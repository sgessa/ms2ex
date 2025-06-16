defmodule Ms2ex.Context.HotBars do
  @moduledoc """
  Context module for hot bar-related operations.

  This module provides functions for managing
  character hot bars and quick slots.
  """

  alias Ms2ex.{Repo, Schema, Types}

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
end
