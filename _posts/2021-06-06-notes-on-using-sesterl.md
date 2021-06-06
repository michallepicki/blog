---
title: Notes on using Sesterl
hidden: true
edit_date: 2021-06-06
---
[Sesterl](https://github.com/gfngfn/Sesterl) is a new statically typed programming language for the BEAM (Erlang virtual machine).

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

## Sesterl "Hello World" with escript and FFI

Sesterl source files have a `.sest` file extension. The syntax is similar to Standard ML or OCaml.

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

The `Hello.erl` file contains the `'Hello'` erlang module, and `sesterl_internal_prim.erl` ("prim" as in "primitives") contains a module with a few functions to provide some of basic functionality of the language (e.g. Erlang send as a function). This will not be available in our escript program unless we add code to load it.

To make our Hello World executable we have to add one dummy line to the beginning of the file, and then we can run it with `escript -c` (the `-c` argument tells escript to compile the module first):

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
