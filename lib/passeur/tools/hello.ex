defmodule Passeur.Tools.Hello do
  use Anubis.Server.Component, type: :tool

  @moduledoc "A simple greeting tool"

  schema do
    field(:name, {:required, :string}, description: "Name to greet")
  end

  @impl true
  def execute(%{name: name}, frame) do
    {:reply,
     Anubis.Server.Response.tool()
     |> Anubis.Server.Response.text("Hello, #{name}! Welcome to Passeur."), frame}
  end
end
