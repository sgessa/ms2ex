defmodule Ms2ex.Packets.Guild do
  @moduledoc """
  Packet serializer for the Guild System (SendOp 0x8C).
  """

  alias Ms2ex.Enums
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Types

  import Packets.PacketWriter

  @commands %{
    load: 0x00,
    created: 0x01,
    disbanded: 0x02,
    invited: 0x03,
    invite_info: 0x04,
    invite_reply: 0x05,
    notify_invite: 0x06,
    leave: 0x07,
    expelled: 0x08,
    notify_expel: 0x09,
    update_member_rank: 0x0A,
    update_member_message: 0x0B,
    update_member_name: 0x0C,
    checked_in: 0x0F,
    joined: 0x12,
    notify_leave: 0x13,
    notify_expel_member: 0x14,
    notify_update_member_rank: 0x15,
    notify_update_member_message: 0x16,
    notify_login: 0x17,
    notify_logout: 0x18,
    notify_update_leader: 0x19,
    notify_update_notice: 0x1A,
    notify_update_emblem: 0x1B,
    notify_update_capacity: 0x1C,
    notify_update_rank: 0x1D,
    notify_update_focus: 0x1E,
    update_member_map: 0x1F,
    update_member: 0x20,
    update_name: 0x22,
    receive_application: 0x2D,
    withdraw_application: 0x2E,
    notify_application: 0x2F,
    notify_applicant: 0x30,
    guild_experience: 0x31,
    guild_funds: 0x32,
    guild_contribution: 0x33,
    upgrade_house: 0x37,
    update_poster: 0x38,
    update_leader: 0x3D,
    update_notice: 0x3E,
    update_emblem: 0x3F,
    update_capacity: 0x40,
    update_rank: 0x41,
    update_focus: 0x42,
    add_tag: 0x4B,
    remove_tag: 0x4C,
    error: 0x4D,
    list_applications: 0x53,
    list_applied_guilds: 0x54,
    list_guilds: 0x55,
    send_application: 0x50
  }

  def load(%{guild: guild, members: members}) do
    load(guild, Map.values(members))
  end

  def load(%Schema.Guild{} = guild, members) do
    leader = guild.leader
    ranks = guild.ranks || Types.GuildRank.default_ranks()
    buffs = guild.buffs || []
    posters = guild.posters || []
    npcs = guild.npcs || []
    bank = guild.bank || []
    focus_val = focus_value(guild.focus)

    leader_account_id = if leader, do: leader.account_id, else: 0
    leader_char_id = if leader, do: leader.id, else: guild.leader_id
    leader_name = if leader, do: leader.name, else: ""

    __MODULE__
    |> build()
    |> put_byte(@commands.load)
    |> put_long(guild.id)
    |> put_ustring(guild.name)
    |> put_ustring(guild.emblem)
    |> put_byte(guild.capacity)
    |> put_ustring()
    |> put_ustring(guild.notice)
    |> put_long(leader_account_id)
    |> put_long(leader_char_id)
    |> put_ustring(leader_name)
    |> put_long(unix_or_zero(guild.inserted_at))
    |> put_byte(1)
    |> put_int(1000)
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_byte(1)
    |> put_int(focus_val)
    |> put_int(guild.experience)
    |> put_int(guild.funds)
    |> put_bool(false)
    |> put_int()
    |> put_members(members)
    |> put_ranks(ranks)
    |> put_buffs(buffs)
    # events count
    |> put_byte(0)
    |> put_int(guild.house_rank)
    |> put_int(guild.house_theme)
    |> put_posters(posters)
    |> put_npcs(npcs)
    # ShopProducts
    |> put_bool(false)
    |> put_int(length(bank))
    |> put_int()
    |> put_ustring()
    |> put_long()
    |> put_long()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
  end

  def created(guild_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.created)
    |> put_byte(0)
    |> put_ustring(guild_name)
  end

  def disbanded do
    __MODULE__
    |> build()
    |> put_byte(@commands.disbanded)
    |> put_byte(0)
  end

  def invited(player_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.invited)
    |> put_ustring(player_name)
  end

  def invite_info(%Types.GuildInvite{} = invite) do
    __MODULE__
    |> build()
    |> put_byte(@commands.invite_info)
    |> put_guild_invite(invite)
  end

  def invite_reply(%Types.GuildInvite{} = invite, accepted?) do
    __MODULE__
    |> build()
    |> put_byte(@commands.invite_reply)
    |> put_guild_invite(invite)
    |> put_bool(accepted?)
  end

  defp put_guild_invite(packet, invite) do
    packet
    |> put_long(invite.guild_id)
    |> put_ustring(invite.guild_name)
    |> put_ustring()
    |> put_ustring(invite.sender_name)
    |> put_ustring(invite.receiver_name)
  end

  def notify_invite(name, response) do
    resp_val = if response == :accept or response == 1, do: 1, else: 2

    __MODULE__
    |> build()
    |> put_byte(@commands.notify_invite)
    |> put_ustring(name)
    |> put_bool(resp_val == 1)
    |> put_byte(resp_val)
  end

  def leave do
    __MODULE__
    |> build()
    |> put_byte(@commands.leave)
  end

  def expelled(player_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.expelled)
    |> put_ustring(player_name)
  end

  def notify_expel(player_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_expel)
    |> put_ustring(player_name)
  end

  def update_member_rank(player_name, rank_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_member_rank)
    |> put_ustring(player_name)
    |> put_byte(rank_id)
  end

  def update_member_message(message) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_member_message)
    |> put_ustring(message)
  end

  def checked_in do
    __MODULE__
    |> build()
    |> put_byte(@commands.checked_in)
  end

  def joined(requestor_name, member, notify \\ true) do
    __MODULE__
    |> build()
    |> put_byte(@commands.joined)
    |> put_ustring(requestor_name)
    |> put_ustring(member.name)
    |> put_bool(notify)
    |> put_member(member)
  end

  def notify_leave(player_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_leave)
    |> put_ustring(player_name)
  end

  def notify_expel_member(requestor_name, player_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_expel_member)
    |> put_ustring(requestor_name)
    |> put_ustring(player_name)
  end

  def notify_update_member_rank(requestor_name, player_name, rank_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_member_rank)
    |> put_ustring(requestor_name)
    |> put_ustring(player_name)
    |> put_byte(rank_id)
  end

  def notify_update_member_message(member) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_member_message)
    |> put_ustring(member.name)
    |> put_ustring(member.message)
  end

  def notify_login(name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_login)
    |> put_ustring(name)
  end

  def notify_logout(name, time) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_logout)
    |> put_ustring(name)
    |> put_long(time)
  end

  def notify_update_leader(old_leader, new_leader) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_leader)
    |> put_ustring(old_leader)
    |> put_ustring(new_leader)
  end

  def notify_update_notice(requestor_name, notice_type, message) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_notice)
    |> put_ustring(requestor_name)
    |> put_byte(notice_type)
    |> put_ustring(message)
  end

  def notify_update_emblem(requestor_name, emblem) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_emblem)
    |> put_interface_text(Enums.StringCode.get_value(:s_guild_notify_change_mark), [
      requestor_name
    ])
    |> put_ustring(emblem)
  end

  def notify_update_capacity(requestor_name, capacity) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_capacity)
    |> put_ustring(requestor_name)
    |> put_int(capacity)
  end

  def notify_update_rank(requestor_name, %Types.GuildRank{} = rank) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_rank)
    |> put_interface_text(Enums.StringCode.get_value(:s_guild_notify_change_grade), [
      requestor_name
    ])
    |> put_byte(rank.id)
    |> put_rank(rank)
  end

  def notify_update_focus(requestor_name, toggle, focus) do
    focus_val = if is_atom(focus), do: Enums.GuildFocus.get_value(focus), else: focus

    __MODULE__
    |> build()
    |> put_byte(@commands.notify_update_focus)
    |> put_ustring(requestor_name)
    |> put_bool(toggle)
    |> put_int(focus_val)
  end

  def update_member_map(player_name, map_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_member_map)
    |> put_ustring(player_name)
    |> put_int(map_id)
  end

  def update_member(member) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_member)
    |> put_ustring(member.name)
    |> put_player_info(member)
  end

  def update_name(guild_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_name)
    |> put_ustring(guild_name)
  end

  def receive_application(application) do
    __MODULE__
    |> build()
    |> put_byte(@commands.receive_application)
    |> put_application(application)
  end

  # confirmation sent to the applicant (s_guild_search_request_join_guild: "You have applied to the guild {0}.")
  def send_application(application_id, guild_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.send_application)
    |> put_long(application_id)
    |> put_ustring(guild_name)
  end

  def withdraw_application(application_id) do
    __MODULE__
    |> build()
    |> put_byte(@commands.withdraw_application)
    |> put_long(application_id)
  end

  def notify_application(requestor_name, player_name, application_id, accepted?) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_application)
    |> put_ustring(requestor_name)
    |> put_ustring(player_name)
    |> put_bool(accepted?)
    |> put_long(application_id)
  end

  def notify_applicant(guild_name, application_id, accepted?) do
    __MODULE__
    |> build()
    |> put_byte(@commands.notify_applicant)
    |> put_ustring(guild_name)
    |> put_long(application_id)
    |> put_bool(accepted?)
  end

  def guild_experience(exp) do
    __MODULE__
    |> build()
    |> put_byte(@commands.guild_experience)
    |> put_int(exp)
  end

  def guild_funds(funds) do
    __MODULE__
    |> build()
    |> put_byte(@commands.guild_funds)
    |> put_int(funds)
  end

  def guild_contribution(member, gained) do
    __MODULE__
    |> build()
    |> put_byte(@commands.guild_contribution)
    |> put_ustring(member.name)
    |> put_int(gained)
    |> put_int(member.weekly_contribution)
    |> put_int(member.total_contribution)
  end

  def upgrade_house(player_name, rank, theme) do
    __MODULE__
    |> build()
    |> put_byte(@commands.upgrade_house)
    |> put_ustring(player_name)
    |> put_int(rank)
    |> put_int(theme)
  end

  def update_poster(poster) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_poster)
    |> put_long(poster.owner_id)
    |> put_ustring(poster.owner_name)
    |> put_int(poster.id)
    |> put_ustring(poster.picture)
  end

  def update_leader(leader_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_leader)
    |> put_ustring(leader_name)
  end

  def update_notice(notice) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_notice)
    |> put_bool(true)
    |> put_ustring(notice)
  end

  def update_emblem(emblem) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_emblem)
    |> put_ustring(emblem)
  end

  def update_capacity(capacity) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_capacity)
    |> put_int(capacity)
  end

  def update_focus(focus) do
    focus_val = if is_atom(focus), do: Enums.GuildFocus.get_value(focus), else: focus

    __MODULE__
    |> build()
    |> put_byte(@commands.update_focus)
    |> put_int(focus_val)
  end

  def list_applications(applications) do
    __MODULE__
    |> build()
    |> put_byte(@commands.list_applications)
    |> put_int(length(applications))
    |> reduce(applications, fn app, packet ->
      packet
      |> put_bool(true)
      |> put_application_summary(app)
    end)
  end

  def list_applied_guilds(applications) do
    __MODULE__
    |> build()
    |> put_byte(@commands.list_applied_guilds)
    |> put_int(length(applications))
    |> reduce(applications, fn app, packet ->
      packet
      |> put_bool(true)
      |> put_application_summary(app)
    end)
  end

  def list_guilds(guilds) do
    __MODULE__
    |> build()
    |> put_byte(@commands.list_guilds)
    |> put_int(length(guilds))
    |> reduce(guilds, fn guild, packet ->
      leader = guild.leader
      leader_account_id = if leader, do: leader.account_id, else: 0
      leader_char_id = if leader, do: leader.id, else: guild.leader_id
      leader_name = if leader, do: leader.name, else: ""
      trophies = (leader && leader.trophies) || [0, 0, 0]
      focus_val = focus_value(guild.focus)
      member_count = if is_list(guild.members), do: length(guild.members), else: 1

      packet
      |> put_bool(true)
      |> put_long(guild.id)
      |> put_ustring(guild.name)
      |> put_ustring(guild.emblem)
      |> put_trophies(trophies)
      |> put_int(member_count)
      |> put_int(guild.capacity)
      |> put_int(focus_val)
      |> put_long(leader_account_id)
      |> put_long(leader_char_id)
      |> put_ustring(leader_name)
    end)
  end

  def add_tag(player_name, guild_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.add_tag)
    |> put_ustring(player_name)
    |> put_ustring(guild_name)
  end

  def remove_tag(player_name) do
    __MODULE__
    |> build()
    |> put_byte(@commands.remove_tag)
    |> put_ustring(player_name)
  end

  def error(error_code, arg \\ 0) do
    error_val =
      if is_atom(error_code) do
        Enums.GuildError.get_value(error_code) || 1
      else
        error_code
      end

    __MODULE__
    |> build()
    |> put_byte(@commands.error)
    |> put_byte(1)
    |> put_byte(error_val)
    |> put_int(arg)
  end

  # ---- Subpacket Helpers ----

  defp put_members(packet, members) do
    packet
    |> put_byte(length(members))
    |> reduce(members, fn member, p -> put_member(p, member) end)
  end

  defp put_member(packet, member) do
    packet
    # type
    |> put_byte(3)
    |> put_byte(member.rank)
    |> put_long(member.character_id)
    |> put_player_info(member)
    |> put_ustring(member.message)
    |> put_long(member.join_time)
    |> put_long(member.last_online_time)
    |> put_long(member.checkin_time)
    |> put_int()
    |> put_int()
    |> put_int(member.weekly_contribution)
    |> put_int(member.total_contribution)
    |> put_int(member.daily_donation_count)
    |> put_long(member.donation_time)
    |> put_int()
    |> put_bool(!member.online?)
  end

  defp put_player_info(packet, member) do
    job_atom = member.job || :beginner
    job_val = Enums.Job.get_value(job_atom)
    job_code = job_val * 10
    gender_val = if member.gender == :female, do: 1, else: 0
    trophies = member.trophies || [0, 0, 0]

    packet
    |> put_long(member.account_id)
    |> put_long(member.character_id)
    |> put_ustring(member.name)
    |> put_byte(gender_val)
    |> put_int(job_code)
    |> put_int(job_val)
    |> put_short(member.level)
    |> put_int(member.gear_score)
    |> put_int(member.map_id)
    |> put_short(member.channel)
    |> put_ustring(member.profile_url)
    |> put_int(member.plot_map_id)
    |> put_int(member.plot_number)
    |> put_int(member.apartment_number)
    |> put_long(member.plot_expiry_time)
    |> put_trophies(trophies)
  end

  defp put_trophies(packet, [combat, adventure, lifestyle]) do
    packet
    |> put_int(combat)
    |> put_int(adventure)
    |> put_int(lifestyle)
  end

  defp put_trophies(packet, _other) do
    packet
    |> put_int(0)
    |> put_int(0)
    |> put_int(0)
  end

  defp put_ranks(packet, ranks) do
    packet
    |> put_byte(length(ranks))
    |> reduce(ranks, fn rank, p -> put_rank(p, rank) end)
  end

  defp put_rank(packet, rank) do
    packet
    |> put_byte(rank.id)
    |> put_ustring(rank.name)
    |> put_int(rank.permission)
  end

  defp put_buffs(packet, buffs) do
    packet
    |> put_byte(length(buffs))
    |> reduce(buffs, fn buff, p ->
      p
      |> put_int(buff.id)
      |> put_int(buff.level)
      |> put_long(buff.expiry_time)
    end)
  end

  defp put_posters(packet, posters) do
    packet
    |> put_int(length(posters))
    |> reduce(posters, fn poster, p ->
      p
      |> put_int(poster.id)
      |> put_ustring(poster.picture)
      |> put_long(poster.owner_id)
      |> put_ustring(poster.owner_name)
    end)
  end

  defp put_npcs(packet, npcs) do
    packet
    |> put_byte(length(npcs))
    |> reduce(npcs, fn npc, p ->
      type_val = npc_type_value(npc.type)

      p
      |> put_int(type_val)
      |> put_int(npc.level)
    end)
  end

  # single push notifying guild members of a new applicant (Command.ReceiveApplication)
  defp put_application(packet, app) do
    info = extract_applicant_info(app)

    packet
    |> put_long(app.id)
    |> put_long(app.guild_id)
    |> put_long(info.char_id)
    |> put_long(info.acc_id)
    |> put_ustring(info.name)
    |> put_ustring(info.profile_url)
    |> put_int(info.job_val)
    |> put_int(info.job_code)
    |> put_int(info.level)
    |> put_trophies(info.trophies)
    |> put_long(unix_or_zero(app.inserted_at))
  end

  # list views (ListApplications/ListAppliedGuilds); confirmed via client crash
  # analysis that this variant has no separate account_id field
  defp put_application_summary(packet, app) do
    info = extract_applicant_info(app)

    packet
    |> put_long(app.id)
    |> put_long(app.guild_id)
    |> put_long(info.char_id)
    |> put_ustring(info.name)
    |> put_ustring(info.profile_url)
    |> put_int(info.job_val)
    |> put_int(info.job_code)
    |> put_int(info.level)
    |> put_trophies(info.trophies)
    |> put_long(unix_or_zero(app.inserted_at))
  end

  defp extract_applicant_info(%{character: %Schema.Character{} = char}) do
    job_val = Enums.Job.get_value(char.job) || 0

    %{
      char_id: char.id,
      acc_id: char.account_id || 0,
      name: char.name || "",
      profile_url: char.profile_url || "",
      job_val: job_val,
      job_code: job_val * 10,
      level: char.level || 1,
      trophies: char.trophies || [0, 0, 0]
    }
  end

  defp extract_applicant_info(app) do
    %{
      char_id: app.character_id,
      acc_id: app.account_id || 0,
      name: "",
      profile_url: "",
      job_val: 0,
      job_code: 0,
      level: 1,
      trophies: [0, 0, 0]
    }
  end

  defp put_interface_text(packet, code, args) do
    packet
    # isLocalized
    |> put_bool(true)
    # unknown
    |> put_int(1)
    |> put_int(code)
    |> put_int(length(args))
    |> reduce(args, fn arg, p -> put_ustring(p, arg) end)
  end

  defp focus_value(focus) when is_atom(focus), do: Enums.GuildFocus.get_value(focus) || 0
  defp focus_value(focus) when is_integer(focus), do: focus
  defp focus_value(_), do: 0

  defp npc_type_value(type) when is_atom(type), do: Enums.GuildNpcType.get_value(type) || 0
  defp npc_type_value(type) when is_integer(type), do: type
  defp npc_type_value(_), do: 0

  defp unix_or_zero(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp unix_or_zero(_), do: 0
end
