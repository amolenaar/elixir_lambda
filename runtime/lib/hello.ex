defmodule Hello do
  @moduledoc """
  This is a simple example module. The infamous Hello World.
  """

  def world(_event, _context), do: {:ok, %{:message => "Hello Elixir"}}
end
