defmodule Ms2ex.Metadata.Checksum do
  defstruct [:table_name, :crc32_c, :last_modified]

  def id(), do: :table_name
end
