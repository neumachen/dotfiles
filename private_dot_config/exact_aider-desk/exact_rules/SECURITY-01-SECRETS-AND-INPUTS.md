# Security Rule: Secrets and Input Validation

When generating or modifying code, never introduce security vulnerabilities related to
secret management or input handling.

## When This Rule Applies

- Any code that reads environment variables, config files, or command-line flags
- Any code that accepts user input (HTTP requests, CLI args, file paths, query params)
- Any code that constructs SQL queries, shell commands, or file paths from external data
- Any code that handles authentication tokens, API keys, or credentials

## Required Behavior

### Secrets

- Never hardcode secrets, tokens, passwords, or API keys in source files
- Always read secrets from environment variables or a secrets manager
- Never log secrets, tokens, or credentials at any log level
- Use `crypto/rand` (Go), `secrets` module (Python), or equivalent — never `math/rand` for
  security-sensitive randomness
- Never commit `.env` files; use `.env.example` with placeholder values

### Input Validation

- Validate and sanitize all external input before use
- Use parameterized queries / prepared statements — never string-interpolate SQL
- Validate file paths; reject `..` traversal sequences before path operations
- Apply length and format constraints before processing user-supplied strings

### Shell and OS

- Never construct shell commands by concatenating user input
- Use argument arrays (e.g., `exec.Command(cmd, arg1, arg2)` in Go) instead of shell strings

## Examples

### Good (Go)

```go
// Read secret from environment
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    return fmt.Errorf("API_KEY environment variable not set")
}

// Parameterized SQL
row := db.QueryRowContext(ctx, "SELECT id FROM users WHERE email = $1", email)

// Safe subprocess
cmd := exec.CommandContext(ctx, "git", "log", "--oneline", ref)
```

### Bad (Go)

```go
// Hardcoded secret
apiKey := "sk-abc123"

// String-interpolated SQL
query := fmt.Sprintf("SELECT id FROM users WHERE email = '%s'", email)

// Shell injection risk
cmd := exec.Command("sh", "-c", "git log "+userInput)
```

## Exceptions

None. These are non-negotiable baseline security behaviors.
