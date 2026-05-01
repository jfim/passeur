defmodule Passeur.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Set boruta defaults if not already configured
    boruta_config = Application.get_env(:boruta, Boruta.Oauth, [])
    boruta_config = Keyword.put_new(boruta_config, :repo, Passeur.Repo)
    boruta_contexts = Keyword.get(boruta_config, :contexts, [])
    boruta_contexts = Keyword.put_new(boruta_contexts, :resource_owners, Passeur.ResourceOwners)
    boruta_config = Keyword.put(boruta_config, :contexts, boruta_contexts)
    Application.put_env(:boruta, Boruta.Oauth, boruta_config)

    load_static_bearer_tokens()

    port = Application.get_env(:passeur, :port, 4000)
    mcp_server = Application.get_env(:passeur, :mcp_server, Passeur.MCPServer)

    children = [
      Passeur.Repo,
      {mcp_server, transport: {:streamable_http, start: true}},
      {Bandit,
       plug: Passeur.Router, port: port, thousand_island_options: [read_timeout: :infinity]}
    ]

    opts = [strategy: :one_for_one, name: Passeur.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp load_static_bearer_tokens do
    if Application.get_env(:passeur, :static_bearer_tokens) == nil do
      tokens =
        case System.get_env("PASSEUR_STATIC_BEARER_TOKENS") do
          nil ->
            []

          "" ->
            []

          raw ->
            raw
            |> String.split(",", trim: true)
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
        end

      Application.put_env(:passeur, :static_bearer_tokens, tokens)
    end
  end
end
