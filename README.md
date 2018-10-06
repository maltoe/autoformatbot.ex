# Autoformatbot

TODO

## Installation

Ideally, you tie this into your automated CI tasks. For example, in the `test` environment and GitHub:

```elixir
# mix.exs
def deps do
  [
    {:autoformatbot, "~> 0.1.0"},
    {:tentacat, "~> 1.1"}
  ]
end
```

```elixir
# config/test.exs
config :autoformatbot,
  branch: ["master"],        # enable only for branches, set to :all for all
  suffix: "-autoformatbot",  # Suffix to apply to branches for autoformatted commits
  adapter: {:github,
    owner: "maltoe",
    repo: "autoformatbot.ex"
  }
```

# License

[MIT](LICENSE)
