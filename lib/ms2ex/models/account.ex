defmodule Ms2ex.Account do
  use Ecto.Schema

  import Ecto.Changeset

  schema "accounts" do
    has_many :characters, Ms2ex.Character

    has_one :wallet, Ms2ex.AccountWallet

    field :password, :string, virtual: true
    field :password_hash, :string
    field :username, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:username, :password])
    |> cast_assoc(:wallet, with: &Ms2ex.AccountWallet.changeset/2)
    |> maybe_encrypt_password()
    |> validate_required([:username, :password_hash])
    |> unique_constraint(:username)
  end

  def set_default_assocs(attrs) do
    Map.put(attrs, :wallet, %{})
  end

  defp maybe_encrypt_password(account) do
    if pwd = get_change(account, :password) do
      change(account, password_hash: Bcrypt.hash_pwd_salt(pwd))
    else
      account
    end
  end
end
