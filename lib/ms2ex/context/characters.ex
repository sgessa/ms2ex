defmodule Ms2ex.Context.Characters do
  alias Ms2ex.{Context, Repo, Schema}

  import Ecto.Query, except: [update: 2]

  def list(%Schema.Account{id: account_id}) do
    Schema.Character
    |> where([c], c.account_id == ^account_id)
    |> Repo.all()
    |> Enum.map(&load_equips(&1))
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

  def delete(%Schema.Character{} = character), do: Repo.delete(character)

  def preload(%Schema.Character{} = character, assocs, opts \\ []) do
    Repo.preload(character, assocs, opts)
  end

  def load_equips(%Schema.Character{} = character) do
    %{character | equips: Context.Equips.list(character)}
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

  def maybe_discover_map(%Schema.Character{discovered_maps: maps} = character, new_map) do
    if Enum.member?(maps, new_map) do
      character
    else
      maps = [new_map | maps]
      {:ok, character} = __MODULE__.update(character, %{discovered_maps: maps})
      character
    end
  end
end
