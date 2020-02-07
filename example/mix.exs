defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: "~> 1.7"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
