defmodule Autoformatbot.Adapter.Github do
  @behaviour Autoformatbot.Adapter

  defstruct [:tentacat, :owner, :repo]

  def new([owner: _, repo: _, access_token: access_token] = opts) do
    {:module, _} = Code.ensure_loaded(Tentacat)

    # Need to start HTTPoison manually in mix task.
    # https://stackoverflow.com/a/35714348
    {:ok, _} = Application.ensure_all_started(:httpoison)

    __MODULE__
    |> struct(opts)
    |> Map.put(:tentacat, Tentacat.Client.new(%{access_token: access_token}))
  end

  def branch_exists?(%{tentacat: t, owner: o, repo: r}, name) do
    case Tentacat.Repositories.Branches.find(t, o, r, name) do
      {404, %{"message" => "Not Found"}, _} ->
        {:error, "repository #{o}/#{r} does not exist on remote"}

      {404, %{"message" => "Branch not found"}, _} ->
        {:ok, false}

      {200, _, _} ->
        {:ok, true}

      other ->
        error(other)
    end
  end

  def create_branch!(%{tentacat: t, owner: o, repo: r}, name, sha) do
    body = %{"ref" => "refs/heads/#{name}", "sha" => sha}

    case Tentacat.References.create(t, o, r, body) do
      {422, %{"message" => "Object does not exist"}, _} ->
        {:error, "current SHA does not exist on remote"}

      {201, _, _} ->
        :ok

      other ->
        error(other)
    end
  end

  def delete_branch!(%{tentacat: t, owner: o, repo: r}, name) do
    case Tentacat.References.remove(t, o, r, "heads/#{name}") do
      {204, _, _} -> :ok
      other -> error(other)
    end
  end

  def reset_branch!(%{tentacat: t, owner: o, repo: r}, name, sha) do
    body = %{"sha" => sha, "force" => true}

    case Tentacat.References.update(t, o, r, "heads/#{name}", body) do
      {200, _, _} -> :ok
      other -> error(other)
    end
  end

  def update_file!(%{tentacat: t, owner: o, repo: r} = client, branch, path) do
    with {:ok, sha} <- get_file_sha(client, path, branch) do
      body = %{
        "message" => "autoformat #{path}",
        "committer" => %{
          "name" => "autoformatbot",
          "email" => "autoformatbot@example.com"
        },
        "content" => File.read!(path) |> Base.encode64(),
        "sha" => sha,
        "branch" => branch
      }

      case Tentacat.Contents.update(t, o, r, path, body) do
        {200, %{"commit" => %{"sha" => sha}}, _} -> {:ok, sha}
        other -> error(other)
      end
    end
  end

  def create_pull!(%{tentacat: t, owner: o, repo: r}, base, branch) do
    body = %{
      "title" => "Autoformat #{base}",
      "body" => "I autoformatted this for you...",
      "base" => base,
      "head" => branch
    }

    case Tentacat.Pulls.create(t, o, r, body) do
      {201, _, _} -> :ok
      other -> error(other)
    end
  end

  defp error(other), do: {:error, "Tentacat error: #{inspect(other)}"}

  defp get_file_sha(%{tentacat: t, owner: o, repo: r}, path, branch) do
    case Tentacat.Contents.find_in(t, o, r, path, "refs/heads/#{branch}") do
      {200, %{"sha" => sha}, _} -> {:ok, sha}
      other -> error(other)
    end
  end
end
