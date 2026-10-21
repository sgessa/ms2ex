defmodule Ms2ex.GameHandlers.RequestPet do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Packets.PacketReader

  @command_summon 0x0
  @command_un_summon 0x1
  @command_switch 0x3
  @command_rename 0x4
  @command_update_potion_config 0x5
  @command_update_loot_config 0x6
  # TODO fusion (pet enchant compose) is unimplemented
  @command_fusion 0xC
  # TODO pet attack state toggle is unimplemented
  @command_attack 0xF
  # TODO evolve and evolve-points are unimplemented
  @command_evolve 0x11
  @command_evolve_points 0x12

  @commands %{
    summon: @command_summon,
    un_summon: @command_un_summon,
    switch: @command_switch,
    rename: @command_rename,
    update_potion_config: @command_update_potion_config,
    update_loot_config: @command_update_loot_config,
    fusion: @command_fusion,
    attack: @command_attack,
    evolve: @command_evolve,
    evolve_points: @command_evolve_points
  }

  @impl true
  def commands, do: @commands

  @specs %{
    @command_summon => [item_uid: :long],
    @command_un_summon => [item_uid: :long],
    @command_switch => [item_uid: :long],
    @command_rename => [name: :ustring],
    @command_update_potion_config => [count: :byte, _potions: {:bytes, 0}],
    @command_update_loot_config => [
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
    @command_fusion => [_item_uid: :long, count: :short, _fodder: {:bytes, 0}],
    @command_attack => [_enabled: :bool],
    @command_evolve => [_item_uid: :long],
    @command_evolve_points => [_item_uid: :long, count: :short, _fodder: {:bytes, 0}]
  }

  @impl true
  def spec(command), do: Map.get(@specs, command, [])

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      handle_command(command, packet, character)
    end

    session
  end

  defp handle_command(@command_summon, packet, character) do
    {item_uid, _packet} = get_long(packet)
    Managers.Pet.summon(character, item_uid)
  end

  defp handle_command(@command_un_summon, packet, character) do
    {item_uid, _packet} = get_long(packet)

    if Managers.Pet.summoned_uid(character.id) == item_uid do
      Managers.Pet.un_summon(character)
    end
  end

  defp handle_command(@command_switch, packet, character) do
    {item_uid, _packet} = get_long(packet)
    Managers.Pet.switch(character, item_uid)
  end

  defp handle_command(@command_rename, packet, character) do
    {name, _packet} = get_ustring(packet)
    Managers.Pet.rename(character, name)
  end

  defp handle_command(@command_update_potion_config, packet, character) do
    {count, packet} = get_byte(packet)
    {potions, _packet} = read_potions(packet, count, [])
    Managers.Pet.update_potion_config(character, potions)
  end

  defp handle_command(@command_update_loot_config, packet, character) do
    {loot, _packet} = read_loot(packet)
    Managers.Pet.update_loot_config(character, loot)
  end

  # TODO fusion, evolve, evolve-points: the client sends them but the
  # server only consumes the payload
  defp handle_command(@command_fusion, packet, _character) do
    {_uid, packet} = get_long(packet)
    {count, packet} = get_short(packet)
    consume_fodder(packet, count)
  end

  defp handle_command(@command_attack, packet, _character) do
    {_enabled, _packet} = get_bool(packet)
  end

  defp handle_command(@command_evolve, packet, _character) do
    {_uid, _packet} = get_long(packet)
  end

  defp handle_command(@command_evolve_points, packet, _character) do
    {_uid, packet} = get_long(packet)
    {count, packet} = get_short(packet)
    consume_fodder(packet, count)
  end

  defp handle_command(_command, _packet, _character), do: :ok

  defp consume_fodder(packet, count) do
    Enum.reduce(1..count//1, packet, fn _, acc ->
      {_, acc} = get_long(acc)
      acc
    end)
  end

  defp read_potions(packet, count, acc) when length(acc) == count do
    {Enum.reverse(acc), packet}
  end

  defp read_potions(packet, count, acc) do
    {index, packet} = get_int(packet)
    {threshold, packet} = get_float(packet)
    {item_id, packet} = get_int(packet)

    read_potions(packet, count, [%{index: index, threshold: threshold, item_id: item_id} | acc])
  end

  defp read_loot(packet) do
    {mesos?, packet} = get_bool(packet)
    {merets?, packet} = get_bool(packet)
    {other?, packet} = get_bool(packet)
    {currency?, packet} = get_bool(packet)
    {equipment?, packet} = get_bool(packet)
    {consumable?, packet} = get_bool(packet)
    {gemstone?, packet} = get_bool(packet)
    {dropped?, packet} = get_bool(packet)
    {rarity, packet} = get_int(packet)
    {enabled?, packet} = get_bool(packet)

    loot = %{
      mesos?: mesos?,
      merets?: merets?,
      other?: other?,
      currency?: currency?,
      equipment?: equipment?,
      consumable?: consumable?,
      gemstone?: gemstone?,
      dropped?: dropped?,
      rarity: rarity,
      enabled?: enabled?
    }

    {loot, packet}
  end
end
