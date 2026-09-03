defmodule Ms2exWeb.Helpers.Ugc do
  @moduledoc """
  Shared plumbing for the user generated content endpoints: reading the binary
  upload envelope, storing files inside the data directory and serving them back.

  Every path segment that originates from a request is validated before it
  touches the filesystem, so a crafted id or file name cannot escape the data
  directory.
  """

  import Plug.Conn

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2exWeb.CacheBodyReader

  @max_upload_size 5 * 1024 * 1024
  @segment ~r/^[A-Za-z0-9_-]{1,64}$/

  @type upload :: %{
          type: atom(),
          character_id: integer(),
          resource_id: integer(),
          id: integer(),
          file: binary()
        }

  @doc """
  Reads the upload envelope: a header identifying the uploader and the resource
  being written, followed by the raw file bytes.
  """
  @spec read_upload(Plug.Conn.t()) :: {:ok, upload()} | {:error, atom()}
  def read_upload(conn) do
    with {:ok, body} <- CacheBodyReader.read(conn) do
      parse_upload(body)
    end
  end

  defp parse_upload(<<
         _unknown::little-signed-32,
         type::little-signed-32,
         _account_id::little-signed-64,
         character_id::little-signed-64,
         resource_id::little-signed-64,
         id::little-signed-32,
         _unknown2::little-signed-32,
         _unknown3::little-signed-64,
         file::binary
       >>) do
    cond do
      file == "" ->
        {:error, :empty}

      byte_size(file) > @max_upload_size ->
        {:error, :too_large}

      true ->
        {:ok,
         %{
           type: ugc_type(type),
           character_id: character_id,
           resource_id: resource_id,
           id: id,
           file: file
         }}
    end
  end

  defp parse_upload(_body), do: {:error, :malformed}

  defp ugc_type(value) do
    Enum.find_value(Enums.UgcType.all_map(), :none, fn {key, val} -> val == value && key end)
  end

  @doc """
  Loads the resource an upload targets, refusing to write to content owned by a
  different character.
  """
  @spec owned_resource(upload()) :: {:ok, Ms2ex.Schema.UgcResource.t()} | {:error, atom()}
  def owned_resource(%{resource_id: 0}), do: {:error, :not_found}

  def owned_resource(%{resource_id: resource_id, character_id: character_id, type: type}) do
    case Context.Ugc.get(resource_id) do
      nil ->
        {:error, :not_found}

      %{character_id: ^character_id, type: ^type} = resource ->
        {:ok, resource}

      _resource ->
        Logger.warning("Character #{character_id} may not write UGC resource #{resource_id}")
        {:error, :forbidden}
    end
  end

  @doc "Writes an uploaded file under the data directory."
  @spec store([String.t()], binary()) :: :ok | {:error, atom()}
  def store(segments, file) when byte_size(file) <= @max_upload_size do
    with {:ok, path} <- resolve(segments),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, file) do
      :ok
    else
      {:error, :invalid_path} = error ->
        error

      {:error, reason} ->
        Logger.error("Failed to store UGC file: #{inspect(reason)}")
        {:error, :failed}
    end
  end

  def store(_segments, _file), do: {:error, :too_large}

  @doc "Removes every file previously stored under `segments`."
  @spec clear([String.t()]) :: :ok
  def clear(segments) do
    case resolve(segments) do
      {:ok, path} ->
        File.rm_rf(path)
        :ok

      _ ->
        :ok
    end
  end

  @doc "Records the path the client should fetch a resource back from."
  @spec publish(Ms2ex.Schema.UgcResource.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def publish(resource, path) do
    case Context.Ugc.update_path(resource, path) do
      {:ok, _resource} -> {:ok, path}
      {:error, _changeset} -> {:error, :failed}
    end
  end

  @doc "Answers an upload with the path the client should use from now on."
  @spec send_path(Plug.Conn.t(), {:ok, String.t()} | {:error, atom()}) :: Plug.Conn.t()
  def send_path(conn, {:ok, path}) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "0,#{path}")
  end

  def send_path(conn, {:error, reason}), do: send_error(conn, reason)

  @spec send_error(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def send_error(conn, :empty), do: send_resp(conn, 400, "Request was empty")
  def send_error(conn, :malformed), do: send_resp(conn, 400, "Malformed request")
  def send_error(conn, :unsupported), do: send_resp(conn, 400, "Unsupported UGC type")
  def send_error(conn, :forbidden), do: send_resp(conn, 403, "Forbidden")
  def send_error(conn, :not_found), do: send_resp(conn, 404, "Unknown UGC resource")
  def send_error(conn, :invalid_path), do: send_resp(conn, 404, "Not Found")
  def send_error(conn, :too_large), do: send_resp(conn, 413, "Payload too large")
  def send_error(conn, _reason), do: send_resp(conn, 500, "Could not store the upload")

  @doc "Serves a stored file, or 404 when it is missing or the path is invalid."
  @spec serve(Plug.Conn.t(), [String.t()], String.t(), String.t()) :: Plug.Conn.t()
  def serve(conn, segments, extension, content_type) do
    with {:ok, file} <- validate_file(List.last(segments), extension),
         {:ok, path} <- resolve(List.replace_at(segments, -1, file)),
         true <- File.regular?(path) do
      conn
      |> put_resp_content_type(content_type, nil)
      |> send_resp(200, File.read!(path))
    else
      _ -> send_error(conn, :invalid_path)
    end
  end

  defp validate_file(file, extension) do
    case String.split(to_string(file), ".", parts: 2) do
      [name, ^extension] -> if safe?(name), do: {:ok, file}, else: {:error, :invalid_path}
      _ -> {:error, :invalid_path}
    end
  end

  # Only the file name may carry a dot; every other segment is a bare id.
  defp resolve(segments) do
    {file, dirs} = List.pop_at(segments, -1)
    [name | _] = String.split(to_string(file), ".", parts: 2)

    if Enum.all?(dirs, &safe?/1) and safe?(name) do
      {:ok,
       Path.join([Context.Ugc.data_dir() | Enum.map(dirs, &to_string/1)] ++ [to_string(file)])}
    else
      {:error, :invalid_path}
    end
  end

  defp safe?(segment), do: Regex.match?(@segment, to_string(segment))
end
