# Autoformatbot

This tiny Mix task uses the beauty of `mix format` to to clean up after you in a non-intrusive way.

* Remember when stylistic linter tools used to give you the red light :tomato: on pull requests because a line in the code hit the 81 characters mark?
* Autoformatbot formats selected branches of your repository and creates a friendly pull request on your favourite hosting platform.

## Installation

Ideally you tie this into your automated CI tasks. Example configuration for the `test` environment and a GitHub-hosted repository:

```elixir
# mix.exs
def deps do
  [
    {:tentacat, "~> 1.1", only: [:test]},
    {:autoformatbot, "~> 0.1.0", only: [:test]}
  ]
end
```

```elixir
# config/test.exs
config :autoformatbot,
  adapter: {:github,                          # currently only GitHub
    owner: "maltoe",
    repo: "autoformatbot.ex",
    access_token: {:system, "GITHUB_TOKEN"}   # retrieves token from environment variable
  }
```

Then configure `mix autoformatbot` to be run after each push to `master` and set the `GITHUB_TOKEN` environment variable.

## Automating with Travis CI

Please see [.travis.yml](.travis.yml) for a working Travis CI configuration. Make sure to specify the branches you want to run the Autoformatbot on.

# License

[MIT](LICENSE)
