defmodule Ms2ex.Accounts do
  alias Ms2ex.{Repo, Account}

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
    attrs = Account.set_default_assocs(attrs)

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
end
