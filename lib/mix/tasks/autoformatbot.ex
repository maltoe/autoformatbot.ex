defmodule Mix.Tasks.Autoformatbot do
  use Mix.Task

  @shortdoc "Run the autoformatbot"
  def run(_) do
    case Autoformatbot.call() do
      :ok ->
        exit(:normal)

      {:stop, msg} ->
        IO.puts(msg)
        exit(:normal)

      {:error, msg} ->
        IO.puts(:stderr, ["ERROR: ", msg])
        exit({:shutdown, 1})
    end
  end
end
