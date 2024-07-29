defmodule Ms2ex.Enum do
  defmacro __using__(_opts) do
    quote do
      def mapping, do: @mapping

      def get_value(key) do
        Map.get(@mapping, key)
      end

      def values(module) do
        Map.values(@mapping)
      end

      def keys(module) do
        Map.keys(@mapping)
      end
    end
  end
end
