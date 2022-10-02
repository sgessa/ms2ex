defmodule Ms2ex.Items.Stat do
  alias Ms2ex.Metadata.Items

  defstruct [:attribute, :type, :class, value: 0]

  def build(%Items.Stat{} = stat, stat_class) do
    build(stat.attribute, stat.type, stat.value, stat_class)
  end

  def build(attr, type, val, stat_class) do
    val = if type == :flat, do: trunc(val), else: val
    %__MODULE__{attribute: attr, type: type, value: val, class: stat_class}
  end

  def flat_value(%__MODULE__{type: :flat, value: val}), do: trunc(val)
  def flat_value(%__MODULE__{type: :rate}), do: 0.0

  def rate_value(%__MODULE__{type: :rate, value: val}), do: val / 1
  def rate_value(%__MODULE__{type: :flat}), do: 0
end
