defmodule MakeupGleam.Mixfile do
  use Mix.Project

  @version "1.0.0"
  @url "https://github.com/lpil/makeup_gleam"

  def project do
    [
      app: :makeup_gleam,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Makeup Gleam",
      description: description(),
      aliases: [docs: &build_docs/1]
    ]
  end

  defp description do
    """
    Gleam lexer for the Makeup syntax highlighter.
    """
  end

  defp package do
    [
      name: :makeup_gleam,
      licenses: ["BSD-2-Clause"],
      links: %{"GitHub" => @url}
    ]
  end

  def application do
    [
      mod: {Makeup.Lexers.GleamLexer.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:makeup, "~> 1.0"}
    ]
  end

  defp build_docs(_) do
    Mix.Task.run("compile")
    ex_doc = Path.join(Mix.path_for(:escripts), "ex_doc")

    unless File.exists?(ex_doc) do
      raise "cannot build docs because escript for ex_doc is not installed, run \"mix escript.install hex ex_doc\""
    end

    paths = Path.join(Mix.Project.build_path(), "lib/*/ebin")
    args = ["MakeupGleam", @version, Mix.Project.compile_path()]
    opts = ~w[--main Makeup.Lexers.GleamLexer --source-ref v#{@version} --source-url #{@url}]
    System.cmd(ex_doc, args ++ ["--paths", paths] ++ opts)
    Mix.shell().info("Docs built successfully")
  end
end
