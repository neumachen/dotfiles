# Go Rule: Testing

Write idiomatic, deterministic Go tests.

Prefer the standard `testing` package unless the repository already uses another testing framework.

## General testing guidance

- Add or update tests for meaningful behavior changes.
- Add regression tests for bug fixes when practical.
- Prefer testing behavior through public APIs where possible.
- Avoid over-mocking.
- Keep tests deterministic and isolated.
- Avoid sleeps in tests when synchronization primitives would be better.
- Follow existing repository test patterns.

## Table-driven tests

Use table-driven tests when testing multiple cases.

Example:

```go
func TestParseUser(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    User
        wantErr bool
    }{
        {
            name:  "valid user",
            input: `{"id":"123"}`,
            want:  User{ID: "123"},
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseUser(tt.input)
            if tt.wantErr {
                if err == nil {
                    t.Fatal("expected error")
                }
                return
            }
            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }
            if got != tt.want {
                t.Fatalf("got %+v, want %+v", got, tt.want)
            }
        })
    }
}
```

## Test helpers

- Use `t.Helper()` in helper functions.
- Use `t.TempDir()` for temporary files.
- Use `httptest` for HTTP handlers and clients.
- Use subtests with clear names.
- Prefer explicit assertions using the style already present in the repo.

## Integration tests

For integration tests:

- Respect existing build tags.
- Respect existing environment variable conventions.
- Respect existing Docker/testcontainer patterns.
- Do not make integration tests run by default if the project keeps them separate.
- Clean up external resources.
