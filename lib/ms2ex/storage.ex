defmodule Ms2ex.Storage do
  @ets_table :metadata

  def get(set, id) do
    key = "#{set}:#{id}"

    case get_from_ets(key) do
      nil -> cache_value(key)
      value -> value
    end
  end

  def get_from_ets(key) do
    case :ets.lookup(@ets_table, key) do
      [{^key, {value, _}}] ->
        value

      [] ->
        nil
    end
  end

  def cache_value(key) do
    case get_from_redis(key) do
      {:ok, value} ->
        value
        |> :erlang.binary_to_term()
        |> then(&put(key, &1))

      _ ->
        nil
    end
  end

  def get_from_redis(key) do
    Redix.command(Ms2ex.Redix, ["GET", key])
  end

  def put(key, value) do
    :ets.insert(@ets_table, {key, {value, :erlang.system_time(:millisecond)}})
    value
  end
end
