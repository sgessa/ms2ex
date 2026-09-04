defmodule Ms2ex.Types.FieldInstrument do
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @type t :: %__MODULE__{}

  defstruct [
    :object_id,
    :owner_id,
    :owner_character_id,
    :position,
    :metadata,
    :score,
    improvising?: false,
    ensemble?: false,
    start_tick: 0
  ]

  @doc """
  Resolves the instrument an item opens. Instrument items carry their
  instrument table id in the `OpenInstrument` item function parameter.
  """
  @spec from_item(Schema.Character.t(), Schema.Item.t(), keyword()) :: {:ok, t()} | :error
  def from_item(%Schema.Character{} = character, %Schema.Item{} = item, opts \\ []) do
    with %{function_name: "OpenInstrument", function_param: instrument_id}
         when is_integer(instrument_id) <- item.metadata,
         {:ok, metadata} <- Storage.Tables.Instruments.lookup(instrument_id) do
      {:ok,
       %__MODULE__{
         owner_id: character.object_id,
         owner_character_id: character.id,
         position: character.position,
         metadata: metadata,
         improvising?: Keyword.get(opts, :improvising?, false),
         ensemble?: Keyword.get(opts, :ensemble?, false),
         start_tick: Keyword.get(opts, :start_tick, Ms2ex.sync_ticks())
       }}
    else
      _ -> :error
    end
  end
end
