defmodule Autoformatbot.Configuration do
  import Autoformatbot.Utils, only: [cmd: 3]
  require Logger

  @options [
    {:branch, :all},
    {:suffix, "-autoformatbot"},
    {:current_branch, {:cmd, "git", ["rev-parse", "--abbrev-ref", "HEAD"]}},
    {:current_sha, {:cmd, "git", ["rev-parse", "HEAD"]}},
    :adapter
  ]

  @doc """
  Builds the configuration map.

  * Retrieves environment variables as needed when specified as `{:system, "FOO"}`
  * Even in nested dictionaries
  * Retrieves configuration from external commands via `{:cmd, "echo", ["foo"]}`

  ## Parameters

  - `token`  pipeline token

  """
  def get(_token) do
    case Enum.reduce_while(@options, %{}, &collect_options/2) do
      %{} = config -> {:ok, config}
      err -> err
    end
  end

  defp collect_options({key, default}, acc) do
    case get_option(key, default) do
      {:error, msg} -> {:halt, {:error, msg}}
      val -> {:cont, Map.put(acc, key, val)}
    end
  end

  defp collect_options(key, acc) do
    case get_option(key, :missing) do
      {:error, msg} -> {:halt, {:error, msg}}
      :missing -> {:halt, {:error, "required option '#{key}' not set"}}
      val -> {:cont, Map.put(acc, key, val)}
    end
  end

  defp get_option(key, default) do
    get_option_from_application(key, default) |> translate(key)
  end

  defp get_option_from_application(key, default) do
    Application.get_env(:autoformatbot, key, default)
  end

  defp translate(nil, _), do: nil
  defp translate([], _), do: []

  defp translate([{sub, value} | xs], key),
    do: [{sub, translate(value, key)} | translate(xs, key)]

  defp translate({adapter, opts}, key) when is_list(opts),
    do: {adapter, translate(opts, key)}

  defp translate({:cmd, command, args}, key),
    do: translate({:cmd, command, args, []}, key)

  defp translate({:cmd, command, args, opts}, key) do
    case cmd(command, args, opts) do
      {:ok, {val, 0}} ->
        val |> String.trim()

      {:ok, {_val, n}} ->
        {:error, "option '#{key}' set to cmd #{command} exited with non-zero return: #{n}"}

      err ->
        {:error, "option '#{key}' set to cmd #{command}:\n#{inspect(err)}"}
    end
  end

  defp translate({:system, var}, key) do
    case System.get_env(var) do
      nil -> {:error, "option '#{key}' set to env var $#{var}, but it is not set"}
      x -> x
    end
  end

  defp translate(val, key) when is_function(val), do: val.()

  defp translate(val, _key), do: val
end
