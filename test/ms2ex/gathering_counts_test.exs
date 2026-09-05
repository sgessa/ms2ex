defmodule Ms2ex.GatheringCountsTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Context
  alias Ms2ex.Managers.Character.Fishing
  alias Ms2ex.Managers.Character.Mastery
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  defp insert_character(name) do
    account = Repo.insert!(%Schema.Account{username: name, password_hash: "x"})

    Repo.insert!(%Schema.Character{
      account_id: account.id,
      name: name,
      job: :knight,
      map_id: 2000,
      level: 10,
      skin_color: {}
    })
    |> Map.put(:sender_session_pid, nil)
  end

  test "harvest counts and masteries survive a flush and reload" do
    character = insert_character("gather_flush")

    character =
      character
      |> Mastery.count_gather(40_000_015)
      |> Mastery.count_gather(40_000_015)
      |> Mastery.count_gather(30_000_005)
      |> Map.put(:masteries, %{mining: 120, fishing: 30})
      |> Mastery.claim(3001)

    {character, _entry, _first?} = Fishing.record_catch(character, 101, 40, true)

    assert Mastery.gathering_counts(character) == %{40_000_015 => 2, 30_000_005 => 1}
    assert character.mastery_dirty?

    character = Mastery.flush(character)
    refute character.mastery_dirty?

    reloaded = Context.Characters.get(character.id)
    assert Mastery.gathering_counts(reloaded) == %{40_000_015 => 2, 30_000_005 => 1}
    assert Mastery.all(reloaded) == %{mining: 120, fishing: 30}
    assert Mastery.claimed?(reloaded, 3001)

    assert Fishing.album(reloaded) == %{
             101 => %{fish_id: 101, total_caught: 1, total_prize: 1, largest_size: 40}
           }
  end

  test "a character that never gathered loads with empty counts" do
    character = insert_character("gather_empty")

    assert Mastery.gathering_counts(Context.Characters.get(character.id)) == %{}
  end

  test "the daily reset clears the persisted counts of every character" do
    first = insert_character("gather_reset_a") |> Mastery.count_gather(40_000_015)
    second = insert_character("gather_reset_b") |> Mastery.count_gather(30_000_005)

    Mastery.flush(first)
    Mastery.flush(second)

    Context.DailyReset.reset()

    for character <- [first, second] do
      assert Mastery.gathering_counts(Context.Characters.get(character.id)) == %{}
    end
  end
end
