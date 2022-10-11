---
title: Reducing unnecessary Elixir recompilations
# edit_date:
---

In my Elixir project at work, we've been complaining about slow incremental
compilation. I managed to improve the situation, and here is what I learned.

## Related reading / listening

This topic was already covered in multiple places:
- [Wojtek Mach's 2020 post on the Dashbit blog](https://dashbit.co/blog/speeding-up-re-compilation-of-elixir-projects)
- [Marc-André Lafortune's Thinking Elixir podcast appearance](https://thinkingelixir.com/podcast-episodes/060-compile-faster-with-marc-andre-lafortune/)
- [Tim Gent's recent blog post series](https://medium.com/multiverse-tech/how-to-speed-up-your-elixir-compile-times-part-1-understanding-elixir-compilation-64d44a32ec6e)

My explanations are more verbose and just different. I also provide additional
background on the topic, throw in some _Naive Thoughts & Silly Ideas™️_,
and comment on recent improvements.

## Unnecessary recompilations (?)

Imagine you compiled your Elixir project already. Maybe you're fixing a test,
or you're running a Phoenix server in your development environment. You modified
_just one file_, and want to quickly see the results of your change.
As a result of your change, Elixir is recompiling the file you changed, but you
observe that it's also compiling other, seemingly unrelated files. It may even
happen that some of these files didn't actually need to be recompiled
(in a sense that the resulting `.beam` files are equivalent to the `.beam` files
that were already compiled). Why is that?

## Elixir compilation is powerful

Elixir has very flexible and powerful metaprogramming features.
Elixir has Lisp-style macros - you can easily write and use Elixir code that
generates other Elixir code.

It's not only that, you can actually execute _arbitrary code_ at
compile-time. The `esbuild` package can download the esbuild binary when it's
being compiled. Some packages will automatically run a native-code compiler
(e.g. `clang`) to prepare NIFs. You may choose to download some data from
Wikipedia at compile-time, or connect to some database to read its schema,
and generate modules for your application based on the information you fetched.

Thanks to this metaprogramming power we can enjoy great tooling,
and sometimes even optimize our code through executing some of the logic at
compile-time. And all of that while writing beautiful and succinct Elixir ✨.

## But with great power...

Let's take a second to think about what happens during incremental compilation:
the compiler takes an already compiled program, the modified source code,
and produces updated compilation artifacts (in our case, `.beam` files).
We (programmers), in order to stay sane at our jobs and not go crazy,
would like this process to:
- have the same result as if we compiled this source code from scratch (it's
  related to _reproducibility_ but because we can perform any side effects at
  compile-time, I'd call this _stability_)

AND
- only recompile the files it really need to recompile (which affects
  compilation _speed_)

(Both at the same time!). See, those are the forces at play, and the Elixir
compiler needs to model the compilation process in a way that balances (most
importantly) compilation _stability_, compilation _speed_, and additionally,
 _maintainability_ of its source code. Naturally, some simplifications have to
be made!

If we're writing simple code, and don't go too crazy about running arbitrary
code at compile-time, we usually don't need to worry about any of this
too much. The Elixir compiler tracks module dependencies to make sure the
code we use is compiled, loaded and up-to-date whenever we want to use it - be
it at compile-time, or run-time. And usually, this process is fast enough.

But it can happen that when working in a ~~legacy~~ real-world codebase,
when using macros, running code at compile-time (even as simple as
`Application.compile_env`), or doing something else that introducies **compile
dependencies** between modules (more about them in a second), we can lead the
Elixir compiler into thinking that it needs to recompile some files, even though
we know there is no need to do that. To learn how to avoid such situations, we
first need to understand **why** and **how** Elixir tracks dependencies between
modules.

## A look inside the Elixir compiler

TODO

- general rules: dependencies changed, config changed, mix.exs changed
- note on module vs file tracking, I'll keep using them interchangeably,
  you should avoid declaring multiple modules in one file anyway
- file mtime, hashes/digests
- external dependency, mention possible hashes tracking for them in the future
- compile manifest - runtime, export, compile dependencies

## Runtime dependencies

Let's start with `runtime` dependencies. Those are the most common dependencies
between modules that the Elixir compiler tracks. Module `A` has a `runtime`
dependency on module `B`, when code from module `A` executes code from module
`B` at run-time. This means that only functions (not macros) from module `B`
are called inside functions (or macros) of module `A`.

"This sounds a bit boring, give me an example" - alright! Take this code:
{% capture c %}{% raw %}
defmodule A do
  def a() do
    B.b()
  end
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" %}

All this means is that `A` only needs code from `B` to be in place when the
code from this module runs - at run-time. (In the meaning of "run-time" from
the point of view of module `A` 😉! Some other module may want to run this code
at compile-time, after all.)

With this kind of dependency in place, when module `B` changes in any way,
module `A` doesn't need to recompile.

🤔 "But what about "X.x/1 is undefined or private" warnings (or similar)? Don't
we see those at compile time?" - you may ask. Well, if you change the interfaces
of your modules, you will see these warnings at compile-time, thanks to
additional checks that the Elixir compiler performs. But because of the dynamic
nature of the BEAM, modules that use this changed depedency only at run-time,
don't need to fully recompile, because it wouldn't change how their resulting 
`.beam` file looks like. After all, on the BEAM, you could (re-)load modules at
run-time, so the Elixir compiler can't be sure that the function will be
missing! This is why these are just warnings (not errors), and the dependency is
just a `runtime` depenedency.

When you have more than two modules, you very likely have _transitive runtime
dependencies_ - in simple terms: `runtime` dependencies of your `runtime`
dependencies are also your `runtime` dependencies. This can also lead to
dependency cycles, which are good to avoid, for reasons we'll soon understand!

## Export dependencies

When module `A` uses a struct `%B{}` from another module, or `import`s module
`B` but doesn't use its macros (uses only functions), module `A` has an `export`
dependency on module `B`.

"Example, please!" Sure! Example one:
{% capture c %}{% raw %}
# lib/a.ex
defmodule A do
  def a(%B{}), do: :ok
end

# lib/b.ex
defmodule B do
  defstruct []
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" %}

Example two:
{% capture c %}{% raw %}
# lib/a.ex
defmodule A do
  import B
  def a(), do: b()
end

# lib/b.ex
defmodule B do
  def b(), do: "something"
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" %}

The Elixir compiler will recompile `A`, if the _public interface_ of `B`
changes - that is, if its struct definitions are modified, a public function is
added or removed, or arity of any public function changes.

So, if you only modify private functions in `B`, and/or change the bodies
of functions in `B`, you should be safe, and you will no see unnecessary
recompilations! (At least, not ones directly caused only by this kind of
dependency 😉.) When introducing new functions, make them private if you can!

In general, the [Elixir Getting Started guide](https://elixir-lang.org/getting-started/alias-require-and-import.html#import)
(the one with its list of contents / menu confusingly placed on the right,
but I digress...) says `import`s are discouraged in the language.
I know this is because they make code harder to follow, but I wonder
(_Naive Thoughts & Silly Ideas №1_): in order to reduce unnecessary
recompilations, should we stop putting _any_ public functions or macros in
modules that define structs? If we have a separate module with just the
responsibility of defining a struct, and keep functionality related to this
struct in other modules, then changing the public interface of those functions
(which I think is more common than changing a struct) wouldn't recompile all
modules that only use this struct! Alternatively, maybe there could be a way to
have separate tracking for `export` and `struct` types of dependencies inside
the Elixir compiler?

_Naive Thoughts & Silly Ideas №2:_
If the Elixir compiler already knows when to warn about "undefined or private"
functions when module interfaces change, without invoking full compilation
of a module with `runtime` dependency, why is a full recompilation needed when
I only add to (and not remove from) `B`'s public functions interface, and the
addition doesn't conflict with any of `A`'s local functions? I don't know!
Maybe the Elixir compiler would need to keep track of much more information
to do this? All I know is this is how the Elixir compiler currently models this
kind of dependencies, and there are probably good reasons for that.

Note: because when you use a struct or `import` another module, this module's
interface doesn't affect your current module's interface, so there's no such
thing as _transitive export dependencies_. I think it's also worth noting that
`export` dependencies are also `runtime` dependencies, so they contribute to
building the dependency graph (and cycles) of modules in your project, just like
`runtime` dependencies do.

## Compile dependencies

Module `A` has a `compile` dependency on module `B`, when compiling module `A`
could cause code from module `B` to be executed (at compile-time).

Examples!

- `require B` or `import B` combined with using macros from `B`

  You can think of macros as functions that return code. So when you use a macro
  from module `B`, you're executing code from module `B` at compile-time
  to generate new code, which will be then compiled. 🤯

- `use B`

  After all, this will just require `B` and execute the `B.__using__/1` macro.
  So you're executing code from `B.__using__/1` at compile-time.

- `B.fun()` directly in module body or in a module attribute (`@attr B.fun()`)

  When Elixir compiles a module, it will execute all the code that is not inside
  its functions (at compile-time).

Module `A` needs to be recompiled when module `B` changed. You may think that
this shouldn't be a big problem: even if you write a macro, or depend on some
module at compile-time in a different way, you rarely need to change the module
you depend on, right? But those were only examples of *direct* compile
dependencies. Girl, let me tell you about how _transitive compile dependencies_
happen.

If module `A` has a `compile` dependency on module `B`, then it means that it
has a _transitive compile dependency_ on **all of its dependencies**. Both
`compile` and `runtime`. Both direct or transitive. Need an example? Here you
go:

{% capture c %}{% raw %}
# lib/a.ex
defmodule A do
  @b B.b()
  def a(), do: @b
end

# lib/b.ex
defmodule B do
  def b(), do: C.c()
  def b2(), do: D.d()
end

# lib/c.ex
defmodule C do
  def c(), do: "c"
  def c2(), do: E.e()
end

# lib/d.ex
defmodule D do
  def d(), do: "d"
end

# lib/e.ex
defmodule E do
  def e(), do: "e"
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" %}

If you modify module `B`, both `B` and `A` have to recompile. If you modify
module `C`, both `C` and `A` have to recompile! This seems bad, but so far, so
good, we can trace the function calls from `@b` through `B.b()` to `C.c()`, so
it kind of makes sanse - maybe the resulting `.beam` file could change.

Now, If you modify module `D`, both `D` and `A` also have to recompile. And the
same happens with `E`! `A` needs to recompile, even though neither `D` nor `E`
are not present when tracing function calls that were used to compute module
attribute `@a`.

This is what I initially missed when reading about this topic. `compile`
dependencies themselves are not that bad, and usually don't cause unnecessary
recompilations. Things can go bad when a `compile` dependency has its own, other
dependencies from the same project.

_Naive Thoughts & Silly Ideas №2:_
Maybe instead of assuming that all dependencies of `B` become `A`'s `compile`
dependency, we could keep track of which modules actually took part in `A`'s
compilation, and only consider those to be `compile` dependencies? Maybe!
But honestly, this sounds risky - with all the metaprogramming features Elixir
has, there may be a hole in this logic, and a counterexample that makes this
idea look bad. Another thought: would it be viable to track `compile`
dependencies with a higher, per function/macro granularity? Also probably not,
it soulds like a lot of data to keep track of!

## In practice

TODO

- how dependencies looks in a typical Phoenix project
- clarification: controller doesn't depend on its view module (!)
- cycles caused by Phoenix router
- spaghetti allo elisir: life happens
- silly idea: generate a routes module using a task / separate :phoenix compiler
  instead
- how the compiler figures out what it needs to recompile based on a list of
  "stale" modules being compiled
- silly idea: track hashes/digests of .beam files, and instead of recompiling
  when a direct compile dependency is stale, check all compile dependencies
  and recompile if any of them are stale AND changed on disk 

## How to find transitive compile dependencies

TODO

- explain xref
- `mix xref graph --label compile-connected`
- `mix xref graph --label compile-connected --fail-above 0`

## Tips on how to remove transitive compile dependencies

TODO

## Recent improvements

Elixir 1.14.1
- https://github.com/elixir-lang/elixir/commit/f3aef6b0606454ed78b173f3436650b06e981f7e#diff-e490c25a76a5cc37928b87a55ee5e43aae262c90eb1d460109cfa268ed41167cR165
- https://github.com/elixir-lang/elixir/pull/12181/files#diff-e490c25a76a5cc37928b87a55ee5e43aae262c90eb1d460109cfa268ed41167cR233

Elixir 1.15
- https://github.com/elixir-lang/elixir/pull/12103
