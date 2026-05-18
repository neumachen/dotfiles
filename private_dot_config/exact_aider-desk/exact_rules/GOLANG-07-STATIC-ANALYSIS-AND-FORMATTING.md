# Go Rule: Static Analysis and Formatting

Generated or modified Go code must be compatible with standard Go tooling and the repository's existing lint configuration.

Before finalizing Go changes, ensure the code is compatible with:

- `gofmt`
- `goimports`
- `go vet`
- `go test`
- `staticcheck`, when used by the project
- `golangci-lint`, when used by the project

Respect existing configuration files, such as:

- `.golangci.yml`
- `.golangci.yaml`
- `staticcheck.conf`
- `go.mod`
- `Makefile`
- `Taskfile.yml`
- CI workflow files

Avoid common static-analysis issues:

- Unused variables.
- Unused imports.
- Ineffective assignments.
- Unreachable code.
- Ignored errors.
- Accidental shadowing that reduces clarity.
- Nil pointer hazards.
- Data races.
- Resource leaks.
- Excessive cyclomatic complexity.
- Duplicated logic.
- Overly broad interfaces.
- Unnecessary allocations.
- Deprecated APIs.
- Build tag mistakes.

Import rules:

- Keep imports clean.
- Use `goimports` ordering.
- Do not leave unused imports.
- Do not add blank import side effects unless required and documented.

Build tags:

- Respect existing build tags.
- Use modern build constraint syntax:

```go
//go:build linux
```

Compatibility:

- Respect the Go version declared in `go.mod`.
- Do not use newer language features if the module's Go version does not support them.
