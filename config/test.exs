use Mix.Config

config :autoformatbot,
  adapter: {:github,
    owner: "maltoe",
    repo: "autoformatbot.ex",
    access_token: {:system, "GITHUB_TOKEN"}
  }
