defmodule Ms2ex.Storage.Tables.LearningQuest do
  alias Ms2ex.Storage

  @table_name "learningquest.xml"

  @doc """
  Returns a Maple Guide entry by id: the level/quest requirements for
  starting the guide and the map/portal its "start" action travels to.
  """
  def get(id) when is_integer(id) do
    table = Storage.get(:table, @table_name)
    get_in(table, [:table, :entries, to_string(id)])
  end
end
