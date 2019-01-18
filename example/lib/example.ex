defmodule Example do
  @moduledoc """
  Example Lambda function.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Example.hello(%{}, %{})
      {:ok, %{ :message => "Hello Elixir", event: %{} }}

  """

  def hello(event, context),
    do: {:ok, %{ :message => "Elixir on AWS Lambda", :event => event, :context => inspect(context) }}

end
