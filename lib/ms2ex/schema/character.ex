defmodule Ms2ex.Schema.Character do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ms2ex.{Enums, Context, EctoTypes, Schema}

  @fields [
    :awakened,
    :discovered_maps,
    :exp,
    :gender,
    :insignia_id,
    :level,
    :job,
    :map_id,
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

  schema "characters" do
    belongs_to :account, Schema.Account

    has_many :emotes, Schema.Emote
    has_many :favorite_stickers, Schema.FavoriteChatSticker
    has_many :friends, Schema.Friend
    has_many :stickers, Schema.ChatStickerGroup

    has_many :equips, Schema.Item
    has_many :inventory_items, Schema.Item
    has_many :inventory_tabs, Schema.InventoryTab

    has_many :hot_bars, Schema.HotBar
    has_many :skill_tabs, Schema.SkillTab
    has_many :titles, Schema.CharacterTitle

    has_one :stats, Schema.CharacterStats
    has_one :wallet, Schema.Wallet

    field :awakened, :boolean, default: false

    field :active_skill_tab_id, :integer
    field :discovered_maps, {:array, :integer}, default: []
    field :exp, :integer, default: 0
    field :insignia_id, :integer, default: 0
    field :level, :integer, default: 1
    field :job, Enums.Job, default: :newbie
    field :map_id, :integer
    field :motto, :string, default: "Let's Maple!"
    field :name, :string

    field :prestige_exp, :integer, default: 0
    field :prestige_level, :integer, default: 1
    field :profile_url, :string, default: ""
    field :rest_exp, :integer, default: 0
    field :skin_color, EctoTypes.Term
    field :taxis, {:array, :integer}, default: []
    field :title_id, :integer, default: 0

    # Virtuals

    # TODO
    field :badges, {:array, :map}, virtual: true, default: []
    field :clubs, {:array, :map}, virtual: true, default: []
    field :trophies, {:array, :integer}, virtual: true, default: [0, 0, 0]

    field :animation, :integer, virtual: true, default: 0
    field :channel_id, :integer, virtual: true
    field :field_pid, EctoTypes.Term, virtual: true
    field :gender, Ms2ex.Enums.Gender, default: :male
    field :guild_name, :string, virtual: true, default: ""
    field :home_name, :string, virtual: true, default: ""
    field :object_id, :integer, virtual: true, default: 0
    field :online?, :boolean, default: false, virtual: true
    field :group_chat_ids, {:array, :integer}, virtual: true, default: []
    field :dismantle_inventory, EctoTypes.Term, virtual: true
    field :mount, :map, virtual: true
    field :party_id, :integer, virtual: true
    field :position, EctoTypes.Term, virtual: true
    field :rotation, EctoTypes.Term, virtual: true
    field :safe_position, EctoTypes.Term, virtual: true
    field :session_pid, EctoTypes.Term, virtual: true
    field :sender_session_pid, EctoTypes.Term, virtual: true
    field :skill_cast, EctoTypes.Term, virtual: true
    field :unknown_id, :integer, virtual: true, default: 0x01EF80C2

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, @fields ++ @optional_fields)
    |> cast_assoc(:emotes, with: &Schema.Emote.changeset/2)
    |> cast_assoc(:inventory_tabs, with: &Schema.InventoryTab.changeset/2)
    |> cast_assoc(:hot_bars, with: &Schema.HotBar.changeset/2)
    |> cast_assoc(:skill_tabs, with: &Schema.SkillTab.changeset/2)
    |> cast_assoc(:stats, with: &Schema.CharacterStats.changeset/2)
    |> cast_assoc(:stickers, with: &Schema.ChatStickerGroup.changeset/2)
    |> cast_assoc(:wallet, with: &Schema.Wallet.changeset/2)
    |> validate_required(@fields)
    |> unique_constraint(:name)
  end

  def job_id(%{awakened: true} = char), do: Enums.Job.get_value(char.job) * 10 + 1
  def job_id(char), do: Enums.Job.get_value(char.job) * 10

  def set_default_assocs(attrs) do
    job = Map.get(attrs, :job)

    attrs
    |> Map.put(:stickers, default_stickers())
    |> Map.put(:emotes, Enum.map(Context.Emotes.default_emotes(), &%{emote_id: &1}))
    |> Map.put(:hot_bars, [%{active: true}, %{}])
    |> Map.put(:inventory_tabs, default_inventory_tabs())
    |> Map.put(:skill_tabs, default_skill_tabs(job))
    |> Map.put(:stats, %{})
    |> Map.put(:wallet, %{})
  end

  defp default_stickers() do
    Enum.map(Context.ChatStickers.default_stickers(), &%{group_id: &1})
  end

  defp default_inventory_tabs() do
    Schema.InventoryTab.default_slots()
    |> Enum.map(fn {tab, slots} ->
      %{tab: tab, slots: slots}
    end)
  end

  defp default_skill_tabs(job) do
    [Context.SkillTabs.set_skills(job, %{name: "Build 1"})]
  end
end
