defmodule Ms2ex.Managers.Managed do
  defmacro __using__(opts) do
    prefix = Keyword.fetch!(opts, :prefix)
    key = Keyword.fetch!(opts, :key)

    quote do
      defp process_name(id), do: :"#{unquote(prefix)}:#{id}"

      def call(%{unquote(key) => id}, msg), do: call(id, msg)

      def call(id, msg) when is_integer(id) do
        case Process.whereis(process_name(id)) do
          nil -> :error
          pid -> GenServer.call(pid, msg)
        end
      end

      def cast(%{unquote(key) => id}, msg), do: cast(id, msg)
      def cast(id, msg) when is_integer(id), do: GenServer.cast(process_name(id), msg)
    end
  end
end
