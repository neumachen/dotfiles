# TypeScript Rule: Core Style

When modifying or generating TypeScript code, follow the project's `tsconfig` and lint configuration strictly.

## Principles

- Prefer clarity over cleverness.
- Match the existing project style before introducing new patterns; do not "modernize" by stealth.
- Keep changes minimal and directly related to the requested task.
- Strict mode is non-negotiable. Honor `strict`, `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, `noUnusedLocals`, `noUnusedParameters` if the tsconfig enables them.

## Types

- Never `// @ts-ignore` or `// @ts-expect-error` without a single-line comment explaining why.
- Never introduce `any` without an inline justification. Prefer `unknown` + a narrowing guard.
- Use `type` for unions, intersections, function signatures, and primitives. Use `interface` for object shapes that may be extended.
- Use `readonly` aggressively: on object properties, array fields, and class fields that don't change after construction.
- Prefer discriminated unions over boolean flags when modeling state:
  ```ts
  type State = { kind: 'idle' } | { kind: 'loading' } | { kind: 'ready'; value: T } | { kind: 'error'; reason: string };
  ```
- Use `const` assertions for fixed value sets: `const ROLES = ['admin', 'user', 'guest'] as const`.

## Imports

- Use `import type { Foo } from 'bar'` for type-only imports. Enforce via `@typescript-eslint/consistent-type-imports`.
- Group imports: built-ins (`node:fs`, `node:path`) → third-party → local. Sort alphabetically within each group.
- Use `node:` prefix for built-ins.
- Path aliases (`@/foo`) are fine if the project's tsconfig defines them; otherwise use relative imports.

## Async

- `async` / `await` over hand-rolled `.then()` chains.
- Always `await` (or explicitly return) promises returned from functions. Floating promises are bugs; let the linter catch them (`@typescript-eslint/no-floating-promises`).
- Wrap I/O in `try/catch` only when the catch site can act on the error. Re-throwing after logging is rarely useful.
- Use `Promise.all` for independent concurrent calls; `Promise.allSettled` when you need partial-success semantics.
- Never `await` inside a `for...of` over an array of independent work — use `Promise.all` with `.map(async ...)` instead.

## Null and undefined

- Prefer optional fields (`foo?: string`) over `foo: string | undefined` — the former lets callers omit the field.
- Use `??` for nullish defaulting, `||` only when "falsy is a valid sentinel."
- `someValue?.method()` over `someValue && someValue.method()`.

## Errors

- Throw `Error` instances or subclasses, not strings or plain objects.
- Use named subclasses for predictable errors that callers should distinguish: `class ValidationError extends Error { ... }`.
- Provide a `cause`: `throw new Error('Failed to load config', { cause: err })`.
- Type catch bindings as `unknown` and narrow: `if (err instanceof Error) { ... }`.

## Logging

- No `console.log` in production paths — use the project's logger (`logger`, `context.log`, etc.).
- `console.warn` / `console.error` are acceptable for CLI tools.
- Never log secrets, tokens, or full request/response bodies.

## React/TSX (when applicable)

- Function components with hooks; no class components in new code.
- One component per file unless they're truly co-located helpers.
- Props types co-located with the component: `type Props = { ... }` immediately above `function Foo(props: Props)`.
- Avoid `React.FC` — it adds `children` implicitly and obscures the props.

## Examples

### Good

```ts
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { z } from 'zod';

import type { Config } from './types';

const ConfigSchema = z.object({ port: z.number(), host: z.string() });

export function loadConfig(dir: string): Config {
  const file = join(dir, 'config.json');
  if (!existsSync(file)) {
    throw new Error(`Config not found at ${file}`);
  }
  try {
    return ConfigSchema.parse(JSON.parse(readFileSync(file, 'utf8')));
  } catch (err) {
    throw new Error(`Invalid config at ${file}`, { cause: err });
  }
}
```

### Bad

```ts
// any, no type imports, floating promise, untyped catch:
export const loadConfig = async (dir: any) => {
  const file = require('path').join(dir, 'config.json');
  fs.readFile(file).then(buf => JSON.parse(buf.toString())).catch(e => console.log(e));
};
```
