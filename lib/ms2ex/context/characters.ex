defmodule Ms2ex.Context.Characters do
  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema

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
    character = Repo.preload(character, :stats, force: true)
    equips = Context.Equips.list(character)
    stats = aggregate_equip_stats(character.stats, equips)
    gear_score = calculate_gear_score(equips)
    %{character | equips: equips, stats: stats, gear_score: gear_score}
  end

  defp calculate_gear_score(equips) do
    Enum.reduce(equips, 0, fn item, total ->
      score = get_in(item.metadata, [:property, :gear_score]) || 0
      score = if get_in(item.metadata, [:property, :type]) in [:dagger, :throwing_star], do: div(score, 2), else: score
      total + score
    end)
  end

  defp aggregate_equip_stats(nil, _equips), do: nil

  defp aggregate_equip_stats(stats, equips) do
    values =
      equips
      |> Enum.flat_map(fn item ->
        item.stats
        |> Map.take([:constants, :statics, :randoms, :enchants, :limit_break_enchants])
        |> Map.values()
        |> Enum.flat_map(&Map.values/1)
      end)
      |> Enum.filter(fn
        %Ms2ex.Types.ItemStat{class: :basic, type: :flat} -> true
        _ -> false
      end)
      |> Enum.reduce(%{}, fn
        %Ms2ex.Types.ItemStat{attribute: attribute, value: value}, acc ->
          Map.update(acc, attribute, trunc(value), &(&1 + trunc(value)))
      end)

    Enum.reduce(values, stats, fn {attribute, value}, stats ->
      fields =
        Enum.map([:min, :cur, :max], &String.to_atom("#{attribute}_#{&1}"))

      if Enum.all?(fields, &Map.has_key?(stats, &1)) do
        Enum.reduce(fields, stats, fn field, stats ->
          Map.update!(stats, field, fn current -> trunc(current) + trunc(value) end)
        end)
      else
        stats
      end
    end)
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
