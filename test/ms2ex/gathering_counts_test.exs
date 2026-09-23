defmodule Ms2ex.GatheringCountsTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  setup do
    account =
      Repo.insert!(%Schema.Account{
        username: "gather_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Gather#{System.unique_integer([:positive])}",
        job: :knight,
        level: 1,
        map_id: 1,
        skin_color: {}
      })

    # the mastery manager owns the counters; its state is a plain map and
    # caches the config row its bumps are persisted through
    state = %{
      character_id: character.id,
      row: character,
      config: Context.CharacterConfigs.get(character.id),
      masteries: %{},
      claimed: %{},
      gathering_counts: %{},
      dirty?: false
    }

    %{character: character, state: state}
  end

  test "harvest bumps accumulate in the manager state and persist", %{
    character: character,
    state: state
  } do
    {:reply, :ok, state} =
      Managers.Mastery.handle_call({:bump_gathering_count, 40_000_015}, :from, state)

    {:reply, :ok, state} =
      Managers.Mastery.handle_call({:bump_gathering_count, 40_000_015}, :from, state)

    {:reply, :ok, state} =
      Managers.Mastery.handle_call({:bump_gathering_count, 30_000_005}, :from, state)

    assert state.gathering_counts == %{40_000_015 => 2, 30_000_005 => 1}
    assert Context.CharacterConfigs.get(character.id).gathering_counts == state.gathering_counts
  end

  test "a character that never gathered reads empty counts", %{character: character} do
    assert Context.CharacterConfigs.get(character.id).gathering_counts == %{}
  end

  test "the daily reset clears the persisted counts and the cached ones", %{
    character: character,
    state: state
  } do
    {:reply, :ok, state} =
      Managers.Mastery.handle_call({:bump_gathering_count, 40_000_015}, :from, state)

    assert state.gathering_counts == %{40_000_015 => 1}

    Context.DailyReset.reset()

    # the persisted column is cleared and reads back empty
    assert Context.CharacterConfigs.get(character.id).gathering_counts == %{}

    # the cached counts drop too, so the next harvest starts from zero
    {:noreply, state} = Managers.Mastery.handle_cast(:reset_gathering_counts, state)
    assert state.gathering_counts == %{}
  end

  test "instant revives accumulate, persist, and the daily reset clears them", %{
    character: character
  } do
    # the config manager owns the revive counter; its state carries the row
    state = %{
      character_id: character.id,
      hot_bars: [],
      config: Context.CharacterConfigs.get(character.id)
    }

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call({:bump_instant_revive_count}, :from, state)

    {:reply, :ok, state} =
      Managers.CharacterConfig.handle_call({:bump_instant_revive_count}, :from, state)

    assert state.config.instant_revive_count == 2
    assert Context.CharacterConfigs.get(character.id).instant_revive_count == 2

    {:reply, 2, ^state} =
      Managers.CharacterConfig.handle_call(:instant_revive_count, :from, state)

    # the daily reset cast clears only the cache; the bulk column clear is
    # what persists, so the row still holds the pre-reset value here
    {:noreply, state} = Managers.CharacterConfig.handle_cast(:reset_daily, state)
    assert state.config.instant_revive_count == 0
    assert Context.CharacterConfigs.get(character.id).instant_revive_count == 2
  end
end
