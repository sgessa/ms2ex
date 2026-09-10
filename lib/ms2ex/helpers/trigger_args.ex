defmodule Ms2ex.Helpers.TriggerArgs do
  @moduledoc """
  Coercion for trigger-script action and condition arguments. Script
  documents arrive with canonical snake_case keys whose values may be
  strings or numbers; these helpers normalize them to the types the
  runtime works with.
  """

  @doc "Integer argument; strings are parsed, anything else falls back to 0."
  def int_arg(args, key) when is_atom(key) do
    case Map.get(args, key) do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, _rest} -> int
          :error -> 0
        end

      value when is_integer(value) ->
        value

      _ ->
        0
    end
  end

  @doc "Float argument; strings are parsed, integers are widened."
  def float_arg(args, key) when is_atom(key) do
    case Map.get(args, key) do
      value when is_binary(value) ->
        case Float.parse(value) do
          {float, _rest} -> float
          :error -> 0.0
        end

      value when is_number(value) ->
        value * 1.0

      _ ->
        0.0
    end
  end

  def bool_arg(args, key), do: int_arg(args, key) == 1

  @doc """
  Integer-list argument: single ids, comma lists and inclusive ranges
  ("5001-5025" expands to every id).
  """
  def int_list_arg(args, key) do
    case Map.get(args, key) do
      value when is_binary(value) -> parse_int_list(value)
      _ -> []
    end
  end

  @doc """
  Comma-separated string list kept verbatim (box ids may carry a leading "!"
  negation, so they cannot go through the int list parser).
  """
  def string_list_arg(args, key) do
    case Map.get(args, key) do
      value when is_binary(value) ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        []
    end
  end

  @doc ~S{"r, g, b" color component floats, rounded to bytes.}
  def rgb_arg(value) when is_binary(value) do
    case value |> String.split(",") |> Enum.map(&String.trim/1) do
      [r, g, b] ->
        {round(parse_number(r)), round(parse_number(g)), round(parse_number(b))}

      _ ->
        nil
    end
  end

  def rgb_arg(_), do: nil

  @doc """
  Normalizes a script's widget type to the atom key the runtime stores
  widgets under; unknown types stay strings.
  """
  def widget_key(name) do
    String.to_existing_atom(Macro.underscore(to_string(name)))
  rescue
    _ -> to_string(name)
  end

  defp parse_number(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end

  defp parse_int_list(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(&parse_int_span/1)
  end

  defp parse_int_span(part) do
    case Integer.parse(part) do
      {first, "-" <> rest} ->
        case Integer.parse(rest) do
          {last, _rest} -> Enum.to_list(first..last//1)
          :error -> [first]
        end

      {int, _rest} ->
        [int]

      :error ->
        []
    end
  end
end
