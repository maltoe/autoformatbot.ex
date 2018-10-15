use Mix.Config

defmodule GithubMock do
  @behaviour Autoformatbot.Adapter

  defstruct [:calls]

  def init(_) do
    %__MODULE__{calls: []}
  end

  @rem """
  @callback new(options()) :: {:ok, client()}
  @callback branch_exists?(client(), String.t()) :: {:ok, boolean()} | {:error, String.t()}
  @callback create_branch!(client(), branch(), sha()) :: :ok | {:error, String.t()}
  @callback delete_branch!(client(), branch()) :: :ok | {:error, String.t()}
  @callback reset_branch!(client(), branch(), sha()) :: :ok | {:error, String.t()}
  @callback update_file!(client(), branch(), path()) :: {:ok, sha()} | {:error, String.t()}
  @callback pull_exists?(client(), branch(), branch()) :: {:ok, boolean()} | {:error, String.t()}
  @callback create_pull!(client(), branch(), branch()) :: :ok | {:error, String.t()}
  """
end

Application.put_env(:autoformatbot, :adapter, {GithubMock, []})
Application.put_env(:autoformatbot, :current_branch, "test-branch")
Application.put_env(:autoformatbot, :current_sha, "ABCDEF")

ExUnit.start()
