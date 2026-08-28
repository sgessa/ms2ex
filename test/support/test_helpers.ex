defmodule Ms2ex.TestHelpers do
  @moduledoc """
  Shared test helpers, imported by the case templates so tests can call them
  without an explicit alias or import.
  """

  @doc """
  Stubs the metadata cache via a Mimic stub of `Ms2ex.Storage.get/2`.

  Keys are `"set:id"` strings matching the projected documents (e.g.
  `"item:15260310"`, `"additional-effect:20000027_1"`,
  `"table:globaldropitembox.xml"`), mirroring what the old ETS seeding
  inserted into `:metadata`. The test module must `use Mimic` (the case
  templates do).
  """
  def stub_metadata(data) do
    Mimic.stub(Ms2ex.Storage, :get, fn set, id -> Map.get(data, "#{set}:#{id}") end)
  end
end
