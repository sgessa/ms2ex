defmodule Ms2ex.SkillCooldownTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Types

  defp skill_cast(level, cooldown_time, state \\ %{}) do
    %Types.SkillCast{
      skill_id: 15_000_220,
      skill_level: level,
      meta: %{
        levels: %{"1" => %{cooldown_time: cooldown_time}},
        state: state
      }
    }
  end

  test "computes the cooldown from the level condition and skill state" do
    cooldown =
      skill_cast(1, 2.5, %{cooldown_group_id: 3, recharge_max_count: 2})
      |> Types.SkillCast.cooldown(1000)

    assert cooldown.skill_id == 15_000_220
    assert cooldown.level == 1
    assert cooldown.start_tick == 1000
    assert cooldown.end_tick == 3500
    assert cooldown.group_id == 3
    assert cooldown.recharge_max_count == 2
    assert cooldown.charges == 0
  end

  test "returns nil when there is no cooldown" do
    assert Types.SkillCast.cooldown(skill_cast(1, 0), 1000) == nil
  end

  test "recharge skills keep a cooldown record without cooldown time" do
    assert Types.SkillCast.cooldown(skill_cast(1, 0, %{recharge_max_count: 3}), 1000).end_tick ==
             1000
  end

  test "missing skill state defaults the group id" do
    assert Types.SkillCast.cooldown(skill_cast(1, 1.0), 1000).group_id == 0
  end

  test "serializes cooldowns in the client layout" do
    bytes =
      Packets.SkillCooldown.bytes([
        %{skill_id: 15_000_220, group_id: 3, end_tick: 3500, charges: 0},
        %{skill_id: 15_000_221, group_id: 0, end_tick: 1234, charges: 1}
      ])

    assert <<0x43::little-signed-16, count, rest::binary>> = bytes
    assert count == 2

    assert <<
             sid1::little-signed-32,
             gid1::little-signed-32,
             end1::little-signed-32,
             chg1::little-signed-32,
             sid2::little-signed-32,
             gid2::little-signed-32,
             end2::little-signed-32,
             chg2::little-signed-32
           >> = rest

    assert {sid1, gid1, end1, chg1} == {15_000_220, 3, 3500, 0}
    assert {sid2, gid2, end2, chg2} == {15_000_221, 0, 1234, 1}
  end

  test "active cooldowns survive field re-entry and are pruned when expired" do
    character = %Ms2ex.Schema.Character{id: 99_999, stats: %{}, level: 1}
    now = Ms2ex.sync_ticks()

    {:ok, _pid} = GenServer.start(Ms2ex.Managers.Character, character, name: :"characters:99999")

    Managers.Character.call(character, {:save_skill_cooldown, %{
      skill_id: 15_000_220,
      level: 1,
      start_tick: now,
      end_tick: now + 1000,
      group_id: 3,
      recharge_max_count: 0,
      charges: 0
    }})

    {:ok, [cooldown]} = Managers.Character.call(99_999, {:get_skill_cooldowns, Ms2ex.sync_ticks()})
    assert cooldown.skill_id == 15_000_220
    assert cooldown.end_tick == now + 1000

    Managers.Character.call(character, {:save_skill_cooldown, %{
      skill_id: 15_000_220,
      level: 1,
      start_tick: now + 2000,
      end_tick: now + 3000,
      group_id: 3,
      recharge_max_count: 0,
      charges: 0
    }})

    {:ok, [cooldown]} = Managers.Character.call(99_999, {:get_skill_cooldowns, Ms2ex.sync_ticks()})
    assert cooldown.end_tick == now + 3000
  end

  test "cooldowns survive a character state replacement" do
    character = %Ms2ex.Schema.Character{id: 101_000, stats: %{}, level: 1}
    now = Ms2ex.sync_ticks()

    {:ok, _pid} =
      GenServer.start(Ms2ex.Managers.Character, character, name: :"characters:101000")

    Managers.Character.call(character, {:save_skill_cooldown, %{
      skill_id: 15_000_220,
      level: 1,
      start_tick: now,
      end_tick: now + 5000,
      group_id: 3,
      recharge_max_count: 0,
      charges: 0
    }})

    Managers.Character.call(101_000, {:update, %Ms2ex.Schema.Character{id: 101_000, stats: %{}, level: 1}})

    {:ok, [cooldown]} = Managers.Character.call(101_000, {:get_skill_cooldowns, Ms2ex.sync_ticks()})
    assert cooldown.skill_id == 15_000_220
  end

  test "setting a cooldown overrides the stored one (cooldown reset)" do
    character = %Ms2ex.Schema.Character{id: 102_000, stats: %{}, level: 1}
    now = Ms2ex.sync_ticks()

    {:ok, _pid} =
      GenServer.start(Ms2ex.Managers.Character, character, name: :"characters:102000")

    Managers.Character.call(character, {:save_skill_cooldown, %{
      skill_id: 15_000_220,
      level: 1,
      start_tick: now,
      end_tick: now + 5000,
      group_id: 3,
      recharge_max_count: 0,
      charges: 0
    }})

    {:ok, cooldown} = Managers.Character.call(character, {:set_skill_cooldown, 15_000_220, 1, 0})
    assert cooldown.end_tick == 0

    assert {:ok, []} = Managers.Character.call(102_000, {:get_skill_cooldowns, Ms2ex.sync_ticks()})
  end

  test "rechargeable skills gain charges on each cast" do
    character = %Ms2ex.Schema.Character{id: 100_000, stats: %{}, level: 1}
    now = Ms2ex.sync_ticks()

    {:ok, _pid} =
      GenServer.start(Ms2ex.Managers.Character, character, name: :"characters:100000")

    for i <- [0, 1, 2] do
      Managers.Character.call(character, {:save_skill_cooldown, %{
        skill_id: 15_000_220,
        level: 1,
        start_tick: now + i,
        end_tick: now + 5000,
        group_id: 0,
        recharge_max_count: 2,
        charges: 0
      }})
    end

    {:ok, [cooldown]} = Managers.Character.call(100_000, {:get_skill_cooldowns, Ms2ex.sync_ticks()})
    assert cooldown.charges == 2
  end
end
