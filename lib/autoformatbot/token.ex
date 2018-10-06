defmodule Autoformatbot.Token do
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
