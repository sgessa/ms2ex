defmodule Ms2ex.GameHandlers.InteractObject do
  @moduledoc """
  Player interactions with field objects (weeds, telescopes, gathering
  nodes, ...). The client opens the interaction with Start and completes it
  with End; End is what counts towards interact-object quest conditions.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Net.SenderSession
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  import Ms2ex.Packets.PacketReader

  @start 0x0B
  @end_command 0x0C

  # InteractResult.none / s_interact_find_new_telescope share the value 0
  @result_none 0x00

  def handle(packet, session) do
    {command, packet} = get_byte(packet)
    {uuid, _packet} = get_string(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      case command do
        @start -> :ok
        @end_command -> complete_interaction(character, uuid)
        _ -> :ok
      end
    end

    :ok
  end

  defp complete_interaction(character, uuid) do
    case Context.Field.interact_object(character, uuid) do
      {:ok, object} ->
        Managers.Quest.update_conditions(character.id, :interact_object, 1, "", 0, "", object.id)

        Managers.Quest.update_conditions(
          character.id,
          :interact_object_rep,
          1,
          "",
          0,
          "",
          object.id
        )

        react(character, object)
        drop_loot(character, object)
        invoke_effects(character, object)

      :error ->
        :ok
    end
  end

  # gathering nodes resolve the harvest before the animation: the client
  # needs to know whether it succeeded
  defp react(character, %{type: :gathering} = object) do
    case Context.Mastery.gather(character, object) do
      {:ok, _character} ->
        SenderSession.push(character, Packets.InteractObject.interact(object, :success, 1))

      {:error, :failed, _character} ->
        SenderSession.push(character, Packets.InteractObject.interact(object, :fail, 0))

      {:error, error, _character} ->
        SenderSession.push(character, Packets.InteractObject.interact(object, :fail, 0))
        SenderSession.push(character, Packets.Mastery.error(error))
    end

    SenderSession.push(character, Packets.InteractObject.result(object, @result_none))
  end

  # a telescope grants exploration exp the first time it is used
  defp react(character, %{type: :telescope} = object) do
    SenderSession.push(character, Packets.InteractObject.result(object, @result_none))

    if Context.Characters.discover_object(character, object.id) do
      exp = Storage.Tables.ExpTable.typed_exp(:telescope, character.level)
      Managers.Character.cast(character, {:earn_exp, exp})
    end
  end

  defp react(_character, _object), do: :ok

  # the object's drop boxes land at its feet, bound to the interacting player
  defp drop_loot(character, %{drop: %{} = drop} = object) do
    height = round(Map.get(drop, :drop_height, 0.0))
    position = %Coord{x: object.position.x, y: object.position.y, z: object.position.z + height}

    (global_items(character, drop) ++ individual_items(character, drop))
    |> Enum.each(&Context.Field.drop_item(character, &1, position))
  end

  defp drop_loot(_character, _object), do: :ok

  defp global_items(character, drop) do
    drop
    |> Map.get(:global_drop_box_ids, [])
    |> Enum.flat_map(&Context.Drops.global_items(&1, character.level, character.map_id))
  end

  # the reference keeps a single random item per individual box
  defp individual_items(character, drop) do
    drop
    |> Map.get(:individual_drop_box_ids, [])
    |> Enum.flat_map(fn box_id ->
      case Context.Drops.individual_items(box_id, character, character.map_id) do
        [] -> []
        items -> [Enum.random(items)]
      end
    end)
    |> Enum.filter(&match?(%Schema.Item{}, &1))
  end

  defp invoke_effects(character, %{additional_effect: %{} = effect}) do
    effect
    |> Map.get(:invoke, [])
    |> Enum.filter(&rolled?/1)
    |> Enum.each(fn invoke ->
      Context.Field.call(character, {:add_effect_buff, invoke.id, invoke.level, character})
    end)

    modify_duration(character, effect)
  end

  defp invoke_effects(_character, _object), do: :ok

  defp modify_duration(character, %{modify_code: code, modify_time: time}) when code > 0 do
    Context.Field.call(
      character,
      {:modify_buff_duration, character.object_id, code, time}
    )
  end

  defp modify_duration(_character, _effect), do: :ok

  defp rolled?(%{probability: probability}) when probability >= 10_000, do: true
  defp rolled?(%{probability: probability}), do: div(probability, 100) >= :rand.uniform(100) - 1
  defp rolled?(_invoke), do: true
end
