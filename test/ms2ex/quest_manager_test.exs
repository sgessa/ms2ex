defmodule Ms2ex.QuestManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Quest.Conditions
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  # a world quest with one map condition worth 2 visits
  @quest_id 2_001_045
  @quest_metadata %{
    id: @quest_id,
    name: "quest manager test",
    basic: %{type: :world_quest, chapter_id: 0},
    conditions: [%{type: :map, value: 2, codes: %{range: nil, strings: [], integers: []}}],
    accept_reward: %{
      exp: 0,
      meso: 0,
      treva: 0,
      rue: 0,
      essential_items: [],
      essential_job_items: [],
      selective_items: []
    },
    complete_reward: %{
      exp: 0,
      meso: 0,
      treva: 0,
      rue: 0,
      essential_items: [],
      essential_job_items: [],
      selective_items: []
    },
    remote_accept: %{enabled: false, map_id: 0, portal_id: 0},
    remote_complete: %{type: :none, map_id: 0, require_dungeon_clear: false},
    go_to_npc: %{enabled: false, map_id: 0, portal_id: 0},
    go_to_dungeon: %{enabled: false, map_id: 0, portal_id: 0},
    mentoring: false,
    summon_portal: false,
    event_mission_type: 0
  }

  setup do
    stub_metadata(%{
      "quest:#{@quest_id}" => @quest_metadata,
      "item:20000022" => %{
        id: 20_000_022,
        limit: %{level: 0},
        option: %{constant_id: 0},
        property: %{type: 2, subtype: 2, stack_limit: 999},
        slot_names: []
      }
    })

    account =
      Repo.insert!(%Schema.Account{
        username: "quest_test_#{System.unique_integer([:positive])}",
        password_hash: "hash"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "QuestTest#{System.unique_integer([:positive])}",
        map_id: 2_000_062,
        job: :knight,
        level: 1,
        skin_color: {},
        gender: :male,
        stat_point_allocation: %{},
        stat_point_sources: Ms2ex.Types.AttributePointSource.default_sources()
      })
      |> Map.put(:session_pid, self())
      |> Map.put(:sender_session_pid, self())

    {:ok, quest} = Managers.Quest.State.create_quest(character, @quest_metadata)

    %{character: character, quest: quest}
  end

  test "condition counters accumulate in memory", %{quest: quest} do
    updated = Conditions.update(quest, :map, 1, "", 0, "", 2_000_062)
    assert updated.conditions[0] == 1

    updated = Conditions.update(updated, :map, 1, "", 0, "", 2_000_062)
    assert updated.conditions[0] == 2
  end

  test "flushing dirty state persists accumulated counters", %{quest: quest} do
    quest = Conditions.update(quest, :map, 1, "", 0, "", 2_000_062)
    quest = Conditions.update(quest, :map, 1, "", 0, "", 2_000_062)

    state = %{
      dirty: MapSet.new([@quest_id]),
      character_quests: %{@quest_id => quest},
      account_quests: %{}
    }

    Managers.Quest.flush_dirty(state)

    saved = Repo.reload!(quest)
    assert saved.conditions["0"] == 2
  end

  test "an unmet quest is not completable", %{quest: quest} do
    assert Conditions.all_met?(quest) == false
  end

  test "completing a met quest marks it completed", %{quest: quest} do
    quest = Conditions.update(quest, :map, 1, "", 0, "", 2_000_062)
    quest = Conditions.update(quest, :map, 1, "", 0, "", 2_000_062)
    assert Conditions.all_met?(quest)

    {:ok, completed} = Managers.Quest.State.complete_quest(quest)
    assert completed.state == :completed
    assert completed.completion_count == 1
  end

  # server shutdown stops the manager, whose terminate flushes pending
  # condition counters — covered by the flush persistence test above via
  # Managers.Quest.flush_dirty/1 (the same function terminate calls).

  # regression: grant_items must return the inventory add results (not the
  # acquisition notification's :ok) so post-commit delivery can push the
  # add-item packets
  test "item rewards grant through the inventory and report their results", %{
    character: character
  } do
    Mimic.expect(Managers.Inventory, :add_item, fn _character, item ->
      {:ok, {:create, item}}
    end)

    reward = %{
      exp: 0,
      meso: 0,
      treva: 0,
      rue: 0,
      essential_items: [%{id: 20_000_022, amount: 3, rarity: 1}],
      essential_job_items: [],
      selective_items: []
    }

    prepared = Managers.Quest.Rewards.prepare(character, reward)
    {:ok, results} = Managers.Quest.Rewards.grant_items(character, prepared)

    assert [create: %Schema.Item{item_id: 20_000_022, amount: 3}] = results

    # post-commit delivery pushes the add-item packets; with no session the
    # character is skipped — the regression here is grant_items returning the
    # bare add results
    :ok = Managers.Quest.Rewards.deliver(%{character | session_pid: nil}, reward, results)
  end
end
