defmodule Ms2ex.Managers.GuildServer do
  @moduledoc """
  GenServer that owns the runtime state and member broadcasts of an active guild.
  """

  use GenServer
  use Ms2ex.Managers.Managed, prefix: "guild", key: :id

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Net.SenderSession
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types
  alias Phoenix.PubSub

  defstruct [
    :id,
    :guild,
    members: %{},
    pending_invites: %{}
  ]

  # ---- Client API ----

  def start(guild_id) when is_integer(guild_id) do
    case GenServer.start(__MODULE__, guild_id, name: process_name(guild_id)) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  def lookup(guild_id), do: call(guild_id, :lookup)

  def topic(guild_id), do: "guild:#{guild_id}"

  def broadcast(guild_id, packet) do
    PubSub.broadcast(Ms2ex.PubSub, topic(guild_id), {:push, packet})
  end

  def broadcast_from(sender_pid, guild_id, packet) do
    PubSub.broadcast_from(Ms2ex.PubSub, sender_pid, topic(guild_id), {:push, packet})
  end

  def subscribe(guild_id) do
    PubSub.subscribe(Ms2ex.PubSub, topic(guild_id))
  end

  def unsubscribe(guild_id) do
    PubSub.unsubscribe(Ms2ex.PubSub, topic(guild_id))
  end

  def member_online(guild_id, character) do
    call(guild_id, {:member_online, character})
  end

  def member_offline(guild_id, character) do
    call(guild_id, {:member_offline, character})
  end

  def update_member_map(guild_id, character_id, map_id) do
    call(guild_id, {:update_member_map, character_id, map_id})
  end

  def invite(guild_id, requestor_id, target_name) do
    call(guild_id, {:invite, requestor_id, target_name})
  end

  def respond_invite(guild_id, character, accepted?) do
    call(guild_id, {:respond_invite, character, accepted?})
  end

  def leave(guild_id, character_id) do
    call(guild_id, {:leave, character_id})
  end

  def expel(guild_id, requestor_id, target_name) do
    call(guild_id, {:expel, requestor_id, target_name})
  end

  def update_member_rank(guild_id, requestor_id, target_name, rank_id) do
    call(guild_id, {:update_member_rank, requestor_id, target_name, rank_id})
  end

  def update_member_message(guild_id, character_id, message) do
    call(guild_id, {:update_member_message, character_id, message})
  end

  def check_in(guild_id, character) do
    call(guild_id, {:check_in, character})
  end

  def donate(guild_id, character, count) do
    call(guild_id, {:donate, character, count})
  end

  def update_leader(guild_id, requestor_id, new_leader_name) do
    call(guild_id, {:update_leader, requestor_id, new_leader_name})
  end

  def update_notice(guild_id, requestor_id, notice) do
    call(guild_id, {:update_notice, requestor_id, notice})
  end

  def update_emblem(guild_id, requestor_id, emblem) do
    call(guild_id, {:update_emblem, requestor_id, emblem})
  end

  def update_focus(guild_id, requestor_id, focus) do
    call(guild_id, {:update_focus, requestor_id, focus})
  end

  def update_rank_def(guild_id, requestor_id, rank) do
    call(guild_id, {:update_rank_def, requestor_id, rank})
  end

  def add_or_update_poster(guild_id, poster) do
    call(guild_id, {:add_or_update_poster, poster})
  end

  def apply_to_guild(guild_id, character) do
    call(guild_id, {:apply, character})
  end

  def respond_application(guild_id, requestor_id, application_id, accepted?) do
    call(guild_id, {:respond_application, requestor_id, application_id, accepted?})
  end

  def list_applications(guild_id) do
    call(guild_id, :list_applications)
  end

  def upgrade_house_rank(guild_id, requestor_id, rank) do
    call(guild_id, {:upgrade_house_rank, requestor_id, rank})
  end

  def upgrade_house_theme(guild_id, requestor_id, theme) do
    call(guild_id, {:upgrade_house_theme, requestor_id, theme})
  end

  def use_buff(guild_id, requestor_id, buff_id) do
    call(guild_id, {:use_buff, requestor_id, buff_id})
  end

  def use_personal_buff(guild_id, requestor_id, buff_id) do
    call(guild_id, {:use_personal_buff, requestor_id, buff_id})
  end

  def upgrade_buff(guild_id, requestor_id, buff_id) do
    call(guild_id, {:upgrade_buff, requestor_id, buff_id})
  end

  def upgrade_npc(guild_id, requestor_id, npc_type) do
    call(guild_id, {:upgrade_npc, requestor_id, npc_type})
  end

  # ---- Server Callbacks ----

  @impl true
  def init(guild_id) do
    case Context.Guilds.get(guild_id) do
      nil ->
        {:stop, :normal}

      %Schema.Guild{} = guild ->
        members = build_initial_members(guild)
        {:ok, %__MODULE__{id: guild_id, guild: guild, members: members}}
    end
  end

  @impl true
  def handle_call(:lookup, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:member_online, character}, _from, state) do
    case Map.get(state.members, character.id) do
      nil ->
        {:reply, :error, state}

      member ->
        updated_member =
          member
          |> Map.put(:online?, true)
          |> Map.put(:level, character.level)
          |> Map.put(:job, character.job)
          |> Map.put(:map_id, character.map_id)
          |> Map.put(:channel, character.channel_id || 1)
          |> Map.put(:sender_session_pid, character.sender_session_pid)
          |> Map.put(:session_pid, character.session_pid)
          |> Map.put(:last_online_time, DateTime.utc_now() |> DateTime.to_unix())

        members = Map.put(state.members, character.id, updated_member)
        state = %{state | members: members}

        broadcast(state.id, Packets.Guild.notify_login(character.name))
        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:member_offline, character}, _from, state) do
    case Map.get(state.members, character.id) do
      nil ->
        {:reply, :error, state}

      member ->
        now_unix = DateTime.utc_now() |> DateTime.to_unix()

        updated_member =
          member
          |> Map.put(:online?, false)
          |> Map.put(:sender_session_pid, nil)
          |> Map.put(:session_pid, nil)
          |> Map.put(:last_online_time, now_unix)

        members = Map.put(state.members, character.id, updated_member)
        state = %{state | members: members}

        broadcast(state.id, Packets.Guild.notify_logout(character.name, now_unix))
        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:update_member_map, character_id, map_id}, _from, state) do
    case Map.get(state.members, character_id) do
      nil ->
        {:reply, :error, state}

      member ->
        updated_member = Map.put(member, :map_id, map_id)
        members = Map.put(state.members, character_id, updated_member)
        state = %{state | members: members}

        broadcast(state.id, Packets.Guild.update_member_map(member.name, map_id))
        {:reply, :ok, state}
    end
  end

  def handle_call({:invite, requestor_id, target_name}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :invite_members),
         :ok <- check_capacity(state),
         {:ok, target} <- Managers.Character.lookup_by_name(target_name),
         :ok <- check_not_in_guild(state, target.id) do
      # Set pending invite
      pending = Map.put(state.pending_invites, target.id, requestor.name)
      state = %{state | pending_invites: pending}

      invite_info = %Types.GuildInvite{
        guild_id: state.id,
        guild_name: state.guild.name,
        sender_id: requestor.character_id,
        sender_name: requestor.name
      }

      SenderSession.push(target, Packets.Guild.invite_info(invite_info))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
      :error -> {:reply, {:error, :s_guild_err_null_user}, state}
    end
  end

  def handle_call({:respond_invite, character, accepted?}, _from, state) do
    case Map.get(state.pending_invites, character.id) do
      nil ->
        {:reply, {:error, :s_guild_err_null_invite_member}, state}

      requestor_name ->
        pending = Map.delete(state.pending_invites, character.id)
        state = %{state | pending_invites: pending}

        if accepted? do
          execute_accept_invite(state, character, requestor_name)
        else
          broadcast(state.id, Packets.Guild.notify_invite(character.name, :reject))
          {:reply, :ok, state}
        end
    end
  end

  def handle_call({:leave, character_id}, _from, state) do
    if character_id == state.guild.leader_id do
      {:reply, {:error, :s_guild_err_cannot_leave_master}, state}
    else
      case Map.get(state.members, character_id) do
        nil ->
          {:reply, {:error, :s_guild_err_not_join_member}, state}

        member ->
          Context.Guilds.remove_member(state.id, character_id)
          Managers.GuildManager.unregister(character_id)

          members = Map.delete(state.members, character_id)
          state = %{state | members: members}

          broadcast(state.id, Packets.Guild.notify_leave(member.name))
          {:reply, :ok, state}
      end
    end
  end

  def handle_call({:expel, requestor_id, target_name}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :expel_members),
         {:ok, target} <- find_member_by_name(state, target_name) do
      execute_expel(state, requestor, target)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_member_rank, requestor_id, target_name, new_rank_id}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :edit_rank),
         {:ok, target} <- find_member_by_name(state, target_name) do
      cond do
        target.rank == new_rank_id ->
          {:reply, {:error, :s_guild_err_set_grade_failed}, state}

        new_rank_id < 0 or new_rank_id > 4 ->
          {:reply, {:error, :s_guild_err_invalid_grade_index}, state}

        true ->
          Context.Guilds.update_member(state.id, target.character_id, %{rank: new_rank_id})
          updated_target = Map.put(target, :rank, new_rank_id)
          members = Map.put(state.members, target.character_id, updated_target)
          state = %{state | members: members}

          broadcast(
            state.id,
            Packets.Guild.notify_update_member_rank(requestor.name, target.name, new_rank_id)
          )

          {:reply, :ok, state}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_member_message, character_id, message}, _from, state) do
    case Map.get(state.members, character_id) do
      nil ->
        {:reply, {:error, :s_guild_err_null_member}, state}

      member ->
        message = String.slice(message || "", 0, 50)
        Context.Guilds.update_member(state.id, character_id, %{message: message})
        updated_member = Map.put(member, :message, message)
        members = Map.put(state.members, character_id, updated_member)
        state = %{state | members: members}

        broadcast(state.id, Packets.Guild.notify_update_member_message(updated_member))
        {:reply, :ok, state}
    end
  end

  def handle_call({:check_in, character}, _from, state) do
    case Map.get(state.members, character.id) do
      nil ->
        {:reply, {:error, :s_guild_err_null_member}, state}

      member ->
        today = Date.utc_today()

        last_checkin_date =
          member.checkin_time > 0 &&
            DateTime.from_unix!(member.checkin_time) |> DateTime.to_date()

        if last_checkin_date == today do
          {:reply, {:error, :already_checked_in}, state}
        else
          execute_check_in(state, character, member)
        end
    end
  end

  def handle_call({:donate, character, count}, _from, state) do
    case Map.get(state.members, character.id) do
      nil ->
        {:reply, {:error, :s_guild_err_null_member}, state}

      member ->
        prop = Storage.Tables.Guild.property_for_exp(state.guild.experience)

        if member.daily_donation_count + count > prop.donate_max do
          {:reply, {:error, :s_guild_err_no_authority}, state}
        else
          execute_donation(state, character, member, count, prop)
        end
    end
  end

  def handle_call({:update_leader, requestor_id, new_leader_name}, _from, state) do
    if requestor_id != state.guild.leader_id do
      {:reply, {:error, :s_guild_err_no_master}, state}
    else
      execute_leader_transfer(state, requestor_id, new_leader_name)
    end
  end

  def handle_call({:update_notice, requestor_id, notice}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :edit_notice) do
      Context.Guilds.update_guild(state.id, %{notice: notice})
      guild = %{state.guild | notice: notice}
      state = %{state | guild: guild}

      broadcast(state.id, Packets.Guild.notify_update_notice(requestor.name, 1, notice))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_emblem, requestor_id, emblem}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :edit_emblem) do
      Context.Guilds.update_guild(state.id, %{emblem: emblem})
      guild = %{state.guild | emblem: emblem}
      state = %{state | guild: guild}

      broadcast(state.id, Packets.Guild.notify_update_emblem(requestor.name, emblem))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_focus, requestor_id, focus}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :edit_notice) do
      focus_atom = if is_integer(focus), do: Enums.GuildFocus.get_key(focus), else: focus
      Context.Guilds.update_guild(state.id, %{focus: focus_atom})
      guild = %{state.guild | focus: focus_atom}
      state = %{state | guild: guild}

      broadcast(state.id, Packets.Guild.notify_update_focus(requestor.name, true, focus))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_rank_def, requestor_id, rank}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :edit_rank) do
      ranks = update_rank_list(state.guild.ranks, rank)
      Context.Guilds.update_guild(state.id, %{ranks: ranks})
      guild = %{state.guild | ranks: ranks}
      state = %{state | guild: guild}

      broadcast(state.id, Packets.Guild.notify_update_rank(requestor.name, rank))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:add_or_update_poster, poster}, _from, state) do
    posters =
      state.guild.posters
      |> Enum.reject(&(&1.id == poster.id))
      |> Kernel.++([poster])

    Context.Guilds.update_guild(state.id, %{posters: posters})
    guild = %{state.guild | posters: posters}
    state = %{state | guild: guild}

    broadcast(state.id, Packets.Guild.update_poster(poster))
    {:reply, :ok, state}
  end

  def handle_call({:apply, character}, _from, state) do
    case Context.Guilds.create_application(state.id, character.id, character.account_id) do
      {:ok, application} ->
        broadcast(state.id, Packets.Guild.receive_application(application))
        {:reply, {:ok, application}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:respond_application, requestor_id, application_id, accepted?}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :invite_members),
         application when not is_nil(application) <-
           Repo.get(Schema.GuildApplication, application_id),
         true <- application.guild_id == state.id do
      Context.Guilds.delete_application(application_id)

      if accepted? do
        process_accept_application(state, requestor, application)
      else
        process_reject_application(state, requestor, application)
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
      _ -> {:reply, {:error, :s_guild_search_null_join_guild_request}, state}
    end
  end

  def handle_call(:list_applications, _from, state) do
    apps = Context.Guilds.list_applications(state.id)
    {:reply, {:ok, apps}, state}
  end

  def handle_call({:upgrade_house_rank, requestor_id, rank}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :edit_notice) do
      Context.Guilds.update_guild(state.id, %{house_rank: rank})
      guild = %{state.guild | house_rank: rank}
      state = %{state | guild: guild}

      broadcast(state.id, Packets.Guild.upgrade_house(requestor.name, rank, guild.house_theme))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:upgrade_house_theme, requestor_id, theme}, _from, state) do
    with {:ok, requestor} <- get_member(state, requestor_id),
         :ok <- check_permission(state, requestor, :edit_notice) do
      Context.Guilds.update_guild(state.id, %{house_theme: theme})
      guild = %{state.guild | house_theme: theme}
      state = %{state | guild: guild}

      broadcast(state.id, Packets.Guild.upgrade_house(requestor.name, guild.house_rank, theme))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:use_buff, _requestor_id, _buff_id}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:use_personal_buff, _requestor_id, _buff_id}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:upgrade_buff, _requestor_id, _buff_id}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:upgrade_npc, _requestor_id, _npc_type}, _from, state) do
    {:reply, :ok, state}
  end

  # ---- Helpers ----

  defp execute_accept_invite(state, character, requestor_name) do
    with :ok <- check_capacity(state),
         {:ok, member_schema} <- Context.Guilds.add_member(state.id, character.id, 4) do
      member_data = build_member_data(member_schema, character)
      members = Map.put(state.members, character.id, member_data)
      state = %{state | members: members}

      Managers.GuildManager.register(state.id, character.id)

      broadcast(state.id, Packets.Guild.joined(requestor_name, member_data))
      {:reply, {:ok, state}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp execute_expel(state, requestor, target) do
    cond do
      target.character_id == state.guild.leader_id ->
        {:reply, {:error, :s_guild_err_expel_target_master}, state}

      target.rank <= requestor.rank ->
        {:reply, {:error, :s_guild_err_no_authority}, state}

      true ->
        Context.Guilds.remove_member(state.id, target.character_id)
        Managers.GuildManager.unregister(target.character_id)

        members = Map.delete(state.members, target.character_id)
        state = %{state | members: members}

        if target.online? and target.sender_session_pid do
          SenderSession.push(
            target.sender_session_pid,
            Packets.Guild.notify_expel(requestor.name)
          )
        end

        broadcast(state.id, Packets.Guild.notify_expel_member(requestor.name, target.name))
        {:reply, :ok, state}
    end
  end

  defp execute_leader_transfer(state, requestor_id, new_leader_name) do
    with {:ok, old_leader} <- get_member(state, requestor_id),
         {:ok, new_leader} <- find_member_by_name(state, new_leader_name) do
      Context.Guilds.update_guild(state.id, %{leader_id: new_leader.character_id})
      Context.Guilds.update_member(state.id, old_leader.character_id, %{rank: 1})
      Context.Guilds.update_member(state.id, new_leader.character_id, %{rank: 0})

      updated_old = Map.put(old_leader, :rank, 1)
      updated_new = Map.put(new_leader, :rank, 0)

      members =
        state.members
        |> Map.put(old_leader.character_id, updated_old)
        |> Map.put(new_leader.character_id, updated_new)

      guild = %{state.guild | leader_id: new_leader.character_id}
      state = %{state | guild: guild, members: members}

      broadcast(state.id, Packets.Guild.notify_update_leader(old_leader.name, new_leader.name))
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp execute_check_in(state, character, member) do
    prop = Storage.Tables.Guild.property_for_exp(state.guild.experience)
    now_unix = DateTime.utc_now() |> DateTime.to_unix()
    contribution = 10

    new_exp = state.guild.experience + prop.check_in_exp
    new_funds = min(state.guild.funds + prop.check_in_fund, prop.fund_max)

    Context.Guilds.update_guild(state.id, %{experience: new_exp, funds: new_funds})

    Context.Guilds.update_member(state.id, character.id, %{
      weekly_contribution: member.weekly_contribution + contribution,
      total_contribution: member.total_contribution + contribution,
      checkin_at: DateTime.utc_now()
    })

    updated_member =
      member
      |> Map.put(:weekly_contribution, member.weekly_contribution + contribution)
      |> Map.put(:total_contribution, member.total_contribution + contribution)
      |> Map.put(:checkin_time, now_unix)

    members = Map.put(state.members, character.id, updated_member)
    guild = %{state.guild | experience: new_exp, funds: new_funds}
    state = %{state | guild: guild, members: members}

    broadcast(state.id, Packets.Guild.guild_experience(new_exp))
    broadcast(state.id, Packets.Guild.guild_funds(new_funds))
    broadcast(state.id, Packets.Guild.guild_contribution(updated_member, contribution))
    broadcast(state.id, Packets.Guild.update_member(updated_member))

    {:reply, {:ok, prop}, state}
  end

  defp execute_donation(state, character, member, count, prop) do
    now_unix = DateTime.utc_now() |> DateTime.to_unix()
    contribution = 10 * count
    new_exp = state.guild.experience + prop.check_in_exp * count
    new_funds = min(state.guild.funds + prop.check_in_fund * count, prop.fund_max)

    Context.Guilds.update_guild(state.id, %{experience: new_exp, funds: new_funds})

    Context.Guilds.update_member(state.id, character.id, %{
      weekly_contribution: member.weekly_contribution + contribution,
      total_contribution: member.total_contribution + contribution,
      daily_donation_count: member.daily_donation_count + count,
      donation_at: DateTime.utc_now()
    })

    updated_member =
      member
      |> Map.put(:weekly_contribution, member.weekly_contribution + contribution)
      |> Map.put(:total_contribution, member.total_contribution + contribution)
      |> Map.put(:daily_donation_count, member.daily_donation_count + count)
      |> Map.put(:donation_time, now_unix)

    members = Map.put(state.members, character.id, updated_member)
    guild = %{state.guild | experience: new_exp, funds: new_funds}
    state = %{state | guild: guild, members: members}

    broadcast(state.id, Packets.Guild.guild_experience(new_exp))
    broadcast(state.id, Packets.Guild.guild_funds(new_funds))
    broadcast(state.id, Packets.Guild.guild_contribution(updated_member, contribution))
    broadcast(state.id, Packets.Guild.update_member(updated_member))

    {:reply, {:ok, prop}, state}
  end

  defp process_accept_application(state, requestor, application) do
    with :ok <- check_capacity(state),
         {:ok, member_schema} <-
           Context.Guilds.add_member(state.id, application.character_id, 4),
         %Schema.Character{} = applicant_char <-
           Context.Characters.get(application.character_id) do
      member_data = build_member_data(member_schema, applicant_char)
      members = Map.put(state.members, applicant_char.id, member_data)
      state = %{state | members: members}

      Managers.GuildManager.register(state.id, applicant_char.id)

      broadcast(
        state.id,
        Packets.Guild.notify_application(
          requestor.name,
          applicant_char.name,
          application.id,
          true
        )
      )

      broadcast(state.id, Packets.Guild.joined(requestor.name, member_data))

      if applicant_char.online? and applicant_char.sender_session_pid do
        SenderSession.push(
          applicant_char.sender_session_pid,
          Packets.Guild.notify_applicant(state.guild.name, application.id, true)
        )
      end

      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp process_reject_application(state, requestor, application) do
    applicant_name =
      case Context.Characters.get(application.character_id) do
        %Schema.Character{name: n} -> n
        _ -> ""
      end

    broadcast(
      state.id,
      Packets.Guild.notify_application(
        requestor.name,
        applicant_name,
        application.id,
        false
      )
    )

    {:reply, :ok, state}
  end

  defp get_member(state, character_id) do
    case Map.get(state.members, character_id) do
      nil -> {:error, :s_guild_err_null_member}
      member -> {:ok, member}
    end
  end

  defp find_member_by_name(state, name) do
    name_down = String.downcase(name)

    state.members
    |> Map.values()
    |> Enum.find(&(String.downcase(&1.name) == name_down))
    |> case do
      nil -> {:error, :s_guild_err_null_member}
      member -> {:ok, member}
    end
  end

  defp check_permission(state, member, flag) do
    rank = Enum.find(state.guild.ranks, &(&1.id == member.rank))

    if rank && Types.GuildRank.has_permission?(rank, flag) do
      :ok
    else
      {:error, :s_guild_err_no_authority}
    end
  end

  defp check_capacity(state) do
    if map_size(state.members) >= state.guild.capacity do
      {:error, :s_guild_err_full_member}
    else
      :ok
    end
  end

  defp check_not_in_guild(state, character_id) do
    if Map.has_key?(state.members, character_id) do
      {:error, :s_guild_err_already_exist}
    else
      :ok
    end
  end

  defp build_initial_members(%Schema.Guild{} = guild) do
    Enum.reduce(guild.members, %{}, fn member, acc ->
      char =
        case Context.Characters.get(member.character_id) do
          %Schema.Character{} = c -> c
          _ -> %Schema.Character{id: member.character_id, name: "", gender: :male}
        end

      member_data = build_member_data(member, char)
      Map.put(acc, member.character_id, member_data)
    end)
  end

  defp build_member_data(member_schema, %Schema.Character{} = char) do
    base = %{
      guild_id: member_schema.guild_id,
      character_id: member_schema.character_id,
      account_id: char.account_id || 0,
      name: char.name,
      gender: char.gender || :male,
      rank: member_schema.rank,
      message: member_schema.message || "",
      join_time: unix_or_now(member_schema.inserted_at),
      last_online_time: unix_or_now(char.updated_at),
      checkin_time: unix_or_zero(member_schema.checkin_at),
      donation_time: unix_or_zero(member_schema.donation_at),
      weekly_contribution: member_schema.weekly_contribution || 0,
      total_contribution: member_schema.total_contribution || 0,
      daily_donation_count: member_schema.daily_donation_count || 0,
      plot_map_id: 0,
      plot_number: 0,
      apartment_number: 0,
      plot_expiry_time: 0
    }

    Map.merge(base, resolve_online_info(char))
  end

  defp resolve_online_info(%Schema.Character{id: char_id} = char) do
    case Managers.Character.lookup(char_id) do
      {:ok, online_char} -> extract_online_char_info(online_char)
      _ -> extract_offline_char_info(char)
    end
  end

  defp extract_online_char_info(char) do
    %{
      online?: true,
      name: char.name,
      gender: char.gender || :male,
      level: char.level,
      job: char.job,
      map_id: char.map_id,
      channel: char.channel_id || 1,
      profile_url: char.profile_url || "",
      gear_score: char.gear_score || 0,
      trophies: char.trophies || [0, 0, 0],
      session_pid: char.session_pid,
      sender_session_pid: char.sender_session_pid
    }
  end

  defp extract_offline_char_info(char) do
    %{
      online?: false,
      name: char.name,
      gender: char.gender || :male,
      level: char.level || 1,
      job: char.job || :beginner,
      map_id: char.map_id || 1,
      channel: 1,
      profile_url: char.profile_url || "",
      gear_score: char.gear_score || 0,
      trophies: char.trophies || [0, 0, 0],
      session_pid: nil,
      sender_session_pid: nil
    }
  end

  defp update_rank_list(ranks, rank) do
    Enum.map(ranks, fn r ->
      if r.id == rank.id, do: rank, else: r
    end)
  end

  defp unix_or_now(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp unix_or_now(_), do: DateTime.utc_now() |> DateTime.to_unix()

  defp unix_or_zero(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp unix_or_zero(_), do: 0
end
