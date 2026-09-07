defmodule Ms2ex.Context.Guilds do
  @moduledoc """
  Database context for the Guild System.
  """

  import Ecto.Query

  alias Ms2ex.Enums
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @default_capacity 60
  @all_focus 0x7FFFFFFF

  @doc """
  Gets a guild by ID, preloading members, leader, and applications.
  """
  @spec get(integer()) :: Schema.Guild.t() | nil
  def get(guild_id) when is_integer(guild_id) do
    Schema.Guild
    |> where([g], g.id == ^guild_id)
    |> preload([:leader, :members, :applications])
    |> Repo.one()
  end

  def get(_), do: nil

  @doc """
  Gets a guild by its name.
  """
  @spec get_by_name(String.t()) :: Schema.Guild.t() | nil
  def get_by_name(name) when is_binary(name) do
    Schema.Guild
    |> where([g], fragment("lower(?) = lower(?)", g.name, ^name))
    |> preload([:leader, :members, :applications])
    |> Repo.one()
  end

  def get_by_name(_), do: nil

  @doc """
  Finds the guild that a character belongs to.
  """
  @spec get_by_character_id(integer()) :: Schema.Guild.t() | nil
  def get_by_character_id(character_id) when is_integer(character_id) do
    Schema.GuildMember
    |> where([m], m.character_id == ^character_id)
    |> select([m], m.guild_id)
    |> Repo.one()
    |> case do
      nil -> nil
      guild_id -> get(guild_id)
    end
  end

  def get_by_character_id(_), do: nil

  @doc """
  Creates a new guild with the given leader character as Master (rank 0).
  """
  @spec create(Schema.Character.t(), String.t(), keyword()) ::
          {:ok, Schema.Guild.t()} | {:error, atom() | Ecto.Changeset.t()}
  def create(%Schema.Character{} = leader, name, opts \\ []) do
    name = String.trim(name)
    focus = focus_value(Keyword.get(opts, :focus, 0))

    cond do
      name == "" or String.length(name) < 2 or String.length(name) > 20 ->
        {:error, :s_guild_err_name_value}

      get_by_name(name) != nil ->
        {:error, :s_guild_err_name_exist}

      get_by_character_id(leader.id) != nil ->
        {:error, :s_guild_err_already_exist}

      true ->
        do_create_guild(leader, name, focus)
    end
  end

  defp do_create_guild(leader, name, focus) do
    guild_attrs = %{
      name: name,
      leader_id: leader.id,
      focus: focus,
      capacity: @default_capacity,
      ranks: Types.GuildRank.default_ranks(),
      buffs: [],
      posters: [],
      npcs: [],
      bank: []
    }

    result =
      Repo.transaction(fn ->
        with {:ok, guild} <- %Schema.Guild{} |> Schema.Guild.changeset(guild_attrs) |> Repo.insert(),
             member_attrs = %{guild_id: guild.id, character_id: leader.id, rank: 0},
             {:ok, member} <-
               %Schema.GuildMember{} |> Schema.GuildMember.changeset(member_attrs) |> Repo.insert() do
          # Delete any pending applications for the leader
          delete_all_applications_for_character(leader.id)
          %{guild | members: [member], leader: leader, applications: []}
        else
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)

    case result do
      {:ok, guild} -> {:ok, guild}
      {:error, _changeset} -> {:error, :s_guild_err_unknown}
    end
  end

  @doc """
  Disbands a guild.
  """
  @spec delete(integer()) :: {:ok, integer()} | {:error, atom()}
  def delete(guild_id) when is_integer(guild_id) do
    case Repo.get(Schema.Guild, guild_id) do
      nil ->
        {:error, :s_guild_err_null_guild}

      guild ->
        case Repo.delete(guild) do
          {:ok, _} -> {:ok, guild_id}
          {:error, _} -> {:error, :s_guild_err_unknown}
        end
    end
  end

  @doc """
  Adds a character as a member to a guild.
  """
  @spec add_member(integer(), integer(), integer()) ::
          {:ok, Schema.GuildMember.t()} | {:error, atom() | Ecto.Changeset.t()}
  def add_member(guild_id, character_id, rank \\ 4) do
    attrs = %{guild_id: guild_id, character_id: character_id, rank: rank}

    Repo.transaction(fn ->
      delete_all_applications_for_character(character_id)

      case %Schema.GuildMember{} |> Schema.GuildMember.changeset(attrs) |> Repo.insert() do
        {:ok, member} -> member
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Removes a member from a guild.
  """
  @spec remove_member(integer(), integer()) :: {:ok, integer()} | {:error, atom()}
  def remove_member(guild_id, character_id) do
    Schema.GuildMember
    |> where([m], m.guild_id == ^guild_id and m.character_id == ^character_id)
    |> Repo.delete_all()
    |> case do
      {1, _} -> {:ok, character_id}
      _ -> {:error, :s_guild_err_not_join_member}
    end
  end

  @doc """
  Updates a guild member record (rank, message, contributions, checkin/donation timestamps).
  """
  @spec update_member(integer(), integer(), map()) ::
          {:ok, Schema.GuildMember.t()} | {:error, atom() | Ecto.Changeset.t()}
  def update_member(guild_id, character_id, attrs) do
    Schema.GuildMember
    |> where([m], m.guild_id == ^guild_id and m.character_id == ^character_id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :s_guild_err_null_member}

      member ->
        member
        |> Schema.GuildMember.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates guild attributes.
  """
  @spec update_guild(Schema.Guild.t() | integer(), map()) ::
          {:ok, Schema.Guild.t()} | {:error, atom() | Ecto.Changeset.t()}
  def update_guild(%Schema.Guild{} = guild, attrs) do
    guild
    |> Schema.Guild.changeset(attrs)
    |> Repo.update()
  end

  def update_guild(guild_id, attrs) when is_integer(guild_id) do
    case Repo.get(Schema.Guild, guild_id) do
      nil -> {:error, :s_guild_err_null_guild}
      guild -> update_guild(guild, attrs)
    end
  end

  @doc """
  Searches guilds by focus.
  """
  @spec search_guilds(atom() | integer(), integer(), integer()) :: [Schema.Guild.t()]
  def search_guilds(focus \\ 0, page \\ 1, page_size \\ 10) do
    offset = max(page - 1, 0) * page_size
    focus_val = focus_value(focus)

    query =
      Schema.Guild
      |> order_by([g], desc: g.experience, desc: g.id)
      |> limit(^page_size)
      |> offset(^offset)
      |> preload([:leader, :members])

    query =
      if focus_val in [0, @all_focus] do
        query
      else
        where(query, [g], fragment("(? & ?) > 0", g.focus, ^focus_val))
      end

    Repo.all(query)
  end

  defp focus_value(focus) when is_atom(focus), do: Enums.GuildFocus.get_value(focus) || 0
  defp focus_value(focus) when is_integer(focus), do: focus
  defp focus_value(_), do: 0

  @doc """
  Searches guilds by name prefix/substring.
  """
  @spec search_guilds_by_name(String.t(), integer(), integer()) :: [Schema.Guild.t()]
  def search_guilds_by_name(name, page \\ 1, page_size \\ 10) do
    offset = max(page - 1, 0) * page_size
    pattern = "%#{String.trim(name)}%"

    Schema.Guild
    |> where([g], ilike(g.name, ^pattern))
    |> order_by([g], desc: g.experience, desc: g.id)
    |> limit(^page_size)
    |> offset(^offset)
    |> preload([:leader, :members])
    |> Repo.all()
  end

  # ---- Applications ----

  @doc """
  Lists applications for a guild.
  """
  @spec list_applications(integer()) :: [Schema.GuildApplication.t()]
  def list_applications(guild_id) when is_integer(guild_id) do
    Schema.GuildApplication
    |> where([a], a.guild_id == ^guild_id)
    |> order_by([a], desc: a.inserted_at)
    |> preload([:character, :account])
    |> Repo.all()
  end

  @doc """
  Creates an application to join a guild.
  """
  @spec create_application(integer(), integer(), integer()) ::
          {:ok, Schema.GuildApplication.t()} | {:error, atom()}
  def create_application(guild_id, character_id, account_id) do
    # Check if max requests reached (max 10 applications per character)
    count =
      Schema.GuildApplication
      |> where([a], a.character_id == ^character_id)
      |> select([a], count(a.id))
      |> Repo.one() || 0

    already_applied? =
      Schema.GuildApplication
      |> where([a], a.guild_id == ^guild_id and a.character_id == ^character_id)
      |> Repo.exists?()

    cond do
      count >= 10 ->
        {:error, :s_guild_search_max_join_request}

      already_applied? ->
        {:error, :s_guild_search_last_request}

      true ->
        attrs = %{guild_id: guild_id, character_id: character_id, account_id: account_id}

        case %Schema.GuildApplication{}
             |> Schema.GuildApplication.changeset(attrs)
             |> Repo.insert() do
          {:ok, app} -> {:ok, Repo.preload(app, [:character, :account, :guild])}
          {:error, _} -> {:error, :s_guild_search_null_join_guild_request}
        end
    end
  end

  @doc """
  Deletes an application by ID.
  """
  @spec delete_application(integer()) :: {:ok, integer()} | {:error, atom()}
  def delete_application(application_id) when is_integer(application_id) do
    case Repo.get(Schema.GuildApplication, application_id) do
      nil ->
        {:error, :s_guild_search_null_join_guild_request}

      app ->
        case Repo.delete(app) do
          {:ok, _} -> {:ok, application_id}
          {:error, _} -> {:error, :s_guild_err_unknown}
        end
    end
  end

  @doc """
  Deletes an application for a character in a guild.
  """
  @spec delete_application_for_character(integer(), integer()) :: :ok
  def delete_application_for_character(guild_id, character_id) do
    Schema.GuildApplication
    |> where([a], a.guild_id == ^guild_id and a.character_id == ^character_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Deletes all applications from a character across all guilds.
  """
  @spec delete_all_applications_for_character(integer()) :: :ok
  def delete_all_applications_for_character(character_id) do
    Schema.GuildApplication
    |> where([a], a.character_id == ^character_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Lists applied guilds for a character.
  """
  @spec list_character_applications(integer()) :: [Schema.GuildApplication.t()]
  def list_character_applications(character_id) when is_integer(character_id) do
    Schema.GuildApplication
    |> where([a], a.character_id == ^character_id)
    |> preload([:character, :account])
    |> Repo.all()
  end
end
