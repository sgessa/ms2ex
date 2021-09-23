defmodule Ms2ex.Character do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, Inventory}

  import Ecto.Changeset
  import EctoEnum

  @max_level 70

  @fields [
    :awakened,
    :discovered_maps,
    :exp,
    :gender,
    :insignia_id,
    :level,
    :job,
    :field_id,
    :motto,
    :name,
    :prestige_exp,
    :prestige_level,
    :rest_exp,
    :skin_color,
    :taxis,
    :title_id
  ]

  @optional_fields [
    :active_skill_tab_id
  ]

  defenum(Gender, male: 0, female: 1)

  @jobs Map.to_list(Ms2ex.Metadata.Job.mapping())
  defenum(Job, @jobs)

  schema "characters" do
    belongs_to :account, Ms2ex.Account

    has_many :emotes, Ms2ex.Emote
    has_many :favorite_stickers, Ms2ex.FavoriteChatSticker
    has_many :friends, Ms2ex.Friend
    has_many :stickers, Ms2ex.ChatStickerGroup

    has_many :equips, Inventory.Item
    has_many :inventory_items, Inventory.Item
    has_many :inventory_tabs, Ms2ex.Inventory.Tab

    has_many :hot_bars, Ms2ex.HotBar
    has_many :skill_tabs, Ms2ex.SkillTab
    has_many :titles, Ms2ex.CharacterTitle

    has_one :stats, Ms2ex.CharacterStats
    has_one :wallet, Ms2ex.Wallet

    field :awakened, :boolean, default: false

    # TODO
    field :badges, {:array, :map}, virtual: true, default: []

    # TODO
    field :clubs, {:array, :map}, virtual: true, default: []

    # TODO
    field :trophies, {:array, :integer}, virtual: true, default: [0, 0, 0]

    field :active_skill_tab_id, :integer
    field :animation, :integer, virtual: true, default: 0
    field :channel_id, :integer, virtual: true
    field :discovered_maps, {:array, :integer}, default: []
    field :exp, :integer, default: 0
    field :field_pid, EctoTypes.Term, virtual: true
    field :gender, Gender, default: :male
    field :group_chat_ids, {:array, :integer}, virtual: true, default: []
    field :guild_name, :string, virtual: true, default: "h4x0rzz"
    field :home_name, :string, virtual: true, default: ""
    field :insignia_id, :integer, default: 0
    field :level, :integer, default: 1
    field :job, Job
    field :field_id, :integer
    field :motto, :string, default: "Let's Maple!"
    field :mount, :map, virtual: true
    field :name, :string
    field :object_id, :integer, virtual: true, default: 0
    field :online?, :boolean, default: false, virtual: true
    field :party_id, :integer, virtual: true
    field :position, EctoTypes.Term, virtual: true
    field :prestige_exp, :integer, default: 0
    field :prestige_level, :integer, default: 1
    field :profile_url, :string, default: ""
    field :rest_exp, :integer, default: 0
    field :rotation, EctoTypes.Term, virtual: true
    field :safe_position, EctoTypes.Term, virtual: true
    field :skill_cast, EctoTypes.Term, virtual: true
    field :skin_color, EctoTypes.Term
    field :taxis, {:array, :integer}, default: []
    field :title_id, :integer, default: 0

    # TODO
    field :unknown_id, :integer, virtual: true, default: 0x01EF80C2

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, @fields ++ @optional_fields)
    |> cast_assoc(:emotes, with: &Ms2ex.Emote.changeset/2)
    |> cast_assoc(:inventory_tabs, with: &Ms2ex.Inventory.Tab.changeset/2)
    |> cast_assoc(:hot_bars, with: &Ms2ex.HotBar.changeset/2)
    |> cast_assoc(:skill_tabs, with: &Ms2ex.SkillTab.changeset/2)
    |> cast_assoc(:stats, with: &Ms2ex.CharacterStats.changeset/2)
    |> cast_assoc(:stickers, with: &Ms2ex.ChatStickerGroup.changeset/2)
    |> cast_assoc(:wallet, with: &Ms2ex.Wallet.changeset/2)
    |> validate_required(@fields)
    |> unique_constraint(:name)
  end

  def job_id(%{awakened: true} = char), do: real_job_id(char) * 10 + 1

  def job_id(char), do: real_job_id(char) * 10

  def real_job_id(character) do
    Keyword.get(Job.__enum_map__(), character.job)
  end

  def max_level(), do: @max_level

  def set_default_assocs(attrs) do
    job = Map.get(attrs, :job)

    attrs
    |> Map.put(:stickers, default_stickers())
    |> Map.put(:emotes, Enum.map(Ms2ex.Emotes.default_emotes(), &%{emote_id: &1}))
    |> Map.put(:hot_bars, [%{active: true}, %{}])
    |> Map.put(:inventory_tabs, default_inventory_tabs())
    |> Map.put(:skill_tabs, default_skill_tabs(job))
    |> Map.put(:stats, %{})
    |> Map.put(:wallet, %{})
  end

  defp default_stickers() do
    Enum.map(Ms2ex.ChatStickers.default_stickers(), &%{group_id: &1})
  end

  defp default_inventory_tabs() do
    Ms2ex.Inventory.Tab.default_slots()
    |> Enum.map(fn {tab, slots} ->
      %{tab: tab, slots: slots}
    end)
  end

  defp default_skill_tabs(job) do
    [Ms2ex.SkillTab.set_skills(job, %{name: "Build 1"})]
  end
end
