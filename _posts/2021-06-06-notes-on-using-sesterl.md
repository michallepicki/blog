---
title: Notes on using Sesterl
hidden: false
edit_date: 2021-06-06
---
[Sesterl](https://github.com/gfngfn/Sesterl) is a new statically typed programming language for the BEAM (the Erlang virtual machine).

## Installation

To install Sesterl, currently you can download a release artifact for latest Ubuntu or MacOS from [Github Actions on the Sesterl Repository](https://github.com/gfngfn/Sesterl/actions?query=branch%3Amaster).

```
$ unzip sesterl-ubuntu-latest.zip
Archive:  sesterl-ubuntu-latest.zip
  inflating: sesterl
$ chmod +x sesterl
$ mv sesterl ~/.local/bin/
$ which sesterl
/home/michal/.local/bin/sesterl
```
{: .terminal}

## "Hello World" with rebar3

Sesterl can generate a [rebar3](https://github.com/erlang/rebar3) config file for your project from a simple `package.yaml` file (note: this file might be soon renamed to `sesterl.yaml`).

<figure markdown="1">
```yaml
# REQUIRED CONFIG

# Package name is used to derive a prefix for resulting Erlang modules,
# e.g. this will cause all modules to be prefixed with
# "TryingSesterl."
package: "trying_sesterl"

# Main module is the only interface to a package from outside
# world. It has to exist and can't be imported by other modules
# in that package.
main_module: "Hello"

source_directories:
  - "src"

# OPTIONAL CONFIG (defaults commented out)

# test_directories: []

# dependencies: []

# test_dependencies: []

# erlang:
#   output_directory: "_generated"
#   test_output_directory: "_generated_test"
```
<figcaption>package.yaml</figcaption>
</figure>

To generate a `rebar3` config from the above file, run:
```
$ sesterl config .
  output written on '/home/michal/trying_sesterl/./rebar.config'.
```
{: .terminal}

Our project also needs an `*.app.src` file in the src directory (run `mkdir src` first):

<figure markdown="1">
```
{application, trying_sesterl,
 [{description, "An OTP library"},
  {vsn, "0.1.0"},
  {applications,
   [kernel,
    stdlib
   ]}
 ]}.
```
<figcaption>src/trying_sesterl.app.src</figcaption>
</figure>

And obvoiusly, it also needs our main module code. Sesterl source files have a `.sest` file extension. The syntax is similar to Standard ML or OCaml.

<figure markdown="1">
```sml
module Hello = struct

  val my_hello() =
    print_debug("Hello, world!")

end
```
<figcaption>src/some_file.sest</figcaption>
</figure>

To compile our "Hello World" program, we can run:

```
$ rebar3 do sesterl compile, compile
===> Fetching rebar_sesterl (from {git,"https://github.com/gfngfn/rebar_sesterl_plugin.git",
                         {branch,"master"}})
===> Analyzing applications...
===> Compiling rebar_sesterl
===> Verifying dependencies...
===> Compiling Sesterl programs (command: "sesterl build ./ -o _generated") ...
  parsing '/home/michal/trying_sesterl/src/some_file.sest' ...
  type checking '/home/michal/trying_sesterl/src/some_file.sest' ...
  output written on '/home/michal/trying_sesterl/./_generated/TryingSesterl.Hello.erl'.
  output written on '/home/michal/trying_sesterl/./_generated/sesterl_internal_prim.erl'.
===> Analyzing applications...
===> Compiling trying_sesterl
_generated/sesterl_internal_prim.erl:8:14: Warning: variable 'Arity' is unused

===> Verifying dependencies...
===> Analyzing applications...
===> Compiling trying_sesterl
_generated/sesterl_internal_prim.erl:8:14: Warning: variable 'Arity' is unused
```
{: .terminal}

And to execute our function from Erlang shell:

```
$ rebar3 shell
===> Verifying dependencies...
===> Analyzing applications...
===> Compiling trying_sesterl
Erlang/OTP 24 [erts-12.0.2] [source] [64-bit] [smp:6:6] [ds:6:6:10] [async-threads:1] [jit]

Eshell V12.0.2  (abort with ^G)
1> 'TryingSesterl.Hello':'my_hello'().
<<"Hello, world!">>
ok
2>
```
{: .terminal}

Yay!

## "Hello World" with escript and FFI

<figure markdown="1">
````sml
module Hello = struct

  val print_string : fun(binary) -> unit = external 1 ```
    print_string(S) ->
      io:format("~ts~n", [S]).
  ```

  val main(args) =
    print_string("Hello, world!")

end
````
<figcaption>some_file.sest</figcaption>
</figure>

When compiling the above example with `sesterl`, we get two Erlang source files as a result:

```
$ sesterl build some_file.sest -o _generated
  parsing '/home/michal/trying_sesterl/some_file.sest' ...
  type checking '/home/michal/trying_sesterl/some_file.sest' ...
  output written on '/home/michal/trying_sesterl/_generated/Hello.erl'.
  output written on '/home/michal/trying_sesterl/_generated/sesterl_internal_prim.erl'.
$ ls _generated
Hello.erl  sesterl_internal_prim.erl
```
{: .terminal}

The `Hello.erl` file contains the `'Hello'` erlang module, and `sesterl_internal_prim.erl` ("prim" as in "primitives") contains a module with a few functions to provide some of basic functionality of the language (e.g. Erlang's [send](http://erlang.org/doc/reference_manual/expressions.html#send) wrapped in a function). These will not be available in our escript program unless we add code to load it.

To make our Hello World executable we have to add one dummy line to the beginning of the erlang source file, and then we can run it with `escript -c` (the `-c` argument tells escript to compile the module first):

```
$ (echo "% additional line for escript to work" && cat _generated/Hello.erl) > tmpfile && mv tmpfile _generated/Hello.erl
$ escript -c _generated/Hello.erl
_generated/Hello.erl:7:8: Warning: variable 'S11Args' is unused
%    7|   
%     |   ^^^^^^

Hello, world!
```
{: .terminal}

Hurray!
