defmodule Ms2ex.Storage.Animations do
  alias Ms2ex.Storage

  # resolves an animation sequence name to its numeric sequence id for a
  # model (docs come from the ingest's anikey projection)
  @spec sequence_id(String.t() | nil, String.t() | nil) :: integer() | nil
  def sequence_id(model, name) when is_binary(model) and is_binary(name) do
    # anikey keys are lowercase; npc metadata model names keep their case
    case Storage.get("animation", String.downcase(model)) do
      %{sequences: sequences} ->
        try do
          Map.get(sequences, String.to_existing_atom(name))
        rescue
          ArgumentError -> nil
        end

      _ ->
        nil
    end
  end

  def sequence_id(_, _), do: nil
end
