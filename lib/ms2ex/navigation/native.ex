defmodule Ms2ex.Navigation.Native do
  @moduledoc false
  # Thin bindings to the native Detour runtime: loads mesh-set binaries and
  # answers path, snap and walkability queries on them. Coordinates are
  # navmesh-space floats (meters, Y up).

  use Rustler,
    otp_app: :ms2ex,
    crate: :navigation

  @type mesh :: reference()
  @type position :: {float(), float(), float()}

  @spec load_mesh(binary()) :: mesh()
  def load_mesh(_binary), do: nif_error()

  @spec find_path(mesh(), position(), position()) ::
          {:ok, [position()]} | {:error, String.t()}
  def find_path(_mesh, _from, _to), do: nif_error()

  @spec snap(mesh(), position()) :: {:ok, position()} | {:error, String.t()}
  def snap(_mesh, _at), do: nif_error()

  @spec valid_position(mesh(), position()) :: boolean()
  def valid_position(_mesh, _at), do: nif_error()

  @spec random_point_around(mesh(), position(), number()) ::
          {:ok, position()} | {:error, String.t()}
  def random_point_around(_mesh, _center, _radius), do: nif_error()

  @spec mesh_stats(mesh()) :: {integer(), integer()}
  def mesh_stats(_mesh), do: nif_error()

  defp nif_error do
    :erlang.nif_error(
      "the native navigation library is not loaded — compile it with `mix compile`"
    )
  end
end
