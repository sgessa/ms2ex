defmodule Ms2ex.Managers.Pet do
  @moduledoc """
  Per-character summoned-pet state: the pet item out, the field registration,
  the auto-behaviour config and the collection unlock. One summoned pet per
  character; the manager lives from summon to despawn (switch, map flow keeps
  it alive and re-registers per field), and dies with the session.
  """

  use GenServer

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  import Ms2ex.Net.SenderSession, only: [push: 2]

  defstruct [:character_id, :object_id, :item, :npc, :pet, :config, :collection]

  # TODO persist potion/loot config with the item row (pet-bag stage)
  def summon(%Schema.Character{id: character_id} = character, item_uid) do
    if alive?(character_id) do
      {:error, :already_summoned}
    else
      with %Schema.Item{} = item <- Managers.Inventory.get(character, item_uid),
           true <- item.inventory_tab == :pets,
           %{} = pet <- Storage.Pets.get_meta(item.item_id),
           %{} = npc_metadata <- Storage.Npcs.get_meta(pet.npc_id) do
        npc = Types.Npc.new(%{id: pet.npc_id, metadata: npc_metadata})

        state = %__MODULE__{
          character_id: character_id,
          item: item,
          npc: npc,
          pet: pet,
          config: Types.PetConfig.new(),
          collection: character.pet_collection || %{}
        }

        {:ok, _pid} = GenServer.start(__MODULE__, state, name: process_name(character_id))

        # registration broadcasts to the field, so it runs on the manager
        # once it is up
        GenServer.call(process_name(character_id), {:summon, character})

        :ok
      else
        _ -> {:error, :invalid_pet}
      end
    end
  end

  def un_summon(%Schema.Character{id: character_id} = character) do
    if alive?(character_id) do
      GenServer.call(process_name(character_id), {:un_summon, character})
    else
      :ok
    end
  end

  def switch(%Schema.Character{} = character, item_uid) do
    :ok = un_summon(character)
    summon(character, item_uid)
  end

  def rename(%Schema.Character{id: character_id} = character, name) do
    if alive?(character_id) do
      GenServer.call(process_name(character_id), {:rename, character, name})
    else
      :error
    end
  end

  def update_potion_config(%Schema.Character{id: character_id} = character, potions) do
    if alive?(character_id) do
      GenServer.call(process_name(character_id), {:update_potion_config, character, potions})
    else
      :error
    end
  end

  def update_loot_config(%Schema.Character{id: character_id} = character, loot) do
    if alive?(character_id) do
      GenServer.call(process_name(character_id), {:update_loot_config, character, loot})
    else
      :error
    end
  end

  @doc """
  The character's field is up: re-register the pet on it. Cast so the field
  process never waits on the pet manager (which calls back into the field).
  """
  def field_entered(%Schema.Character{} = character) do
    if alive?(character.id) do
      GenServer.cast(process_name(character.id), {:field_entered, character})
    else
      :ok
    end
  end

  def stop(%Schema.Character{id: character_id} = character) do
    if alive?(character_id) do
      GenServer.call(process_name(character_id), {:un_summon, character})
    else
      :ok
    end
  end

  def alive?(character_id), do: Process.whereis(process_name(character_id)) != nil

  @doc "The item-row uid of the summoned pet, or nil when none is out."
  def summoned_uid(character_id) do
    if alive?(character_id) do
      GenServer.call(process_name(character_id), :summoned_uid)
    end
  end

  defp process_name(character_id), do: :"pets:#{character_id}"

  # -- server ----------------------------------------------------------------

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:field_entered, character}, state) do
    # a summon in flight raced the field enter: whichever registration runs
    # second re-anchors the pet on the current field
    if state.object_id do
      Managers.Field.despawn_pet(character)
    end

    {:noreply, register_on_field(character, state)}
  end

  @impl true
  def handle_call(:summoned_uid, _from, state), do: {:reply, state.item.id, state}

  @impl true
  def handle_call({:summon, character}, _from, %{object_id: nil} = state) do
    state = register_on_field(character, state)

    if state.object_id do
      broadcast_summon(character, state)
      push_load(character, state)
    end

    {:reply, :ok, state}
  end

  def handle_call({:un_summon, character}, _from, state) do
    if state.object_id do
      Managers.Field.broadcast(
        character,
        Packets.ResponsePet.un_summon(character.object_id, state.item.id)
      )

      Managers.Field.despawn_pet(character)
    end

    {:stop, :normal, :ok, state}
  end

  def handle_call({:rename, character, name}, _from, state) do
    pet = Types.ItemPet.get(state.item) |> struct(name: name, rename_remaining: 0)
    item = Types.ItemPet.put(state.item, pet)

    :ok = Managers.Inventory.update_item(item, %{data: item.data})
    state = %{state | item: item}

    push(character, Packets.ResponsePet.rename(character.object_id, item))

    {:reply, :ok, state}
  end

  def handle_call({:update_potion_config, character, potions}, _from, state) do
    config = %{state.config | potion_config: potions}
    push(character, Packets.ResponsePet.potion_config(character.object_id, potions))
    {:reply, :ok, %{state | config: config}}
  end

  def handle_call({:update_loot_config, character, loot}, _from, state) do
    config = %{state.config | loot_config: loot}
    push(character, Packets.ResponsePet.loot_config(character.object_id, config))
    {:reply, :ok, %{state | config: config}}
  end

  # re-anchoring across map changes is async: the field process must never
  # wait on this manager while this manager calls back into it
  defp register_on_field(character, state) do
    {:ok, character} = Managers.Character.call(character.id, :lookup)

    attrs = [
      item: state.item,
      npc: state.npc,
      pet: state.pet,
      position: character.position,
      rotation: character.rotation,
      # TODO badge pet-skin override
      skin_id: state.pet.npc_id
    ]

    case Managers.Field.spawn_pet(character, attrs) do
      {:ok, object_id} ->
        state = %{state | object_id: object_id}
        unlock_collection(character, state)

      :error ->
        state
    end
  end

  defp broadcast_summon(character, state) do
    field_pet = field_pet(character, state)
    Managers.Field.broadcast(character, Packets.ResponsePet.summon(field_pet, character))
  end

  defp push_load(character, state) do
    push(character, Packets.ResponsePet.load(character.object_id, state.item, state.config))
  end

  defp field_pet(%Schema.Character{} = character, %__MODULE__{} = state) do
    Types.FieldPet.new(
      object_id: state.object_id,
      item: state.item,
      npc: state.npc,
      pet: state.pet,
      owner_character_id: character.id,
      owner_object_id: character.object_id,
      position: character.position,
      rotation: character.rotation,
      skin_id: state.pet.npc_id,
      map_id: character.map_id
    )
  end

  # summoning records the pet at its rarity; only a higher rarity updates it.
  # the collection map is threaded through the manager state so a stale
  # character copy can't re-push the unlock on every map change
  defp unlock_collection(character, state) do
    pet_id = state.item.item_id
    collection = state.collection || character.pet_collection || %{}

    if Map.get(collection, pet_id, 0) < state.item.rarity do
      collection = Map.put(collection, pet_id, state.item.rarity)
      Context.Characters.persist(character, %{pet_collection: collection})
      push(character, Packets.ResponsePet.add_collection(pet_id, state.item.rarity))
      %{state | collection: collection}
    else
      state
    end
  end
end
