defmodule Ms2ex.Users do
  alias Ms2ex.{Characters, Repo}
  alias Ms2ex.Users.Account

  def authenticate(username, password) do
    account = Repo.get_by(Account, username: username)

    case account do
      nil -> {:error, :invalid_credentials}
      _ -> check_password(account, password)
    end
  end

  defp check_password(%Account{password_hash: hash} = account, pwd) do
    case Bcrypt.verify_pass(pwd, hash) do
      true -> {:ok, account}
      false -> {:error, :invalid_credentials}
    end
  end

  def get(id), do: Repo.get(Account, id)

  def create(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Account{} = account), do: Repo.delete(account)

  def load_characters(%Account{} = account, opts \\ []) do
    account =
      Repo.preload(
        account,
        [characters: [equipment: [:ears, :face, :face_decor, :hair, :top, :bottom, :shoes]]],
        opts
      )

    characters = Enum.map(account.characters, &Characters.load_equips(&1))
    Map.put(account, :characters, characters)
  end
end
