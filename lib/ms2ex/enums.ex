defmodule Ms2ex.Enums do
  defmacro __using__(_opts) do
    quote do
      def mapping, do: @mapping

      def get_value(key) do
        Map.get(@mapping, key)
      end

      def get_key(value) do
        @mapping
        |> Map.new(fn {key, val} -> {val, key} end)
        |> Map.get(value)
      end

      def values do
        Map.values(@mapping)
      end

      def keys do
        Map.keys(@mapping)
      end
    end
  end
end
