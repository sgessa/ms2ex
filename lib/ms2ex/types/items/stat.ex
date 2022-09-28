defmodule Ms2ex.Items.Stat do
  alias Ms2ex.Metadata.Items

  defstruct [:attribute, :type, :flat, :rate]

  def build(%Items.Stat{} = stat) do
    build(stat.attribute, stat.type, stat.value)
  end

  def build(%Items.StatAttribute{} = attr, :flat, val) do
    %__MODULE__{attribute: attr, type: :flat, flat: trunc(val), rate: nil}
  end

  def build(%Items.StatAttribute{} = attr, :rate, val) do
    %__MODULE__{attribute: attr, type: :rate, flat: nil, rate: val}
  end
end
