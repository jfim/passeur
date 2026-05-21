defmodule Passeur.MCPServer do
  @moduledoc false

  use Anubis.Server,
    name: "Passeur",
    version: "0.1.0",
    capabilities: [:tools]

  component(Passeur.Tools.Hello)

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end
