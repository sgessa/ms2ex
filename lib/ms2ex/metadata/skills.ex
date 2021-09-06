defmodule Ms2ex.Metadata.SkillAttack do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :condition_skill_ids, 1, repeated: true, type: :int32
end

defmodule Ms2ex.Metadata.SkillData do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :duration, 1, type: :int32
  field :buff_type, 2, type: :int32
  field :buff_sub_type, 3, type: :int32
  field :buff_category, 4, type: :int32
  field :event_buff_type, 5, type: :int32
  field :max_stacks, 6, type: :int32
end

defmodule Ms2ex.Metadata.SkillMotion do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :sequence_name, 1, type: :string
  field :effect, 2, type: :string
end

defmodule Ms2ex.Metadata.Skill do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:id, :skill_levels, :sub_skills, :job, :learned, :state]

  field :id, 1, type: :int32
  field :skill_levels, 2, repeated: true, type: Ms2ex.Metadata.SkillLevel
  field :sub_skills, 3, repeated: true, type: :int32
  field :job, 4, type: Ms2ex.Metadata.Job, enum: true
  field :learned, 5, type: :bool
  field :state, 6, type: :string
  field :passive, 7, type: :bool
end

defmodule Ms2ex.Metadata.SkillLevel do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :level, 1, type: :int32
  field :spirit, 2, type: :int32
  field :stamina, 3, type: :int32
  field :damage_rate, 4, type: :float
  field :feature, 5, type: :string
  field :motion, 6, type: Ms2ex.Metadata.SkillMotion
  field :attack, 7, type: Ms2ex.Metadata.SkillAttack
  field :data, 8, type: Ms2ex.Metadata.SkillData
end

defmodule Ms2ex.Metadata.Skills do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Skill

  defstruct [:items]

  field :items, 1, repeated: true, type: Skill

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
      [{_id, %Skill{} = meta}] -> meta
      _ -> nil
    end
  end
end
