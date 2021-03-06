defmodule Autoformatbot.Utils do
  @doc """
  Executes system command.

  Returns `{:ok, {output, exit_status}}` or `{:error, msg}` on error.
  """
  def cmd(exec, args, opts \\ []) do
    try do
      {:ok, System.cmd(exec, args, Keyword.put(opts, :stderr_to_stdout, true))}
    rescue
      e in ErlangError -> {:error, "failed to execute #{exec}: #{e.original}"}
    end
  end

  @doc """
  Turns non-zero results of commands into errors.

  Also trims the output.

  Returns `{:ok, output}` or `{:error, msg}` on error.
  """
  def cmd!(exec, args) do
    case cmd(exec, args) do
      {:ok, {output, 0}} -> {:ok, String.trim(output)}
      {:ok, {output, _status}} -> {:error, "non-zero exit code of #{exec}: #{output}"}
      err -> err
    end
  end

  @doc """
  Returns a numeric-only timestamp of the current time as string.
  """
  def timestamp do
    DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()
  end
end
