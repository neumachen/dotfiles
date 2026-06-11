# Elixir Rule: Core Style

When writing or modifying Elixir code, follow idiomatic Elixir + OTP conventions. Elixir is Erlang's BEAM with macros and ergonomics — most OTP rules transfer; the syntax and ecosystem do not.

## Principles

- Prefer clarity over cleverness. Pattern matching, the pipeline operator, and `with` are your primary tools.
- Match the project's Elixir version (`mix.exs` `elixir:` requirement, `.tool-versions`). Do not use 1.18+ syntax in a 1.15 codebase.
- Match the project's existing libraries — Ecto vs. raw SQL, Phoenix vs. Plug, Oban vs. Quantum vs. raw GenServer scheduling. Do not introduce a parallel.
- `mix format` is mandatory. The project's `.formatter.exs` is the source of truth.

## Modules

- One concept per module. Module names use `CamelCase`, deeply nested for organization: `MyApp.Accounts.User`, `MyApp.Repo`.
- Module structure: `@moduledoc`, `use/import/alias/require`, `@behaviour`, type specs (`@type`, `@spec`), struct definition, public functions, then private functions (`defp`).
- Use `@moduledoc false` for internal modules — the absence of a moduledoc is a doc-warning in OTP 26+.
- Aliases at the top: `alias MyApp.Accounts.User`, `alias MyApp.{Repo, Accounts}` for multi-alias.
- Avoid `import` — it makes call origins ambiguous. Reach for it only when the imported functions feel like syntax (e.g., `Ecto.Query`, `Plug.Conn`).

## Pattern matching

- Destructure in function heads:
  ```elixir
  def handle({:ok, value}), do: {:ok, process(value)}
  def handle({:error, _reason} = err), do: err
  ```
- Multi-clause functions over `case` when the dispatch is on the shape of arguments. Use `case` inside a clause when only one path branches.
- Use the pin operator (`^var`) to match against an existing value rather than rebinding.

## Pipelines

- Use `|>` when the value flows linearly through transformations:
  ```elixir
  user
  |> User.changeset(attrs)
  |> Repo.insert()
  |> case do
    {:ok, user} -> {:ok, user}
    {:error, changeset} -> {:error, format_errors(changeset)}
  end
  ```
- The first value in a pipeline is the **subject**, not a one-line call: `start = DateTime.utc_now()` then `start |> ...` is better than `DateTime.utc_now() |> ...`.
- Don't pipeline through a single function — `[1, 2, 3] |> Enum.sum()` is uglier than `Enum.sum([1, 2, 3])`.

## `with`

For multi-step happy-path flows where each step can fail with `{:error, ...}`:

```elixir
def register(attrs) do
  with {:ok, user}    <- create_user(attrs),
       {:ok, _email}  <- send_welcome(user),
       {:ok, _signin} <- create_session(user) do
    {:ok, user}
  else
    {:error, %Ecto.Changeset{} = cs}    -> {:error, format_changeset(cs)}
    {:error, :rate_limited}             -> {:error, :throttled}
    other                               -> other
  end
end
```

- One `with` per logical flow. Nesting `with` inside `with` usually means you should extract a function.
- `else` clauses pattern-match the failure shape; bias toward enumerating known errors rather than a catch-all `_`.

## Error handling

- Tagged tuples (`{:ok, x} | {:error, reason}`) for expected failures. The convention is non-negotiable.
- `raise` for invariant violations and unexpected states. Use `raise MyApp.SpecificError, message: "..."` over `raise "string"`.
- Define error structs: `defmodule MyApp.NotFoundError do; defexception message: "not found"; end`.
- `!`-suffix sibling functions raise on error: `Repo.get!/2` raises, `Repo.get/2` returns `nil`. Match the project's existing pattern.
- `try/rescue` only when bridging external libraries that raise. Otherwise, let-it-crash and let the supervisor handle restart.

## GenServer

```elixir
defmodule MyApp.Cache do
  use GenServer

  ## API
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def lookup(key), do: GenServer.call(__MODULE__, {:lookup, key})
  def put(key, value), do: GenServer.cast(__MODULE__, {:put, key, value})

  ## Callbacks
  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:lookup, key}, _from, state) do
    {:reply, Map.fetch(state, key), state}
  end

  @impl true
  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end
end
```

- Always `@impl true` on callbacks — catches typos.
- Use `name: __MODULE__` for singleton servers. Use `Registry` or `:via` for per-key processes.
- `handle_call` returns `{:reply, reply, new_state}` or `{:noreply, new_state}` (with manual `GenServer.reply/2` later).
- Don't block in `handle_call/handle_cast`. Long work goes into `Task.Supervisor.async_nolink/3` or a dedicated worker.

## Supervision

- Trees declared in `Application.start/2`:
  ```elixir
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub},
      MyAppWeb.Endpoint,
      {Task.Supervisor, name: MyApp.TaskSupervisor},
      MyApp.Cache
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
  ```
- `:one_for_one` (default), `:one_for_all`, `:rest_for_one`.
- Children specs: tuple form `{Module, opts}` for most cases. Map form when you need restart/shutdown overrides.
- `DynamicSupervisor` for runtime-created children. `Task.Supervisor` for fire-and-forget tasks with crash isolation.

## Structs

```elixir
defmodule MyApp.User do
  @enforce_keys [:id, :email]
  defstruct [:id, :email, :name, role: "user", active: true]

  @type t :: %__MODULE__{
    id: integer(),
    email: String.t(),
    name: String.t() | nil,
    role: String.t(),
    active: boolean()
  }
end
```

- `@enforce_keys` for fields that must be set at construction.
- `@type t :: %__MODULE__{...}` and use it in specs: `@spec greet(User.t()) :: String.t()`.
- Pattern match on struct type: `def role(%User{role: r}), do: r` — both extracts and asserts the type.

## Behaviours and protocols

- `@behaviour` for callback contracts (a la Java interfaces). Use for "modules that play a role" (`@behaviour Plug`, `@behaviour MyApp.Notifier`).
- `defprotocol` for data-driven dispatch (a la Ruby duck-typing): one protocol, many implementations. Use sparingly — multi-clause functions usually suffice.
- Consolidate protocols in production (`config :phoenix, :consolidate_protocols, true`) for the speed.

## Strings vs charlists vs binaries

- `"hello"` is a UTF-8 binary. This is the default.
- `'hello'` is a charlist (`[104, 101, ...]`). Used only when interop with Erlang functions that take strings (`:ssh`, parts of `:os`, etc.).
- `?h` is the integer codepoint, useful in pattern matching: `<<?h, rest::binary>>`.
- Concatenate with `<>`, interpolate with `"#{var}"`. Build with `IO.iodata_to_binary/1` at the boundary.

## Ecto

- One schema per file at `lib/my_app/<context>/<resource>.ex`. Contexts live at `lib/my_app/<context>.ex`.
- `Ecto.Changeset` for validation, casting, and constraint mapping:
  ```elixir
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
  end
  ```
- Repo functions return `{:ok, struct}` or `{:error, changeset}`. Pattern match.
- Queries via `Ecto.Query` DSL: `from(u in User, where: u.active, order_by: [desc: u.inserted_at])`.
- `Repo.all/1` to materialize, `Repo.one/1` for single results, `Repo.aggregate/3` for counts/sums.
- N+1 prevention: `Repo.preload(users, :posts)` after the fact, or `from(u in User, preload: [:posts])` in the query.
- Migrations under `priv/repo/migrations/`, one file per change, named `YYYYMMDDHHMMSS_description.exs`.

## Phoenix

- Match the project's Phoenix version. Phoenix 1.7+ introduced verified routes (`~p"/users"`) and major changes to LiveView.
- Contexts (`MyApp.Accounts`) own data + business rules. Controllers are thin.
- LiveView: state in `socket.assigns`, transitions via `handle_event/3`. Don't reach for raw JS unless LiveView's `phx-` events truly can't model the flow.
- `Plug.Conn` is the request/response. Halt with `|> halt()` after writing a response — chained plugs continue otherwise.

## OTP applications

- `mix.exs` `application/0` defines start module and runtime dependencies.
- `extra_applications: [:logger]` for OTP apps you need at runtime.
- Releases (`mix release`) for production. Match the project's release config.
- Config: `config/config.exs` (compile-time defaults), `config/runtime.exs` (runtime, reads env vars), `config/{dev,test,prod}.exs` for env-specific overrides.

## Concurrency primitives

- `Task.async/1` + `Task.await/1` for parent-waits-for-child work.
- `Task.Supervisor.async_nolink/3` for crash-isolated tasks.
- `Task.async_stream/3,5` for parallel mapping over an enumerable with bounded concurrency.
- `Agent` for trivially-stateful processes (one piece of state, no logic). Usually a sign you should reach for `GenServer` instead.
- `Registry` for named per-key processes (one connection per user, one channel per chat).
- `Stream` for lazy enumeration. Use for files, paginated APIs, anything where the full collection wouldn't fit in memory.

## Testing

- ExUnit. `test/test_helper.exs` configures the suite; `test/<mirror of lib>/*_test.exs` for tests.
- `describe` and `test` blocks. Pattern match in `assert` heavily: `assert {:ok, %User{id: id}} = Accounts.register(attrs)`.
- `setup/1` for per-test fixtures, returns a map merged into `context`.
- `setup_all/1` for fixtures shared across the module — only for genuinely expensive read-only setup.
- `Mox` for behaviour-based mocking. Don't reach for it casually — most tests want real implementations + sandboxed Repo.
- `ExUnit.CaptureLog` to assert on log output. `ExUnit.CaptureIO` for stdout/stderr.

## Tooling

- `mix format` on every commit. CI checks with `mix format --check-formatted`.
- `mix credo --strict` for style and refactor suggestions. Address; don't suppress.
- `mix dialyzer` for static type checking. Fix warnings.
- `mix test --cover` for coverage.
- `mix deps.audit` (via `hex.audit`) and `mix deps.tree` for dependency hygiene.

## Anti-patterns

- `Enum.each(...) |> ...` — `Enum.each/2` returns `:ok`, not the collection. The pipe is broken.
- `if condition, do: x, else: y` over multi-line `if` for trivial branches — fine. Multi-line `if` with `do/else/end` for non-trivial.
- Long pipelines (>10 steps) — extract intermediate functions.
- Using `Process.send_after/3` for cron-like scheduling instead of `Oban`/`Quantum`.
- Reaching for macros when a function would do.
- `try/rescue` to catch any exception — almost always wrong.

## Examples

### Good — context with changeset and tagged-tuple flow

```elixir
defmodule MyApp.Accounts do
  alias MyApp.{Repo, Accounts.User}

  @spec register(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_active() :: [User.t()]
  def list_active do
    User
    |> where(active: true)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end
end
```

### Bad

```elixir
# raises on error, no spec, raw SQL string, no formatter compliance:
defmodule MyApp.Accounts do
  def register(attrs) do
    user = MyApp.Repo.insert!(%MyApp.Accounts.User{email: attrs["email"]})
    Ecto.Adapters.SQL.query!(MyApp.Repo, "UPDATE users SET active = true WHERE id = #{user.id}")
    user
  end
end
```
