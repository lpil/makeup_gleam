defmodule GleamLexerTokenizer do
  use ExUnit.Case, async: false
  import Makeup.Lexers.GleamLexer.Testing, only: [lex: 1]

  test "empty string" do
    assert lex("") == []
  end

  describe "whitespace" do
    test "spaces and newlines" do
      assert lex(" ") == [{:whitespace, %{}, " "}]
      assert lex("\n") == [{:whitespace, %{}, "\n"}]
      assert lex("\t") == [{:whitespace, %{}, "\t"}]
      assert lex("\f") == [{:whitespace, %{}, "\f"}]
      assert lex("\s") == [{:whitespace, %{}, "\s"}]
    end
  end

  describe "comments" do
    test "single-line comment //" do
      assert lex("// a comment") == [{:comment_single, %{}, "// a comment"}]
      assert lex("//no space") == [{:comment_single, %{}, "//no space"}]
      assert lex("//") == [{:comment_single, %{}, "//"}]
    end

    test "doc comments /// and ////" do
      assert lex("/// doc comment") == [{:comment_single, %{}, "/// doc comment"}]
      assert lex("//// module doc") == [{:comment_single, %{}, "//// module doc"}]
    end

    test "comment stops at newline" do
      assert lex("// comment\n") == [
               {:comment_single, %{}, "// comment"},
               {:whitespace, %{}, "\n"}
             ]
    end

    test "comment followed by code" do
      assert lex("// comment\n42") == [
               {:comment_single, %{}, "// comment"},
               {:whitespace, %{}, "\n"},
               {:number_integer, %{}, "42"}
             ]
    end
  end

  describe "strings" do
    test "simple string" do
      assert lex(~s/"hello"/) == [{:string, %{}, ~s/"hello"/}]
      assert lex(~s/"hello world"/) == [{:string, %{}, ~s/"hello world"/}]
    end

    test "multi-line string" do
      assert lex("""
             let x = "one
             two"
             """) == [
               {:keyword, %{}, "let"},
               {:whitespace, %{}, " "},
               {:name, %{}, "x"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:string, %{}, ~s/"one\ntwo"/},
               {:whitespace, %{}, "\n"}
             ]

      assert lex(~s/"hello world"/) == [{:string, %{}, ~s/"hello world"/}]
    end

    test "empty string" do
      assert lex(~s/""/) == [{:string, %{}, ~s/""/}]
    end

    test "string with escaped double quote" do
      assert lex(~s/"escape \\"quote\\""/) == [{:string, %{}, ~s/"escape \\"quote\\""/}]
    end

    test "string with escape sequences" do
      assert lex(~s/"\\n"/) == [{:string, %{}, ~s/"\\n"/}]
      assert lex(~s/"\\t"/) == [{:string, %{}, ~s/"\\t"/}]
      assert lex(~s/"\\r"/) == [{:string, %{}, ~s/"\\r"/}]
      assert lex(~s/"\\\\b"/) == [{:string, %{}, ~s/"\\\\b"/}]
    end

    test "does not tokenize identifiers inside strings" do
      refute {:name, %{}, "hello"} in lex(~s/"hello"/)
      refute {:keyword, %{}, "fn"} in lex(~s/"fn"/)
    end

    test "does not tokenize operators inside strings" do
      refute {:operator, %{}, "=="} in lex(~s/"=="/)
    end
  end

  describe "numbers" do
    test "decimal integers" do
      assert lex("0") == [{:number_integer, %{}, "0"}]
      assert lex("42") == [{:number_integer, %{}, "42"}]
      assert lex("123456") == [{:number_integer, %{}, "123456"}]
    end

    test "hexadecimal integers" do
      assert lex("0xFF") == [{:number_integer, %{}, "0xFF"}]
      assert lex("0xDEAD") == [{:number_integer, %{}, "0xDEAD"}]
      assert lex("0xff") == [{:number_integer, %{}, "0xff"}]
      assert lex("0x1a2b") == [{:number_integer, %{}, "0x1a2b"}]
    end

    test "octal integers" do
      assert lex("0o77") == [{:number_integer, %{}, "0o77"}]
      assert lex("0o0") == [{:number_integer, %{}, "0o0"}]
      assert lex("0o755") == [{:number_integer, %{}, "0o755"}]
    end

    test "binary integers" do
      assert lex("0b1010") == [{:number_integer, %{}, "0b1010"}]
      assert lex("0b0") == [{:number_integer, %{}, "0b0"}]
      assert lex("0b11110000") == [{:number_integer, %{}, "0b11110000"}]
    end

    test "floating point numbers" do
      assert lex("1.0") == [{:number_float, %{}, "1.0"}]
      assert lex("3.14") == [{:number_float, %{}, "3.14"}]
      assert lex("0.5") == [{:number_float, %{}, "0.5"}]
    end

    test "floating point numbers with scientific notation" do
      assert lex("1.0e10") == [{:number_float, %{}, "1.0e10"}]
      assert lex("1.5E3") == [{:number_float, %{}, "1.5E3"}]
      assert lex("1.0e-5") == [{:number_float, %{}, "1.0e-5"}]
      assert lex("2.5e+3") == [{:number_float, %{}, "2.5e+3"}]
    end
  end

  describe "variables (lowercase identifiers)" do
    test "simple variable" do
      assert lex("x") == [{:name, %{}, "x"}]
      assert lex("foo") == [{:name, %{}, "foo"}]
      assert lex("foo_bar") == [{:name, %{}, "foo_bar"}]
    end

    test "variable with digits" do
      assert lex("x1") == [{:name, %{}, "x1"}]
      assert lex("foo123") == [{:name, %{}, "foo123"}]
    end

    test "discard variable (underscore prefix)" do
      assert lex("_") == [{:name, %{}, "_"}]
      assert lex("_unused") == [{:name, %{}, "_unused"}]
    end
  end

  describe "type names and constructors (uppercase identifiers)" do
    test "simple type names" do
      assert lex("User") == [{:name_class, %{}, "User"}]
      assert lex("MyType") == [{:name_class, %{}, "MyType"}]
    end

    test "constructor calls" do
      assert lex("Ok(x)") == [
               {:name_class, %{}, "Ok"},
               {:punctuation, %{group_id: "group-1"}, "("},
               {:name, %{}, "x"},
               {:punctuation, %{group_id: "group-1"}, ")"}
             ]

      assert lex("Error(e)") == [
               {:name_class, %{}, "Error"},
               {:punctuation, %{group_id: "group-1"}, "("},
               {:name, %{}, "e"},
               {:punctuation, %{group_id: "group-1"}, ")"}
             ]
    end
  end

  describe "function calls" do
    test "simple function call" do
      assert lex("foo(") == [
               {:name_function, %{}, "foo"},
               {:punctuation, %{group_id: "group-1"}, "("}
             ]
    end

    test "function call with argument" do
      assert lex("foo(1)") == [
               {:name_function, %{}, "foo"},
               {:punctuation, %{group_id: "group-1"}, "("},
               {:number_integer, %{}, "1"},
               {:punctuation, %{group_id: "group-1"}, ")"}
             ]
    end

    test "module-qualified function call" do
      assert lex("io.println(") == [
               {:name, %{}, "io"},
               {:punctuation, %{}, "."},
               {:name_function, %{}, "println"},
               {:punctuation, %{group_id: "group-1"}, "("}
             ]
    end
  end

  describe "keywords" do
    test "all keywords are tokenized as keyword" do
      assert lex("as") == [{:keyword, %{}, "as"}]
      assert lex("assert") == [{:keyword, %{}, "assert"}]
      assert lex("case") == [{:keyword, %{}, "case"}]
      assert lex("const") == [{:keyword, %{}, "const"}]
      assert lex("else") == [{:keyword, %{}, "else"}]
      assert lex("fn") == [{:keyword, %{}, "fn"}]
      assert lex("if") == [{:keyword, %{}, "if"}]
      assert lex("import") == [{:keyword, %{}, "import"}]
      assert lex("let") == [{:keyword, %{}, "let"}]
      assert lex("opaque") == [{:keyword, %{}, "opaque"}]
      assert lex("panic") == [{:keyword, %{}, "panic"}]
      assert lex("pub") == [{:keyword, %{}, "pub"}]
      assert lex("todo") == [{:keyword, %{}, "todo"}]
      assert lex("type") == [{:keyword, %{}, "type"}]
      assert lex("use") == [{:keyword, %{}, "use"}]
    end

    test "keyword prefix is not a keyword" do
      refute {:keyword, %{}, "fn"} in lex("fnx")
      refute {:keyword, %{}, "type"} in lex("types")
      refute {:keyword, %{}, "let"} in lex("letter")
      refute {:keyword, %{}, "let"} in lex("let_x")
    end
  end

  describe "builtin types" do
    test "builtin type names are tokenized as keyword_type" do
      assert lex("Int") == [{:keyword_type, %{}, "Int"}]
      assert lex("Float") == [{:keyword_type, %{}, "Float"}]
      assert lex("Bool") == [{:keyword_type, %{}, "Bool"}]
      assert lex("String") == [{:keyword_type, %{}, "String"}]
      assert lex("List") == [{:keyword_type, %{}, "List"}]
      assert lex("Nil") == [{:keyword_type, %{}, "Nil"}]
      assert lex("Result") == [{:keyword_type, %{}, "Result"}]
      assert lex("BitArray") == [{:keyword_type, %{}, "BitArray"}]
      assert lex("Dynamic") == [{:keyword_type, %{}, "Dynamic"}]
    end

    test "type prefix is not a builtin type" do
      refute {:keyword_type, %{}, "Int"} in lex("Integer")
      refute {:keyword_type, %{}, "String"} in lex("StringBuilder")
    end
  end

  describe "attributes" do
    test "attribute names are tokenized as name_decorator" do
      assert lex("@external") == [{:name_decorator, %{}, "@external"}]
      assert lex("@deprecated") == [{:name_decorator, %{}, "@deprecated"}]
      assert lex("@target") == [{:name_decorator, %{}, "@target"}]
      assert lex("@internal") == [{:name_decorator, %{}, "@internal"}]

      assert lex("@unknown_future_attribute") == [
               {:name_decorator, %{}, "@unknown_future_attribute"}
             ]
    end
  end

  describe "operators" do
    test "arithmetic operators" do
      assert lex("+") == [{:operator, %{}, "+"}]
      assert lex("-") == [{:operator, %{}, "-"}]
      assert lex("*") == [{:operator, %{}, "*"}]
      assert lex("/") == [{:operator, %{}, "/"}]
    end

    test "float arithmetic operators" do
      assert lex("+.") == [{:operator, %{}, "+."}]
      assert lex("-.") == [{:operator, %{}, "-."}]
      assert lex("*.") == [{:operator, %{}, "*."}]
      assert lex("/.") == [{:operator, %{}, "/."}]
    end

    test "comparison operators" do
      assert lex("==") == [{:operator, %{}, "=="}]
      assert lex("!=") == [{:operator, %{}, "!="}]
      assert lex("<") == [{:operator, %{}, "<"}]
      assert lex(">") == [{:operator, %{}, ">"}]
      assert lex("<=") == [{:operator, %{}, "<="}]
      assert lex(">=") == [{:operator, %{}, ">="}]
    end

    test "boolean operators" do
      assert lex("&&") == [{:operator, %{}, "&&"}]
      assert lex("||") == [{:operator, %{}, "||"}]
    end

    test "pipe operator" do
      assert lex("|>") == [{:operator, %{}, "|>"}]
    end

    test "string concatenation operator" do
      assert lex("<>") == [{:operator, %{}, "<>"}]
    end

    test "arrow and bind operators" do
      assert lex("->") == [{:operator, %{}, "->"}]
      assert lex("<-") == [{:operator, %{}, "<-"}]
    end

    test "spread operator" do
      assert lex("..") == [{:operator, %{}, ".."}]
    end

    test "assignment operator" do
      assert lex("=") == [{:operator, %{}, "="}]
    end

    test "longer operators take precedence over shorter ones" do
      # == before =
      assert lex("==") == [{:operator, %{}, "=="}]
      # != not just !
      assert lex("!=") == [{:operator, %{}, "!="}]
      # <= not just <
      assert lex("<=") == [{:operator, %{}, "<="}]
      # >= not just >
      assert lex(">=") == [{:operator, %{}, ">="}]
      # |> not just |
      assert lex("|>") == [{:operator, %{}, "|>"}]
      # -> not just -
      assert lex("->") == [{:operator, %{}, "->"}]
      # <> not just <
      assert lex("<>") == [{:operator, %{}, "<>"}]
      # .. not just .
      assert lex("..") == [{:operator, %{}, ".."}]
    end
  end

  describe "punctuation" do
    test "common punctuation" do
      assert lex(",") == [{:punctuation, %{}, ","}]
      assert lex(":") == [{:punctuation, %{}, ":"}]
      assert lex(".") == [{:punctuation, %{}, "."}]
      assert lex("|") == [{:punctuation, %{}, "|"}]
      assert lex("#") == [{:punctuation, %{}, "#"}]
      assert lex(";") == [{:punctuation, %{}, ";"}]
    end

    test "grouped punctuation" do
      assert lex("()") == [
               {:punctuation, %{group_id: "group-1"}, "("},
               {:punctuation, %{group_id: "group-1"}, ")"}
             ]

      assert lex("[]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]

      assert lex("{}") == [
               {:punctuation, %{group_id: "group-1"}, "{"},
               {:punctuation, %{group_id: "group-1"}, "}"}
             ]
    end
  end

  describe "bit arrays" do
    test "empty bit array" do
      assert lex("<<>>") == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "bit array with content" do
      assert lex(~s/<<1, 2, 3>>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:number_integer, %{}, "1"},
               {:punctuation, %{}, ","},
               {:whitespace, %{}, " "},
               {:number_integer, %{}, "2"},
               {:punctuation, %{}, ","},
               {:whitespace, %{}, " "},
               {:number_integer, %{}, "3"},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "bit array with string" do
      assert lex(~s/<<"hello">>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:string, %{}, ~s/"hello"/},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "<< and >> are not tokenized as < and >" do
      refute {:operator, %{}, "<"} in lex("<<")
      refute {:operator, %{}, ">"} in lex(">>")
    end
  end

  describe "real Gleam code snippets" do
    test "let binding" do
      assert {:keyword, %{}, "let"} in lex("let x = 42")
      assert {:name, %{}, "x"} in lex("let x = 42")
      assert {:operator, %{}, "="} in lex("let x = 42")
      assert {:number_integer, %{}, "42"} in lex("let x = 42")
    end

    test "function definition" do
      tokens = lex("pub fn hello(name: String) -> String {")
      assert {:keyword, %{}, "pub"} in tokens
      assert {:keyword, %{}, "fn"} in tokens
      assert {:name_function, %{}, "hello"} in tokens
      assert {:punctuation, %{}, ":"} in tokens
      assert {:keyword_type, %{}, "String"} in tokens
      assert {:operator, %{}, "->"} in tokens
    end

    test "import statement" do
      assert lex("import gleam/io") == [
               {:keyword, %{}, "import"},
               {:whitespace, %{}, " "},
               {:name, %{}, "gleam/io"}
             ]
    end

    test "case expression" do
      tokens = lex("case x {\n  True -> 1\n  False -> 0\n}")
      assert {:keyword, %{}, "case"} in tokens
      assert {:name_class, %{}, "True"} in tokens
      assert {:name_class, %{}, "False"} in tokens
      assert {:operator, %{}, "->"} in tokens
    end

    test "type definition" do
      tokens = lex("pub type Color {\n  Red\n  Green\n  Blue\n}")
      assert {:keyword, %{}, "pub"} in tokens
      assert {:keyword, %{}, "type"} in tokens
      assert {:name_class, %{}, "Color"} in tokens
      assert {:name_class, %{}, "Red"} in tokens
    end

    test "pipe operator usage" do
      tokens = lex("x |> foo |> bar")
      assert {:name, %{}, "x"} in tokens
      assert {:operator, %{}, "|>"} in tokens
      assert {:name, %{}, "foo"} in tokens
      assert {:name, %{}, "bar"} in tokens
    end

    test "external attribute" do
      tokens = lex(~s/@external(erlang, "erlang", "abs")/)
      assert {:name_decorator, %{}, "@external"} in tokens
      assert {:name, %{}, "erlang"} in tokens
    end

    test "tuple literal" do
      assert lex("#(1, 2)") == [
               {:punctuation, %{}, "#"},
               {:punctuation, %{group_id: "group-1"}, "("},
               {:number_integer, %{}, "1"},
               {:punctuation, %{}, ","},
               {:whitespace, %{}, " "},
               {:number_integer, %{}, "2"},
               {:punctuation, %{group_id: "group-1"}, ")"}
             ]
    end
  end
end
