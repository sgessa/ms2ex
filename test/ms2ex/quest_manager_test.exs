defmodule Ms2ex.QuestManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context.Quests
  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ms2ex.TestHelpers

  # a world quest with one map condition worth 2 visits, rewarding potions
  @quest_id 2_001_045
  @quest_metadata %{
    id: @quest_id,
    basic: %{type: :world_quest, chapter_id: 0},
    conditions: [%{type: :map, value: 2, codes: %{range: nil, strings: [], integers: []}}],
    complete_reward: %{
      exp: 0,
      meso: 0,
      treva: 0,
      rue: 0,
      essential_items: [],
      essential_job_items: [],
      selective_items: []
    }
  }

  setup {Mimic, :set_mimic_global}

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

    {:ok, _quest} =
      Quests.create_quest(%{
        owner_id: character.id,
        quest_id: @quest_id,
        is_account_quest: false,
        state: :started,
        conditions: %{},
        start_time: System.system_time(:second)
      })

    {:ok, char_pid} = Managers.Character.start(character)
    :ok = Managers.Inventory.start(character)
    {:ok, quest_pid} = Managers.Quest.start_link(character.id)

    on_exit(fn ->
      if Process.alive?(quest_pid), do: GenServer.stop(quest_pid)
      if Process.alive?(char_pid), do: GenServer.stop(char_pid)
    end)

    %{character: character}
  end

  # condition updates are asynchronous casts; poll until the assertion holds
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

  defp quest_conditions(character_id) do
    Repo.get_by(Schema.CharacterQuest, %{owner_id: character_id, quest_id: @quest_id}).conditions
  end

  test "condition counters accumulate in memory and persist on flush", %{
    character: character
  } do
    Managers.Quest.update_conditions(character.id, :map, 1, "", 0, "", 2_000_062)

    wait_until(fn ->
      {_account_quests, character_quests} = Managers.Quest.get_all_quests(character.id)
      assert character_quests[@quest_id].conditions[0].counter == 1
    end)

    # the database row still holds the pre-event counters: ordinary events
    # do not write
    assert quest_conditions(character.id) == %{}

    Managers.Quest.update_conditions(character.id, :map, 1, "", 0, "", 2_000_062)

    :ok = Managers.Quest.flush(character.id)

    assert %{"0" => 2} = quest_conditions(character.id)
  end

  test "completing a quest marks it completed", %{character: character} do
    Managers.Quest.update_conditions(character.id, :map, 1, "", 0, "", 2_000_062)
    Managers.Quest.update_conditions(character.id, :map, 1, "", 0, "", 2_000_062)

    wait_until(fn ->
      {_account, character_quests} = Managers.Quest.get_all_quests(character.id)
      assert character_quests[@quest_id].conditions[0].counter == 2
    end)

    assert {:ok, _quest} = Managers.Quest.complete(@quest_id, character.id)

    assert %Schema.CharacterQuest{state: :completed} =
             Repo.get_by(Schema.CharacterQuest, %{owner_id: character.id, quest_id: @quest_id})
  end

  # regression: grant_items must return the inventory add results (not the
  # acquisition notification's :ok) so post-commit delivery can push the
  # add-item packets
  test "item rewards grant through the inventory and report their results", %{
    character: character
  } do
    reward = %{
      exp: 0,
      meso: 0,
      treva: 0,
      rue: 0,
      essential_items: [%{id: 20_000_022, amount: 3, rarity: 1}],
      essential_job_items: [],
      selective_items: []
    }

    prepared = Ms2ex.Managers.Quest.Rewards.prepare(character, reward)
    {:ok, results} = Ms2ex.Managers.Quest.Rewards.grant_items(character, prepared)

    assert [create: %Schema.Item{item_id: 20_000_022, amount: 3}] = results

    :ok = Ms2ex.Managers.Quest.Rewards.deliver(character, reward, results)

    assert %Schema.Item{amount: 3} =
             Repo.get_by(Schema.Item, %{character_id: character.id, item_id: 20_000_022})
  end
end
