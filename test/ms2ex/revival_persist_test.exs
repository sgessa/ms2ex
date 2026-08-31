defmodule Ms2ex.RevivalPersistTest do
  use Ms2ex.DataCase, async: true
  use Mimic

  import Ms2ex.TestHelpers

  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @map_id 2000

  setup do
    stub_metadata(%{
      "map:#{@map_id}" => %{
        property: %{revival_return_id: 0, no_revival_here: false, only_dark_tomb: false},
        pc_spawns: [
          %{position: %{x: 100, y: 200, z: 0}, rotation: %{x: 0, y: 0, z: 0}, enable: true}
        ]
      }
    })

    :ok
  end

  # a real DB row (no Context.Characters stub), so the persistence step writes
  # to an actual character row instead of being swallowed by Mimic
  defp insert_character do
    account = Repo.insert!(%Schema.Account{username: "revival_persist", password_hash: "x"})

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "RevivalPersist",
        job: :knight,
        map_id: @map_id,
        level: 60,
        skin_color: {}
      })

    Repo.insert!(%Schema.Wallet{character_id: character.id, mesos: 100_000})

    character
    |> Context.Characters.preload([:stats])
    |> Map.put(:sender_session_pid, self())
    |> Map.put(:field_pid, nil)
    |> Map.put(:channel_id, 1)
    |> Map.put(:object_id, 9_999)
    |> Map.put(:stats, %Schema.CharacterStats{health_cur: 1000, health_max: 1000})
  end

  defp cast(character, msg) do
    {:noreply, updated} = Ms2ex.Managers.Character.handle_cast(msg, character)
    updated
  end

  test "death count and instant revive count are written to the db" do
    character =
      insert_character()
      |> cast({:decrease_stats, [health: 1000]})
      |> cast({:revive, :instant, false})

    reloaded = Repo.get!(Schema.Character, character.id)
    assert reloaded.death_count == 1
    assert reloaded.instant_revive_count == 1
  end
end
