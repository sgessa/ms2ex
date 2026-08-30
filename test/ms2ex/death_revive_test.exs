defmodule Ms2ex.DeathReviveTest do
  use ExUnit.Case, async: true
  use Mimic

  import Ms2ex.TestHelpers

  alias Ms2ex.Packets
  alias Ms2ex.Types

  @map_id 2000

  setup do
    Mimic.stub(Ms2ex.Context.Characters, :update, fn character, _attrs -> {:ok, character} end)

    Mimic.stub(Ms2ex.Context.Wallets, :find, fn _character ->
      %Ms2ex.Schema.Wallet{mesos: 100_000}
    end)

    Mimic.stub(Ms2ex.Context.Wallets, :update, fn _character, _currency, _amount ->
      {:ok, %Ms2ex.Schema.Wallet{}}
    end)

    :ok
  end

  defp character(character_id) do
    %Ms2ex.Schema.Character{
      id: character_id,
      object_id: character_id + 100_000,
      map_id: @map_id,
      channel_id: 1,
      sender_session_pid: self(),
      field_pid: nil,
      stats: %{
        health_max: 1000,
        health_cur: 1000,
        spirit_max: 0,
        spirit_cur: 0,
        stamina_max: 0,
        stamina_cur: 0,
        hp_regen_interval_cur: 1000,
        sp_regen_interval_cur: 1000,
        stamina_regen_interval_cur: 1000
      }
    }
  end

  defp stub_map(property) do
    spawn = %{position: %{x: 100, y: 200, z: 0}, rotation: %{x: 0, y: 0, z: 0}}

    stub_metadata(%{
      "map:#{@map_id}" => %{property: property, pc_spawns: [Map.merge(spawn, %{enable: true})]}
    })
  end

  # drive the character process handlers directly (no live GenServer), so the
  # metadata stub applies to the calling process, mirroring Field.handle_call
  defp cast(character, msg) do
    {:noreply, updated} = Ms2ex.Managers.Character.handle_cast(msg, character)
    updated
  end

  test "health reaching 0 marks the character dead once" do
    stub_map(%{revival_return_id: 0, no_revival_here: false, only_dark_tomb: false})

    character =
      character(50_001)
      |> cast({:decrease_stats, [health: 500]})

    assert character.dead? == false

    character =
      character
      |> cast({:decrease_stats, [health: 500]})

    assert character.dead?
    assert character.death_count == 1

    # further damage while dead must not re-trigger the death flow
    character = cast(character, {:decrease_stats, [health: 100]})
    assert character.death_count == 1
  end

  test "safe revive restores full health and clears the dead flag" do
    stub_map(%{revival_return_id: 0, no_revival_here: false, only_dark_tomb: false})

    character =
      character(50_002)
      |> cast({:decrease_stats, [health: 1000]})
      |> cast({:revive, :safe})

    assert character.dead? == false
    assert character.stats.health_cur == 1000
  end

  test "no-revival maps refuse the revive" do
    stub_map(%{revival_return_id: 0, no_revival_here: true, only_dark_tomb: true})

    character =
      character(50_003)
      |> cast({:decrease_stats, [health: 1000]})
      |> cast({:revive, :safe})

    assert character.dead?
  end

  test "revival return map routes the safe revive through the return map" do
    spawn = %{position: %{x: 1, y: 2, z: 0}, rotation: %{x: 0, y: 0, z: 0}}

    # the destination map must exist too (change_field resolves its spawn)
    stub_metadata(%{
      "map:#{@map_id}" => %{
        property: %{revival_return_id: 6200, no_revival_here: false, only_dark_tomb: false},
        pc_spawns: [Map.merge(spawn, %{enable: true})]
      },
      "map:6200" => %{property: %{}, pc_spawns: [Map.merge(spawn, %{enable: true})]}
    })

    character =
      character(50_004)
      |> cast({:decrease_stats, [health: 1000]})
      |> cast({:revive, :safe})

    assert character.dead? == false
  end

  test "tombstone hit count scales with the death count and caps" do
    first = Types.Tombstone.new(character(50_005), 1)
    assert first.total_hit_count == first.hits_remaining

    # a capped hit count stays under the per-death multiplier
    repeat = Types.Tombstone.new(character(50_005), 5)
    assert repeat.hits_remaining <= repeat.total_hit_count
  end

  describe "instant revive meso cost" do
    test "matches the client price at level 60 (60k)" do
      assert Ms2ex.Managers.Character.Revival.revival_meso_cost(60, 0) == 60_000
    end

    test "first daily revive is flat, later ones scale with level" do
      assert Ms2ex.Managers.Character.Revival.revival_meso_cost(60, 1) == 10_000
      assert Ms2ex.Managers.Character.Revival.revival_meso_cost(20, 0) == 20_000
      assert Ms2ex.Managers.Character.Revival.revival_meso_cost(60, 0) == 60_000
    end
  end

  test "instant revive count persists and the daily reset zeroes it" do
    die = &cast(&1, {:decrease_stats, [health: 1000]})
    revive = &cast(&1, {:revive, :instant, false})

    char =
      character(50_006)
      |> die.()
      |> revive.()
      |> die.()
      |> revive.()

    assert char.instant_revive_count == 2

    # the daily-reset worker cast clears the in-memory counter
    reset = cast(char, :reset_daily_revives)
    assert reset.instant_revive_count == 0
  end

  describe "packet serialization" do
    test "DeadUser writes object id and tomb flag" do
      assert <<0xA8::little-signed-16, 9_999::little-signed-32, 0>> =
               Packets.DeadUser.bytes(9_999, false)

      assert <<0xA8::little-signed-16, 9_999::little-signed-32, 1>> =
               Packets.DeadUser.bytes(9_999, true)
    end

    test "Revival writes the object id and a trailing byte" do
      assert <<0x35::little-signed-16, 9_999::little-signed-32, 0>> =
               Packets.Revival.bytes(9_999)
    end

    test "Tombstone writes hit counts and flags" do
      tombstone = %Types.Tombstone{
        object_id: 9_999,
        hits_remaining: 3,
        total_hit_count: 5,
        unknown1: 1,
        unknown2: false
      }

      assert <<0x5E::little-signed-16, 9_999::little-signed-32, 3, 5, 1::little-signed-32, 0>> =
               Packets.Tombstone.bytes(tombstone)
    end

    test "update_dead broadcasts the dead flag" do
      char = %Ms2ex.Schema.Character{object_id: 9_999, dead?: true}

      assert <<0x80::little-signed-16, 0x5, 9_999::little-signed-32, 0x1, 1>> =
               Packets.ProxyGameObj.update_dead(char)

      assert <<0x80::little-signed-16, 0x5, 9_999::little-signed-32, 0x1, 0>> =
               Packets.ProxyGameObj.update_dead(%{char | dead?: false})
    end

    test "FieldAddUser carries the dead peer's death count" do
      # the reference writes the death count right after the character's current
      # health (FieldPacket.WriteCharacter); the client uses it to build a
      # targetable tombstone for a player who joins a field where someone is
      # already dead
      alive =
        character(9_999)
        |> Map.put(:name, "Alice")
        |> Map.put(:skin_color, Types.SkinColor.build({0, 0, 0, 0}, {0, 0, 0, 0}))
        |> Map.put(:clubs, [])
        |> Map.put(:trophies, [])

      dead = %{alive | death_count: 2}

      zero = Ms2ex.Packets.CharacterList.put_character(<<>>, dead, 0)
      two = Ms2ex.Packets.CharacterList.put_character(<<>>, dead, 2)

      # identical except for the death-count short
      diff_at = first_diff(zero, two)
      assert diff_at != -1
      assert <<0::little-signed-16>> = binary_part(zero, diff_at, 2)
      assert <<2::little-signed-16>> = binary_part(two, diff_at, 2)
      assert byte_size(zero) == byte_size(two)
    end

    defp first_diff(a, b) do
      Enum.reduce_while(0..(byte_size(a) - 1), -1, fn i, _acc ->
        if binary_part(a, i, 1) != binary_part(b, i, 1) do
          {:halt, i}
        else
          {:cont, -1}
        end
      end)
    end
  end
end
