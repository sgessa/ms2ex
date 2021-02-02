defmodule Ms2ex.HotBars do
  alias Ms2ex.{Character, HotBar, QuickSlot, Repo}

  import Ecto.Query, except: [update: 2]

  def get_by(attrs), do: Repo.get_by(HotBar, attrs)

  def list(%Character{id: character_id}) do
    HotBar
    |> where([hb], hb.character_id == ^character_id)
    |> order_by(asc: :id)
    |> Repo.all()
  end

  def move_quick_slot(hot_bar, quick_slot, target) do
    if valid_target_slot?(target) do
      add_or_swap(hot_bar, quick_slot, target)
    else
      :error
    end
  end

  def remove_quick_slot(hot_bar, skill_id, item_uid) do
    target_idx = find_quick_slot_index(hot_bar, skill_id, item_uid)

    if valid_target_slot?(target_idx) do
      slots = List.update_at(hot_bar.quick_slots, target_idx, fn _ -> %QuickSlot{} end)

      hot_bar
      |> HotBar.changeset(%{quick_slots: slots})
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
    |> HotBar.changeset(%{quick_slots: slots})
    |> Repo.update()
  end

  defp find_quick_slot_index(hot_bar, skill_id, item_uid) do
    Enum.find_index(hot_bar.quick_slots, &(&1.skill_id == skill_id && &1.item_uid == item_uid))
  end

  defp valid_target_slot?(target) do
    !(target < 0 or target >= HotBar.max_quick_slots())
  end
end
