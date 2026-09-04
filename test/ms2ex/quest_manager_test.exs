defmodule Ms2ex.QuestManagerTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context.Quests
  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ms2ex.TestHelpers

  # a world quest with one map condition worth 2 visits
  @quest_id 2_001_045
  @quest_metadata %{
    id: @quest_id,
    basic: %{type: :world_quest},
    conditions: [%{type: :map, value: 2, codes: %{range: nil, strings: [], integers: []}}]
  }

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{"quest:#{@quest_id}" => @quest_metadata})

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
end
