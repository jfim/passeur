defmodule Passeur.MixProject do
  use Mix.Project

  def project do
    [
      app: :passeur,
      version: "0.1.0",
      elixir: "~> 1.19",
      description: "Self-hosted MCP server framework with OAuth 2.1 and Dynamic Client Registration",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: "https://github.com/jfim/passeur"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Passeur.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jfim/passeur"}
    ]
  end

  defp deps do
    [
      {:hermes_mcp, "~> 0.14.1"},
      {:boruta, "~> 3.0.0-beta.4"},
      {:plug, "~> 1.19"},
      {:bandit, "~> 1.10"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.19"},
      {:argon2_elixir, "~> 4.1"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
