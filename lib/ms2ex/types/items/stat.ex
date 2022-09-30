defmodule Ms2ex.Items.Stat do
  alias Ms2ex.Metadata.Items

  defstruct [:attribute, :type, value: 0]

  def build(%Items.Stat{} = stat) do
    build(stat.attribute, stat.type, stat.value)
  end

  def build(attr, type, val) do
    val = if type == :flat, do: trunc(val), else: val
    %__MODULE__{attribute: attr, type: type, value: val}
  end
end
