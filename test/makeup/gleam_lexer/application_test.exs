defmodule Makeup.Lexers.GleamLexer.ApplicationTest do
  use ExUnit.Case, async: true

  alias Makeup.Registry
  alias Makeup.Lexers.GleamLexer

  describe "start/2" do
    test "registers itself as a `makeup` lexer on application boot for the `gleam` language name" do
      assert {:ok, {GleamLexer, []}} == Registry.fetch_lexer_by_name("gleam")
    end

    test "registers itself as a `makeup` lexer on application boot for the `gleam` file extension" do
      assert {:ok, {GleamLexer, []}} == Registry.fetch_lexer_by_extension("gleam")
    end
  end
end
