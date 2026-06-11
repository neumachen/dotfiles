# Erlang Rule: Core Style

When writing or modifying Erlang, follow OTP conventions. The let-it-crash philosophy is real — design around supervision, not around catching every error.

## Principles

- Prefer clarity over cleverness. Pattern matching is your primary tool.
- Match the project's OTP version (`rebar.config` `minimum_otp_vsn`, or the project's `.tool-versions`/`erlang_version`). Do not silently use OTP 26+ features in an OTP 24 codebase.
- Match the project's build tool: `rebar3` is the default; `erlang.mk` for projects that use it. Do not mix.
- Module names match the filename: `my_server.erl` exports `-module(my_server).`.

## Modules

- One concept per module. Module names use `snake_case`.
- File header order: `-module/1`, `-behaviour/1`, `-export/1`, `-export_type/1`, then `-include_lib/1` / `-include/1`, then `-define/2` macros, then records, then API functions, then callbacks, then internal helpers.
- Use `-spec/2` on every exported function. Use `-type/1` for non-trivial type definitions.
- Avoid `import` — fully-qualified calls (`lists:reverse/1`) are easier to grep.

## Pattern matching

- Destructure in function heads, not in `case` bodies:
  ```erlang
  %% Good
  handle({ok, Value}) -> {ok, process(Value)};
  handle({error, _Reason} = Err) -> Err.

  %% Bad
  handle(Result) ->
    case Result of
      {ok, Value} -> {ok, process(Value)};
      {error, _Reason} -> Result
    end.
  ```
- Use the `_` wildcard for unused bindings. Use `_Name` (e.g., `_Reason`) when you want the documentation but not the binding.
- Bind once. Erlang is single-assignment. If you find yourself reaching for `Value2 = ...`, the function is too long.

## Errors

- **Let it crash.** Exit a process via supervised restart rather than wrapping everything in `try/catch`.
- `try ... of ... catch ... end` only when:
  - You can recover (e.g., parse failure → return `{error, Reason}` to the caller).
  - You need to clean up resources before bubbling the exit.
- Use tagged tuples (`{ok, V} | {error, Reason}`) for expected failure paths; use `error(Reason)` for invariant violations.
- Never use `catch _:_ -> ...` — it swallows `error:badmatch`, `exit:normal`, and everything else. Match specific classes (`error:badarg`, `throw:_`, `exit:Reason`).

## Processes

- Use `gen_server`, `gen_statem`, `gen_event`, or `supervisor`. Hand-spawn raw processes only for short-lived workers (`proc_lib:spawn_link/1`).
- Send messages with `gen_server:cast/2` (fire-and-forget) and `gen_server:call/2,3` (synchronous, returns value). Avoid raw `!` except in tightly-controlled flows like `gen_statem` event posting.
- `gen_server:call/2` defaults to 5s timeout — explicit `gen_server:call(Pid, Req, Timeout)` for anything that may take longer.
- Always link or monitor child processes. Orphan processes that crash are silently lost.

## gen_server

```erlang
-module(my_server).
-behaviour(gen_server).

-export([start_link/1, lookup/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {table :: ets:tid()}).

-spec start_link(map()) -> {ok, pid()}.
start_link(Opts) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Opts, []).

-spec lookup(term(), timeout()) -> {ok, term()} | not_found.
lookup(Key, Timeout) ->
    gen_server:call(?MODULE, {lookup, Key}, Timeout).

%% callbacks
init(_Opts) ->
    Tid = ets:new(?MODULE, [set, protected, named_table]),
    {ok, #state{table = Tid}}.

handle_call({lookup, Key}, _From, State = #state{table = T}) ->
    Reply = case ets:lookup(T, Key) of
        [{Key, V}] -> {ok, V};
        []         -> not_found
    end,
    {reply, Reply, State}.

handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.
```

- Always implement every callback even if it's a stub — explicit beats compile warnings.
- Use a `#state{}` record. Naked maps are tempting but lose the spec discipline.
- `handle_call` returns `{reply, Reply, NewState}` or `{noreply, NewState}` (manual `gen_server:reply/2` later) — never block.

## gen_statem

- Use `gen_statem` when state transitions are the model (auth flows, connection lifecycles, protocols). Use `gen_server` when the model is "I hold state and serve requests."
- `state_functions` callback mode for simple state machines; `handle_event_function` for complex ones. Match the project's existing style.

## Supervision

- Top-level `application:start/1` → `Supervisor` → workers.
- One supervisor per logical fault domain. Crashing one worker should not take down siblings unless that's intentional (`one_for_all`).
- Restart strategies: `one_for_one` (default), `one_for_all`, `rest_for_one`, `simple_one_for_one` (deprecated in OTP 18+, use `simple_one_for_one` via `child_spec` map form on OTP 26+, or `DynamicSupervisor` patterns).
- `intensity` and `period` define the restart envelope — defaults `1/5` (1 restart per 5s) are tight. Tune up for noisy worker pools.

## Records vs maps

- Records when the shape is known at compile time and you want pattern matching with field access (`#user{id = Id}`). Records compile to tuples — cheap and well-supported by Dialyzer.
- Maps when shape is dynamic or interoperating with JSON/external data (`#{<<"id">> := Id}`).
- Don't mix in the same module without a comment explaining why.

## Binaries and strings

- Strings are lists of integers by convention. **Use binaries (`<<"hello">>`) for actual text data** — they're vastly cheaper.
- Pattern-match binaries with bit syntax: `<<Header:32/binary, Rest/binary>> = Frame`.
- Use `iolist_to_binary/1` only at the boundary (e.g., before a `gen_tcp:send/2`). Internally, prefer iolists for accumulation — no copying.
- `binary:split/2`, `binary:match/2`, `binary:replace/3` for binary manipulation; not `re` unless the pattern truly needs regex.

## ETS

- Use ETS for per-VM shared state (lookup tables, counters, caches).
- `set | ordered_set | bag | duplicate_bag` — pick deliberately. `set` is the default and what you usually want.
- Protected (default) vs public (anyone can write): default to `protected`, expose via the owning gen_server.
- `read_concurrency, true` for read-heavy tables; `write_concurrency, true` for write-heavy. Both have memory cost.
- ETS tables die with the owning process unless given to a heir or made `named_table` with explicit ownership transfer logic.

## Concurrency primitives

- `gen_server:call/2,3` for synchronous request/reply.
- `gen_server:cast/2` for fire-and-forget.
- `selective receive` only in well-bounded message protocols. A `receive` with no timeout and no upper bound on accepted messages is a deadlock waiting to happen.
- `erlang:monitor/2` over `link/1` when you want a death notification but not bidirectional crash propagation.

## OTP releases

- Use `relx` (via `rebar3 release`) for production releases.
- `sys.config` for runtime config; `vm.args` for VM flags (heap sizes, distribution cookie, node name).
- Hot code upgrades exist but are an advanced topic — most projects deploy by rolling restart.

## Tooling

- `rebar3 compile` clean.
- `rebar3 dialyzer` — type checking. Fix warnings; don't suppress.
- `rebar3 eunit` and `rebar3 ct` (Common Test) for tests.
- `rebar3 xref` for unused-call detection.
- `erlfmt` for formatting (modern equivalent of `gofmt`).
- `elvis` for style linting.

## Examples

### Good — supervised worker pool

```erlang
-module(jobs_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 30},
    Workers = [
        #{id => job_worker_1,
          start => {job_worker, start_link, [worker_1]},
          restart => permanent,
          shutdown => 5000,
          type => worker,
          modules => [job_worker]}
    ],
    {ok, {SupFlags, Workers}}.
```

### Bad

```erlang
%% Bare spawn, no link, no supervision, catch-all rescue, naked send:
do_thing(Pid) ->
    spawn(fun() ->
        Result = (catch some_module:work()),
        Pid ! Result
    end).
```
