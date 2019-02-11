defmodule ExampleTest do
  use ExUnit.Case
  doctest Example

  test "greets the world" do
    assert Example.hello(%{}, %{}) ==
             {:ok, %{:message => "Elixir on AWS Lambda", event: %{}}}
  end
end
