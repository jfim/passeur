defmodule PasseurTest do
  use ExUnit.Case
  doctest Passeur

  test "greets the world" do
    assert Passeur.hello() == :world
  end
end
