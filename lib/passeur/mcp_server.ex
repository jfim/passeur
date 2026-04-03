defmodule Passeur.MCPServer do
  use Hermes.Server,
    name: "Passeur",
    version: "0.1.0",
    capabilities: [:tools]

  component Passeur.Tools.Hello

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end
