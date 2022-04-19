---
title: Format HEEx files quickly on CI
---

Phoenix LiveView 0.17.8 provides a [HTMLFormatter](https://hexdocs.pm/phoenix_live_view/0.17.8/Phoenix.LiveView.HTMLFormatter.html)
plugin to `mix format` your Phoenix templates and LiveView `~H` snippets.
Because the plugin module comes from a Hex dependency,
Mix requires it to be compiled to do its magic.
As per [Mix module plugins documentation](https://hexdocs.pm/mix/1.13.4/Mix.Tasks.Format.html#module-plugins):

> Remember that, when running the formatter with plugins, you must make sure that your dependencies and your application have been compiled, so the relevant plugin code can be loaded. Otherwise a warning is logged.

And indeed, that's what happens
when `mix format` runs immediately after checking out the repository:

{% raw %}<div><pre><code class="terminal">$ mix format
<font color="#CC0000"><b>Skipping formatter plugin Phoenix.LiveView.HTMLFormatter because module cannot be found </b></font>
</code></pre></div>{% endraw %}

I think it's understandable, but also a bit unfortunate,
because I like to get immediate feedback from CI
when I forget to format my files.
Compiling the whole project from scratch could take a few minutes!

Thankfully, I discovered that `mix compile` is not strictly necessary
for the plugin to be available. At least currently,
only the `phoenix_live_view` dependency needs to be compiled.

`mix deps.compile` works but I felt it was also a bit too slow for me.
`mix deps.compile phoenix_live_view` doesn't work because some of its dependencies are not compiled yet:

{% raw %}<div><pre><code class="terminal">$ mix deps.compile phoenix_live_view
==&gt; phoenix_live_view
Compiling 31 files (.ex)
<font color="#C4A000">warning: </font>@behaviour Phoenix.Template.Engine does not exist (in module Phoenix.LiveView.HTMLEngine)
  lib/phoenix_live_view/html_engine.ex:1: Phoenix.LiveView.HTMLEngine (module)


== Compilation error in file lib/phoenix_live_view/js.ex ==
** (ArgumentError) could not load module Phoenix.HTML.Safe due to reason :unavailable
    (elixir 1.14.0-dev) lib/protocol.ex:323: Protocol.assert_protocol!/2
    lib/phoenix_live_view/js.ex:120: (module)
<font color="#CC0000"><b>could not compile dependency :phoenix_live_view, &quot;mix compile&quot; failed. Errors may have been logged above. You can recompile this dependency with &quot;mix deps.compile phoenix_live_view&quot;, update it with &quot;mix deps.update phoenix_live_view&quot; or clean it with &quot;mix deps.clean phoenix_live_view&quot;</b></font>
</code></pre></div>{% endraw %}

## Solution

Through trial and error I found this minimal set of packages
to compile that works for me:

```
mix deps.compile phoenix_pubsub plug phoenix_html phoenix phoenix_live_view
```

This takes only a few seconds, and allows `mix format` (or `mix format --check-formatted`) to run, including the HEEx formatter plugin. I can have my cake and eat it too!
