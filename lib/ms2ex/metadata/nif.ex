defmodule Ms2ex.Metadata.Nif do
  defstruct [:llid, :blocks]

  def ids(), do: [:llid]
end
