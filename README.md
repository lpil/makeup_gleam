# MakeupGleam

[![CI](https://github.com/lpil/makeup_gleam/actions/workflows/ci.yml/badge.svg)](https://github.com/lpil/makeup_gleam/actions/workflows/ci.yml)
[![Module Version](https://img.shields.io/hexpm/v/makeup_gleam.svg)](https://hex.pm/packages/makeup_gleam)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/makeup_gleam)

A [Makeup](https://github.com/elixir-makeup/makeup/) lexer for the `Gleam` language.

## Installation

Add `makeup_gleam` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:makeup_gleam, ">= 1.0.0 and < 2.0.0"}
  ]
end
```

The lexer will automatically register itself with `Makeup` for the language `gleam`
as well as the extension `.gleam`.

## History

This package was based off of the [MakeupElixir](https://github.com/elixir-makeup/makeup_erlang)
package, thank you to the original contributors:

- Ang
- José Valim
- Josh Price
- Kian-Meng Ang
- Lukas Backström
- Lukas Larsson
- Marcos Ferreira
- sir fish
- tmbb
- Wojtek Mach

LLM assistance was used in the creation of this package.
