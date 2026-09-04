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
    Repo.transaction(fn ->
      Enum.reduce(reservations, [], fn reservation, slots ->
        case insert_slot(character, banner_id, reservation) do
          {:ok, slot} -> [to_slot(%{slot | character: character}) | slots]
          :error -> Repo.rollback(:conflict)
        end
      end)
      |> Enum.reverse()
    end)
    |> case do
      {:ok, slots} -> {:ok, slots}
      {:error, _reason} -> :error
    end
  end

  defp insert_slot(character, banner_id, reservation) do
    attrs = Map.merge(reservation, %{banner_id: banner_id, character_id: character.id})

    case %Schema.BannerSlot{} |> Schema.BannerSlot.changeset(attrs) |> Repo.insert() do
      {:ok, slot} -> {:ok, slot}
      {:error, _changeset} -> :error
    end
  end

  def attach(slot_ids, ugc) do
    from(slot in Schema.BannerSlot, where: slot.id in ^slot_ids)
    |> Repo.update_all(set: [ugc_resource_id: ugc.id])
  end

  defp to_slot(slot) do
    ugc =
      case slot.ugc_resource do
        %Schema.UgcResource{} = resource ->
          %{id: resource.id, author: slot.character.name, url: resource.path}

        _ ->
          nil
      end

    %{
      id: slot.id,
      banner_id: slot.banner_id,
      date: slot.date,
      hour: slot.hour,
      active: false,
      ugc: ugc
    }
  end
end
