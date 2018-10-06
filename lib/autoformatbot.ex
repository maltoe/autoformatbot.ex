defmodule Autoformatbot do
  @moduledoc """
  Documentation for Autoformatbot.
  """

  defmodule Configuration do
    @options [
      {:branch, ["master"]},
      {:suffix, "-autoformatbot"},
      :github_owner,
      :github_repo,
      :github_token
    ]

    def get(_token) do
      case Enum.reduce_while(@options, %{}, &collect_options/2) do
        %{} = config -> {:ok, config}
        err -> err
      end
    end

    defp collect_options({key, default}, acc) do
      case get_option(key, default) do
        {:ok, val} -> {:cont, Map.put(acc, key, val)}
        err -> {:halt, err}
      end
    end

    defp collect_options(key, acc) do
      case get_option(key, :missing) do
        {:ok, :missing} -> {:halt, {:error, "required option '#{key}' not set"}}
        {:ok, val} -> {:cont, Map.put(acc, key, val)}
        err -> {:halt, err}
      end
    end

    defp get_option(key, default) do
      case Application.get_env(:autoformatbot, key, default) do
        {:system, var} -> get_option_from_system_env(key, var)
        x -> {:ok, x}
      end
    end

    defp get_option_from_system_env(key, var) do
      case System.get_env(var) do
        nil -> {:error, "option '#{key}' set to env var $#{var}, but it is not set"}
        x -> {:ok, x}
      end
    end
  end

  defmodule Token do
    defstruct [
      :error,
      :config,
      :current_branch,
      :current_sha,
      :target_branch,
      :files,
      :gh
    ]

    def pipeline(functions) do
      case Enum.reduce_while(functions, %__MODULE__{}, &step/2) do
        %__MODULE__{} -> :ok
        err -> err
      end
    end

    defp step({key, function}, token) do
      case function.(token) do
        {:ok, result} -> {:cont, Map.put(token, key, result)}
        err -> {:halt, err}
      end
    end

    defp step(function, token) do
      case function.(token) do
        :ok -> {:cont, token}
        err -> {:halt, err}
      end
    end
  end

  defmodule GithubClient do
    defstruct [:tentacat, :owner, :repo]

    def new(token, owner, repo) do
      %__MODULE__{
        tentacat: Tentacat.Client.new(%{access_token: token}),
        owner: owner,
        repo: repo
      }
    end

    def branch_exists?(%{tentacat: t, owner: o, repo: r}, name) do
      case Tentacat.Repositories.Branches.find(t, o, r, name) do
        {404, %{"message" => "Not Found"}, _} -> {:error, "repository #{o}/#{r} does not exist on remote"}
        {404, %{"message" => "Branch not found"}, _} -> {:ok, false}
        {200, _, _} -> {:ok, true}
        other -> {:error, other}
      end
    end

    def create_branch!(%{tentacat: t, owner: o, repo: r}, name, sha) do
      body = %{"ref" => "refs/heads/#{name}", "sha" => sha}

      case Tentacat.References.create(t, o, r, body) do
        {422, %{"message" => "Object does not exist"}, _} -> {:error, "current SHA does not exist on remote"}
        {201, _, _} -> :ok
        other -> {:error, other}
      end
    end

    def reset_branch!(%{tentacat: t, owner: o, repo: r}, name, sha) do
      body = %{"sha" => sha, "force" => true}

      case Tentacat.References.update(t, o, r, "heads/#{name}", body) do
        {200, _, _} -> :ok
        other -> {:error, other}
      end
    end

    def get_file_sha(%{tentacat: t, owner: o, repo: r}, path, branch) do
      case Tentacat.Contents.find_in(t, o, r, path, "refs/heads/#{branch}") do
        {200, %{"sha" => sha}, _} -> {:ok, sha}
        other -> {:error, other}
      end
    end

    def update_file!(%{tentacat: t, owner: o, repo: r}, path, sha, branch) do
      body = %{
        "message" => "autoformatted #{path}",
        "committer" => %{
          "name" => "autoformatbot",
          "email" => "autoformatbot@example.com"
        },
        "content" => File.read!(path) |> Base.encode64(),
        "sha" => sha,
        "branch" => branch
      }

      case Tentacat.Contents.update(t, o, r, path, body) do
        {200, _, _} -> :ok
        other -> {:error, other}
      end
    end

    def create_pull!(%{tentacat: t, owner: o, repo: r}, base, branch) do
      body = %{
        "title" => "Autoformat",
        "body" => "I autoformatted this for you...",
        "base" => base,
        "head" => branch
      }

      case Tentacat.Pulls.create(t, o, r, body) do
        {201, _, _} -> :ok
        other -> {:error, other}
      end
    end
  end

  def call do
    [
      {:config, &Configuration.get/1},
      {:current_branch, fn _token -> cmd!("git", ["rev-parse", "--abbrev-ref", "HEAD"]) end},
      {:current_sha, fn _token -> cmd!("git", ["rev-parse", "HEAD"]) end},
      &prevent_infinite_loop/1,
      &autoformat_enabled_for_branch?/1,
      &needs_formatting?/1,
      {:files, &format!/1},
      {:target_branch, fn %{config: %{suffix: s}, current_branch: b} -> {:ok, b <> s} end},
      {:gh, &new_github_client/1},
      &prepare_target_branch/1,
      &upload_files/1,
      &create_pull/1
    ]
    |> Token.pipeline()
  end

  defp prevent_infinite_loop(%{config: config, current_branch: b}) do
    if String.ends_with?(b, config.suffix) do
      {:error, "Autoformat infinite loop prevention policy."}
    else
      :ok
    end
  end

  defp autoformat_enabled_for_branch?(%{config: %{branch: x}, current_branch: b}) do
    enabled =
      case x do
        x when is_binary(x) -> x == b
        x when is_list(x) -> Enum.member?(x, b)
      end

    if enabled, do: :ok, else: {:stop, "Autoformat disabled for branch #{b}."}
  end

  defp needs_formatting?(_token) do
    case cmd("mix", ["format", "--check-formatted"]) do
      {:ok, {_, 1}} -> :ok
      {:ok, {_, 0}} -> {:stop, "Project is formatted, nothing to do."}
      err -> err
    end
  end

  defp format!(_token) do
    with {:ok, _} <- cmd("mix", ["format"]),
         {:ok, output} <- cmd!("git", ["diff", "--name-only"]) do
      {:ok, String.split(output, "\n")}
    end
  end

  defp new_github_client(%{config: config}) do
    gh = GithubClient.new(config.github_token, config.github_owner, config.github_repo)
    {:ok, gh}
  end

  defp prepare_target_branch(%{gh: gh, current_sha: sha, target_branch: b}) do
    with {:ok, branch_exists} <- GithubClient.branch_exists?(gh, b)
    do
      if branch_exists do
        GithubClient.reset_branch!(gh, b, sha)
      else
        GithubClient.create_branch!(gh, b, sha)
      end
    end
  end

  defp upload_files(%{gh: gh, files: files, target_branch: b}) do
    Enum.reduce_while(files, :ok, fn file, _acc ->
      with {:ok, sha} <- GithubClient.get_file_sha(gh, file, b),
           :ok <- GithubClient.update_file!(gh, file, sha, b) do
        {:cont, :ok}
      else
        err -> {:halt, err}
      end
    end)
  end

  defp create_pull(%{gh: gh, current_branch: base, target_branch: head}),
    do: GithubClient.create_pull!(gh, base, head)

  # Executes system command, returns {:ok, {output, exit_status}} or {:error, msg} on error.
  defp cmd(exec, args) do
    try do
      {:ok, System.cmd(exec, args, stderr_to_stdout: true)}
    rescue
      e in ErlangError -> {:error, "failed to execute #{exec}: #{e.original}"}
    end
  end

  # Turns non-zero results of commands into errors.
  # Also trims the output.
  def cmd!(exec, args) do
    case cmd(exec, args) do
      {:ok, {output, 0}} -> {:ok, String.trim(output)}
      {:ok, {output, _status}} -> {:error, "non-zero exit code of #{exec}: #{output}"}
      err -> err
    end
  end
end
