defmodule Ms2ex.Managers.Character.Pet do
  @moduledoc """
  The character's summoned pet: which item is out, its auto-behaviour
  config and its collection bookkeeping. The state rides the character
  struct as volatile runtime state (like `field_pid`) — the field process
  owns the spawned actor, this module owns the decision to have one.

  Functions are state-in/state-out on the character struct; the field is
  never called from here (the field calls in, handlers orchestrate).
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @type t :: %{
          item: Schema.Item.t(),
          pet: map(),
          config: Types.PetConfig.t()
        }

  @doc "The summoned pet state, or nil when no pet is out."
  @spec summoned(Schema.Character.t()) :: t() | nil
  def summoned(%{pet: pet}) when is_map(pet), do: pet
  def summoned(_character), do: nil

  @spec summon(Schema.Character.t(), item_uid :: integer()) ::
          {:ok, Schema.Character.t()} | {:error, :already_summoned | :invalid_pet}
  def summon(character, item_uid) do
    if summoned(character) do
      {:error, :already_summoned}
    else
      with %Schema.Item{} = item <- Managers.Inventory.get(character, item_uid),
           true <- item.inventory_tab == :pets,
           %{} = metadata <- Storage.Pets.get_meta(item.item_id) do
        {:ok,
         %{
           character
           | pet: %{item: item, pet: metadata, config: Types.PetConfig.new()}
         }}
      else
        _ -> {:error, :invalid_pet}
      end
    end
  end

  @spec un_summon(Schema.Character.t()) :: Schema.Character.t()
  def un_summon(character), do: %{character | pet: nil}

  @doc "Renames the pet item and persists the item row; returns the updated item."
  @spec rename(Schema.Character.t(), String.t()) ::
          {:ok, Schema.Character.t(), Schema.Item.t()} | :error
  def rename(character, name) do
    case summoned(character) do
      nil ->
        :error

      %{item: item} = pet ->
        new_pet = Types.ItemPet.get(item) |> struct(name: name, rename_remaining: 0)
        item = Types.ItemPet.put(item, new_pet)
        :ok = Managers.Inventory.update_item(item, %{data: item.data})
        {:ok, %{character | pet: %{pet | item: item}}, item}
    end
  end

  @spec update_potion_config(Schema.Character.t(), list()) :: Schema.Character.t()
  def update_potion_config(character, potions) do
    update_config(character, fn config -> %{config | potion_config: potions} end)
  end

  @spec update_loot_config(Schema.Character.t(), map()) :: Schema.Character.t()
  def update_loot_config(character, loot) do
    update_config(character, fn config -> %{config | loot_config: loot} end)
  end

  defp update_config(character, update) do
    case summoned(character) do
      nil -> character
      pet -> %{character | pet: %{pet | config: update.(pet.config)}}
    end
  end

  @doc "Flags the pet item's bag as holding (or not holding) items; persists."
  @spec set_has_items(Schema.Character.t(), boolean()) ::
          {:ok, Schema.Character.t(), Schema.Item.t()} | :error
  def set_has_items(character, has_items?) do
    case summoned(character) do
      nil ->
        :error

      %{item: item} = pet ->
        new_pet = Types.ItemPet.get(item) |> struct(has_items: has_items?)
        item = Types.ItemPet.put(item, new_pet)
        :ok = Managers.Inventory.update_item(item, %{data: item.data})
        {:ok, %{character | pet: %{pet | item: item}}, item}
    end
  end

  @doc """
  Records the pet at its rarity; only a rarity increase updates the entry.
  Persists the character row and refreshes the in-memory copy so later
  reads can't re-push the unlock.
  """
  @spec unlock_collection(Schema.Character.t(), pet_id :: integer(), rarity :: integer()) ::
          {:updated, Schema.Character.t()} | :keep
  def unlock_collection(character, pet_id, rarity) do
    collection = character.pet_collection || %{}

    if Map.get(collection, pet_id, 0) < rarity do
      collection = Map.put(collection, pet_id, rarity)
      Context.Characters.persist(character, %{pet_collection: collection})
      {:updated, Map.put(character, :pet_collection, collection)}
    else
      :keep
    end
  end
end
