defmodule Autoformatbot.Adapter do
  @type client() :: any()

  @callback new(list()) :: {:ok, any()}

  @callback branch_exists?(client(), String.t()) :: {:ok, boolean()} | {:error, String.t()}

  @callback create_branch!(any(), String.t(), String.t()) :: :ok | {:error, String.t()}

  @callback reset_branch!(any(), String.t(), String.t()) :: :ok | {:error, String.t()}

  @callback update_file!(any(), String.t(), String.t()) :: :ok | {:error, String.t()}

  @callback create_pull!(any(), String.t(), String.t()) :: :ok | {:error, String.t()}
end
