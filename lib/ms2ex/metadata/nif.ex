defmodule Ms2ex.Metadata.Nif do
  defstruct [:llid, :blocks]

  def id(), do: :llid
end
