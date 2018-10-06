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
    [
      extra_applications: [:httpoison]
    ]
  end

  defp deps do
    [
      {:tentacat, "~> 1.1"}
    ]
  end
end
