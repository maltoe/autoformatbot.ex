defmodule Autoformatbot.Adapter do
  @type options() :: list()
  @type client() :: any()
  @type branch() :: String.t
  @type sha() :: String.t
  @type path() :: String.t

  @callback new(options()) :: {:ok, client()}

  @callback branch_exists?(client(), String.t) :: {:ok, boolean()} | {:error, String.t}

  @callback create_branch!(client(), branch(), sha()) :: :ok | {:error, String.t}

  @callback delete_branch!(client(), branch()) :: :ok | {:error, String.t}

  @callback reset_branch!(client(), branch(), sha()) :: :ok | {:error, String.t}

  @callback update_file!(client(), branch(), path()) :: {:ok, sha()} | {:error, String.t}

  @callback create_pull!(client(), String.t, String.t) :: :ok | {:error, String.t}
end
