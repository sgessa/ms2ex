defmodule Ms2ex.FieldPetWildTest do
  use Ms2ex.DataCase, async: true

  # synthetic mesh-set binary (regenerable with the crate's gen_fixtures
  # binary): an open 40x40 floor
  @open File.read!("test/fixtures/navmesh/open.mset")

  alias Ms2ex.Managers.Field.Pet
  alias Ms2ex.Types

  setup do
    # deterministic runaway/trace rolls
    :rand.seed(:exsss, {11, 22, 33})
    stub_metadata(%{})
    :ok
  end

  defp unique_map do
    suffix = System.unique_integer([:positive])
    {994_000_000 + suffix, "test_wild_pet_#{suffix}"}
  end

  defp stub_world(map_id, xblock) do
    stub_metadata(%{
      "map:#{map_id}" => %{x_block: xblock},
      "navmesh_bin:#{xblock}" => @open,
      # anikey docs key on the lowercased model name; declaring the keys
      # here also makes the atoms exist for Storage.Animations' to_existing_atom
      "animation:testmob" => %{
        sequences: %{
          Walk_A: %{id: 9},
          Run_A: %{id: 11},
          Idle_A: %{id: 10},
          Attack_Idle_A: %{id: 8}
        }
      }
    })

    on_exit(fn -> :persistent_term.erase({:navmesh_native, xblock}) end)
  end

  defp wild_pet(map_id, position, taming_points) do
    Types.FieldPet.new(%{
      object_id: 60_000_001,
      map_id: map_id,
      npc:
        Types.Npc.new(%{
          id: 61_000_002,
          metadata: %{
            basic: %{friendly: 1, class: 0, level: 10},
            stat: %{stats: %{health: 1000, movement_speed: 100}},
            model: %{name: "TestMob"},
            capsule: %{radius: 50, height: 150},
            action: %{walk_speed: 100, run_speed: 350},
            skill: []
          }
        }),
      position: position,
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      taming_points: taming_points,
      taming_rank: 10
    })
  end

  # one live player on the field at the given position
  defp field_with_player(position) do
    %{
      players: %{1 => 100},
      player_positions: %{1 => %{position: position}},
      tombstones: %{}
    }
  end

  defp empty_field, do: %{players: %{}, player_positions: %{}, tombstones: %{}}

  defp distance(from, to) do
    dx = to.x - from.x
    dy = to.y - from.y
    :math.sqrt(dx * dx + dy * dy)
  end

  # 200ms ticks, like the field loop's cadence
  defp run(pet, field, ticks) do
    Enum.reduce(1..ticks, pet, fn i, pet ->
      {pet, _} = Pet.wild_ai(pet, field, i * 200)
      pet
    end)
  end

  test "a pet with no players nearby holds position" do
    {map_id, xblock} = unique_map()
    stub_world(map_id, xblock)

    pet = wild_pet(map_id, %Types.Coord{x: 1000, y: -1000, z: 0}, 0)
    pet = run(pet, empty_field(), 6)

    assert pet.velocity == {0, 0, 0}
    assert pet.position.x == 1000
    assert pet.position.y == -1000
  end

  test "a full-gauge pet traces to the player and holds inside the band" do
    {map_id, xblock} = unique_map()
    stub_world(map_id, xblock)

    player = %Types.Coord{x: 2000, y: -1000, z: 0}
    pet = wild_pet(map_id, %Types.Coord{x: 1000, y: -1000, z: 0}, 10_000)

    pet = run(pet, field_with_player(player), 20)

    assert distance(pet.position, player) <= 400
    assert pet.velocity == {0, 0, 0}, "holds once inside the approach band"
  end

  test "a calm pet closes distance far slower than a full-gauge one" do
    {map_id, xblock} = unique_map()
    stub_world(map_id, xblock)

    player = %Types.Coord{x: 2000, y: -1000, z: 0}
    calm = wild_pet(map_id, %Types.Coord{x: 1000, y: -1000, z: 0}, 4_000)
    ready = wild_pet(map_id, %Types.Coord{x: 1000, y: -1000, z: 0}, 10_000)

    calm = run(calm, field_with_player(player), 20)
    ready = run(ready, field_with_player(player), 20)

    assert distance(ready.position, player) <= 400
    assert distance(calm.position, player) > 400, "the fed pet mostly stands"
  end

  test "a nearly-full pet backs off when the player is close" do
    {map_id, xblock} = unique_map()
    stub_world(map_id, xblock)

    player = %Types.Coord{x: 1200, y: -1000, z: 0}
    pet = wild_pet(map_id, %Types.Coord{x: 1000, y: -1000, z: 0}, 9_000)

    pet = run(pet, field_with_player(player), 20)

    assert distance(pet.position, player) > 200, "shies away inside the band"
  end

  test "a panicked pet keeps its distance from a close player" do
    {map_id, xblock} = unique_map()
    stub_world(map_id, xblock)

    player = %Types.Coord{x: 1200, y: -1000, z: 0}
    pet = wild_pet(map_id, %Types.Coord{x: 1000, y: -1000, z: 0}, 0)

    pet = run(pet, field_with_player(player), 20)

    assert distance(pet.position, player) > 200, "runaway hops dominate at low gauge"
  end
end
