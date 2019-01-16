defmodule Mix.Tasks.Package do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("compile", [])

    config = Mix.Project.config()
    app = Keyword.fetch!(config, :app)
    version = Keyword.fetch!(config, :version)

    build_path = Mix.Project.build_path()

    package_files = ls_r(build_path <> "/lib")
    |> Enum.map(&(String.trim_leading(&1, build_path <> "/")))

    case zip("#{app}-#{version}.zip", package_files, build_path) do
      {:ok, zipfile} -> IO.inspect(zipfile, label: "Created archive")
      {:error, err} -> IO.inspect(err, label: "Could not create zip file")
    end
  end

  def ls_r(path \\ ".") do
    cond do
      File.regular?(path) -> [path]
      File.dir?(path) ->
        File.ls!(path)
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&ls_r/1)
        |> Enum.concat
      true -> []
    end
  end

  def zip(name, package_files, build_path) do
    :zip.zip(name |> String.to_charlist(),
      package_files |> Enum.map(&String.to_charlist/1),
      cwd: build_path |> String.to_charlist())
  end
end
