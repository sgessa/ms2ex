defmodule Ms2ex.AchievementManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context.Achievements
  alias Ms2ex.Context.Characters
  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ms2ex.TestHelpers

  # counter-type achievement with two grades (values 2 and 4)
  @achievement_id 236_000
  @metadata %{
    id: @achievement_id,
    account_wide: false,
    category: 2,
    grades: %{
      "1" => %{condition: %{type: :monster_kill, value: 2}},
      "2" => %{condition: %{type: :monster_kill, value: 4}, reward: nil}
    }
  }
  @reward_id 236_001
  @reward_metadata %{
    id: @reward_id,
    account_wide: false,
    category: 1,
    grades: %{
      "1" => %{
        condition: %{type: :quest_accept, value: 1},
        reward: %{type: :statpoint, value: 3}
      }
    }
  }
  @manual_reward_id 236_002
  @manual_reward_title_id 100_000
  @manual_reward_metadata %{
    id: @manual_reward_id,
    account_wide: false,
    category: 2,
    grades: %{
      "1" => %{
        condition: %{type: :guild_join, value: 1},
        reward: %{type: :title, code: @manual_reward_title_id, value: 0, rank: 1}
      }
    }
  }

  @item_reward_id 236_003
  @reward_item_id 5_000_001
  @item_reward_metadata %{
    id: @item_reward_id,
    account_wide: false,
    category: 2,
    grades: %{
      "1" => %{
        condition: %{type: :send_mail, value: 1},
        reward: %{type: :item, code: @reward_item_id, value: 2, rank: 1}
      }
    }
  }

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "achievement:#{@achievement_id}" => @metadata,
      "achievement:#{@reward_id}" => @reward_metadata,
      "achievement:#{@manual_reward_id}" => @manual_reward_metadata,
      "achievement:#{@item_reward_id}" => @item_reward_metadata,
      "item:#{@reward_item_id}" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 0, subtype: 2},
        slot_names: [],
        stack_limit: 10,
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "achievement:index" => %{
        monster_kill: [@achievement_id],
        quest_accept: [@reward_id],
        guild_join: [@manual_reward_id],
        send_mail: [@item_reward_id]
      }
    })

    account =
      Repo.insert!(%Schema.Account{
        username: "ach_test_#{System.unique_integer([:positive])}",
        password_hash: "hash"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "AchTest#{System.unique_integer([:positive])}",
        map_id: 2_000_062,
        job: :knight,
        level: 1,
        skin_color: {},
        gender: :male,
        discovered_maps: [],
        insignia_id: 0,
        online?: false,
        position: %{x: 0, y: 0, z: 0, rotation: 0},
        stat_point_allocation: %{},
        stat_point_sources: Ms2ex.Types.AttributePointSource.default_sources()
      })
      |> Map.put(:session_pid, self())
      |> Map.put(:sender_session_pid, self())

    {:ok, char_pid} = Managers.Character.start(character)
    :ok = Managers.Achievement.start(character)

    achievement_pid = Process.whereis(:"achievements:#{character.id}")

    on_exit(fn ->
      if achievement_pid != nil and Process.alive?(achievement_pid),
        do: GenServer.stop(achievement_pid)

      if Process.alive?(char_pid), do: GenServer.stop(char_pid)
    end)

    # both managers read and write the database from their own processes
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), char_pid)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), achievement_pid)

    %{character: character}
  end

  # progress is applied through asynchronous casts; poll until the
  # assertion holds instead of sleeping a fixed amount
  defp wait_until(fun, attempts \\ 50)
  defp wait_until(fun, attempts) when attempts <= 0, do: fun.()

  defp wait_until(fun, attempts) do
    try do
      fun.()
    rescue
      ExUnit.AssertionError ->
        Process.sleep(20)
        wait_until(fun, attempts - 1)
    end
  end

  test "progress accumulates in memory and creates the row once", %{character: character} do
    Managers.Achievement.update(character.id, :monster_kill)

    # the row is created the moment progress starts, with its insert-time
    # defaults; the accumulated counter only reaches the database on flush
    wait_until(fn ->
      assert length(Achievements.list(character.id)) == 1
    end)

    # a second event advances the counter in memory without another insert
    Managers.Achievement.update(character.id, :monster_kill)
    :ok = Managers.Achievement.flush(character)

    assert [%Schema.Achievement{counter: 2}] = Achievements.list(character.id)
  end

  test "grade completion bumps trophy counts and stop flushes progress", %{
    character: character
  } do
    Managers.Achievement.update(character.id, :monster_kill)
    Managers.Achievement.update(character.id, :monster_kill)

    wait_until(fn ->
      assert Managers.Achievement.trophy_counts(character) == [0, 1, 0]
    end)

    # the pending grade completion persists on flush
    :ok = Managers.Achievement.flush(character)

    assert [%Schema.Achievement{counter: 2, current_grade: 2, grades: grades}] =
             Achievements.list(character.id)

    assert Map.keys(grades) == ["1"]
  end

  # server shutdown stops the manager, whose terminate flushes pending
  # progress; the state snapshot + direct terminate call mirrors that path
  test "stopping the manager flushes pending progress", %{character: character} do
    Managers.Achievement.update(character.id, :monster_kill)

    # the row is created with its insert-time defaults; the accumulated
    # counter lives in memory
    wait_until(fn ->
      assert length(Achievements.list(character.id)) == 1
    end)

    Managers.Achievement.update(character.id, :monster_kill)

    pid = Process.whereis(:"achievements:#{character.id}")
    state = :sys.get_state(pid)
    GenServer.stop(pid, :normal)
    Managers.Achievement.terminate(:shutdown, state)

    assert [%Schema.Achievement{counter: 2}] = Achievements.list(character.id)
  end

  test "stat point rewards are granted automatically on rank up", %{character: character} do
    Managers.Achievement.update(character.id, :quest_accept)

    wait_until(fn ->
      saved = Repo.reload(character)
      assert saved.stat_point_sources.trophy == 3
    end)

    # the reward grade advanced past the current grade in memory, so
    # nothing is left to claim
    Managers.Achievement.claim_reward(character, @reward_id)
    :ok = Managers.Achievement.flush(character)

    assert [%Schema.Achievement{reward_grade: 2}] = Achievements.list(character.id)
  end

  test "item and title rewards wait for manual claim", %{character: character} do
    Managers.Achievement.update(character.id, :guild_join)

    wait_until(fn ->
      assert [%Schema.Achievement{reward_grade: 1}] = Achievements.list(character.id)
    end)

    assert Characters.list_titles(character) == []

    Managers.Achievement.claim_reward(character, @manual_reward_id)
    :ok = Managers.Achievement.flush(character)

    assert Characters.list_titles(character) == [@manual_reward_title_id]
    assert [%Schema.Achievement{reward_grade: 2}] = Achievements.list(character.id)
  end

  test "item rewards fallback to mail when inventory is not available or full", %{
    character: character
  } do
    Managers.Achievement.update(character.id, :send_mail)

    wait_until(fn ->
      assert [%Schema.Achievement{achievement_id: @item_reward_id, reward_grade: 1}] =
               Achievements.list(character.id)
    end)

    Managers.Achievement.claim_reward(character, @item_reward_id)
    :ok = Managers.Achievement.flush(character)

    assert [%Schema.Achievement{achievement_id: @item_reward_id, reward_grade: 2}] =
             Achievements.list(character.id)

    # Item was mailed
    mails = Ms2ex.Context.Mails.list(character.id)
    assert length(mails) == 1
    assert List.first(mails).items |> Enum.any?(&(&1.item_id == @reward_item_id))
  end
end
