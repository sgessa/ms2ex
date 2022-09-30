defmodule Ms2ex.Items.Stat do
  alias Ms2ex.Metadata.Items

  defstruct [:attribute, :type, :class, value: 0]

  def build(%Items.Stat{} = stat, stat_class) do
    build(stat.attribute, stat.type, stat.value, stat_class)
  end

  @spec build(any, any, any, any) :: %Ms2ex.Items.Stat{
          attribute: any,
          class: any,
          type: any,
          value: any
        }
  def build(attr, type, val, stat_class) do
    val = if type == :flat, do: trunc(val), else: val
    %__MODULE__{attribute: attr, type: type, value: val, class: stat_class}
  end
end
