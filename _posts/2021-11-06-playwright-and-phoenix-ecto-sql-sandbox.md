---
title: Playwright and Phoenix.Ecto.SQL.Sandbox
hidden: false
# edit_date:
---

[Playwright](https://github.com/microsoft/playwright) is a library for browser automation from Microsoft. There's an unofficial [playwright-elixir](https://github.com/geometerio/playwright-elixir) library for using it from Elixir. You can think of it as an alternative to [Wallaby](https://github.com/elixir-wallaby/wallaby) or [Hound](https://github.com/HashNuke/hound), but using different technology underneath. Let's make it work with [Phoenix Ecto sandbox](https://hexdocs.pm/phoenix_ecto/Phoenix.Ecto.SQL.Sandbox.html)!

## Setup

We'll be using a new, freshly generated Phoenix `1.6.2` app, and Playwright `1.16`. After generating a new project with `mix phx.new hello` and using `mix phx.gen.auth` (to have some database data to show, in this case a listing of users), let's install Playwright (requires `node` and `npm`). This also downloads the browsers compatible with this version of Playwright, and `ffmpeg` (for video recording):

{% raw %}
<div><pre><code class="terminal">$ cd assets/ &amp;&amp; npm i --save-dev playwright@1.16 &amp;&amp; cd -

&gt; playwright@1.16.3 install /home/michal/projects/hello/assets/node_modules/playwright
&gt; node install.js

Downloading Playwright build of chromium v930007 - 127.5 Mb
Downloading Playwright build of ffmpeg v1006 - 2.6 Mb
Downloading Playwright build of firefox v1297 - 72.1 Mb
Downloading Playwright build of webkit v1564 - 79.3 Mb

+ playwright@1.16.3
added 46 packages from 85 contributors and audited 46 packages in 34.17s
</code></pre></div>
{% endraw %}

And add `playwright-elixir` to our dependencies:

{% capture c %}{% raw %}
  def deps do
    ...
      {:playwright, "~> 0.1.16-preview-1", only: :test}
    ]
  end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=false figure=true figcaption="mix.exs"%}

We can add a listing of all users to the index page:

{% capture c %}{% raw %}
<section id="users" class="row">
  <article class="column">
    <h2>Users</h2>
    <ul>
      <%= for user <- Hello.Repo.all(Hello.Accounts.User) do %>
        <li>
          <%= user.email %> created at <%= inspect(user.inserted_at) %>
        </li>
      <% end %>
    </ul>
  </article>
</section>
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="html" numbered=true figure=true figcaption="lib/hello_web/templates/page/index.html.heex"%}

We can add an example test:

{% capture c %}{% raw %}
defmodule HelloWeb.Integration.ATest do
  use Hello.DataCase, async: false
  use PlaywrightTest.Case, headless: false

  test "navigating to our app", %{page: page} do
    text =
      page
      |> Playwright.Page.goto("http://localhost:4002")
      |> Playwright.Page.text_content("#users h2")

    assert text == "Users"
  end
end

{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=true figure=true figcaption="test/hello_web/integration/a_test.exs"%}

To access the server in tests we need to change the Endpoint config in `config/test.exs` to say `server: true`. Then, the test should pass, and we'll see a browser quickly flashing (thanks to the `headless: false` option we passed in):

{% capture c %}{% raw %}
$ mix test test/hello_web/integration/
.

Finished in 1.7 seconds (1.7s async, 0.00s sync)
1 test, 0 failures
{% endraw %}{% endcapture %}{% include code_block.html code=c class="terminal" %}

## Testing registration

Let's write a test that registers a user, waits a few seconds, refreshes the page and confirms there is only one user registered. This is just to see that sandboxing works as intended.

{% capture c %}{% raw %}
test "registering a user", %{page: page} do
  email = Hello.AccountsFixtures.unique_user_email()
  password = Hello.AccountsFixtures.valid_user_password())

  page
  |> Playwright.Page.goto("http://localhost:4002/users/register")
  |> Playwright.Page.fill("#user_email", email)
  |> Playwright.Page.fill("#user_password", password)
  |> Playwright.Page.click("button[type='submit']")

  :timer.sleep(3000)
  Playwright.Page.goto(page, "http://localhost:4002")

  :timer.sleep(5000)

  users = page |> Playwright.Page.query_selector_all("#users li")

  assert Enum.count(users) == 1
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" %}

Let's save that test in `test/hello_web/integration/a_test.exs`, but also create a second test file at `test/hello_web/integration/b_test.exs`, copy the registration test there, and mark both of them as `async:true`, so that they can execute in parallel.

{% capture c %}{% raw %}
defmodule HelloWeb.Integration.BTest do
  use Hello.DataCase, async: true
  use PlaywrightTest.Case, headless: false
  ...
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" %}

When two such tests execute at the same time, we want the assertion to pass, and we want to see two browser windows with a different list of users each. But currently that's not what's happening:

{% raw %}
<div><pre><code class="terminal">$ mix test test/hello_web/integration/
<span style="color:red;">14:46:54.855 [error] #PID&lt;0.631.0&gt; running HelloWeb.Endpoint (connection #PID&lt;0.625.0&gt;, stream id 3) terminated
Server: localhost:4002 (http)
Request: POST /users/register
** (exit) an exception was raised:
    ** (DBConnection.OwnershipError) cannot find ownership process for #PID&lt;0.631.0&gt;.</span>
...
Finished in 9.2 seconds (9.2s async, 0.00s sync)
<span style="color:red;">2 tests, 2 failures</span>
</code></pre></div>
{% endraw %}

Let's fix that!

## Phoenix Ecto Sandbox configuration

Phoenix needs some information to identify the test that browser requests originate from. We need to make sure that Playwright passes that information. This is usually done in the `user-agent` header, but we'll use a separate `x-phoenix-ecto-sandbox` header.

Let's create our own `Hello.PlaywrightCase` module. We can copy and modify the [`PlaywrightTest.Case`](https://github.com/geometerio/playwright-elixir/blob/4eeea1c126090173d5316331d86bec9995edecdf/lib/playwright_test/case.ex) module that `playwright-elixir` provides. Please have in mind that the `playwright-elixir` libary is still in early stages of development, so this will look cleaner in the future (what you see below is mostly a copy-pasta of library code with a few changes):

{% capture c %}{% raw %}
defmodule Hello.PlaywrightCase do
  use ExUnit.CaseTemplate

  defmacro __using__(options \\ %{}) do
    case_using = super(options)

    quote do
      unquote(case_using)
      alias Playwright.Runner.Config

      setup_all do
        inline_options = unquote(options) |> Enum.into(%{})
        launch_options = Map.merge(Config.launch_options(), inline_options)
        runner_options = Map.merge(Config.playwright_test(), inline_options)

        Application.put_env(:playwright, LaunchOptions, launch_options)

        {:ok, _} = Application.ensure_all_started(:playwright)

        case runner_options.transport do
          :driver ->
            {connection, browser} = Playwright.BrowserType.launch()

            [
              connection: connection,
              browser: browser,
              transport: :driver
            ]

          :websocket ->
            options = Config.connect_options()
            {connection, browser} = Playwright.BrowserType.connect(options.ws_endpoint)

            [
              connection: connection,
              browser: browser,
              transport: :websocket
            ]
        end
      end

      setup ctx do
        pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Hello.Repo, shared: not ctx[:async])
        metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Hello.Repo, pid)
        context = Hello.PlaywrightCase.new_context(ctx[:browser], metadata)
        page = Hello.PlaywrightCase.new_page(context)

        on_exit(:ok, fn ->
          Playwright.Page.close(page)
          Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
        end)

        [page: page]
      end
    end
  end

  # Copied and modified from Playwright.Browser.new_context
  def new_context(%Playwright.Browser{connection: connection} = subject, metadata) do
    sandbox_header = Phoenix.Ecto.SQL.Sandbox.encode_metadata(metadata)

    context =
      Playwright.Runner.Channel.send(subject, "newContext", %{
        noDefaultViewport: false,
        sdkLanguage: "elixir",
        extraHTTPHeaders: [%{name: "x-phoenix-ecto-sandbox", value: sandbox_header}]
      })

    case context do
      %Playwright.BrowserContext{} ->
        Playwright.Runner.Channel.patch(connection, context.guid, %{browser: subject})

      _other ->
        raise(
          "expected new_context to return a  Playwright.BrowserContext, received: #{inspect(context)}"
        )
    end
  end

  # Copied and modified from Playwright.Browser.new_page
  def new_page(%{connection: connection} = context) do
    page = Playwright.BrowserContext.new_page(context)

    Playwright.Runner.Channel.patch(connection, context.guid, %{owner_page: page})

    case page do
      %Playwright.Page{} ->
        Playwright.Runner.Channel.patch(connection, page.guid, %{owned_context: context})

      _other ->
        raise("expected new_page to return a  Playwright.Page, received: #{inspect(page)}")
    end
  end
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=true figure=true figcaption="test/support/playwright_case.exs"%}

Having that set up, we can modify our tests to use our `Case` module:

{% capture c %}{% raw %}
defmodule HelloWeb.Integration.ATest do
  use Hello.PlaywrightCase, async: true, headless: false
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir"%}

We add appropriate config to `config/test.exs`:

{% capture c %}{% raw %}
config :hello, sql_sandbox: true
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir"%}

And conditionally add the `Phoenix.Ecto.SQL.Sandbox` plug in `lib/hello_web/endpoint.ex`:

{% capture c %}{% raw %}
  if Application.get_env(:hello, :sql_sandbox) do
    plug Phoenix.Ecto.SQL.Sandbox, header: "x-phoenix-ecto-sandbox"
  end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir"%}

For applications that use Phoenix Channels or LiveViews, we'd need to pass the metadata header in Phoenix socket assigns, and call `Sandbox.allow` when initializing them. Follow [Phoenix.Ecto.SQL.Sandbox docs](https://hexdocs.pm/phoenix_ecto/Phoenix.Ecto.SQL.Sandbox.html) to get that set up. For this example with only one "dead view", we'll only need the plug.

Now when executing the tests we see that they pass:

{% raw %}
<div><pre><code class="terminal">$ mix test helltest/hello_web/integration/
<span style="color:lime;">.</span><span style="color:lime;">.</span>

Finished in 9.2 seconds (9.2s async, 0.00s sync)
<span style="color:lime;">2 tests, 0 failures</span>
</code></pre></div>
{% endraw %}

Both tests created a separate user, and listing all users did not show the user created in the other test.
