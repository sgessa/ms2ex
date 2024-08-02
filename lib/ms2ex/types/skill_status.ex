defmodule Ms2ex.Types.SkillStatus do
  alias Ms2ex.SkillCast

  defstruct [
    :id,
    :skill_cast,
    :source,
    :target,
    :stacks,
    :start,
    :end,
    :duration
  ]

  def new(%SkillCast{} = skill_cast, target, source, stacks) do
    start = Ms2ex.sync_ticks()
    duration = SkillCast.duration(skill_cast)
    stacks = stacks |> min(SkillCast.max_stacks(skill_cast)) |> max(0)

    %__MODULE__{
      id: Ms2ex.generate_long(),
      target: target,
      source: source,
      stacks: stacks,
      skill_cast: skill_cast,
      start: start,
      duration: duration,
      end: start + duration
    }
  end
end
