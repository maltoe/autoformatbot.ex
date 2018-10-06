defmodule Autoformatbot do
  @moduledoc """
  Documentation for Autoformatbot.
  """

  import Autoformatbot.Utils
  alias Autoformatbot.{Adapter, Configuration, Token}

  def call do
    [
      {:config, &Configuration.get/1},
      {:current_branch, fn _token -> cmd!("git", ["rev-parse", "--abbrev-ref", "HEAD"]) end},
      {:current_sha, fn _token -> cmd!("git", ["rev-parse", "HEAD"]) end},
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

  defp prevent_infinite_loop(%{config: config, current_branch: b}) do
    if String.ends_with?(b, config.suffix) do
      {:normal, "Abort due to autoformat infinite loop prevention policy."}
    else
      :ok
    end
  end

  defp autoformat_enabled_for_branch?(%{config: %{branch: x}, current_branch: b}) do
    enabled =
      case x do
        :all -> true
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

  defp target_branch(%{config: %{suffix: s}, current_branch: b}),
    do: {:ok, b <> s}

  defp temporary_branch(%{config: %{suffix: s}, current_branch: b}),
    do: {:ok, b <> s <> (DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string())}

  defp format!(_token) do
    with {:ok, _} <- cmd("mix", ["format"]),
         {:ok, output} <- cmd!("git", ["diff", "--name-only"]) do
      {:ok, String.split(output, "\n")}
    end
  end

  defp init_adapter(%{config: config}) do
    case config[:adapter] do
      {:github, opts} -> {:ok, {Adapter.Github, Adapter.Github.new(opts)}}
      other -> {:error, "unknown adapter option: #{inspect(other)}"}
    end
  end

  defp prepare_temporary_branch(%{adapter: {mod, c}, current_sha: sha, temporary_branch: b}) do
    mod.create_branch!(c, b, sha)
  end

  defp update_files(%{adapter: {mod, c}, files: files, target_branch: b}) do
    Enum.reduce_while(files, :ok, fn path, _acc ->
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
    do: mod.remove_branch!(c, b)

  defp create_pull(%{adapter: {mod, c}, current_branch: base, target_branch: head}),
    do: mod.create_pull!(c, base, head)
end
