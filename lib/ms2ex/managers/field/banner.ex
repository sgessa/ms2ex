defmodule Ms2ex.Managers.Field.Banner do
  @moduledoc """
  UGC banners: each map's banners own a set of slots players reserve and
  attach artwork to. Slots are either hour-scoped (a fixed hour of the day)
  or event-scoped (an explicit start/end time). Slot documents persist
  through `Context.BannerSlots`; the field keeps the live copy, activates
  slots as their windows open and broadcasts the transitions.
  """

  alias Ms2ex.Context
  alias Ms2ex.Storage

  @doc "Loads every banner of the map with its persisted slots."
  def load(map_id) do
    banners = Storage.Tables.Banners.for_map(map_id)
    slots = Context.BannerSlots.list(Enum.map(banners, & &1.id))

    banners
    |> Map.new(fn banner ->
      {banner.id, Map.put(banner, :slots, Enum.filter(slots, &(&1.banner_id == banner.id)))}
    end)
  end

  @doc "Every banner of the field with its live slot set."
  def all(state), do: Map.values(state.banners)

  @doc """
  Refreshes slot activity against the clock: expired event slots are
  dropped (and deleted), hour slots flip active/inactive. Returns
  `{state, changed_banners}` — only banners whose slot set changed.
  """
  def activate(state) do
    now = DateTime.utc_now()
    state = expire_slots(state, now)

    {banners, changed} =
      Enum.map_reduce(state.banners, [], fn {banner_id, banner}, changed ->
        active_slot = Enum.find(banner.slots, &current_slot?(&1, now))

        slots = Enum.map(banner.slots, &update_slot_active(&1, active_slot, now))

        updated_banner = %{banner | slots: slots}
        changed = if slots == banner.slots, do: changed, else: [updated_banner | changed]
        {{banner_id, updated_banner}, changed}
      end)

    {%{state | banners: Map.new(banners)}, changed}
  end

  defp expire_slots(state, now) do
    {banners, expired_slots} =
      Enum.map_reduce(state.banners, [], fn {banner_id, banner}, expired_slots ->
        {expired, slots} = Enum.split_with(banner.slots, &expired?(&1, now))
        {{banner_id, %{banner | slots: slots}}, expired ++ expired_slots}
      end)

    case expired_slots do
      [] ->
        state

      _ ->
        Context.BannerSlots.expire(expired_slots)
        %{state | banners: Map.new(banners)}
    end
  end

  defp current_slot?(
         %{starts_at: %DateTime{} = starts_at, ends_at: %DateTime{} = ends_at} = slot,
         now
       ) do
    not is_nil(slot.ugc) and DateTime.compare(starts_at, now) != :gt and
      DateTime.compare(now, ends_at) == :lt
  end

  defp current_slot?(slot, now) do
    (slot.ugc && slot.date == now.year * 10_000 + now.month * 100 + now.day) and
      slot.hour == now.hour
  end

  defp update_slot_active(slot, nil, _now), do: Map.put(slot, :active, false)

  defp update_slot_active(slot, %{id: id}, now) when slot.id == id do
    slot
    |> Map.put(:active, true)
    |> Map.put_new(:activated_at, now)
  end

  defp update_slot_active(slot, _active_slot, _now), do: Map.put(slot, :active, false)

  defp expired?(%{ends_at: %DateTime{} = ends_at}, now), do: DateTime.compare(now, ends_at) != :lt
  defp expired?(_slot, _now), do: false

  @doc "Reserves slots for a character; the reservation persists immediately."
  def reserve(character, banner_id, reservations, state) do
    case Map.fetch(state.banners, banner_id) do
      :error ->
        :error

      {:ok, banner} ->
        case Context.BannerSlots.reserve(character, banner_id, reservations) do
          {:ok, slots} ->
            banners = Map.put(state.banners, banner_id, %{banner | slots: banner.slots ++ slots})
            {:ok, slots, %{state | banners: banners}}

          :error ->
            :error
        end
    end
  end

  @doc """
  Attaches artwork to the character's own empty slots. Every requested slot
  must be attachable; the attachment persists only when they all are.
  """
  def attach(character, banner_id, slot_ids, ugc, state) do
    with {:ok, banner} <- Map.fetch(state.banners, banner_id),
         {:ok, banner} <- attachable(banner, character, slot_ids, ugc),
         {_count, _slots} <- Context.BannerSlots.attach(slot_ids, ugc) do
      {:ok, banner, %{state | banners: Map.put(state.banners, banner_id, banner)}}
    else
      _ -> :error
    end
  end

  defp attachable(banner, character, slot_ids, ugc) do
    if Enum.all?(slot_ids, &attachable_slot?(banner.slots, character.id, &1)) do
      {:ok, %{banner | slots: Enum.map(banner.slots, &put_slot_ugc(&1, slot_ids, ugc))}}
    end
  end

  defp attachable_slot?(slots, character_id, id) do
    Enum.any?(slots, &(&1.id == id and &1.character_id == character_id and is_nil(&1.ugc)))
  end

  defp put_slot_ugc(slot, ids, ugc) do
    if slot.id in ids, do: Map.put(slot, :ugc, ugc), else: slot
  end

  @doc """
  Confirms the upload behind an artwork resource: the slot carrying that
  resource receives the rendered image path.
  """
  def confirm(resource_id, path, state) do
    case find_confirmed(state.banners, resource_id, path) do
      nil ->
        :error

      {banner_id, banner} ->
        {:ok, banner, %{state | banners: Map.put(state.banners, banner_id, banner)}}
    end
  end

  defp find_confirmed(banners, resource_id, path) do
    Enum.find_value(banners, fn {banner_id, banner} ->
      case confirmed_banner(banner, resource_id, path) do
        {:ok, banner} -> {banner_id, banner}
        _ -> nil
      end
    end)
  end

  defp confirmed_banner(banner, resource_id, path) do
    if Enum.any?(banner.slots, &slot_resource?(&1, resource_id)) do
      {:ok, %{banner | slots: Enum.map(banner.slots, &put_slot_path(&1, resource_id, path))}}
    end
  end

  defp slot_resource?(slot, resource_id), do: get_in(slot, [:ugc, :id]) == resource_id

  defp put_slot_path(slot, resource_id, path) do
    if slot_resource?(slot, resource_id), do: put_in(slot, [:ugc, :url], path), else: slot
  end
end
