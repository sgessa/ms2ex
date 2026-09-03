defmodule Ms2ex.Managers.Character.Equips do
  @moduledoc """
  Equip transitions owned by the character process.

  Equipping moves items between inventory and equipment, rebuilds the
  character's derived stats, and must keep the character's cached equip list
  coherent: other players' field serialization reads that list through the
  character manager. A transition therefore runs as one step inside the
  manager — the request is validated, conflicting items are unequipped into
  the freed space, the incoming item is equipped, the equip list and stats
  are refreshed once, and the field plus the owner's client are notified of
  the result.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  # slots no equip request may target: the none slot, off-hand (off-hand
  # items are equipped into either hand instead), and ears
  @unreachable_slots [:NONE, :OH, :ER]

  # Equips an inventory item into the requested slot, first unequipping the
  # items that occupy the taken slots. Returns the refreshed character.
  @spec equip(Schema.Character.t(), integer(), String.t()) ::
          {:ok, Schema.Character.t()} | :error
  def equip(character, item_id, slot_name) do
    case prepare(character, item_id, slot_name) do
      {:ok, item, equip_slot, conflicts} ->
        # the slot the item vacates is the preferred destination for the
        # item unequipped from the target slot
        preferred_slot = item.inventory_slot

        case Context.Equips.equip(item, equip_slot) do
          {:ok, item} ->
            removed = unequip_conflicts(conflicts, equip_slot, preferred_slot)
            {:ok, commit(character, {:equipped, item}, removed)}

          {:error, _changeset} ->
            :error
        end

      :error ->
        :error
    end
  end

  # Moves an equipped item back to the inventory. Returns the refreshed
  # character.
  @spec unequip(Schema.Character.t(), integer()) ::
          {:ok, Schema.Character.t()} | :error
  def unequip(character, item_id) do
    case get_item(character, item_id) do
      %{location: :equipment} = item ->
        case unequip_item(item, nil) do
          {:ok, removed} -> {:ok, commit(character, nil, [removed])}
          :error -> :error
        end

      _ ->
        :error
    end
  end

  # validates the request, loads the item's metadata, and resolves which
  # equipped items conflict with the incoming one
  defp prepare(character, item_id, slot_name) do
    with {:ok, item} <- load_inventory_item(character, item_id),
         :ok <- equippable?(character, item),
         {:ok, equip_slot} <- requested_slot(item, slot_name),
         {:ok, equip_slot, conflicts} <- resolve_conflicts(character, item, equip_slot) do
      {:ok, item, equip_slot, conflicts}
    else
      _ ->
        :error
    end
  end

  defp load_inventory_item(character, item_id) do
    case get_item(character, item_id) do
      %{location: :inventory} = item ->
        {:ok, Context.Items.load_metadata(item)}

      _ ->
        notify(character, :s_item_invalid_do_not_have)
    end
  end

  # level, job, and expiry limits must be met before an item can be equipped;
  # failures are reported to the owner with a localized message box
  defp equippable?(character, item) do
    limits = Map.get(item.metadata, :limit, %{})

    cond do
      character.level < Map.get(limits, :level, 0) ->
        notify(character, :s_item_err_puton_low_level)

      Context.Inventory.expired?(item) ->
        notify(character, :s_item_err_puton_expired)

      job_restricted?(character, limits) ->
        notify(character, :s_item_err_puton_job)

      true ->
        :ok
    end
  end

  # items without job limits can be worn by every job
  defp job_restricted?(character, limits) do
    job_limits = Map.get(limits, :job_limits, [])
    job_limits != [] and Enums.Job.get_value(character.job) not in job_limits
  end

  # the requested slot must be a slot the item occupies: its primary slot,
  # with either hand valid for off-hand items
  defp requested_slot(item, slot_name) do
    case Context.Equips.valid_slot?(slot_name) do
      true -> target_slot(item, String.to_existing_atom(slot_name))
      false -> :error
    end
  end

  defp target_slot(_item, slot) when slot in @unreachable_slots, do: :error

  defp target_slot(item, slot) do
    slots = Map.get(item.metadata, :slots, [])

    if :OH in slots do
      if slot in [:LH, :RH], do: {:ok, slot}, else: :error
    else
      if slot == List.first(slots), do: {:ok, slot}, else: :error
    end
  end

  # Equipped items occupying the slots the incoming item takes over. Off-hand
  # items replace whatever is in the targeted hand; every other item takes
  # over all the slots it covers. Items covering multiple slots (two-handed
  # weapons, suits) additionally need enough free inventory space to hold
  # everything that will be unequipped: the vacated slot plus one per
  # displaced item.
  defp resolve_conflicts(character, item, equip_slot) do
    conflict_slots =
      if :OH in item.metadata.slots, do: [equip_slot], else: item.metadata.slots

    conflicts =
      Enum.filter(
        character.equips,
        &(&1.equip_slot in conflict_slots and &1.inventory_tab == item.inventory_tab)
      )

    if multi_slot?(item) do
      free_slots = Context.Inventory.free_slot_count(character.id, item.inventory_tab)

      if free_slots + 1 > length(conflicts) do
        {:ok, equip_slot, conflicts}
      else
        :error
      end
    else
      {:ok, equip_slot, conflicts}
    end
  end

  defp multi_slot?(item), do: length(item.metadata.slots) > 1

  defp notify(character, string_code) do
    code = Enums.StringCode.get_value(string_code)
    Net.SenderSession.push(character, Packets.Notice.message_box(code))
    :error
  end

  # Moves an equipped item out of its slot. Returns `{:ok, {kind, item}}`
  # where the item was either unequipped back to the inventory (`:unequipped`)
  # or discarded as a cosmetic (`:discarded`).
  defp unequip_item(item, preferred_slot) do
    case Context.Equips.unequip(item, preferred_slot) do
      {:ok, item} -> {:ok, {:unequipped, item}}
      {:discard, item} -> {:ok, {:discarded, item}}
      {:error, _reason} -> :error
    end
  end

  # the item displaced from the requested slot is unequipped first so it can
  # claim the vacated inventory slot
  defp unequip_conflicts(conflicts, equip_slot, preferred_slot) do
    {primary, others} = Enum.split_with(conflicts, &(&1.equip_slot == equip_slot))
    ordered = primary ++ others

    ordered
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, index} ->
      destination = if index == 0, do: preferred_slot, else: nil

      case unequip_item(item, destination) do
        {:ok, removed} -> [removed]
        :error -> []
      end
    end)
  end

  defp get_item(character, item_id) do
    Context.Inventory.get_by(character_id: character.id, id: item_id)
  end

  # refreshes the cached equip list and derived stats once for the whole
  # transition, then announces the result to the field and the owner's
  # client; `equipped` is nil when the transition ended without a new equip
  defp commit(character, equipped, removed) do
    character = refresh(character)

    Enum.each(removed, fn {_kind, item} ->
      Context.Field.broadcast(character, Packets.UnequipItem.bytes(character, item.id))
    end)

    if equipped do
      Context.Field.broadcast(character, Packets.EquipItem.bytes(character, elem(equipped, 1)))
    end

    Context.Field.broadcast_stats(character)
    Context.Field.broadcast(character, Packets.ProxyGameObj.update_gear_score(character))

    Enum.each(removed, fn
      {:unequipped, item} ->
        Net.SenderSession.push(
          character,
          Packets.InventoryItem.add_item({:create, item}, character)
        )

      {:discarded, _item} ->
        :ok
    end)

    if equipped do
      Net.SenderSession.push(character, Packets.InventoryItem.remove_item(elem(equipped, 1).id))
    end

    character
  end

  defp refresh(character) do
    character
    |> Context.Characters.load_equips()
    |> Context.CharacterStats.apply()
    |> elem(0)
  end
end
