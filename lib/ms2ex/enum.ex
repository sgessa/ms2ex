defmodule Ms2ex.Enum do
  defmacro __using__(values) do
    quote do
      use Ecto.Type
      def type, do: :integer

      def cast(string) when is_binary(string) do
        atom =
          try do
            string |> String.to_existing_atom()
          rescue
            _ -> :invalid_enum
          end

        cast(atom)
      end

      def cast(key) when is_atom(key) do
        case Map.has_key?(unquote(values), key) do
          true ->
            {:ok, key}

          _ ->
            :error
        end
      end

      def cast(int) when is_integer(int), do: cast(get_key(int))
      def cast(_), do: :error

      def load(data) when is_integer(data) do
        {:ok, get_key(data)}
      end

      def dump(value) when is_atom(value) do
        {:ok, Map.get(unquote(values), value)}
      end

      def dump(_), do: :error

      def all_map, do: unquote(values)

      def values, do: unquote(values) |> Enum.map(&elem(&1, 1))

      def all, do: unquote(values) |> Map.keys()

      def get_value(key) do
        Map.get(unquote(values), key)
      end

      def get_key(value) do
        item =
          unquote(values)
          |> Enum.filter(fn {_, v} -> v == value end)
          |> hd()

        case item do
          {k, _} -> k
          _ -> :invalid_enum
        end
      end
    end
  end
end
