defmodule Ms2ex.Context.BannerSlots do
  import Ecto.Query

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  def list(banner_ids) do
    Schema.BannerSlot
    |> where([slot], slot.banner_id in ^banner_ids)
    |> preload([:character, :ugc_resource])
    |> Repo.all()
    |> Enum.map(&to_slot/1)
  end

  def reserve(character, banner_id, reservations) do
    Repo.transaction(fn -> reserve_slots(character, banner_id, reservations) end)
    |> case do
      {:ok, slots} -> {:ok, slots}
      {:error, _reason} -> :error
    end
  end

  defp reserve_slots(character, banner_id, reservations) do
    Enum.reduce(reservations, [], fn reservation, slots ->
      case insert_slot(character, banner_id, reservation) do
        {:ok, slot} -> [to_slot(%{slot | character: character}) | slots]
        _ -> Repo.rollback(:conflict)
      end
    end)
    |> Enum.reverse()
  end

  defp insert_slot(character, banner_id, reservation) do
    with {:ok, starts_at} <- starts_at(reservation) do
      attrs =
        Map.merge(reservation, %{
          banner_id: banner_id,
          character_id: character.id,
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 1, :hour)
        })

      %Schema.BannerSlot{}
      |> Schema.BannerSlot.changeset(attrs)
      |> Repo.insert()
    end
  end

  defp starts_at(%{date: date, hour: hour}) do
    with {:ok, day} <- Date.new(div(date, 10_000), rem(div(date, 100), 100), rem(date, 100)),
         {:ok, time} <- Time.new(hour, 0, 0, 0),
         {:ok, starts_at} <- DateTime.new(day, time, "Etc/UTC") do
      {:ok, starts_at}
    else
      _ -> :error
    end
  end

  def attach(slot_ids, ugc),
    do:
      Schema.BannerSlot
      |> where([slot], slot.id in ^slot_ids)
      |> Repo.update_all(set: [ugc_resource_id: ugc.id])

  def expire(slots) do
    slot_ids = Enum.map(slots, & &1.id)

    case Repo.transaction(fn ->
           resource_ids = resource_ids(slot_ids)

           Schema.BannerSlot
           |> where([s], s.id in ^slot_ids)
           |> Repo.delete_all()

           resources = orphaned_resources(resource_ids)
           Enum.each(resources, &Repo.delete!/1)

           resources
         end) do
      {:ok, resources} ->
        delete_files(slots, resources)
        :ok

      {:error, _reason} ->
        :error
    end
  end

  defp resource_ids(slot_ids),
    do:
      Schema.BannerSlot
      |> where([s], s.id in ^slot_ids)
      |> where([s], not is_nil(s.ugc_resource_id))
      |> select([s], s.ugc_resource_id)
      |> Repo.all()

  defp orphaned_resources(resource_ids) do
    referenced_resource_ids =
      Schema.BannerSlot
      |> where([slot], not is_nil(slot.ugc_resource_id))
      |> select([slot], slot.ugc_resource_id)
      |> Repo.all()

    Schema.UgcResource
    |> where([r], r.id in ^resource_ids)
    |> where([r], r.id not in ^referenced_resource_ids)
    |> Repo.all()
  end

  defp delete_files(slots, resources) do
    resource_ids = MapSet.new(resources, & &1.id)

    Enum.each(slots, fn slot ->
      if get_in(slot, [:ugc, :id]) in resource_ids do
        Ms2ex.Context.Ugc.data_dir()
        |> Path.join(["banner", to_string(slot.banner_id), "#{slot.ugc.id}.m2u"])
        |> File.rm()
      end
    end)
  end

  defp to_slot(slot),
    do: %{
      id: slot.id,
      banner_id: slot.banner_id,
      date: slot.date,
      hour: slot.hour,
      character_id: slot.character_id,
      starts_at: slot.starts_at,
      ends_at: slot.ends_at,
      active: false,
      ugc: ugc_resource_meta(slot)
    }

  defp ugc_resource_meta(%{ugc_resource: %Schema.UgcResource{} = resource} = slot),
    do: %{
      id: resource.id,
      account_id: slot.character.account_id,
      character_id: resource.character_id,
      author: slot.character.name,
      url: resource.path
    }

  defp ugc_resource_meta(_res), do: nil
end
