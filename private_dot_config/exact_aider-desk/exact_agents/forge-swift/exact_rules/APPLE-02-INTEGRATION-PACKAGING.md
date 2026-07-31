# Apple Rule: System Integration & Packaging

Applies when embedding executables/helpers, doing IPC, or handling sandbox/signing/distribution in a native macOS app. These are trust- and lifecycle-sensitive; when a change would alter a boundary below, return `needs_decision` to Analyst rather than guessing.

## Bundle layout and resource discovery

- Resolve resources through `Bundle` APIs (`Bundle.main.url(forResource:...)`, `Bundle.main.executableURL`, `Contents/Helpers`, `Contents/Frameworks`, `Contents/Resources`). Never hard-code absolute or repository-relative paths.
- Embedded executables/helpers live inside the app bundle and are located relative to the running bundle at runtime — never relative to the build machine or source checkout.
- Bundle non-Swift runtimes/helpers inside the app; do not depend on Homebrew, `/usr/local`, `mise`, or a developer's `$PATH` at runtime.

## Helper processes and IPC

- Preserve declared authority and ownership boundaries; a helper's privilege must match its registration.
- Give each helper an explicit, attributable identity (bundle id / service name); no anonymous processes.
- Prefer `SMAppService` (ServiceManagement) for login items/daemons/agents on current targets; prefer XPC for structured, type-checked IPC. Use Unix-domain sockets only when a byte-stream protocol is genuinely required.
- Bound every startup, shutdown, reconnect, and cleanup operation with a timeout; never wait unbounded.
- Prevent duplicate authoritative helpers (single-owner via a lock or registration check). Distinguish stale artifacts (sockets, pid files) from live owners before removing anything.
- Keep logs separate from protocol channels; don't multiplex diagnostics into the IPC stream.
- On termination, reap children deterministically and clean up only the sockets/temp files you own.

## Sandbox, entitlements, and permissions

- Match the project's existing App Sandbox posture. Adding or removing an entitlement, a `com.apple.security.*` key, or a hardened-runtime exception is a trust-boundary change → `needs_decision`.
- Use security-scoped bookmarks for user-selected paths that must persist; store secrets in the Keychain, never in `UserDefaults`, files, logs, fixtures, or the bundle.
- Never bypass TCC/permission prompts or user-confirmation dialogs. Do not disable Gatekeeper/SIP or suggest doing so.

## Signing, notarization, distribution

- Prefer letting Xcode/`xcodebuild` manage signing. Read-only inspection is fine (`codesign --display/--verify`, `spctl -a`); actual signing/notarization uses the user's credentials and must be surfaced, not automated silently.
- Never extract, print, or copy private signing material, certificates, or profiles. Never read `~/.ssh`.
- Changing signing identity, distribution channel, or minimum OS is a policy decision → `needs_decision`.

## Evidence to return

For lifecycle-sensitive work, return evidence for: launch, failure handling, restart, forced termination, relocation (moved/renamed bundle), signing/verification, and cleanup — with the exact commands run.
