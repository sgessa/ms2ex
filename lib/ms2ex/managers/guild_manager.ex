defmodule Ms2ex.Managers.GuildManager do
  @moduledoc """
  Global registry and coordinator for Guild servers and member routing.
  """

  use GenServer

  alias Ms2ex.Context
  alias Ms2ex.Managers.GuildServer
  alias Ms2ex.Schema

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def lookup_by_character(character_id) when is_integer(character_id) do
    call({:lookup_by_character, character_id})
  end

  def lookup_by_character(%Schema.Character{id: id}), do: lookup_by_character(id)

  def get_or_start(guild_id) when is_integer(guild_id) do
    call({:get_or_start, guild_id})
  end

  def create(leader, name) do
    call({:create, leader, name})
  end

  def disband(guild_id) do
    call({:disband, guild_id})
  end

  def register(guild_id, character_id) do
    cast({:register, guild_id, character_id})
  end

  def unregister(character_id) do
    cast({:unregister, character_id})
  end

  # ---- Server Callbacks ----

  @impl true
  def init(:ok) do
    {:ok, %{character_guilds: %{}, guild_pids: %{}}}
  end

  @impl true
  def handle_call({:lookup_by_character, character_id}, _from, state) do
    case Map.get(state.character_guilds, character_id) do
      nil ->
        # Check database
        case Context.Guilds.get_by_character_id(character_id) do
          %Schema.Guild{id: guild_id} ->
            {:ok, pid, state} = ensure_server_started(state, guild_id)
            state = put_in(state.character_guilds[character_id], guild_id)
            {:reply, {:ok, guild_id, pid}, state}

          nil ->
            {:reply, :error, state}
        end

      guild_id ->
        {:ok, pid, state} = ensure_server_started(state, guild_id)
        {:reply, {:ok, guild_id, pid}, state}
    end
  end

  def handle_call({:get_or_start, guild_id}, _from, state) do
    case ensure_server_started(state, guild_id) do
      {:ok, pid, state} -> {:reply, {:ok, pid}, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:create, leader, name}, _from, state) do
    case Context.Guilds.create(leader, name) do
      {:ok, guild} ->
        {:ok, pid} = GuildServer.start(guild.id)
        Process.monitor(pid)

        state =
          state
          |> put_in([:guild_pids, guild.id], pid)
          |> put_in([:character_guilds, leader.id], guild.id)

        {:reply, {:ok, guild}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:disband, guild_id}, _from, state) do
    # Stop guild server if running
    case Map.get(state.guild_pids, guild_id) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    Context.Guilds.delete(guild_id)

    # Clean up state
    character_guilds =
      state.character_guilds
      |> Enum.reject(fn {_char_id, g_id} -> g_id == guild_id end)
      |> Enum.into(%{})

    guild_pids = Map.delete(state.guild_pids, guild_id)
    state = %{state | character_guilds: character_guilds, guild_pids: guild_pids}

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:register, guild_id, character_id}, state) do
    state = put_in(state.character_guilds[character_id], guild_id)
    {:noreply, state}
  end

  def handle_cast({:unregister, character_id}, state) do
    state = update_in(state.character_guilds, &Map.delete(&1, character_id))
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    guild_pids =
      state.guild_pids
      |> Enum.reject(fn {_guild_id, server_pid} -> server_pid == pid end)
      |> Enum.into(%{})

    {:noreply, %{state | guild_pids: guild_pids}}
  end

  # ---- Helpers ----

  defp ensure_server_started(state, guild_id) do
    case Map.get(state.guild_pids, guild_id) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid, state}
        else
          start_and_monitor(state, guild_id)
        end

      nil ->
        start_and_monitor(state, guild_id)
    end
  end

  defp start_and_monitor(state, guild_id) do
    case GuildServer.start(guild_id) do
      {:ok, pid} ->
        Process.monitor(pid)
        state = put_in(state.guild_pids[guild_id], pid)
        {:ok, pid, state}

      error ->
        error
    end
  end

  defp call(msg), do: GenServer.call(__MODULE__, msg)
  defp cast(msg), do: GenServer.cast(__MODULE__, msg)
end
