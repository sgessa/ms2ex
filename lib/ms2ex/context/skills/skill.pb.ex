defmodule Ms2ex.Metadata.SkillJob do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :knight, 10
  field :berseker, 20
  field :wizard, 30
  field :priest, 40
  field :archer, 50
  field :heavy_gunner, 60
  field :thief, 70
  field :assassin, 80
  field :rune_blade, 90
  field :striker, 100
  field :soul_binder, 110
  field :game_master, 999
end

defmodule Ms2ex.Metadata.SkillMetadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:id, :skill_levels, :sub_skills, :job, :learned, :state]

  field :id, 1, type: :int32
  field :skill_levels, 2, repeated: true, type: Ms2ex.Metadata.SkillLevel
  field :sub_skills, 3, repeated: true, type: :int32
  field :job, 4, type: Ms2ex.Metadata.SkillJob, enum: true
  field :learned, 5, type: :bool
  field :state, 6, type: :int32
end

defmodule Ms2ex.Metadata.SkillLevel do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:level, :spirit, :damage_rate, :feature]

  field :level, 1, type: :int32
  field :spirit, 2, type: :int32
  field :damage_rate, 3, type: :float
  field :feature, 4, type: :string
end

defmodule Ms2ex.Metadata.ListSkillMetadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.SkillMetadata

  defstruct [:items]

  field :items, 1, repeated: true, type: SkillMetadata

  @table :skill_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-skill-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: item_id} = metadata <- list.items do
      :ets.insert(@table, {item_id, metadata})
    end
  end

  def get(skill_id) do
    case :ets.lookup(@table, skill_id) do
      [{_id, %SkillMetadata{} = meta}] -> meta
      _ -> nil
    end
  end
end
