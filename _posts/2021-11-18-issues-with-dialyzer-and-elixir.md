---
title: Issues with Dialyzer and Elixir
hidden: true
# edit_date:
---

new user starts learning Elixir,
user wants to solve some Advent of Code puzzles,
people recommend elixir ls...

their computer starts shutting down every time he opens VSCode,
( https://elixirforum.com/t/laptop-turning-off-due-to-elixir-ls/43342 ),

user finally affords to fix or get a better computer,
user sees there are some types that are checked,
Dialyzer points out issue caused by wrong spec in other module,
but issue is reported at call site so user tries to find mistakes there
(sometimes dialyzer will use the spec instead of inferred type)

user figures out that the issue is not where it's reported,
user fixes the spec but issue persists
(module with issue was not recompiled, so stale issue is still shown),

user added a single newline that fixed things,
some refactoring, user introduces a bug in code,
user thinks adding specs will help narrow down issue,
their specs are ignored this time and dialyzer issues are still confusing
(often Dialyzer ignores the provided spec and uses inferred type)

user made some mistakes in code passing mistyped atom literal,
wild no local return issues show up in all 20 functions upper in call tree without additional info,
(user is on current Elixir 1.12 and current OTP 24, https://github.com/elixir-lang/elixir/issues/11107 )
(and no local return issues propagate up)

user downgraded Erlang,
the editor starts crashing over and over again
user removes project not thinking things through and starts over losing work
(only .elixir_ls directory had to be removed but user didnt know)

user sees all issues now,
user also tried encapsulating data for AoC task with some opaque types,
opaque value created in kosher way but at compile time lands in module attribute,
Dialyzer complains for good code
(dialyzer analyzes beam files and arrtibute was inlined as literal value)
