---
name: shiki-go-implementation
description: "Go-specific implementation discipline. Use when implementing features, fixing bugs, or refactoring in Go codebases. Enforces idiomatic Go patterns, proper testing, and toolchain compliance."
license: Apache-2.0
---

# Go Implementation

Go-specific implementation discipline for idiomatic, tested, and maintainable Go code.

## When to Use

Use this skill when:

- Implementing features in Go codebases
- Fixing bugs in Go code
- Refactoring Go code
- Adding tests to Go code

Do not use when:

- Working in non-Go codebases
- Only reading/analyzing Go code
- Working on configuration files

## Rules

### Rule: Follow Go idioms

**When:** Writing Go code

**Then:** Apply Go idioms

**Error handling:**
```go
// ✅ Correct: Return error, let caller decide
if err != nil {
    return fmt.Errorf("operation failed: %w", err)
}

// ❌ Wrong: Log and continue
if err != nil {
    log.Printf("error: %v", err)
}

// ❌ Wrong: Panic in library code
if err != nil {
    panic(err)
}
```

**Naming:**
- Use short names for short scopes: `i`, `n`, `err`, `ctx`
- Use descriptive names for wider scopes: `userRepository`, `connectionTimeout`
- Acronyms stay capitalized: `ID`, `HTTP`, `URL`, `API`, `JSON`, `SQL`
- Avoid stuttering: `user.User` → `user.Account` or just `User` in package `user`
- Receivers: short, consistent, not `this` or `self`

**Zero values:**
- Leverage zero values in struct design
- Don't check for zero when zero is valid
- Design structs so zero value is useful

**Interfaces:**
- Keep interfaces small (1-3 methods)
- Define interfaces where they're used, not where they're implemented
- Accept interfaces, return concrete types

### Rule: Respect package boundaries

**When:** Adding new code

**Then:** Verify package structure

**Package rules:**
- No import cycles (Go compiler enforces this, but plan ahead)
- Internal packages for implementation details: `internal/`
- Public API surfaces are intentional, not accidental
- Keep package interfaces small
- One package = one responsibility

**Detection method:**
```bash
# Check imports for a package
go list -f '{{.ImportPath}}: {{.Imports}}' ./...

# Check for import cycles (will fail if cycle exists)
go build ./...
```

**When to use internal/:**
- Implementation details that shouldn't be imported
- Helpers specific to this module
- Code that may change without notice

### Rule: Run Go tools

**When:** After any code change

**Then:** Run Go toolchain

**Required tools (in order):**
```bash
# 1. Format code
gofmt -w .
# or better: goimports -w .

# 2. Build check (catches type errors, import issues)
go build ./...

# 3. Vet (catches common mistakes)
go vet ./...

# 4. Run tests
go test ./...
# or narrower scope: go test ./pkg/mypackage/...

# 5. Race detector (for concurrent code)
go test -race ./...
```

**If repository uses golangci-lint:**
```bash
golangci-lint run
```

**Tool output interpretation:**
- Exit code 0, no output = proceed
- Any error = fix before claiming completion
- Any warning from vet/lint = evaluate and fix or document exception

**Narrowing test scope:**
- Full suite: `go test ./...`
- Single package: `go test ./pkg/mypackage`
- Single test: `go test ./pkg/mypackage -run TestSpecificName`
- Use narrow scope during development, full suite before completion

### Rule: Write idiomatic tests

**When:** Adding or modifying tests

**Then:** Follow Go test patterns

**Table-driven tests (preferred for multiple cases):**
```go
func TestParse(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    Result
        wantErr bool
    }{
        {
            name:    "empty input",
            input:   "",
            want:    Result{},
            wantErr: true,
        },
        {
            name:  "valid input",
            input: "abc",
            want:  Result{Value: "abc"},
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Parse(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Parse() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if !tt.wantErr && got != tt.want {
                t.Errorf("Parse() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

**Test helper pattern:**
```go
func newTestServer(t *testing.T) *Server {
    t.Helper() // Marks this as helper for better error reporting
    srv := &Server{/* setup */}
    t.Cleanup(func() {
        srv.Close()
    })
    return srv
}
```

**Testing conventions:**
- Test file: `foo_test.go` next to `foo.go`
- Test function: `TestFunctionName` or `TestType_MethodName`
- Use `t.Helper()` in helper functions
- Use `t.Cleanup()` for teardown
- Use `t.Parallel()` for independent tests
- Use `testdata/` directory for test fixtures

### Rule: Handle context correctly

**When:** Writing functions that do I/O, blocking, or long-running work

**Then:** Accept context.Context as first parameter

```go
// ✅ Correct: Context first
func (s *Service) GetUser(ctx context.Context, id string) (*User, error)

// ✅ Correct: Method with context
func (c *Client) Do(ctx context.Context, req *Request) (*Response, error)

// ❌ Wrong: No context for I/O operation
func (s *Service) GetUser(id string) (*User, error)

// ❌ Wrong: Context not first parameter
func (s *Service) GetUser(id string, ctx context.Context) (*User, error)
```

**Context rules:**
- Pass context down the call chain
- Respect cancellation: check `ctx.Done()` in loops
- Don't store context in structs (pass it through)
- Use `context.Background()` only at program entry points
- Use `context.TODO()` when context should be added but isn't yet

**Context-aware APIs:**
```go
// Use these instead of non-context versions
db.QueryContext(ctx, query, args...)
http.NewRequestWithContext(ctx, method, url, body)
```

### Rule: Concurrency safety

**When:** Writing concurrent code

**Then:** Verify safety

**Concurrency checklist:**
- [ ] Shared mutable state protected by mutex or channel
- [ ] Goroutines have clear lifecycle (start, stop, error handling)
- [ ] No goroutine leaks (all goroutines can exit)
- [ ] Race detector passes: `go test -race ./...`
- [ ] Context cancellation respected

**Common patterns:**

Mutex for shared state:
```go
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}
```

Channel for coordination:
```go
done := make(chan struct{})
go func() {
    defer close(done)
    // work...
}()
<-done // wait for completion
```

errgroup for parallel work:
```go
g, ctx := errgroup.WithContext(ctx)
for _, item := range items {
    item := item // capture for goroutine
    g.Go(func() error {
        return process(ctx, item)
    })
}
if err := g.Wait(); err != nil {
    return err
}
```

### Rule: Check module compatibility

**When:** Using new language features or APIs

**Then:** Verify go.mod version compatibility

```bash
# Check Go version in go.mod
grep '^go ' go.mod
```

**Version constraints:**
- Don't use features newer than go.mod version
- If feature requires newer Go, discuss upgrade first
- Check standard library additions are available in target version

### Rule: Error wrapping conventions

**When:** Handling errors

**Then:** Follow project error patterns

**Standard library approach:**
```go
// Wrap with context using %w
if err != nil {
    return fmt.Errorf("load config from %s: %w", path, err)
}

// Check error types
if errors.Is(err, os.ErrNotExist) {
    // handle missing file
}

// Extract error types
var pathErr *os.PathError
if errors.As(err, &pathErr) {
    // use pathErr.Path, pathErr.Op, etc.
}
```

**Error message conventions:**
- Lowercase, no trailing punctuation
- Include relevant context (what operation, what input)
- Don't duplicate context already in wrapped error
- Use `%w` for errors that callers might want to inspect

## Process

1. Detect Go codebase (`go.mod` exists)
2. Check Go version in `go.mod`
3. Read existing code patterns (invoke shiki-code-change-discipline)
4. Write idiomatic Go code
5. Run `gofmt -w .` or `goimports -w .`
6. Run `go build ./...`
7. Run `go vet ./...`
8. Run `go test ./...` (or narrower scope, then full)
9. If concurrent code: run `go test -race ./...`
10. If configured: run `golangci-lint run`
11. Verify all pass before claiming completion

## Preconditions

Before using this skill, verify:

- `go.mod` exists in repository root or parent
- Go toolchain is available (`go version` succeeds)
- Test infrastructure exists or will be created

## Postconditions

After completing this skill, verify:

- Code formatted with gofmt/goimports
- Build succeeds: `go build ./...`
- Vet clean: `go vet ./...`
- Tests pass: `go test ./...`
- Race detector passes (if concurrent code): `go test -race ./...`
- Lint clean (if golangci-lint configured)

## Success Metrics

This skill is successful when:

- All Go tools pass (format, build, vet, test)
- Code follows Go idioms
- Package boundaries respected
- Tests are table-driven where appropriate
- Context handled correctly
- No race conditions (race detector passes)
- Error handling is idiomatic

## Integration

This skill is invoked by:
- **shiki-implement** - When Go codebase detected
- **shiki-two-stage-review-execution** - For Go tasks
- **shiki-systematic-debugging** - For Go bug fixes

This skill invokes:
- **shiki-code-change-discipline** - For inspection requirements
- **shiki-test-driven-development** - For test-first approach

## Common Situations

**Situation:** Adding new function to existing package

**Pattern:**
- Read existing functions in package
- Match naming, error handling, logging patterns
- Add table-driven test with edge cases
- Run `go test ./pkg/...` for that package
- Run full suite before completion

**Situation:** Creating new package

**Pattern:**
- Determine if `internal/` appropriate (implementation detail vs public API)
- Create minimal package with focused responsibility
- Define small interface if needed
- Export only necessary types and functions
- Add package-level doc comment in `doc.go` or main file
- Add tests from the start

**Situation:** Fixing bug

**Pattern:**
- Write failing test first (reproduces bug)
- Verify test fails for expected reason
- Fix bug minimally
- Verify test passes
- Run broader test suite
- Run race detector if concurrent code involved

**Situation:** Adding dependency

**Pattern:**
- Check if similar functionality exists in stdlib
- Check if project already has similar dependency
- Run `go get` to add dependency
- Run `go mod tidy` to clean up
- Verify build and tests still pass

**Situation:** Refactoring

**Pattern:**
- Ensure comprehensive test coverage exists first
- Make incremental changes
- Run tests after each change
- Use `gofmt` to ensure consistent formatting
- Run race detector if touching concurrent code
