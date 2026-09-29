defmodule Ms2ex.LiftupTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field.Liftup
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  import Ms2ex.Packets.PacketReader

  @map_id 2_000_003
  @item_id 18_100_025
  @weapon_skill 99_900_551
  @character %Schema.Character{id: 1, object_id: 501, name: "Testy"}
  @topic "liftup-test"
  # -1650/-600/900 are the block-aligned world coords; the tile is /150
  @grid {-11, -4, 6}

  @weapon %{
    item_ids: [@item_id],
    respawn_tick: 45_000,
    active_distance: 150.0,
    position: %{x: -1650, y: -600, z: 900},
    rotation: %{x: 0, y: 0, z: 0},
    spawn_npc_id: 0,
    spawn_npc_count: 0,
    spawn_npc_rate: 0.0,
    spawn_npc_life_tick: 0
  }

  defp stub_weapon_item(skill_weapon_id) do
    stub_metadata(%{
      "map:#{@map_id}" => %{object_weapons: [@weapon]},
      "item:#{@item_id}" => %{
        slot_names: [],
        skill_weapon_id: skill_weapon_id,
        skill_weapon_level: 1
      }
    })
  end

  defp liftup_state do
    Liftup.init_liftups(%{map_id: @map_id, topic: @topic})
  end

  setup do
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, @topic)
    :ok
  end

  test "init keys the weapons by their block tile" do
    # every test stubs its own metadata: async Mimic stubs are global, so an
    # unstubbed read would race a concurrent test's stub set
    stub_weapon_item(@weapon_skill)

    grid = @grid
    state = liftup_state()
    assert %{^grid => weapon} = state.object_weapons
    assert weapon.item_ids == [@item_id]
    assert state.held_liftups == %{}
  end

  test "lifting rolls the item, broadcasts the pickup and arms the hold" do
    stub_weapon_item(@weapon_skill)

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      1, :lookup -> {:ok, @character}
    end)

    before = Ms2ex.sync_ticks()
    state = liftup_state()
    {state, :ok} = Liftup.liftup(state, 1, @grid)
    after_tick = Ms2ex.sync_ticks()

    hold = state.held_liftups[1]
    assert hold.item_id == @item_id
    assert hold.skill_id == @weapon_skill
    assert hold.skill_level == 1

    assert_receive {:push, pickup}
    {opcode, packet} = get_short(pickup)
    {mode, packet} = get_byte(packet)
    {error, packet} = get_byte(packet)
    {object_id, packet} = get_int(packet)
    {x, packet} = get_sbyte(packet)
    {y, packet} = get_sbyte(packet)
    {z, packet} = get_sbyte(packet)
    {_padding, packet} = get_sbyte(packet)
    {rolled_item, packet} = get_int(packet)
    {respawn_at, _packet} = get_int(packet)

    assert {opcode, mode, error} == {0x6B, 0x11, 0}
    assert {object_id, x, y, z} == {501, -11, -4, 6}
    assert rolled_item == @item_id
    # the respawn deadline is the shared tick plus the weapon's delay
    assert respawn_at in (before + 45_000)..(after_tick + 45_000)

    # holding a thrown object is combat: the stance packet goes out
    assert_receive {:push, <<0x30::little-16, 501::little-32, 1>>}
  end

  test "lifting with a full grip is refused with the not-allowed error" do
    stub_weapon_item(@weapon_skill)

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      1, :lookup -> {:ok, @character}
    end)

    state = liftup_state()
    {state, :ok} = Liftup.liftup(state, 1, @grid)
    assert_receive {:push, <<0x6B::little-16, 0x11, _::binary>>}
    assert_receive {:push, <<0x30::little-16, _::binary>>}

    {_state, {:error, 95}} = Liftup.liftup(state, 1, @grid)
    assert Map.has_key?(state.held_liftups, 1)
    refute_receive {:push, _}
  end

  test "lifting at an empty tile is refused with the no-cube error" do
    stub_weapon_item(@weapon_skill)

    state = liftup_state()
    {state, {:error, 37}} = Liftup.liftup(state, 1, {0, 0, 0})

    assert state.held_liftups == %{}
    refute_receive {:push, _}
  end

  test "lifting an item without a weapon skill is refused" do
    stub_weapon_item(0)

    state = liftup_state()
    {state, {:error, 37}} = Liftup.liftup(state, 1, @grid)

    assert state.held_liftups == %{}
    refute_receive {:push, _}
  end

  test "the throw skill consumes the hold, other skills are refused" do
    stub_weapon_item(@weapon_skill)

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      1, :lookup -> {:ok, @character}
    end)

    state = liftup_state()
    {state, :ok} = Liftup.liftup(state, 1, @grid)

    {state, :error} = Liftup.use_skill(state, 1, 30_000_001, 1)
    assert Map.has_key?(state.held_liftups, 1)

    {state, :ok} = Liftup.use_skill(state, 1, @weapon_skill, 1)
    refute Map.has_key?(state.held_liftups, 1)

    # no hold: every cast passes through
    {_state, :ok} = Liftup.use_skill(state, 1, 30_000_001, 1)
  end

  test "dropping releases the grip and broadcasts the drop frame" do
    stub_weapon_item(@weapon_skill)

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      1, :lookup -> {:ok, @character}
    end)

    state = liftup_state()
    {state, :ok} = Liftup.liftup(state, 1, @grid)
    assert_receive {:push, <<0x6B::little-16, 0x11, _::binary>>}
    assert_receive {:push, <<0x30::little-16, _::binary>>}

    {state, :ok} = Liftup.drop(state, 1)
    assert state.held_liftups == %{}
    assert_receive {:push, <<0x6B::little-16, 0x12, 0, 501::little-32>>}
  end

  test "leaving the field releases the hold without a broadcast" do
    stub_weapon_item(@weapon_skill)

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      1, :lookup -> {:ok, @character}
    end)

    state = liftup_state()
    {state, :ok} = Liftup.liftup(state, 1, @grid)
    assert_receive {:push, <<0x6B::little-16, 0x11, _::binary>>}
    assert_receive {:push, <<0x30::little-16, _::binary>>}

    state = Liftup.release(state, 1)

    assert state.held_liftups == %{}
    refute_receive {:push, _}
  end

  test "dropping with empty hands is a silent no-op" do
    stub_weapon_item(@weapon_skill)

    state = liftup_state()
    {_state, :error} = Liftup.drop(state, 1)

    refute_receive {:push, _}
  end

  test "the error notice rides the response-cube error command" do
    bytes = Packets.ResponseCube.error(37)
    <<0x6B::little-16, 0x02, 37>> = bytes
  end
end
