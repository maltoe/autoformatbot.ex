defmodule Autoformatbot do
  @moduledoc """
  Documentation for Autoformatbot.
  """

  require Logger
  import Autoformatbot.Utils
  alias Autoformatbot.{Adapter, Configuration, Token}

  def call do
    Logger.info("autoformatbot start")

    [
      {:config, &Configuration.get/1},
      &prevent_infinite_loop/1,
      &autoformat_enabled_for_branch?/1,
      &needs_formatting?/1,
      {:files, &format!/1},
      {:target_branch, &target_branch/1},
      {:temporary_branch, &temporary_branch/1},
      {:adapter, &init_adapter/1},
      &prepare_temporary_branch/1,
      {:target_sha, &update_files/1},
      &create_or_reset_target_branch/1,
      &delete_temporary_branch/1,
      &create_pull/1
    ]
    |> Token.pipeline()
  end

  defp prevent_infinite_loop(%{config: config}) do
    if String.contains?(config.current_branch, config.suffix) do
      {:stop, "Abort due to autoformat infinite loop prevention policy."}
    else
      :ok
    end
  end

  defp autoformat_enabled_for_branch?(%{config: config}) do
    enabled =
      case config.branch do
        :all -> true
        x when is_binary(x) -> x == config.current_branch
        x when is_list(x) -> Enum.member?(x, config.current_branch)
      end

    if enabled, do: :ok, else: {:stop, "Autoformat disabled for branch #{config.current_branch}."}
  end

  defp needs_formatting?(_token) do
    case cmd("mix", ["format", "--check-formatted"]) do
      {:ok, {_, 1}} -> :ok
      {:ok, {_, 0}} -> {:stop, "Project is formatted, nothing to do."}
      err -> err
    end
  end

  defp target_branch(%{config: config}),
    do: {:ok, config.current_branch <> config.suffix}

  defp temporary_branch(%{config: config}),
    do: {:ok, config.current_branch <> config.suffix <> timestamp()}

  defp format!(_token) do
    with {:ok, _} <- cmd("mix", ["format"]),
         {:ok, output} <- cmd!("git", ["diff", "--name-only"]) do
      {:ok, String.split(output, "\n")}
    end
  end

  defp init_adapter(%{config: config}) do
    case config[:adapter] do
      {:github, opts} ->
        {:ok, {Adapter.Github, Adapter.Github.new(opts)}}

      {mod, opts} when is_atom(mod) ->
        {:ok, {mod, mod.new(opts)}}

      other ->
        {:error, "unknown adapter option: #{inspect(other)}"}
    end
  end

  defp prepare_temporary_branch(%{config: config, adapter: {mod, c}, temporary_branch: b}) do
    mod.create_branch!(c, b, config.current_sha)
  end

  defp update_files(%{adapter: {mod, c}, files: files, temporary_branch: b}) do
    Enum.reduce_while(files, :ok, fn path, _acc ->
      Logger.info("updating #{path}")

      case mod.update_file!(c, b, path) do
        {:ok, sha} -> {:cont, {:ok, sha}}
        err -> {:halt, err}
      end
    end)
  end

  defp create_or_reset_target_branch(%{adapter: {mod, c}, target_branch: b, target_sha: sha}) do
    with {:ok, branch_exists} <- mod.branch_exists?(c, b) do
      if branch_exists do
        mod.reset_branch!(c, b, sha)
      else
        mod.create_branch!(c, b, sha)
      end
    end
  end

  defp delete_temporary_branch(%{adapter: {mod, c}, temporary_branch: b}),
    do: mod.delete_branch!(c, b)

  defp create_pull(%{config: config, adapter: {mod, c}, target_branch: head}) do
    case mod.pull_exists?(c, config.current_branch, head) do
      {:ok, true} ->
        Logger.info("Pull request already exists.")
        :ok

      {:ok, false} ->
        Logger.info("Creating pull request: #{head} -> #{config.current_branch}")
        mod.create_pull!(c, config.current_branch, head)

      err ->
        err
    end
  end
end
