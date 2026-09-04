defmodule Ms2ex.Context.QuestsTest do
  use Ms2ex.DataCase, async: true
  use Mimic

  alias Ms2ex.Context.Quests
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  setup do
    stub_metadata(%{
      "quest:5001" => %{
        id: 5001,
        conditions: [
          %{
            type: :map,
            value: 1,
            codes: %{strings: [], integers: [2000], range: nil},
            target: %{strings: [], integers: [], range: nil}
          },
          %{
            type: :quest_clear,
            value: 1,
            codes: %{strings: [], integers: [5001], range: nil},
            target: %{strings: [], integers: [], range: nil}
          }
        ]
      }
    })

    :ok
  end

  test "create_quest persists integer-backed quest states" do
    assert {:ok, quest} =
             Quests.create_quest(%{
               owner_id: 42,
               quest_id: 5001,
               state: :started,
               start_time: 123,
               track: true,
               conditions: %{
                 0 => %{counter: 1, metadata: %{type: :map, value: 1}},
                 1 => %{counter: 0, metadata: %{type: :quest_clear, value: 1}}
               },
               is_account_quest: false
             })

    assert quest.state == :started
    assert quest.conditions[0].counter == 1
    assert quest.conditions[1].counter == 0
  end

  test "get_all_quests reads counters from rows stored before the counters-only format" do
    account =
      Repo.insert!(%Schema.Account{
        username: "legacy_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    Repo.insert!(%Schema.CharacterQuest{
      owner_id: account.id,
      quest_id: 5001,
      state: :started,
      start_time: 123,
      track: true,
      # legacy shape: the whole condition (metadata included) per index
      conditions: %{
        "0" => %{"counter" => 1, "metadata" => %{"type" => "map", "value" => 1}}
      },
      is_account_quest: false
    })

    {account_quests, %{5001 => quest}} = Quests.get_all_quests(account.id, account.id)
    assert account_quests == %{}

    assert quest.conditions[0].counter == 1
    assert quest.conditions[0].metadata.type == :map
  end
end
