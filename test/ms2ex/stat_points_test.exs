defmodule Ms2ex.StatPointsTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context.StatPoints
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types.AttributePointSource

  # ---- unit tests (no DB) ----

  test "AttributePointSource.normalize fills missing keys with 0" do
    normalized = AttributePointSource.normalize(%{command: 10})
    assert normalized == %{trophy: 0, quest: 0, exploration: 0, prestige: 0, command: 10}
  end

  test "AttributePointSource.normalize accepts legacy integer keys" do
    normalized = AttributePointSource.normalize(%{5 => 7})
    assert normalized.command == 7
  end

  test "StatPoints.apply adds +1 per strength point" do
    character = character_with_stats(%{strength_cur: 10, strength_max: 10})
    character = %{character | stat_point_allocation: %{strength: 3}}
    character = StatPoints.apply(character)
    assert character.stats.strength_cur == 13
  end

  test "StatPoints.apply adds +10 per health point" do
    character = character_with_stats(%{health_cur: 500, health_max: 500})
    character = %{character | stat_point_allocation: %{health: 2}}
    character = StatPoints.apply(character)
    assert character.stats.health_cur == 520
  end

  test "StatPoints.apply adds +3 per critical_rate point" do
    character = character_with_stats(%{critical_rate_cur: 10, critical_rate_max: 10})
    character = %{character | stat_point_allocation: %{critical_rate: 1}}
    character = StatPoints.apply(character)
    assert character.stats.critical_rate_cur == 13
  end

  test "StatPoints.normalize_allocation accepts wire integer keys" do
    normalized = StatPoints.normalize_allocation(%{0 => 5, 17 => 2})
    assert normalized == %{strength: 5, critical_rate: 2}
  end

  test "Packets.StatPoints.sources encodes atom-keyed map correctly" do
    bytes =
      Packets.StatPoints.sources(%{trophy: 2, quest: 0, exploration: 0, prestige: 0, command: 3})

    # opcode 0x46, command 0x00, total=5, count=5, then sorted entries
    assert <<0x46::little-16, 0x00, 5::little-32, 5::little-32, 1::little-32, 2::little-32,
             2::little-32, 0::little-32, 3::little-32, 0::little-32, 4::little-32, 0::little-32,
             5::little-32, 3::little-32>> = bytes
  end

  test "Packets.StatPoints.allocation encodes atom-keyed map with byte attribute IDs" do
    bytes = Packets.StatPoints.allocation(%{strength: 1}, 10)

    # opcode 0x46, command 0x01, total=10, count=1, attribute 0 (byte), amount=1
    assert <<0x46::little-16, 0x01, 10::little-32, 1::little-32, 0::8, 1::little-32>> = bytes
  end

  test "Packets.Notice.message encodes non-localised string" do
    bytes = Packets.Notice.message("s_char_info_limit_stat_point")

    # opcode 0x73, command 4 (byte), flags 1 (short), localized=false (bool),
    # unknown=5 (int, because "s_" prefix), then unicode string
    assert <<0x73::little-16, 4::8, 1::little-16, 0::8, 5::little-32, _rest::binary>> = bytes
  end

  test "Packets.Notice.message_box encodes localised code" do
    bytes = Packets.Notice.message_box(100)

    assert <<0x73::little-16, 4::8, 64::little-16, 1::8, 1::little-32, 100::little-32, _::binary>> =
             bytes
  end

  # ---- integration tests (DB + manager) ----

  test "add_stat_point persists and increments the correct source" do
    character = insert_character()
    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    assert {:ok, _char} = Managers.Character.add_stat_point(character, :command, 5)

    saved = Repo.get(Schema.Character, character.id)
    assert saved.stat_point_sources.command == 5
  end

  test "allocate_stat_point is rejected when no points available" do
    character = insert_character()
    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    # no sources added → total = 0
    assert :error = Managers.Character.allocate_stat_point(character, :strength)
  end

  test "allocate_stat_point persists and applies stat delta" do
    character =
      insert_character(%{
        stat_point_sources: %{trophy: 0, quest: 0, exploration: 0, prestige: 0, command: 3},
        stats: %{strength_cur: 10, strength_max: 10}
      })

    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    assert {:ok, updated} = Managers.Character.allocate_stat_point(character, :strength)
    assert updated.stats.strength_cur == 11
    assert updated.stat_point_allocation.strength == 1

    saved = Repo.get(Schema.Character, character.id)
    assert saved.stat_point_allocation.strength == 1
  end

  test "reset_stat_points clears allocation and reverts stats" do
    sources = %{trophy: 0, quest: 0, exploration: 0, prestige: 0, command: 5}

    character =
      insert_character(%{
        stat_point_sources: sources,
        stat_point_allocation: %{strength: 2},
        stats: %{strength_cur: 12, strength_max: 12}
      })

    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    assert {:ok, reset} = Managers.Character.reset_stat_points(character)
    assert reset.stat_point_allocation == %{}
    assert reset.stats.strength_cur == 10

    saved = Repo.get(Schema.Character, character.id)
    assert saved.stat_point_allocation == %{}
  end

  # ---- helpers ----

  defp character_with_stats(stat_map) do
    %Schema.Character{
      stats: stat_map,
      stat_point_allocation: %{},
      stat_point_sources: AttributePointSource.default_sources()
    }
  end

  defp insert_character(overrides \\ %{}) do
    account =
      Repo.insert!(%Schema.Account{
        username: "sp_test_#{System.unique_integer([:positive])}",
        password_hash: "hash"
      })

    default_stats = %{
      strength_cur: 10,
      strength_max: 10,
      dexterity_cur: 10,
      dexterity_max: 10,
      intelligence_cur: 10,
      intelligence_max: 10,
      luck_cur: 10,
      luck_max: 10,
      health_cur: 500,
      health_max: 500,
      critical_rate_cur: 10,
      critical_rate_max: 10
    }

    char =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        awakened: false,
        discovered_maps: [],
        exp: 0,
        gender: :male,
        insignia_id: 0,
        level: 1,
        job: :beginner,
        map_id: 0,
        motto: "Let's Maple!",
        name: "SPTest#{System.unique_integer([:positive])}",
        prestige_exp: 0,
        prestige_level: 1,
        profile_url: "",
        rest_exp: 0,
        skin_color: 0,
        taxis: [],
        title_id: 0,
        stat_point_sources: AttributePointSource.default_sources(),
        stat_point_allocation: %{}
      })

    stats = Map.merge(default_stats, Map.get(overrides, :stats, %{}))

    sources =
      Map.get(overrides, :stat_point_sources, AttributePointSource.default_sources())

    allocation = Map.get(overrides, :stat_point_allocation, %{})

    char
    |> Map.put(:stats, stats)
    |> Map.put(:stat_point_sources, sources)
    |> Map.put(:stat_point_allocation, allocation)
    |> Map.put(:sender_session_pid, self())
  end
end
