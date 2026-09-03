defmodule Ms2ex.Context.Ugc do
  @moduledoc """
  Persistence for user generated content resources and the files uploaded for
  them. A resource row is created by the game server when a client announces an
  upload; the web server then stores the file and records the path the client
  should fetch it back from.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @doc "Creates a resource owned by `character_id` and returns it."
  @spec create(integer(), atom()) :: {:ok, Schema.UgcResource.t()} | {:error, Ecto.Changeset.t()}
  def create(character_id, type) do
    %Schema.UgcResource{}
    |> Schema.UgcResource.changeset(%{character_id: character_id, type: type})
    |> Repo.insert()
  end

  @spec get(integer()) :: Schema.UgcResource.t() | nil
  def get(id), do: Repo.get(Schema.UgcResource, id)

  @spec update_path(Schema.UgcResource.t(), String.t()) ::
          {:ok, Schema.UgcResource.t()} | {:error, Ecto.Changeset.t()}
  def update_path(%Schema.UgcResource{} = resource, path) do
    resource
    |> Schema.UgcResource.changeset(%{path: path})
    |> Repo.update()
  end

  @doc """
  Root directory holding every uploaded file. Configurable so deployments can
  point it at a persistent volume.
  """
  @spec data_dir() :: String.t()
  def data_dir do
    config = Application.get_env(:ms2ex, Ms2ex)
    config[:ugc][:data_dir] || Path.join(:code.priv_dir(:ms2ex), "ugc")
  end
end
