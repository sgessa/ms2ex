defmodule Ms2ex.Context.HotBars do
  @moduledoc """
  Context module for hot bar persistence.

  Hot bar rows live in the character-config manager's memory while a
  character is online; this module loads them once and persists updates,
  returning the updated rows for the manager's state.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  import Ecto.Query, except: [update: 2]

  @doc """
  Lists all hot bars for a given character, ordered by ID.

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
  Persists a bar's quick slots and returns the updated row: the manager's
  state always carries what the database has.
  """
  @spec update_quick_slots(Schema.HotBar.t(), [Types.QuickSlot.t()]) ::
          {:ok, Schema.HotBar.t()} | {:error, Ecto.Changeset.t()}
  def update_quick_slots(%Schema.HotBar{} = hot_bar, slots) do
    hot_bar
    |> Ecto.Changeset.change(quick_slots: slots)
    |> Repo.update()
  end

  @doc """
  Persists a bar's active flag and returns the updated row.
  """
  @spec set_active(Schema.HotBar.t(), boolean()) ::
          {:ok, Schema.HotBar.t()} | {:error, Ecto.Changeset.t()}
  def set_active(%Schema.HotBar{} = hot_bar, active) do
    hot_bar
    |> Ecto.Changeset.change(active: active)
    |> Repo.update()
  end
end
