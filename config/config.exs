import Config

config :passeur,
  ecto_repos: [Passeur.Repo]

config :boruta, Boruta.Oauth,
  repo: Passeur.Repo,
  contexts: [
    resource_owners: Passeur.ResourceOwners
  ],
  max_ttl: [
    access_token: 60 * 60 * 24 * 365,
    refresh_token: 60 * 60 * 24 * 365
  ]

import_config "#{config_env()}.exs"
