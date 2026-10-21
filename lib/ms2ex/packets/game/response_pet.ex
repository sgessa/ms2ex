defmodule Ms2ex.Packets.ResponsePet do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Packets.PacketWriter

  @commands %{
    summon: 0x0,
    un_summon: 0x1,
    rename: 0x4,
    potion_config: 0x5,
    loot_config: 0x6,
    load_collection: 0x7,
    add_collection: 0x8,
    load: 0x9
  }

  @specs %{
    0x0 => [
      owner_object_id: :int,
      pet_object_id: :int,
      _present: :bool,
      item_id: :int,
      item_uid: :long,
      rarity: :int,
      _item: {:bytes, 0}
    ],
    0x1 => [owner_object_id: :int, item_uid: :long],
    0x4 => [
      owner_object_id: :int,
      name: :ustring,
      exp: :long,
      _unused: :int,
      level: :int,
      rename_remaining: :short
    ],
    0x5 => [owner_object_id: :int, count: :byte, _potions: {:bytes, 0}],
    0x6 => [
      owner_object_id: :int,
      mesos?: :bool,
      merets?: :bool,
      other?: :bool,
      currency?: :bool,
      equipment?: :bool,
      consumable?: :bool,
      gemstone?: :bool,
      dropped?: :bool,
      rarity: :int,
      enabled?: :bool
    ],
    0x7 => [count: :int, _entries: {:bytes, 0}],
    0x8 => [pet_id: :int, rarity: :short],
    0x9 => [
      owner_object_id: :int,
      name: :ustring,
      exp: :long,
      _unused: :int,
      level: :int,
      rename_remaining: :short,
      potion_count: :byte,
      _potions: {:bytes, 0},
      _loot: {:bytes, 13}
    ]
  }

  @impl true
  def commands, do: @commands

  @impl true
  def spec(command), do: Map.get(@specs, command, [])

  def summon(field_pet, character) do
    __MODULE__
    |> build()
    |> put_byte(@commands.summon)
    |> put_int(field_pet.owner_object_id)
    |> put_int(field_pet.object_id)
    |> put_bool(true)
    |> put_int(field_pet.item.item_id)
    |> put_long(field_pet.item.id)
    |> put_int(field_pet.item.rarity)
    |> Packets.InventoryItem.put_item(field_pet.item, character)
  end

  def un_summon(owner_object_id, item_uid) do
    __MODULE__
    |> build()
    |> put_byte(@commands.un_summon)
    |> put_int(owner_object_id)
    |> put_long(item_uid)
  end

  def rename(owner_object_id, item) do
    __MODULE__
    |> build()
    |> put_byte(@commands.rename)
    |> put_int(owner_object_id)
    |> put_profile(item)
  end

  def potion_config(owner_object_id, potions) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@commands.potion_config)
      |> put_int(owner_object_id)
      |> put_byte(length(potions))

    Enum.reduce(potions, packet, fn potion, packet ->
      packet
      |> put_int(potion.index)
      |> put_float(potion.threshold)
      |> put_int(potion.item_id)
    end)
  end

  def loot_config(owner_object_id, %Types.PetConfig{} = config) do
    loot = config.loot_config

    __MODULE__
    |> build()
    |> put_byte(@commands.loot_config)
    |> put_int(owner_object_id)
    |> put_bool(loot.mesos?)
    |> put_bool(loot.merets?)
    |> put_bool(loot.other?)
    |> put_bool(loot.currency?)
    |> put_bool(loot.equipment?)
    |> put_bool(loot.consumable?)
    |> put_bool(loot.gemstone?)
    |> put_bool(loot.dropped?)
    |> put_int(loot.rarity)
    |> put_bool(loot.enabled?)
  end

  def load_collection(collection) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@commands.load_collection)
      |> put_int(map_size(collection))

    Enum.reduce(collection, packet, fn {pet_id, rarity}, packet ->
      packet
      |> put_int(pet_id)
      |> put_short(rarity)
    end)
  end

  def add_collection(pet_id, rarity) do
    __MODULE__
    |> build()
    |> put_byte(@commands.add_collection)
    |> put_int(pet_id)
    |> put_short(rarity)
  end

  def load(owner_object_id, item, %Types.PetConfig{} = config) do
    packet =
      __MODULE__
      |> build()
      |> put_byte(@commands.load)
      |> put_int(owner_object_id)
      |> put_profile(item)
      |> put_byte(length(config.potion_config))

    packet =
      Enum.reduce(config.potion_config, packet, fn potion, packet ->
        packet
        |> put_int(potion.index)
        |> put_float(potion.threshold)
        |> put_int(potion.item_id)
      end)

    put_loot_config(packet, config.loot_config)
  end

  defp put_profile(packet, item) do
    pet = Types.ItemPet.get(item)

    packet
    |> put_ustring(pet.name)
    |> put_long(pet.exp)
    |> put_int()
    |> put_int(pet.level)
    |> put_short(pet.rename_remaining)
  end

  defp put_loot_config(packet, loot) do
    packet
    |> put_bool(loot.mesos?)
    |> put_bool(loot.merets?)
    |> put_bool(loot.other?)
    |> put_bool(loot.currency?)
    |> put_bool(loot.equipment?)
    |> put_bool(loot.consumable?)
    |> put_bool(loot.gemstone?)
    |> put_bool(loot.dropped?)
    |> put_int(loot.rarity)
    |> put_bool(loot.enabled?)
  end
end
