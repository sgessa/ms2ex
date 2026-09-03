defmodule Ms2ex.Schema.Achievement do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "achievements" do
    field :owner_id, :integer, primary_key: true
    field :achievement_id, :integer, primary_key: true
    field :current_grade, :integer
    field :reward_grade, :integer
    field :favorite, :boolean, default: false
    field :counter, :integer, default: 0
    field :category, :integer
    field :grades, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [:owner_id, :achievement_id, :current_grade, :reward_grade, :favorite, :counter, :category, :grades])
    |> validate_required([:owner_id, :achievement_id, :current_grade, :reward_grade, :category, :grades])
  end
end
