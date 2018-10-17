use Mix.Config

config :autoformatbot,
  adapter:
    {:github, owner: "maltoe", repo: "autoformatbot.ex", access_token: {:system, "GITHUB_TOKEN"}},
  current_sha: {:system, "TRAVIS_COMMIT"},
  current_branch: fn ->
    if System.get_env("TRAVIS_PULL_REQUEST") == "false",
      do: System.get_env("TRAVIS_BRANCH"),
      else: System.get_env("TRAVIS_PULL_REQUEST_BRANCH")
  end
