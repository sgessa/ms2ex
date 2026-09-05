defmodule Ms2ex.Context.Characters do
  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ecto.Query, except: [update: 2]

  def list(%Schema.Account{id: account_id}) do
    Schema.Character
    |> where([c], c.account_id == ^account_id)
    |> Repo.all()
    |> Enum.map(&load_equips/1)
  end

  def create(%Schema.Account{} = account, attrs) do
    attrs = Schema.Character.set_default_assocs(attrs)

    changeset =
      account
      |> Ecto.build_assoc(:characters)
      |> Schema.Character.changeset(attrs)

    Repo.transaction(fn ->
      with {:ok, %{skill_tabs: [tab]} = character} <- Repo.insert(changeset),
           {:ok, character} <- update(character, %{active_skill_tab_id: tab.id}) do
        character
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def get(%Schema.Account{id: account_id}, character_id) do
    Repo.get_by(Schema.Character, account_id: account_id, id: character_id)
  end

  def get(id), do: Repo.get(Schema.Character, id)

  def get_by(attrs), do: Repo.get_by(Schema.Character, attrs)

  def update(%Schema.Character{} = character, attrs) do
    character
    |> Schema.Character.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Writes deferred state that the in-memory struct already carries. A cast
  changeset would drop every field as unchanged, so the changes are forced.
  """
  def persist(%Schema.Character{} = character, attrs) do
    attrs
    |> Enum.reduce(Ecto.Changeset.change(character), fn {field, value}, changeset ->
      Ecto.Changeset.force_change(changeset, field, value)
    end)
    |> Repo.update()
  end

  def update_stat_points(%Schema.Character{} = character, sources, allocation) do
    character
    |> Schema.Character.changeset(%{
      stat_point_sources: sources,
      stat_point_allocation: allocation
    })
    |> Repo.update()
  end

  def delete(%Schema.Character{} = character), do: Repo.delete(character)

  def preload(%Schema.Character{} = character, assocs, opts \\ []) do
    Repo.preload(character, assocs, opts)
  end

  # bulk listings read persisted rows: inventory managers only exist for
  # characters currently in game, and a listing spans every character of the
  # account
  defp load_equips(%Schema.Character{} = character) do
    %{character | equips: Context.Inventory.list_equipped(character.id)}
  end

  def load_skills(%Schema.Character{} = character, opts \\ []) do
    %{skill_tabs: tabs} = Repo.preload(character, :skill_tabs, opts)

    tabs =
      Enum.map(tabs, fn t ->
        %{t | skills: Context.Skills.load_tab_skills(character, t)}
      end)

    %{character | skill_tabs: tabs}
  end

  def list_titles(%Schema.Character{id: character_id}) do
    Schema.CharacterTitle
    |> where([t], t.character_id == ^character_id)
    |> select([t], t.title_id)
    |> Repo.all()
  end

  def learn_title(%Schema.Character{} = character, title_id) do
    character
    |> Ecto.build_assoc(:titles, %{title_id: title_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def maybe_discover_map(%Schema.Character{discovered_maps: maps} = character, new_map) do
    if Enum.member?(maps, new_map) do
      character
    else
      maps = [new_map | maps]
      {:ok, character} = __MODULE__.update(character, %{discovered_maps: maps})
      character
    end
  end

  @doc "Records a first-time interaction; returns false when already known."
  def discover_object(%Schema.Character{} = character, object_id) do
    objects = character.discovered_objects || []

    if Enum.member?(objects, object_id) do
      false
    else
      {:ok, character} =
        __MODULE__.update(character, %{discovered_objects: [object_id | objects]})

      Ms2ex.Managers.Character.call(character, {:update, character})
      true
    end
  end
end
