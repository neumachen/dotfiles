# Tooling Preflight — Working Notes

> Version-controlled copy. Renders via chezmoi to ~/.config/aider-desk/docs/tooling-preflight-NOTES.md.

Persistent tracker for the coding-agent toolchain-preflight initiative. Resume here when the
missing-tooling problem resurfaces.

## Problem origin

- Symptom: `forge-rust` edits triggered the LSP extension to start `rust-analyzer`, but the
  rustup shim reported `rust-analyzer is unavailable for the active toolchain` — the LSP log
  died right after "Starting Rust LSP server". Root cause: shiki provisions toolchains via
  `shiki-mise.toml`, which had NO rust entry; the rust-analyzer at `/root/.cargo/bin` was a
  dangling rustup shim with no component behind it.
- Generalized ask: every coding (forge-*) agent should verify its toolchain before running;
  if missing, auto-install (user-space) with notification; failures must bubble up.

## Decisions made

- Architecture: ONE global rule (`TOOLING-01-PREFLIGHT.mdc`) holds the shared algorithm;
  per-language tool lists live in each agent's `power---bash` allowedPattern (config.json) —
  NOT duplicated per-agent rule files (those were created then deleted).
- Behavior: **auto-install with notification** (not notify-only), user-space only, no sudo.
- Run-once: session sentinel `${TMPDIR:-/tmp}/.forge-preflight-<agent>`.
- Determinism (Design A): exit-code probe (`exit 87` + `PREFLIGHT_FAIL: missing <bin>`),
  first-line report sentinel `STATUS: BLOCKED_MISSING_TOOLING`, and an Analyst refusal
  contract in ROUTING-01.

## Commits

- `ac905b9` feat(agents): add toolchain preflight contract to coding agents
  (1 global rule + 10 config.json allowedPattern/customInstructions edits)
- (this note's commit) deterministic-failure hardening for TOOLING-01 + ROUTING-01

## Files touched

- `private_dot_config/exact_aider-desk/exact_rules/TOOLING-01-PREFLIGHT.mdc`
- `private_dot_config/exact_aider-desk/exact_rules/ROUTING-01-ANALYST-DISPATCHER.mdc`
- `private_dot_config/exact_aider-desk/exact_agents/{forge,forge-go,forge-rust,forge-elixir,forge-ruby,forge-typescript,forge-infra,forge-data,forge-shell,forge-lua}/config.json`

## Open / deferred items

- [x] ~~Add `rust` to shiki-mise.toml / rebuild shiki image~~ — **Shiki container retired**;
      container-specific durable fixes (shiki-mise.toml, image rebuild, in-container GPG
      signing) no longer apply. Toolchains are now provisioned via the host mise config.
- [ ] **Design B (optional, if agents ignore the sentinel in practice)**: build an AiderDesk
      extension with an `onToolFinished`-style hook that inspects `power---bash` results for
      `PREFLIGHT_FAIL:` / exit 87 and hard-fails the tool call — true runtime enforcement
      independent of model compliance.
- [ ] Verify per-language allowedPattern covers real project commands as new stacks appear.

## Verification checklist (next time)

- [ ] In a fresh session, edit a `.rs` file → forge-rust runs exit-code probe before cargo.
- [ ] Simulate missing tool → confirm `STATUS: BLOCKED_MISSING_TOOLING` first line + Analyst
      surfaces it to the user instead of reporting success.
- [ ] Confirm sentinel prevents a second probe in the same session.
