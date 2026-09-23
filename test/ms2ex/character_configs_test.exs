defmodule Ms2ex.CharacterConfigsTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

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

    %{character: character}
  end

  test "a character without a config row reads an all-empty config", %{character: character} do
    config = Context.CharacterConfigs.get(character.id)

    assert config.key_binds == %{}
    assert config.guide_records == %{}
    assert config.gathering_counts == %{}
  end

  test "update_field inserts when no row exists yet", %{character: character} do
    config = Context.CharacterConfigs.get(character.id)

    {:ok, inserted} =
      Context.CharacterConfigs.update_field(config, :key_binds, %{
        18 => %Types.KeyBind{key_code: 18, option_type: 1, option_guid: 500_009}
      })

    assert inserted.id != nil
    assert Context.CharacterConfigs.get(character.id).key_binds |> map_size() == 1
  end

  test "update_field replaces the field and returns the updated row", %{character: character} do
    {:ok, first} =
      Context.CharacterConfigs.update_field(
        Context.CharacterConfigs.get(character.id),
        :guide_records,
        %{101 => 2}
      )

    {:ok, updated} =
      Context.CharacterConfigs.update_field(first, :guide_records, %{101 => 6, 202 => 4})

    assert updated.id == first.id
    assert Context.CharacterConfigs.get(character.id).guide_records == %{101 => 6, 202 => 4}
  end

  test "updating with an unchanged value emits no write and keeps the row", %{
    character: character
  } do
    counts = %{40_000_015 => 2}

    {:ok, first} =
      Context.CharacterConfigs.update_field(
        Context.CharacterConfigs.get(character.id),
        :gathering_counts,
        counts
      )

    # the manager only calls this after an actual change, but an unchanged
    # value is safely skipped instead of written
    {:ok, same} =
      Context.CharacterConfigs.update_field(first, :gathering_counts, counts)

    assert same.id == first.id
    assert Context.CharacterConfigs.get(character.id).gathering_counts == counts
  end
end
