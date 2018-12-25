defmodule Example do
  @moduledoc """
  Example Lambda function.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Example.hello()
      {:ok, %{ :message => "Hello Elixir" }}

  """
  def hello do
    {:ok, %{ :message => "Hello Elixir" }}
  end
end
