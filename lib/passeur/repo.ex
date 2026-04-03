defmodule Passeur.Repo do
  use Ecto.Repo,
    otp_app: :passeur,
    adapter: Ecto.Adapters.Postgres
end
