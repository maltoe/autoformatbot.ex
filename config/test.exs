use Mix.Config

config :autoformatbot,
  current_branch: {:system, "TRAVIS_BRANCH"},
  current_sha: {:system, "TRAVIS_COMMIT"},
  adapter: {:github,
    owner: "maltoe",
    repo: "autoformatbot.ex",
    access_token: {:system, "GITHUB_TOKEN"}
  }
