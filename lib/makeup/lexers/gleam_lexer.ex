defmodule Makeup.Lexers.GleamLexer do
  @moduledoc """
  A `Makeup` lexer for the `Gleam` language.
  """

  @behaviour Makeup.Lexer

  import NimbleParsec
  import Makeup.Lexer.Combinators
  import Makeup.Lexer.Groups

  ###################################################################
  # Step #1: tokenize the input (into a list of tokens)
  ###################################################################

  whitespace = ascii_string([?\s, ?\f, ?\r, ?\n, ?\t], min: 1) |> token(:whitespace)

  # This combinator ensures that the lexer will never reject a file
  # because of invalid input syntax
  any_char = utf8_char([]) |> token(:error)

  # Gleam comments start with //; ///, //// are also just line comments
  comment =
    string("//")
    |> optional(utf8_string([not: ?\n], min: 1))
    |> token(:comment_single)

  # String escape sequences: \", \\, \n, \r, \t, \f, \u{XXXX}
  escape_double_quote = string(~s/\\"/)

  gleam_string = string_like(~s/"/, ~s/"/, [escape_double_quote], :string)

  # Number helpers
  digits = ascii_string([?0..?9], min: 1)

  float_scientific_part =
    ascii_string([?e, ?E], 1)
    |> optional(ascii_char([?+, ?-]))
    |> concat(digits)

  number_hex =
    string("0x")
    |> ascii_string([?0..?9, ?a..?f, ?A..?F], min: 1)
    |> token(:number_integer)

  number_oct =
    string("0o")
    |> ascii_string([?0..?7], min: 1)
    |> token(:number_integer)

  number_bin =
    string("0b")
    |> ascii_string([?0..?1], min: 1)
    |> token(:number_integer)

  number_float =
    digits
    |> string(".")
    |> concat(digits)
    |> optional(float_scientific_part)
    |> token(:number_float)

  number_integer =
    digits
    |> token(:number_integer)

  # Lowercase identifier: variables, function names, keywords
  # Can start with a-z or _ (for discard variables like _unused)
  lowercase_name =
    ascii_string([?a..?z, ?_], 1)
    |> optional(ascii_string([?a..?z, ?_, ?0..?9], min: 1))
    |> reduce({Enum, :join, []})

  # Uppercase identifier: type names and constructors
  uppercase_name =
    ascii_string([?A..?Z], 1)
    |> optional(ascii_string([?a..?z, ?_, ?0..?9, ?A..?Z], min: 1))
    |> reduce({Enum, :join, []})

  # Function call: lowercase name followed by optional whitespace and (
  function =
    lowercase_name
    |> lexeme()
    |> token(:name_function)
    |> concat(optional(whitespace))
    |> concat(token("(", :punctuation))

  # Variable or keyword (bare lowercase identifier)
  variable =
    lowercase_name
    |> lexeme()
    |> token(:name)

  # Module path: lowercase/lowercase or lowercase/lowercase/lowercase etc.
  # Used in import statements: import gleam/io, import gleam/string
  module_path =
    lowercase_name
    |> string("/")
    |> concat(lowercase_name)
    |> repeat(string("/") |> concat(lowercase_name))
    |> reduce({Enum, :join, []})
    |> lexeme()
    |> token(:name)

  # Constructor call: uppercase name followed by optional whitespace and (
  constructor_call =
    uppercase_name
    |> lexeme()
    |> token(:name_class)
    |> concat(optional(whitespace))
    |> concat(token("(", :punctuation))

  # Bare type or constructor name
  type_name =
    uppercase_name
    |> lexeme()
    |> token(:name_class)

  # Attributes: @external, @deprecated, @target, @internal, etc.
  attribute =
    string("@")
    |> concat(lowercase_name)
    |> token(:name_decorator)

  # Gleam operators - longer patterns first to avoid partial matches
  operators =
    word_from_list(
      ~W[== != <= >= |> -> <- <> .. +. -. *. /. && || + - * / < > =],
      :operator
    )

  punctuation =
    word_from_list(
      [",", "(", ")", "[", "]", "{", "}", ":", ".", ";", "|", "#"],
      :punctuation
    )

  # Tag the tokens with the language name.
  # This makes it easier to postprocess files with multiple languages.
  @doc false
  def __as_gleam_language__({ttype, meta, value}) do
    {ttype, Map.put(meta, :language, :gleam), value}
  end

  root_element_combinator =
    choice([
      whitespace,
      comment,
      gleam_string,
      # Numbers: specific prefixes before general, float before integer
      number_hex,
      number_oct,
      number_bin,
      number_float,
      number_integer,
      # Attributes
      attribute,
      # Uppercase: constructor calls (with parens) before bare type names
      constructor_call,
      type_name,
      # Lowercase: module paths (a/b/c), then function calls (with parens), then bare variables
      module_path,
      function,
      variable,
      # Bit array delimiters must be matched before < and > operators
      token("<<", :punctuation),
      token(">>", :punctuation),
      # Operators and punctuation
      operators,
      punctuation,
      # Fallback: highlight unknown characters as errors
      any_char
    ])

  ##############################################################################
  # Semi-public API: these two functions can be used by someone who wants to
  # embed this lexer into another lexer, but other than that, they are not
  # meant to be used by end-users
  ##############################################################################

  @impl Makeup.Lexer
  defparsec(
    :root_element,
    root_element_combinator |> map({__MODULE__, :__as_gleam_language__, []})
  )

  @impl Makeup.Lexer
  defparsec(
    :root,
    repeat(parsec(:root_element))
  )

  ###################################################################
  # Step #2: postprocess the list of tokens
  ###################################################################

  @keywords ~W[
    as assert auto case const delegate derive
    echo else fn if implement import let macro
    opaque panic pub todo type use
  ]

  @keyword_types ~W[Bool Float Int List Nil Result String BitArray Dynamic UtfCodepoint]

  defp postprocess_helper([{:name, meta, value} | tokens]) when value in @keywords,
    do: [{:keyword, meta, value} | postprocess_helper(tokens)]

  defp postprocess_helper([{:name_class, meta, value} | tokens]) when value in @keyword_types,
    do: [{:keyword_type, meta, value} | postprocess_helper(tokens)]

  defp postprocess_helper([token | tokens]), do: [token | postprocess_helper(tokens)]

  defp postprocess_helper([]), do: []

  # By default, return the list of tokens unchanged
  @impl Makeup.Lexer
  def postprocess(tokens, _opts \\ []), do: postprocess_helper(tokens)

  #######################################################################
  # Step #3: highlight matching delimiters
  #######################################################################

  @impl Makeup.Lexer
  defgroupmatcher(:match_groups,
    parentheses: [
      open: [[{:punctuation, %{language: :gleam}, "("}]],
      close: [[{:punctuation, %{language: :gleam}, ")"}]]
    ],
    list: [
      open: [
        [{:punctuation, %{language: :gleam}, "["}]
      ],
      close: [
        [{:punctuation, %{language: :gleam}, "]"}]
      ]
    ],
    bit_array: [
      open: [
        [{:punctuation, %{language: :gleam}, "<<"}]
      ],
      close: [
        [{:punctuation, %{language: :gleam}, ">>"}]
      ]
    ],
    block: [
      open: [
        [{:punctuation, %{language: :gleam}, "{"}]
      ],
      close: [
        [{:punctuation, %{language: :gleam}, "}"}]
      ]
    ]
  )

  defp remove_initial_newline([{ttype, meta, text} | tokens]) do
    case to_string(text) do
      "\n" -> tokens
      "\n" <> rest -> [{ttype, meta, rest} | tokens]
    end
  end

  # Finally, the public API for the lexer
  @impl Makeup.Lexer
  def lex(text, opts \\ []) do
    group_prefix = Keyword.get(opts, :group_prefix, random_prefix(10))
    {:ok, tokens, "", _, _, _} = root("\n" <> text)

    tokens
    |> remove_initial_newline()
    |> postprocess()
    |> match_groups(group_prefix)
  end
end
