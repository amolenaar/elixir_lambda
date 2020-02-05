defmodule Example do
  @moduledoc """
  Example Lambda function.
  """

  require Logger

  def hello(event, context) do
    Logger.info("Event: #{inspect(event)}")
    Logger.info("Context: #{inspect(context)}")
    # need to return an empty map because the default API Gateway response
    # proxy only accepts an empty json response
    {:ok, %{}}
  end
end
