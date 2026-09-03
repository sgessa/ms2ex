defmodule Ms2exWeb.ClientController do
  @moduledoc """
  Binary endpoints the game client polls outside of the TCP session. Requests
  and responses are raw packets; responses are zlib compressed.
  """

  use Ms2exWeb, :controller

  require Logger

  import Plug.Conn

  alias Ms2exWeb.CacheBodyReader

  def rankings(conn, _params) do
    with {:ok, body} <- CacheBodyReader.read(conn),
         <<type::little-signed-32, _page::little-signed-32, _account_id::little-signed-64,
           _character_id::little-signed-64, _target_id::little-signed-64,
           _ranking_id::little-signed-32, _season_id::little-signed-32, _rest::binary>> <- body do
      # TODO: build the requested ranking board; an empty payload leaves the
      # client's list blank instead of stalling it
      Logger.debug("Unimplemented ranking request type #{type}")
      send_packet(conn, <<>>)
    else
      _ -> send_resp(conn, 400, "Malformed request")
    end
  end

  def info(conn, _params) do
    with {:ok, body} <- CacheBodyReader.read(conn),
         <<_header::little-signed-32, _account_id::little-signed-64,
           _character_id::little-signed-64, type::little-signed-32, _rest::binary>> <- body do
      # TODO: answer the mentor/mentee listing
      Logger.debug("Unimplemented info request type #{type}")
      send_packet(conn, <<>>)
    else
      _ -> send_resp(conn, 400, "Malformed request")
    end
  end

  defp send_packet(conn, payload) do
    conn
    |> put_resp_content_type("application/octet-stream")
    |> send_resp(200, :zlib.compress(payload))
  end
end
