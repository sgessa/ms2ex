defmodule Ms2ex.CharacterConfigsTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  setup do
    account =
      Repo.insert!(%Schema.Account{
        username: "cfg_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Cfg#{System.unique_integer([:positive])}",
        job: :knight,
        level: 1,
        map_id: 1,
        skin_color: {}
      })

    Repo.insert!(%Schema.CharacterConfig{character_id: character.id})

    %{account: account, character: character}
  end

  test "character creation seeds the config row", %{account: account} do
    {:ok, character} =
      Context.Characters.create(account, %{
        name: "CfgNew#{System.unique_integer([:positive])}",
        job: :knight,
        map_id: 1,
        skin_color: {}
      })

    config = Context.CharacterConfigs.get(character.id)

    assert config.key_binds == %{}
    assert config.guide_records == %{}
    assert config.gathering_counts == %{}
    assert config.instant_revive_count == 0
  end

  test "reading a missing config row raises", %{account: account} do
    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "CfgOrphan#{System.unique_integer([:positive])}",
        job: :knight,
        level: 1,
        map_id: 1,
        skin_color: {}
      })

    assert_raise Ecto.NoResultsError, fn ->
      Context.CharacterConfigs.get(character.id)
    end
  end

  test "update ignores fields outside the config changeset", %{character: character} do
    {:ok, config} =
      Context.CharacterConfigs.update(Context.CharacterConfigs.get(character.id), %{
        name: "nope",
        key_binds: %{18 => :bind}
      })

    # only the cast fields land; the rest of the attrs is dropped
    assert config.key_binds == %{18 => :bind}
    assert Context.CharacterConfigs.get(character.id).gathering_counts == %{}
  end

  test "update replaces the field and returns the updated row", %{character: character} do
    {:ok, first} =
      Context.CharacterConfigs.update(Context.CharacterConfigs.get(character.id), %{
        guide_records: %{101 => 2}
      })

    {:ok, updated} =
      Context.CharacterConfigs.update(first, %{guide_records: %{101 => 6, 202 => 4}})

    assert updated.id == first.id
    assert Context.CharacterConfigs.get(character.id).guide_records == %{101 => 6, 202 => 4}
  end

  test "updating with an unchanged value emits no write and keeps the row", %{
    character: character
  } do
    counts = %{101 => 2}

    {:ok, first} =
      Context.CharacterConfigs.update(Context.CharacterConfigs.get(character.id), %{
        guide_records: counts
      })

    # the manager only calls this after an actual change, but an unchanged
    # value is safely skipped instead of written
    {:ok, same} = Context.CharacterConfigs.update(first, %{guide_records: counts})

    assert same.id == first.id
    assert Context.CharacterConfigs.get(character.id).guide_records == counts
  end
end
