defmodule Ms2ex.Storage do
  @moduledoc """
  Lazy, Redis-backed metadata cache.

  Metadata documents (written by the `ms2ex-file-ingest` tool as ETF blobs)
  are fetched from Redis on first access, decoded with
  `:erlang.binary_to_term/1`, and cached in the `:metadata` ETS table.
  Subsequent lookups of the same key are pure memory reads.

  Ingested data is immutable while the server runs: there is no invalidation.
  Keys missing from Redis are negatively cached (`:missing` tombstones) so
  repeated lookups of nonexistent ids never hit Redis again.
  """

  @table :metadata

  @type set :: atom()
  @type id :: String.t() | integer()

  @spec get(set(), id()) :: map() | nil
  def get(set, id) do
    key = "#{set}:#{id}"

    case :ets.lookup(@table, key) do
      [{^key, {:ok, value}}] -> value
      [{^key, :missing}] -> nil
      [] -> load(key)
    end
  end

  @doc """
  Fetches a single document from Redis and caches it. Missing keys are
  stored as tombstones so later lookups skip Redis entirely.
  """
  @spec load(String.t()) :: map() | nil
  def load(key) do
    case Redix.command(Ms2ex.Redix, ["GET", key]) do
      {:ok, nil} ->
        :ets.insert(@table, {key, :missing})
        nil

      {:ok, blob} when is_binary(blob) ->
        value = :erlang.binary_to_term(blob)
        :ets.insert(@table, {key, {:ok, value}})
        value

      _ ->
        nil
    end
  end

  @doc "Reads a raw blob straight from Redis without touching the cache."
  @spec get_from_redis(String.t()) :: {:ok, binary() | nil} | {:error, term()}
  def get_from_redis(key) do
    Redix.command(Ms2ex.Redix, ["GET", key])
  end
end
