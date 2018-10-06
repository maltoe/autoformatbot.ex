defmodule Autoformatbot.MixProject do
  use Mix.Project

  def project do
    [
      app: :autoformatbot,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: false,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:tentacat, "~> 1.1", optional: true}
    ]
  end
end
