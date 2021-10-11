---
title: Using structs for Oban worker arguments
hidden: false
# edit_date:
---
[Oban](https://hexdocs.pm/oban/) is a very good background job library for Elixir. It performs well, doesn't need Redis (uses PostgreSQL), has many nice features and is rather intuitive to use. I have one small issue with it - it's easy to make small mistakes (typos and similar) in job arguments. What if we could use Elixir structs to help with that?

[Oban.Worker](https://hexdocs.pm/oban/Oban.Worker.html)'s arguments are based on maps. When defining a worker, you pattern match on that map to extract individual job arguments:

{% capture c %}{% raw %}
defmodule MyApp.Business do
  use Oban.Worker, queue: :my_queue

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id} = _args}) do
    IO.inspect(id, label: "Running #{__MODULE__} with ID")
    :ok
  end
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=true %}

When scheduling a job, you also pass the arguments as a map. You can use atom keys but Oban will serialize them to JSON (that's why you need to use string keys in the `peform/1` function head in the snippet above).

{% capture c %}{% raw %}
iex(1)> %{id: 1}
|> MyApp.Business.new()
|> Oban.insert()
{:ok,
 %Oban.Job{
   ...
 }}
Running Elixir.MyApp.Business ID: 1
{% endraw %}{% endcapture %}{% include code_block.html code=c class="terminal" %}

What happens if you make a typo? The job fails at the start of executing with

> ** (FunctionClauseError) no function clause matching in MyApp.Business.perform/1

Yes, I know you could write tests to catch such mistakes. I am personally against writing tests just in order to catch "typos" when the compiler and static analysis tools can do that.

I played a bit with the idea of using structs to prevent mistakes similar to this one, and got an initial proof of concept working. We could define a struct for worker's arguments and use Jason to make it automatically serializable. Oban also allows us to override the `new/2` function so that we can ensure at the time of scheduling (or with static analysis like Dialyzer) that the passed in arguments are a struct. We can also `@enforce_keys` so that the Elixir compiler will ensure all required arguments are passed in.

{% capture c %}{% raw %}
defmodule MyApp.Business do
  use Oban.Worker, queue: :my_queue
  @derive Jason.Encoder
  @args [:id]
  @enforce_keys @args
  defstruct @args

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id} = _args}) do
    IO.inspect(id, label: "Running #{__MODULE__} with ID")
    :ok
  end

  @impl Oban.Worker
  def new(%MyApp.Business{} = args, opts), do: super(args, opts)
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=true %}

This works well!

{% capture c %}{% raw %}
iex(1)> %MyApp.Business{id: 1}
|> MyApp.Business.new()
|> Oban.insert()
{:ok,
 %Oban.Job{
   ...
 }}
Running Elixir.MyApp.Business with ID: 1
{% endraw %}{% endcapture %}{% include code_block.html code=c class="terminal" %}

But we can still mistype one of the arguments in the `perform/1` function head and have a run-time error. Let's try to generate that pattern match expression as well!

{% capture c %}{% raw %}
defmodule ObanArgsHelper do
  def convert(keys),
    do: {:%{}, [], Enum.map(keys, fn key -> {Atom.to_string(key), Macro.var(key, nil)} end)}
end

defmodule MyApp.Business do
  use Oban.Worker, queue: :my_queue
  @derive Jason.Encoder
  @args [:id]
  @enforce_keys @args
  defstruct @args

  @impl Oban.Worker
  def perform(%Oban.Job{args: unquote(ObanArgsHelper.convert(@args))}) do
    IO.inspect(id, label: "Running #{__MODULE__} with ID")
    :ok
  end

  @impl Oban.Worker
  def new(%MyApp.Business{} = args, opts), do: super(args, opts)
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=true %}

## Solution

Now that we only have one place where we define a list of argument names, let's introduce a helper module that will get rid of most of the boilerplate:

{% capture c %}{% raw %}
defmodule ObanWorkerHelper do
  defmacro __using__(opts) do
    {args, opts} = Keyword.pop(opts, :args)
    {module, oban_opts} = Keyword.pop(opts, :module)

    quote do
      use Oban.Worker, unquote(oban_opts)
      @derive Jason.Encoder
      @enforce_keys unquote(args)
      defstruct unquote(args)
      @args_matcher ObanWorkerHelper.convert(unquote(args))

      @impl Oban.Worker
      def new(%unquote(module){} = args, opts) do
        super(args, opts)
      end
    end
  end

  def convert(keys),
    do: {:%{}, [], Enum.map(keys, fn key -> {Atom.to_string(key), Macro.var(key, nil)} end)}
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=true %}

And with that, our worker module reduces to just:

{% capture c %}{% raw %}
defmodule MyApp.Business do
  use ObanWorkerHelper, queue: :my_queue, args: [:id], module: __MODULE__

  @impl Oban.Worker
  def perform(%Oban.Job{args: unquote(@args_matcher)}) do
    IO.inspect(id, label: "Running #{__MODULE__} with ID")
    :ok
  end
end
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="elixir" numbered=true %}

Ta-daa! While a bit "hacky", I think this should work well and can be used in real-world projects.

The generated pattern match expression can't be used when arguments format changes (you can however have an additional function head befofore or after to translate "old arguments" format of already scheduled jobs to the new one). Maybe there is a way to have some kind of "versioned" structs here.

And it would be good to have this in Oban itself - maybe a similar (or better) solution will come in the future!
