# Go Rule: Error Style

Use the repository's established error package and error style.

This rule controls error construction, wrapping, comparison, and message style. It is intentionally separate from the mandatory error-checking rule so it can be replaced by a project-specific error package rule when needed.

## General guidance

- Follow the repository's existing error conventions first.
- If the project uses a specific error package, use that package consistently.
- If the project does not define a specific error package, prefer standard Go errors using `errors` and `fmt.Errorf`.
- Return errors instead of panicking in normal application or library flow.
- Avoid `panic`, `log.Fatal`, and `os.Exit` outside application entry points.
- Reusable packages should return errors rather than terminating the process.

## Wrapping and context

When using standard Go error handling, wrap errors with useful operation context:

```go
if err != nil {
    return fmt.Errorf("load config: %w", err)
}
```

Use:

- `fmt.Errorf` with `%w` for wrapping.
- `errors.Is` for sentinel error checks.
- `errors.As` for typed error checks.

Error messages should generally:

- Start with lowercase.
- Avoid trailing punctuation.
- Include useful operation context.
- Not leak secrets or sensitive details.

Good:

```go
return fmt.Errorf("query user by id: %w", err)
```

Avoid:

```go
return fmt.Errorf("Failed!")
```

## Sentinel errors

Use sentinel errors only when callers need to compare against them.

Example:

```go
var ErrNotFound = errors.New("not found")
```

When wrapping sentinel errors, preserve comparability with `%w` unless the repository's error package provides a different mechanism.

## Logging and returning

- Do not both log and return the same error unless there is a clear boundary reason.
- Lower-level code should generally return errors.
- Boundary code such as CLI commands, HTTP handlers, workers, and application entry points commonly logs errors.
