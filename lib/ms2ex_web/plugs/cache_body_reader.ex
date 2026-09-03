defmodule Ms2exWeb.CacheBodyReader do
  @moduledoc """
  Keeps the raw request body around. The game client posts binary payloads that
  the parsers would otherwise consume before a controller can read them.
  """

  @max_body_size 5 * 1024 * 1024

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
  end

  @doc "Returns the binary body of a request, cached or not yet read."
  @spec read(Plug.Conn.t()) :: {:ok, binary()} | {:error, :empty | :too_large | :malformed}
  def read(%{assigns: %{raw_body: body}}) when byte_size(body) > 0, do: {:ok, body}
  def read(%{assigns: %{raw_body: _}}), do: {:error, :empty}

  def read(conn) do
    case Plug.Conn.read_body(conn, length: @max_body_size) do
      {:ok, "", _conn} -> {:error, :empty}
      {:ok, body, _conn} -> {:ok, body}
      {:more, _partial, _conn} -> {:error, :too_large}
      {:error, _reason} -> {:error, :malformed}
    end
  end
end
