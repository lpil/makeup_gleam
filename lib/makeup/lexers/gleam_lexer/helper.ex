defmodule Makeup.Lexers.GleamLexer.Helper do
  @moduledoc false
  import NimbleParsec
  alias Makeup.Lexer.Combinators

  def with_optional_separator(combinator, separator) when is_binary(separator) do
    combinator |> repeat(string(separator) |> concat(combinator))
  end

  def lookahead_string(left, right, middle) do
    if middle == [] do
      left
      |> repeat(lookahead_not(right) |> concat(utf8_char([])))
    else
      choices = middle ++ [utf8_char([])]

      left
      |> repeat(lookahead_not(right) |> choice(choices))
    end
    |> concat(right)
    |> post_traverse({__MODULE__, :build_string, []})
  end

  def build_string(rest, acc, context, line, offset) do
    type = :string

    Combinators.collect_raw_chars_and_binaries(rest, acc, context, line, offset, type, %{})
  end
end
