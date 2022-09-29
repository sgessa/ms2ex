defmodule Ms2ex.Items.Stat do
  alias Ms2ex.Metadata.Items

  defstruct [:attribute, :type, flat: 0, rate: 0]

  def build(%Items.Stat{} = stat) do
    build(stat.attribute, stat.type, stat.value)
  end

  def build(attr, :flat, val) do
    %__MODULE__{attribute: attr, type: :flat, flat: trunc(val)}
  end

  def build(attr, :rate, val) do
    %__MODULE__{attribute: attr, type: :rate, rate: val}
  end
end
