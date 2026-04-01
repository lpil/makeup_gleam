defmodule Makeup.Lexers.GleamLexer.Application do
  @moduledoc false
  use Application

  alias Makeup.Registry
  alias Makeup.Lexers.GleamLexer

  def start(_type, _args) do
    Registry.register_lexer(GleamLexer,
      options: [],
      names: ["gleam"],
      extensions: ["gleam"]
    )

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
