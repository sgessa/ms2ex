defmodule Ms2ex.Types.ItemPet do
  @moduledoc """
  Per-item pet state: the identity and progression a pet item instance
  carries (`item.data.pet`). Items created before pet support (or freshly
  looted) read through `get/1` into these defaults.
  """

  @type t :: %__MODULE__{}

  defstruct name: "",
            exp: 0,
            evolve_points: 0,
            level: 1,
            rename_remaining: 1,
            has_items: false

  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc "Reads the pet state off an item's data map, falling back to defaults."
  @spec get(item :: map()) :: t()
  def get(%{data: %{pet: pet}}) when is_map(pet) do
    struct(__MODULE__, pet)
  end

  def get(_item) do
    new()
  end

  @doc "Writes the pet state back into an item's data map."
  @spec put(item :: map(), t()) :: map()
  def put(item, %__MODULE__{} = pet) do
    data = Map.get(item, :data) || %{}
    %{item | data: Map.put(data, :pet, Map.from_struct(pet))}
  end
end
