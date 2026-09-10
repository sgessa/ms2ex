defmodule Ms2ex.GameHandlers.Guild do
  @moduledoc """
  Handler for Guild packet requests (RecvOp 0x4C).
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  require Logger

  @guild_create_price 2_000
  @guild_create_min_level 10
  @guild_coin_id 30_000_861
  @guild_coin_rarity 4

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Create (1)
  defp handle_mode(0x01, packet, session) do
    {guild_name, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      process_create_guild(session, character, guild_name)
    end
  end

  # Disband (2)
  defp handle_mode(0x02, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id),
         {:ok, guild_state} <- Managers.GuildServer.call(guild_id, :lookup) do
      process_disband_guild(session, character, guild_id, guild_state)
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # Invite (3)
  defp handle_mode(0x03, packet, session) do
    {player_name, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(guild_id, {:invite, character.id, player_name}) do
        :ok ->
          push(session, Packets.Guild.invited(player_name))

        {:error, reason} ->
          push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # RespondInvite (5)
  defp handle_mode(0x05, packet, session) do
    {guild_id, packet} = get_long(packet)
    {guild_name, packet} = get_ustring(packet)
    {_blank, packet} = get_ustring(packet)
    {sender_name, packet} = get_ustring(packet)
    {receiver_name, packet} = get_ustring(packet)
    {accepted?, _packet} = get_bool(packet)

    invite = %Types.GuildInvite{
      guild_id: guild_id,
      guild_name: guild_name,
      sender_name: sender_name,
      receiver_name: receiver_name
    }

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      process_respond_invite(session, character, guild_id, invite, accepted?)
    end
  end

  # Leave (7)
  defp handle_mode(0x07, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(guild_id, {:leave, character.id}) do
        :ok -> process_leave_guild(session, character, guild_id)
        {:error, reason} -> push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # Expel (8)
  defp handle_mode(0x08, packet, session) do
    {player_name, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(guild_id, {:expel, character.id, player_name}) do
        :ok ->
          push(session, Packets.Guild.expelled(player_name))

        {:error, reason} ->
          push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # UpdateMemberRank (10)
  defp handle_mode(0x0A, packet, session) do
    {player_name, packet} = get_ustring(packet)
    {rank_id, _packet} = get_byte(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(
             guild_id,
             {:update_member_rank, character.id, player_name, rank_id}
           ) do
        :ok ->
          push(session, Packets.Guild.update_member_rank(player_name, rank_id))

        {:error, reason} ->
          push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # UpdateMemberMessage (13 / 0x0D)
  defp handle_mode(0x0D, packet, session) do
    {message, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(guild_id, {:update_member_message, character.id, message}) do
        :ok ->
          push(session, Packets.Guild.update_member_message(message))

        {:error, reason} ->
          push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # CheckIn (15 / 0x0F)
  defp handle_mode(0x0F, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      process_check_in(session, character, guild_id)
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # UpdateLeader (61 / 0x3D)
  defp handle_mode(0x3D, packet, session) do
    {leader_name, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(guild_id, {:update_leader, character.id, leader_name}) do
        :ok ->
          push(session, Packets.Guild.update_leader(leader_name))

        {:error, reason} ->
          push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # UpdateNotice (62 / 0x3E)
  defp handle_mode(0x3E, packet, session) do
    {_flag, packet} = get_bool(packet)
    {notice, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(guild_id, {:update_notice, character.id, notice}) do
        :ok ->
          push(session, Packets.Guild.update_notice(notice))

        {:error, reason} ->
          push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # IncreaseCapacity (64 / 0x40) — accepted, no cost/limit model implemented
  defp handle_mode(0x40, _packet, session), do: session

  # UpdateRank (65 / 0x41)
  defp handle_mode(0x41, packet, session) do
    {_code, packet} = get_byte(packet)
    {rank_id, packet} = get_byte(packet)
    {rank_name, packet} = get_ustring(packet)
    {permission, _packet} = get_int(packet)

    rank = %Types.GuildRank{id: rank_id, name: rank_name, permission: permission}

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      Managers.GuildServer.call(guild_id, {:update_rank_def, character.id, rank})
    end
  end

  # UpdateFocus (66 / 0x42)
  defp handle_mode(0x42, packet, session) do
    {_code, packet} = get_byte(packet)
    {focus, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      Managers.GuildServer.call(guild_id, {:update_focus, character.id, focus})
    end
  end

  # SendMail (69 / 0x45)
  defp handle_mode(0x45, packet, session) do
    {title, packet} = get_ustring(packet)
    {content, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      case Managers.GuildServer.call(guild_id, {:send_mail, character.id, title, content}) do
        :ok -> session
        {:error, reason} -> push(session, Packets.Guild.error(reason))
      end
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # SendApplication (80 / 0x50)
  defp handle_mode(0x50, packet, session) do
    {guild_id, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      case Managers.GuildServer.call(guild_id, {:apply_to_guild, character}) do
        {:ok, app} ->
          push(session, Packets.Guild.send_application(app.id, app.guild.name))

        {:error, reason} ->
          push(session, Packets.Guild.error(reason))
      end
    end
  end

  # CancelApplication (81 / 0x51)
  defp handle_mode(0x51, packet, session) do
    {application_id, _packet} = get_long(packet)

    Context.Guilds.delete_application(application_id)
    push(session, Packets.Guild.withdraw_application(application_id))
  end

  # RespondApplication (82 / 0x52)
  defp handle_mode(0x52, packet, session) do
    {application_id, packet} = get_long(packet)
    {accepted?, _packet} = get_bool(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      Managers.GuildServer.call(
        guild_id,
        {:respond_application, character.id, application_id, accepted?}
      )
    end
  end

  # ListApplications (84 / 0x54)
  defp handle_mode(0x54, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id),
         {:ok, apps} <- Managers.GuildServer.call(guild_id, :list_applications) do
      push(session, Packets.Guild.list_applications(apps))
    else
      _ ->
        apps = Context.Guilds.list_character_applications(session.character_id)
        push(session, Packets.Guild.list_applied_guilds(apps))
    end
  end

  # SearchGuilds (85 / 0x55)
  defp handle_mode(0x55, packet, session) do
    {focus, packet} = get_int(packet)
    {page, _packet} = get_int(packet)

    guilds = Context.Guilds.search_guilds(focus, max(page, 1), 10)
    push(session, Packets.Guild.list_guilds(guilds))
  end

  # SearchGuildName (86 / 0x56)
  defp handle_mode(0x56, packet, session) do
    {guild_name, _packet} = get_ustring(packet)

    guilds = Context.Guilds.search_guilds_by_name(guild_name, 1, 10)
    push(session, Packets.Guild.list_guilds(guilds))
  end

  # UseBuff (88 / 0x58) — accepted, no buff effects implemented
  defp handle_mode(0x58, packet, session) do
    {_buff_id, _packet} = get_int(packet)
    session
  end

  # UsePersonalBuff (89 / 0x59) — accepted, no buff effects implemented
  defp handle_mode(0x59, packet, session) do
    {_buff_id, _packet} = get_int(packet)
    session
  end

  # UpgradeBuff (90 / 0x5A) — accepted, no cost/level model implemented
  defp handle_mode(0x5A, packet, session) do
    {_buff_id, _packet} = get_int(packet)
    session
  end

  # SendGift (106 / 0x6A) — accepted, no gift log implemented
  defp handle_mode(0x6A, packet, session) do
    {_item_id, packet} = get_int(packet)
    {_rarity, packet} = get_short(packet)
    {_amount, packet} = get_int(packet)
    {_unknown1, packet} = get_bool(packet)
    {_unknown2, packet} = get_bool(packet)
    {_unknown3, packet} = get_bool(packet)
    {_unknown4, packet} = get_bool(packet)
    {_player_name, _packet} = get_ustring(packet)
    session
  end

  # UpdateGiftLog (109 / 0x6D) — accepted, no gift log implemented
  defp handle_mode(0x6D, _packet, session), do: session

  # Donate (110 / 0x6E)
  defp handle_mode(0x6E, packet, session) do
    {count, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      process_donate(session, character, guild_id, count)
    else
      _ -> push(session, Packets.Guild.error(:s_guild_err_null_guild))
    end
  end

  # EnterHouse (100 / 0x64)
  defp handle_mode(0x64, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id),
         {:ok, guild_state} <- Managers.GuildServer.call(guild_id, :lookup) do
      house =
        Storage.Tables.Guild.get_house(
          guild_state.guild.house_rank,
          guild_state.guild.house_theme
        )

      if house && house.map_id > 0 do
        Managers.Field.change_field(character, house.map_id)
      end
    end
  end

  # UpgradeHouseRank (98 / 0x62)
  defp handle_mode(0x62, packet, session) do
    {rank, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      Managers.GuildServer.call(guild_id, {:upgrade_house_rank, character.id, rank})
    end
  end

  # UpgradeNpc (111 / 0x6F) — accepted, no npc upgrade model implemented
  defp handle_mode(0x6F, packet, session) do
    {_npc_type, _packet} = get_int(packet)
    session
  end

  # UpgradeHouseTheme (99 / 0x63)
  defp handle_mode(0x63, packet, session) do
    {theme, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, guild_id, _pid} <- Managers.GuildManager.lookup_by_character(character.id) do
      Managers.GuildServer.call(guild_id, {:upgrade_house_theme, character.id, theme})
    end
  end

  defp handle_mode(mode, _packet, _session) do
    Logger.warning("Unhandled Guild command mode #{inspect(mode)}")
    :ok
  end

  # ---- Internal Processing Helpers ----

  defp process_create_guild(session, character, guild_name) do
    cond do
      character.level < @guild_create_min_level ->
        push(session, Packets.Guild.error(:s_guild_err_not_enough_level))

      Context.Wallets.find(character).mesos < @guild_create_price ->
        push(session, Packets.Guild.error(:s_guild_err_no_money))

      true ->
        create_and_load_guild(session, character, guild_name)
    end
  end

  defp create_and_load_guild(session, character, guild_name) do
    case Managers.GuildManager.create(character, guild_name) do
      {:ok, guild} ->
        Context.Wallets.update(character, :mesos, -@guild_create_price)

        :ok =
          Managers.Character.call(
            character.id,
            {:update, %{character | guild_name: guild.name, guild_id: guild.id}}
          )

        Managers.Quest.update_conditions(character.id, :guild_join, 1, "", 0, "", 0)

        Ms2ex.Net.SenderSession.run_async(character, fn ->
          Managers.GuildServer.subscribe(guild.id)
        end)

        Managers.Field.broadcast(character, Packets.Guild.add_tag(character.name, guild.name))

        session
        |> push(Packets.Guild.created(guild.name))
        |> push(Packets.Guild.load(guild, [build_leader_member(character)]))

      {:error, reason} ->
        push(session, Packets.Guild.error(reason))
    end
  end

  defp process_disband_guild(session, character, guild_id, guild_state) do
    cond do
      character.id != guild_state.guild.leader_id ->
        push(session, Packets.Guild.error(:s_guild_err_no_master))

      map_size(guild_state.members) > 1 ->
        push(session, Packets.Guild.error(:s_guild_err_exist_member))

      true ->
        Managers.GuildManager.disband(guild_id)

        :ok =
          Managers.Character.call(
            character.id,
            {:update, %{character | guild_name: "", guild_id: 0}}
          )

        Ms2ex.Net.SenderSession.run_async(character, fn ->
          Managers.GuildServer.unsubscribe(guild_id)
        end)

        Managers.Field.broadcast(character, Packets.Guild.remove_tag(character.name))
        push(session, Packets.Guild.disbanded())
    end
  end

  defp process_respond_invite(session, character, guild_id, invite, accepted?) do
    case Managers.GuildServer.call(guild_id, {:respond_invite, character, accepted?}) do
      {:ok, guild_state} ->
        :ok =
          Managers.Character.call(
            character.id,
            {:update, %{character | guild_name: guild_state.guild.name, guild_id: guild_state.id}}
          )

        Managers.Quest.update_conditions(character.id, :guild_join, 1, "", 0, "", 0)

        Ms2ex.Net.SenderSession.run_async(character, fn ->
          Managers.GuildServer.subscribe(guild_id)
        end)

        Managers.Field.broadcast(
          character,
          Packets.Guild.add_tag(character.name, guild_state.guild.name)
        )

        session
        |> push(Packets.Guild.invite_reply(invite, true))
        |> push(Packets.Guild.load(guild_state))

      :ok ->
        push(session, Packets.Guild.invite_reply(invite, false))

      {:error, reason} ->
        push(session, Packets.Guild.error(reason))
    end
  end

  defp process_check_in(session, character, guild_id) do
    case Managers.GuildServer.call(guild_id, {:check_in, character}) do
      {:ok, prop} ->
        push(session, Packets.Guild.checked_in())
        deliver_checkin_rewards(character, prop)

      {:error, :already_checked_in} ->
        :ok

      {:error, reason} ->
        push(session, Packets.Guild.error(reason))
    end
  end

  defp deliver_checkin_rewards(character, prop) do
    if prop.check_in_coin > 0 do
      coin_item =
        Context.Items.init(@guild_coin_id, %{
          amount: prop.check_in_coin,
          rarity: @guild_coin_rarity
        })

      Managers.Inventory.add_item(character, coin_item)
    end

    if prop.check_in_player_exp_rate > 0 do
      exp_amount = trunc(character.exp * prop.check_in_player_exp_rate)
      if exp_amount > 0, do: Managers.Character.cast(character, {:earn_exp, exp_amount})
    end
  end

  defp process_donate(session, character, guild_id, count) do
    cost = 10_000 * count

    if Context.Wallets.find(character).mesos < cost do
      push(session, Packets.Guild.error(:s_guild_err_no_money))
    else
      execute_donation(session, character, guild_id, count, cost)
    end
  end

  defp execute_donation(session, character, guild_id, count, cost) do
    case Managers.GuildServer.call(guild_id, {:donate, character, count, cost}) do
      {:ok, prop, member} ->
        Context.Wallets.update(character, :mesos, -cost)
        Managers.Quest.update_conditions(character.id, :guild_donation, count, "", 0, "", 0)

        if prop.donate_coin > 0 do
          coin_item =
            Context.Items.init(@guild_coin_id, %{
              amount: prop.donate_coin * count,
              rarity: @guild_coin_rarity
            })

          Managers.Inventory.add_item(character, coin_item)
        end

        push(session, Packets.Guild.donated(member.daily_donation_count, member.donation_time))

      {:error, reason} ->
        push(session, Packets.Guild.error(reason))
    end
  end

  defp build_leader_member(character) do
    %{
      guild_id: character.guild_id,
      character_id: character.id,
      account_id: character.account_id,
      name: character.name,
      rank: 0,
      message: "",
      join_time: DateTime.utc_now() |> DateTime.to_unix(),
      last_online_time: DateTime.utc_now() |> DateTime.to_unix(),
      checkin_time: 0,
      donation_time: 0,
      weekly_contribution: 0,
      total_contribution: 0,
      daily_donation_count: 0,
      plot_map_id: 0,
      plot_number: 0,
      apartment_number: 0,
      plot_expiry_time: 0,
      online?: true,
      level: character.level,
      job: character.job,
      gender: character.gender,
      map_id: character.map_id,
      channel: character.channel_id || 1,
      profile_url: character.profile_url || "",
      gear_score: character.gear_score || 0,
      trophies: character.trophies || [0, 0, 0]
    }
  end

  defp process_leave_guild(session, character, guild_id) do
    :ok =
      Managers.Character.call(
        character.id,
        {:update, %{character | guild_name: "", guild_id: 0}}
      )

    Ms2ex.Net.SenderSession.run_async(character, fn ->
      Managers.GuildServer.unsubscribe(guild_id)
    end)

    Managers.Field.broadcast(character, Packets.Guild.remove_tag(character.name))
    push(session, Packets.Guild.leave())
  end
end
