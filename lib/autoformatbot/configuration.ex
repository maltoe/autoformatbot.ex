defmodule Autoformatbot.Configuration do
  @options [
    {:branch, ["master"]},
    {:suffix, "-autoformatbot"},
    :adapter
  ]

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

  defp translate({:system, var}, key) do
    case System.get_env(var) do
      nil -> {:error, "option '#{key}' set to env var $#{var}, but it is not set"}
      x -> x
    end
  end

  defp translate(val, _key), do: val
end
