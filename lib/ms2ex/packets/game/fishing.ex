defmodule Ms2ex.Packets.Fishing do
  @moduledoc """
  Fishing frames: the water tiles a rod can reach, the bite timer, catches
  and the fish album.
  """

  import Ms2ex.Packets.PacketWriter

  alias Ms2ex.Enums

  @modes %{
    prepare: 0x0,
    stop: 0x1,
    error: 0x2,
    increase_mastery: 0x3,
    load_tiles: 0x4,
    catch_item: 0x5,
    prize_fish: 0x6,
    load_album: 0x7,
    catch_fish: 0x8,
    start: 0x9,
    auto: 0xA
  }

  # the client only runs the fight minigame when the tile advertises this id
  @tile_fish_id 10_000_001
  @tile_bore_time 15_000

  def prepare(rod_uid) do
    __MODULE__
    |> build()
    |> put_byte(@modes.prepare)
    |> put_long(rod_uid)
  end

  def stop do
    __MODULE__
    |> build()
    |> put_byte(@modes.stop)
  end

  def error(error) do
    __MODULE__
    |> build()
    |> put_byte(@modes.error)
    |> put_short(Enums.FishingError.get_value(error))
  end

  def increase_mastery(fish_id, grade, exp, caught_type) do
    __MODULE__
    |> build()
    |> put_byte(@modes.increase_mastery)
    |> put_int(fish_id)
    |> put_int(exp)
    |> put_short(Enums.CaughtFishType.get_value(caught_type))
    |> put_short(grade)
  end

  def load_tiles(tiles, reduce_time) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load_tiles)
    |> put_byte()
    |> put_int(length(tiles))
    |> reduce(tiles, fn tile, packet ->
      packet
      |> put_sbyte_coord(tile.position)
      |> put_byte()
      |> put_int(@tile_fish_id)
      |> put_int(25)
      |> put_int(@tile_bore_time - reduce_time)
      |> put_short(1)
    end)
  end

  def catch_item(items) do
    __MODULE__
    |> build()
    |> put_byte(@modes.catch_item)
    |> put_int(length(items))
    |> reduce(items, fn item, packet ->
      packet
      |> put_int(item.item_id)
      |> put_int(item.amount)
    end)
  end

  def prize_fish(character_name, fish_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.prize_fish)
    |> put_ustring(character_name)
    |> put_int(fish_id)
    |> put_int()
  end

  def load_album(album \\ %{}) do
    entries = Map.values(album)

    __MODULE__
    |> build()
    |> put_byte(@modes.load_album)
    |> put_int(length(entries))
    |> reduce(entries, fn entry, packet -> put_entry(packet, entry) end)
  end

  def catch_fish(fish_id, size, auto_fish?, entry \\ nil) do
    __MODULE__
    |> build()
    |> put_byte(@modes.catch_fish)
    |> put_int(fish_id)
    |> put_int(size)
    |> put_bool(entry != nil)
    |> put_bool(auto_fish?)
    |> then(&if(entry, do: put_entry(&1, entry), else: &1))
  end

  def start(end_tick, mini_game?) do
    __MODULE__
    |> build()
    |> put_byte(@modes.start)
    |> put_bool(mini_game?)
    |> put_int(end_tick)
  end

  def auto(auto_fish?) do
    __MODULE__
    |> build()
    |> put_byte(@modes.auto)
    |> put_bool(auto_fish?)
  end

  defp put_entry(packet, entry) do
    packet
    |> put_int(entry.fish_id)
    |> put_int(entry.total_caught)
    |> put_int(entry.total_prize)
    |> put_int(entry.largest_size)
  end
end
