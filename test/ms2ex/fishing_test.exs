defmodule Ms2ex.FishingTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketReader

  describe "fishing packets" do
    test "prepare echoes the rod uid" do
      {opcode, packet} = Packets.Fishing.prepare(1234) |> get_short()
      {command, packet} = get_byte(packet)
      {rod_uid, packet} = get_long(packet)

      assert {opcode, command, rod_uid, packet} == {0xC6, 0x00, 1234, <<>>}
    end

    test "errors carry the short error code" do
      {opcode, packet} = Packets.Fishing.error(:s_fishing_error_lack_mastery) |> get_short()
      {command, packet} = get_byte(packet)
      {error, packet} = get_short(packet)

      assert {opcode, command, error, packet} == {0xC6, 0x02, 3, <<>>}
    end

    test "tiles are block coordinates padded to four bytes" do
      tiles = [%{position: %{x: 3, y: -2, z: 5}, liquid_type: :water}]

      {opcode, packet} = Packets.Fishing.load_tiles(tiles, 2000) |> get_short()
      {command, packet} = get_byte(packet)
      {_disabled, packet} = get_byte(packet)
      {count, packet} = get_int(packet)
      {position, packet} = get_sbyte_coord(packet)
      {_padding, packet} = get_byte(packet)
      {fish_id, packet} = get_int(packet)
      {_unknown, packet} = get_int(packet)
      {bore_time, packet} = get_int(packet)
      {_unknown2, packet} = get_short(packet)

      assert {opcode, command, count} == {0xC6, 0x04, 1}
      assert {position.x, position.y, position.z} == {3, -2, 5}
      assert {fish_id, bore_time, packet} == {10_000_001, 13_000, <<>>}
    end

    test "a catch without an album entry omits the entry block" do
      {opcode, packet} = Packets.Fishing.catch_fish(101, 55, false) |> get_short()
      {command, packet} = get_byte(packet)
      {fish_id, packet} = get_int(packet)
      {size, packet} = get_int(packet)
      {has_entry, packet} = get_bool(packet)
      {auto, packet} = get_bool(packet)

      assert {opcode, command, fish_id, size, has_entry, auto, packet} ==
               {0xC6, 0x08, 101, 55, false, false, <<>>}
    end

    test "the album lists every recorded fish" do
      album = %{101 => %{fish_id: 101, total_caught: 4, total_prize: 1, largest_size: 90}}

      {opcode, packet} = Packets.Fishing.load_album(album) |> get_short()
      {command, packet} = get_byte(packet)
      {count, packet} = get_int(packet)
      {fish_id, packet} = get_int(packet)
      {caught, packet} = get_int(packet)
      {prize, packet} = get_int(packet)
      {largest, packet} = get_int(packet)

      assert {opcode, command, count, fish_id, caught, prize, largest, packet} ==
               {0xC6, 0x07, 1, 101, 4, 1, 90, <<>>}
    end

    test "the guide object create frame carries the bobber position" do
      guide = %{
        object_id: 7,
        character_id: 42,
        position: %{x: 150, y: 300, z: 450},
        rotation: %{x: 0, y: 0, z: 0}
      }

      {opcode, packet} = Packets.GuideObject.create(guide) |> get_short()
      {command, packet} = get_byte(packet)
      {type, packet} = get_short(packet)
      {object_id, packet} = get_int(packet)
      {character_id, packet} = get_long(packet)
      {position, packet} = get_coord(packet)
      {_rotation, packet} = get_coord(packet)

      assert {opcode, command, type, object_id, character_id} == {0x70, 0x00, 1, 7, 42}
      assert {position.x, position.y, position.z} == {150.0, 300.0, 450.0}
      assert packet == <<>>
    end
  end

  describe "fish album" do
    alias Ms2ex.Managers.Character.Fishing

    test "the first catch of a kind seeds the entry" do
      {character, entry, first?} =
        Fishing.record_catch(%Ms2ex.Schema.Character{}, 101, 40, false)

      assert first?
      assert entry == %{fish_id: 101, total_caught: 1, total_prize: 0, largest_size: 40}
      assert character.mastery_dirty?
    end

    test "later catches keep the largest size and count prize fish" do
      character = %Ms2ex.Schema.Character{}
      {character, _entry, _first?} = Fishing.record_catch(character, 101, 40, false)
      {character, entry, first?} = Fishing.record_catch(character, 101, 90, true)

      refute first?
      assert entry == %{fish_id: 101, total_caught: 2, total_prize: 1, largest_size: 90}
      assert Fishing.album(character) == %{101 => entry}
    end
  end
end
