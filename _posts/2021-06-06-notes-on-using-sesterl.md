---
title: Notes on using Sesterl
hidden: false
edit_date: 2021-06-11
---
[Sesterl](https://github.com/gfngfn/Sesterl) is a new statically typed programming language for the BEAM (the Erlang virtual machine).

## Installation

To install Sesterl, we can download a release artifact for latest Ubuntu or MacOS from [Github Actions on the Sesterl Repository](https://github.com/gfngfn/Sesterl/actions?query=branch%3Amaster) (when logged in to GitHub, click the top entry on that list, and then on the artifact name, e.g. `sesterl-ubuntu-latest`).

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

On other systems sesterl has to be [compiled from source](https://github.com/gfngfn/Sesterl#how-to-install).

## "Hello World" with rebar3

Sesterl can generate a [rebar3](https://github.com/erlang/rebar3) config file for a project from a `package.yaml` file (note: this file might be soon renamed to `sesterl.yaml`).

{% capture _code %}{% highlight yaml linenos %}{% raw %}
# REQUIRED CONFIG

# Package name is used to derive a prefix for resulting Erlang modules,
# e.g. this will cause all modules to be prefixed with "HelloSesterl."
package: "hello_sesterl"

# Main module is the only interface to a package from outside world.
# It has to exist and can't be imported by modules in that package.
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
{% endraw %}{% endhighlight %}<figcaption>package.yaml</figcaption>{% endcapture %}{% include code_block.html code=_code use_figure=true %}

To generate a `rebar3` config from the above file, we can run:
```
$ sesterl config .
  output written on '/home/michal/hello_sesterl/./rebar.config'.
```
{: .terminal}

A rebar3 project also needs an `*.app.src` file in the `src/` directory:

{% capture _code %}{% highlight erlang linenos %}{% raw %}
{application, hello_sesterl,
 [{description, "An OTP library"},
  {vsn, "0.1.0"},
  {applications,
   [kernel,
    stdlib
   ]}
 ]}.
{% endraw %}{% endhighlight %}<figcaption>src/hello_sesterl.app.src</figcaption>{% endcapture %}{% include code_block.html code=_code %} use_figure=true %}


Sesterl source files have a `.sest` file extension. The syntax is similar to Standard ML or OCaml.

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct

  val my_hello() =
    print_debug("Hello, world!")

end
{% endraw %}{% endhighlight %}<figcaption>src/some_file.sest</figcaption>{% endcapture %}{% include code_block.html code=_code %} use_figure=true %}

To compile a project, we can run:

{% raw %}
<div class="terminal"><pre><code>$ rebar3 do sesterl compile, compile
<span style="color:lime;">===&gt; Fetching rebar_sesterl (from {git,&quot;https://github.com/gfngfn/rebar_sesterl_plugin.git&quot;,
                         {branch,&quot;master&quot;}})
</span><span style="color:lime;">===&gt; Analyzing applications...
</span><span style="color:lime;">===&gt; Compiling rebar_sesterl
</span><span style="color:lime;">===&gt; Verifying dependencies...
</span><span style="color:lime;">===&gt; Compiling Sesterl programs (command: &quot;sesterl build ./ -o _generated&quot;) ...
</span>  parsing '/home/michal/projects/huh/src/some_file.sest' ...
  type checking '/home/michal/projects/huh/src/some_file.sest' ...
  output written on '/home/michal/projects/huh/./_generated/HelloSesterl.Hello.erl'.
  output written on '/home/michal/projects/huh/./_generated/sesterl_internal_prim.erl'.
<span style="color:lime;">===&gt; Analyzing applications...
</span><span style="color:lime;">===&gt; Compiling hello_sesterl
</span>_generated/sesterl_internal_prim.erl:8:14: Warning: variable 'Arity' is unused

<span style="color:lime;">===&gt; Verifying dependencies...
</span><span style="color:lime;">===&gt; Analyzing applications...
</span><span style="color:lime;">===&gt; Compiling hello_sesterl
</span>_generated/sesterl_internal_prim.erl:8:14: Warning: variable 'Arity' is unused
</code></pre></div>
{% endraw %}

And to execute code from the above module from the Erlang shell:

{% raw %}
<div class="terminal"><pre><code>$ rebar3 shell
<span style="color:lime;">===&gt; Verifying dependencies...
</span><span style="color:lime;">===&gt; Analyzing applications...
</span><span style="color:lime;">===&gt; Compiling hello_sesterl
</span>Erlang/OTP 24 [erts-12.0.2] [source] [64-bit] [smp:6:6] [ds:6:6:10] [async-threads:1] [jit]

Eshell V12.0.2  (abort with ^G)
1&gt; 'HelloSesterl.Hello':my_hello().
&lt;&lt;&quot;Hello, world!&quot;&gt;&gt;
ok
</code></pre></div>
{% endraw %}

Yay!

## Separate types without tags

Something similar to "newtypes" or phantom types (?) - separate, incompatible types that have the same run-time representation (without boxing or tagging) - can be achieved with the Sesterl's type system (just like [OCaml's](https://dev.realworldocaml.org/files-modules-and-programs.html#nested-modules)):

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct

  module Username :> sig
    type t :: o
    val from_binary : fun(binary) -> t
  end = struct
    type t = binary
    val from_binary(x) = x
  end

  module Hostname :> sig
    type t :: o
    val from_binary : fun(binary) -> t
  end = struct
    type t = binary
    val from_binary(x) = x
  end

  val do_something_with_username(x : Username.t) = x

  val main() =
    let a = Hostname.from_binary("example.com") in
    do_something_with_username(a)

end
/*(*
! [Type error] file 'some_file.sest', line 23, characters 31-32:
  this expression has type
    Hello.Hostname.t
  but is expected of type
    Hello.Username.t
*)*/
{% endraw %}{% endhighlight %}{% endcapture %}{% include code_block.html code=_code %}

Or if we want to reuse the interface signature and implementation:

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct

  signature ID = sig
    type t :: o
    val from_binary : fun(binary) -> t
  end

  module BinaryID = struct
    type t = binary
    val from_binary(x) = x
  end

  module Username :> ID = BinaryID
  module Hostname :> ID = BinaryID

  val do_something_with_username(x : Username.t) = x

  val main() =
    let a = Hostname.from_binary("example.com") in
    do_something_with_username(a)

end
/*(*
! [Type error] file 'some_file.sest', line 22, characters 31-32:
  this expression has type
    Hello.Hostname.t
  but is expected of type
    Hello.Username.t
*)*/
{% endraw %}{% endhighlight %}{% endcapture %}{% include code_block.html code=_code %}

The below example doesn't work (doesn't throw an error), because Sesterl ignores the unused parameter from the type and assumes they are the same thing:

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct

  type id<$a> = binary

  type hostname =
    | Hostname
  
  type username =
    | Username

  val do_something_with_username(x : id<username>) = x

  val hostname_from_binary(x : binary) : id<hostname> = x

  val main() =
    let a = hostname_from_binary("example.com") in
    do_something_with_username(a)

end
/*(* No error even though we'd like to see one here! *)*/
{% endraw %}{% endhighlight %}{% endcapture %}{% include code_block.html code=_code %}

## Sesterl standard library

Sesterl [standard library](https://github.com/gfngfn/sesterl_stdlib) is just a rebar3 package, that can be added as a git dependency to the configuration yaml file:

{% capture _code %}{% highlight yaml linenos %}{% raw %}
dependencies:
  - name: "sesterl_stdlib"
    source:
      type: "git"
      repository: "https://github.com/gfngfn/sesterl_stdlib"
      spec:
        type: "branch"
        value: "master"
{% endraw %}{% endhighlight %}{% endcapture %}{% include code_block.html code=_code %}

Rebar3 config needs to be regenerated with `sesterl config .`, and on next compilation we'll be able to refer to modules from the stdlib (but only through what is defined in its main Stdlib module):

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct
  val my_hello() =
    let list = Stdlib.Binary.to_list("Hello, world!") in
    print_debug(list)
end
{% endraw %}{% endhighlight %}{% endcapture %}{% include code_block.html code=_code %}

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct
  module Binary = Stdlib.Binary

  val my_hello() =
    let list = Binary.to_list("Hello, world!") in
    print_debug(list)

end
{% endraw %}{% endhighlight %}{% endcapture %}{% include code_block.html code=_code %}

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct
  open Stdlib.Binary

  val my_hello() =
    let list = to_list("Hello, world!") in
    print_debug(list)

end
{% endraw %}{% endhighlight %}{% endcapture %}{% include code_block.html code=_code %}

## Bonus: "Hello World" without rebar3

{% capture _code %}{% highlight sml linenos %}{% raw %}
module Hello = struct

  val print_string : fun(binary) -> unit = external 1 ```
    print_string(S) ->
      io:format("~ts~n", [S]).
  ```

  val main(args) =
    print_string("Hello, world!")

end
{% endraw %}{% endhighlight %}<figcaption>without_rebar.sest</figcaption>{% endcapture %}{% include code_block.html code=_code use_figure=true %}

When compiling the above example with `sesterl`, we get two Erlang source files as a result:

```
$ sesterl build without_rebar3.sest -o _generated
  parsing '/home/michal/hello_sesterl/without_rebar3.sest' ...
  type checking '/home/michal/hello_sesterl/without_rebar3.sest' ...
  output written on '/home/michal/hello_sesterl/_generated/Hello.erl'.
  output written on '/home/michal/hello_sesterl/_generated/sesterl_internal_prim.erl'.
$ ls _generated
Hello.erl  sesterl_internal_prim.erl
```
{: .terminal}

The `Hello.erl` file contains the `'Hello'` erlang module, and `sesterl_internal_prim.erl` ("prim" as in "primitives") contains a module with a few functions to provide some of basic functionality of the language (e.g. Erlang's [send](http://erlang.org/doc/reference_manual/expressions.html#send) wrapped in a function). This module will not be available in our escript program unless we add code to load it.

To make the escript executable we have to add one dummy line to the beginning of the erlang source file, and then we can run it with `escript -c` (the `-c` argument tells escript to compile the module first):

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
