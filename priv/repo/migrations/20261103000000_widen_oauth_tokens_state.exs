defmodule Passeur.Repo.Migrations.WidenOauthTokensState do
  use Ecto.Migration

  # Boruta creates these as varchar(255), but some clients (e.g. Google's
  # MCP connector) send OAuth `state` values well over 1KB.
  def change do
    alter table(:oauth_tokens) do
      modify :state, :text, from: :string
      modify :redirect_uri, :text, from: :string
    end
  end
end
