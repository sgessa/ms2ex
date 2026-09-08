defmodule Ms2ex.GuildTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "table:guild.xml" => %{
        table: %{
          properties: %{
            1 => %{
              level: 1,
              experience: 0,
              capacity: 60,
              fund_max: 10_000_000,
              donate_max: 5,
              check_in_exp: 10,
              check_in_fund: 1000,
              check_in_coin: 1,
              check_in_player_exp_rate: 0.05,
              donate_coin: 1,
              donate_player_exp_rate: 0.05,
              win_mini_game_exp: 50,
              lose_mini_game_exp: 10,
              win_mini_game_fund: 5000,
              lose_mini_game_fund: 1000,
              win_mini_game_coin: 5,
              lose_mini_game_coin: 1,
              raid_exp: 100,
              raid_fund: 10_000
            }
          },
          buffs: %{},
          houses: %{
            0 => %{
              0 => %{
                map_id: 2_000_001,
                require_level: 1,
                upgrade_cost: 0,
                retheme_cost: 0,
                facilities: []
              }
            }
          },
          npcs: %{}
        }
      },
      "item:90000004" => %{
        limit: %{level: 0, gender: 0, job_recommends: [], transfer_type: 0},
        property: %{type: 3, ride: 0, tradable_count: 0, stack_limit: 999},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    leader = insert_character("GuildLeader")
    member = insert_character("GuildMember")
    applicant = insert_character("GuildApplicant")

    # Start inventory for coin grants
    Repo.insert!(%Schema.InventoryTab{character_id: leader.id, tab: :consumable, slots: 84})
    Repo.insert!(%Schema.InventoryTab{character_id: member.id, tab: :consumable, slots: 84})

    Managers.Character.start(leader)
    Managers.Character.start(member)
    Managers.Character.start(applicant)

    Managers.Inventory.start(leader)
    Managers.Inventory.start(member)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), :erlang.whereis(:"inventories:#{leader.id}"))
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), :erlang.whereis(:"inventories:#{member.id}"))

    on_exit(fn ->
      Managers.Inventory.stop(leader.id)
      Managers.Inventory.stop(member.id)
    end)

    %{leader: leader, member: member, applicant: applicant}
  end

  describe "context operations" do
    test "create guild with leader as Master", %{leader: leader} do
      assert {:ok, guild} = Context.Guilds.create(leader, "Apex")
      assert guild.name == "Apex"
      assert guild.leader_id == leader.id
      assert guild.capacity == 60
      assert length(guild.ranks) == 5
      assert length(guild.members) == 1
      assert List.first(guild.members).rank == 0

      assert Context.Guilds.get(guild.id).id == guild.id
      assert Context.Guilds.get_by_name("apex").id == guild.id
      assert Context.Guilds.get_by_character_id(leader.id).id == guild.id
    end

    test "validates guild name constraints", %{leader: leader} do
      assert {:error, :s_guild_err_name_value} = Context.Guilds.create(leader, "A")

      assert {:error, :s_guild_err_name_value} =
               Context.Guilds.create(leader, "WayTooLongGuildName123")

      assert {:error, :s_guild_err_name_value} = Context.Guilds.create(leader, "")

      {:ok, _guild} = Context.Guilds.create(leader, "Original")
      assert {:error, :s_guild_err_already_exist} = Context.Guilds.create(leader, "Duplicate")
    end

    test "members management in context", %{leader: leader, member: member} do
      {:ok, guild} = Context.Guilds.create(leader, "Valor")

      assert {:ok, guild_member} = Context.Guilds.add_member(guild.id, member.id, 4)
      assert guild_member.rank == 4

      assert {:ok, updated_member} =
               Context.Guilds.update_member(guild.id, member.id, %{rank: 2, message: "Hello"})

      assert updated_member.rank == 2
      assert updated_member.message == "Hello"

      assert {:ok, _} = Context.Guilds.remove_member(guild.id, member.id)
      assert is_nil(Context.Guilds.get_by_character_id(member.id))
    end

    test "guild search by name and focus", %{leader: leader} do
      {:ok, guild} = Context.Guilds.create(leader, "KnightsOfMaple", focus: :dungeons)

      results = Context.Guilds.search_guilds_by_name("knight")
      assert length(results) == 1
      assert List.first(results).id == guild.id

      focus_results = Context.Guilds.search_guilds(:dungeons)
      assert length(focus_results) == 1
      assert List.first(focus_results).id == guild.id

      # Searching with 0x7FFFFFFF (all focus bits) returns all guilds
      all_results = Context.Guilds.search_guilds(0x7FFFFFFF)
      refute Enum.empty?(all_results)
    end

    test "applications in context", %{leader: leader, applicant: applicant} do
      {:ok, guild} = Context.Guilds.create(leader, "Mythic")

      assert {:ok, app} =
               Context.Guilds.create_application(guild.id, applicant.id, applicant.account_id)

      assert app.guild_id == guild.id
      assert app.character_id == applicant.id

      apps = Context.Guilds.list_applications(guild.id)
      assert length(apps) == 1

      assert {:ok, _} = Context.Guilds.delete_application(app.id)
      assert Context.Guilds.list_applications(guild.id) == []
    end
  end

  describe "manager and server operations" do
    test "create, invite, accept, and leave lifecycle", %{leader: leader, member: member} do
      assert {:ok, guild} = Managers.GuildManager.create(leader, "Legends")
      assert {:ok, guild_id, pid} = Managers.GuildManager.lookup_by_character(leader.id)
      assert is_pid(pid)
      assert guild_id == guild.id

      # Invite member
      assert :ok = Managers.GuildServer.call(guild.id, {:invite, leader.id, member.name})

      # Member accepts invite
      assert {:ok, state} = Managers.GuildServer.call(guild.id, {:respond_invite, member, true})
      assert Map.has_key?(state.members, member.id)

      # Member updates message
      assert :ok =
               Managers.GuildServer.call(
                 guild.id,
                 {:update_member_message, member.id, "Ready to raid!"}
               )

      {:ok, current} = Managers.GuildServer.call(guild.id, :lookup)
      assert current.members[member.id].message == "Ready to raid!"

      # Member leaves
      assert :ok = Managers.GuildServer.call(guild.id, {:leave, member.id})
      {:ok, current} = Managers.GuildServer.call(guild.id, :lookup)
      refute Map.has_key?(current.members, member.id)

      # Disband
      assert :ok = Managers.GuildManager.disband(guild.id)
      assert Managers.GuildManager.lookup_by_character(leader.id) == :error
    end

    test "check in awards exp, funds, and contribution", %{leader: leader} do
      {:ok, guild} = Managers.GuildManager.create(leader, "Rising")

      assert {:ok, prop} = Managers.GuildServer.call(guild.id, {:check_in, leader})
      assert prop.check_in_exp == 10

      {:ok, current} = Managers.GuildServer.call(guild.id, :lookup)
      assert current.guild.experience == 10
      assert current.guild.funds == 1000
      assert current.members[leader.id].weekly_contribution == 10
      assert current.members[leader.id].total_contribution == 10
      assert current.members[leader.id].checkin_time > 0

      # Second check in on same day is rejected
      assert {:error, :already_checked_in} =
               Managers.GuildServer.call(guild.id, {:check_in, leader})
    end

    test "donations increase funds and contributions", %{leader: leader} do
      {:ok, guild} = Managers.GuildManager.create(leader, "Donators")

      assert {:ok, _prop} = Managers.GuildServer.call(guild.id, {:donate, leader, 2})

      {:ok, current} = Managers.GuildServer.call(guild.id, :lookup)
      assert current.guild.experience == 20
      assert current.guild.funds == 2000
      assert current.members[leader.id].weekly_contribution == 20
      assert current.members[leader.id].daily_donation_count == 2
    end

    test "rank updates and leadership transfer", %{leader: leader, member: member} do
      {:ok, guild} = Managers.GuildManager.create(leader, "Royalty")
      Managers.GuildServer.call(guild.id, {:invite, leader.id, member.name})
      {:ok, _} = Managers.GuildServer.call(guild.id, {:respond_invite, member, true})

      # Promote member to Jr. Master (rank 1)
      assert :ok =
               Managers.GuildServer.call(
                 guild.id,
                 {:update_member_rank, leader.id, member.name, 1}
               )

      {:ok, state} = Managers.GuildServer.call(guild.id, :lookup)
      assert state.members[member.id].rank == 1

      # Transfer leader to member
      assert :ok = Managers.GuildServer.call(guild.id, {:update_leader, leader.id, member.name})
      {:ok, state} = Managers.GuildServer.call(guild.id, :lookup)
      assert state.guild.leader_id == member.id
      assert state.members[member.id].rank == 0
      assert state.members[leader.id].rank == 1
    end

    test "expelling members", %{leader: leader, member: member} do
      {:ok, guild} = Managers.GuildManager.create(leader, "Enforcers")
      Managers.GuildServer.call(guild.id, {:invite, leader.id, member.name})
      {:ok, _} = Managers.GuildServer.call(guild.id, {:respond_invite, member, true})

      # Cannot expel master
      assert {:error, :s_guild_err_expel_target_master} =
               Managers.GuildServer.call(guild.id, {:expel, leader.id, leader.name})

      # Master expels member
      assert :ok = Managers.GuildServer.call(guild.id, {:expel, leader.id, member.name})
      {:ok, state} = Managers.GuildServer.call(guild.id, :lookup)
      refute Map.has_key?(state.members, member.id)
    end
  end

  describe "packets" do
    test "serializes guild packets without crashing", %{leader: leader, member: member} do
      {:ok, guild} = Context.Guilds.create(leader, "Visuals")

      guild_state = %{
        guild: guild,
        members: %{
          leader.id => %{
            character_id: leader.id,
            account_id: leader.account_id,
            name: leader.name,
            rank: 0,
            message: "Lead",
            join_time: 1000,
            last_online_time: 2000,
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
            level: 10,
            job: :knight,
            gender: :male,
            map_id: 1,
            channel: 1,
            profile_url: "",
            gear_score: 100,
            trophies: [1, 2, 3]
          }
        }
      }

      assert is_binary(Packets.Guild.load(guild_state))
      assert is_binary(Packets.Guild.created(guild.name))
      assert is_binary(Packets.Guild.disbanded())
      assert is_binary(Packets.Guild.invited(member.name))
      assert is_binary(Packets.Guild.notify_login(leader.name))
      assert is_binary(Packets.Guild.notify_logout(leader.name, 2000))
      assert is_binary(Packets.Guild.checked_in())
      assert is_binary(Packets.Guild.guild_experience(100))
      assert is_binary(Packets.Guild.guild_funds(5000))
      assert is_binary(Packets.Guild.update_notice("New Notice"))
      assert is_binary(Packets.Guild.update_emblem("path/to/emblem.png"))
      assert is_binary(Packets.Guild.error(:s_guild_err_no_money))
    end
  end

  describe "handler dispatch" do
    test "handles create, checkin, donate, and notice commands", %{leader: leader} do
      session = %Ms2ex.Net.Session{
        character_id: leader.id,
        sender_pid: self()
      }

      # Create Guild (1)
      create_packet = <<0x01, 7::little-16, "Genesis"::utf16>>
      Ms2ex.GameHandlers.Guild.handle(create_packet, session)
      assert_receive {:push, _created_pkt}
      assert_receive {:push, _load_pkt}

      # Check in (15 / 0x0F)
      Ms2ex.GameHandlers.Guild.handle(<<0x0F>>, session)
      assert_receive {:push, _checked_in_pkt}

      # Update notice (62 / 0x3E)
      notice_packet = <<0x3E, 1, 11::little-16, "Welcome all"::utf16>>
      Ms2ex.GameHandlers.Guild.handle(notice_packet, session)
      assert_receive {:push, _notice_pkt}

      # Search guilds (85 / 0x55) with 0x7FFFFFFF (all focus)
      search_packet = <<0x55, 0x7FFFFFFF::little-32, 1::little-32>>
      Ms2ex.GameHandlers.Guild.handle(search_packet, session)
      assert_receive {:push, _list_guilds_pkt}
    end
  end

  # ---- Helpers ----

  defp insert_character(name) do
    unique = System.unique_integer([:positive])

    account =
      Repo.insert!(%Schema.Account{
        username: "acc_#{name}_#{unique}",
        password_hash: "hash"
      })

    Repo.insert!(%Schema.AccountWallet{account_id: account.id})

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "#{name}#{unique}",
        gender: :male,
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: %{}
      })

    Repo.insert!(%Schema.Wallet{character_id: character.id, mesos: 1_000_000})
    stats = Repo.insert!(%Schema.CharacterStats{character_id: character.id})
    %{character | stats: stats, sender_session_pid: self()}
  end
end
