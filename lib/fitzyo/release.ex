defmodule Fitzyo.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :fitzyo

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Loads the demo catalog from `priv/repo/seeds.exs`. Every seed upserts on a
  stable id, so this runs on each deploy to keep products, variants, and
  photos in sync with the repo.
  """
  def seed do
    load_app()
    {:ok, _} = Application.ensure_all_started(@app)

    [:code.priv_dir(@app), "repo", "seeds.exs"]
    |> Path.join()
    |> Code.eval_file()

    :ok
  end

  @doc "What the release command runs on deploy: migrate, then seed."
  def migrate_and_seed do
    migrate()
    seed()
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
