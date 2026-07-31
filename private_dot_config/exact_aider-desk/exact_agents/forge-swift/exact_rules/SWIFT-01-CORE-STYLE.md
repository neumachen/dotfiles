# Swift Rule: Core Style

When writing or modifying Swift, follow modern idiomatic patterns. `swift-format`/`swiftformat` and `swiftlint` (whichever the project configures) are non-negotiable on every change.

## Principles

- Prefer clarity over cleverness.
- Match the project's Swift tools version (`// swift-tools-version:` in `Package.swift`) and Xcode deployment target. Do not silently raise either.
- Match the project's minimum OS (`platforms:` in `Package.swift` or `*_DEPLOYMENT_TARGET` build settings). Do not use APIs newer than the declared minimum without an `if #available` gate.
- Keep changes minimal and directly related to the requested task.

## Concurrency

- Prefer structured concurrency (`async`/`await`, `Task`, `TaskGroup`) over completion handlers and manual `DispatchQueue` hopping.
- Isolate UI-mutating state to `@MainActor`. Do not touch AppKit/SwiftUI view state off the main actor.
- Use `actor` for shared mutable state; avoid locks unless bridging non-async code.
- Treat Swift 6 strict-concurrency warnings as errors in scope; do not silence with `@unchecked Sendable` unless you can justify the invariant in a comment.
- Never block the main thread on I/O, IPC, or subprocess waits.

## Optionals and errors

- Model absence with optionals; avoid force-unwrap (`!`) except for invariants the type system can't express (comment why). Never force-unwrap external input.
- Use `throws`/`Result` for recoverable failures; reserve `fatalError`/`precondition` for programmer errors.
- Prefer `guard` for early exits and to keep the happy path unindented.

## SwiftUI

- Keep views small and value-typed; push logic into `@Observable`/`ObservableObject` models or plain types.
- Choose the narrowest state ownership: `let` > `@State` > `@Binding` > `@Environment` > shared model. Don't promote to a global store by default.
- Drive windows/scenes through the `Scene` graph (`WindowGroup`, `Window`, `Settings`); don't spawn `NSWindow` manually when a scene expresses the intent.

## AppKit and SwiftUI↔AppKit bridging

- Bridge with `NSViewRepresentable`/`NSHostingView`; keep the Coordinator the single owner of delegate callbacks.
- For text-heavy UI (syntax highlighting, diffs, selections, annotations) prefer TextKit 2 (`NSTextLayoutManager`) on current targets; only fall back to TextKit 1 when a required API is missing, and note it.
- Respect the responder chain, first-responder, and key-view loop; don't hard-code focus.

## Accessibility

- Provide accessibility labels/roles/values for custom controls and verify full keyboard navigation. Accessibility is part of "done," not a follow-up.

## Testing

- Write XCTest unit tests for logic; use `XCUITest` only for genuine UI flows.
- Prefer dependency injection over singletons so units are testable without the full app.
- Run `swift test` (SwiftPM) or `xcodebuild test -scheme <scheme> -destination '...'` (Xcode) and report the destination used.

## Tooling

- `swift build`, `swift test`, `xcodebuild`, and the project's formatter/linter must pass. Report the exact commands and the deployment target/destination assumed.
