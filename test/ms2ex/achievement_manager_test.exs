defmodule Ms2ex.AchievementManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context.Achievements
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

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "achievement:#{@achievement_id}" => @metadata,
      "achievement:#{@reward_id}" => @reward_metadata,
      "achievement:index" => %{
        monster_kill: [@achievement_id],
        quest_accept: [@reward_id]
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
end
