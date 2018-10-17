defmodule Mix.Tasks.Autoformatbot do
  use Mix.Task
  require Logger

  @shortdoc "Run the autoformatbot"
  def run(_) do
    case Autoformatbot.call() do
      :ok ->
        exit(:normal)

      {:stop, msg} ->
        Logger.info(msg)
        exit(:normal)

      {:error, msg} ->
        Logger.error(msg)
        exit({:shutdown, 1})
    end
  end
end
