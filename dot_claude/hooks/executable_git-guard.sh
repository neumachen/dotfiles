#!/usr/bin/env bash
# PreToolUse/Bash guard: refuse force pushes, hand-moved published refs, and
# attempts to remove the GitHub-side branch protection. Reads the hook payload
# on stdin and answers with a PreToolUse permission decision.
set -uo pipefail

# Fail closed: a guard that cannot inspect the command must not wave it through.
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"git guard cannot run: jq is not on PATH. Fix or remove the hook deliberately rather than leaving it failing open."}}'
  exit 0
fi

cmd=$(jq -r '.tool_input.command // empty') || {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"git guard could not parse the hook payload."}}'
  exit 0
}
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Collapse whitespace so "git   -C  x   push" reads like "git -C x push".
norm=$(printf '%s' "$cmd" | tr '\n' ' ' | tr -s '[:space:]' ' ')
has() { printf '%s' "$norm" | grep -Eq "$1"; }

# A git invocation reaching `push`, whatever sits between (-C <path>, --git-dir=...).
GITPUSH='(^|[;&|]|\s)git\b[^;&|]*\spush\b'

has "${GITPUSH}[^;&|]*\s(-f|--force|--force-with-lease|--force-if-includes)(\s|=|$)" &&
  deny "Force push blocked by the local git guard. Protected branches are enforced server-side by the protect-main ruleset; resolve a rejected push by integrating the remote commits, never by overriding it."

has "${GITPUSH}[^;&|]*\s\+[A-Za-z0-9_./-]+" &&
  deny "Force push spelled as a +refspec blocked by the local git guard."

has "${GITPUSH}[^;&|]*\s(-d|--delete)(\s|$)" &&
  deny "Remote branch deletion blocked by the local git guard."

has "${GITPUSH}[^;&|]*\s:[A-Za-z0-9_./-]+" &&
  deny "Remote branch deletion spelled as a :refspec blocked by the local git guard."

# Moving a published ref by hand - the gap a plain `git reset` deny leaves open.
has '(^|[;&|]|\s)git\b[^;&|]*\s(update-ref|filter-branch|filter-repo)\b' &&
  deny "Direct ref manipulation blocked by the local git guard. Move a branch with an ordinary commit, not by rewriting its ref."

# Removing or weakening the protection itself.
if has '(^|[;&|]|\s)gh\b[^;&|]*\sapi\b' &&
   has '\s(-X|--method)\s+(DELETE|PATCH|PUT)\b' &&
   has '(rulesets|branches/[^ ]+/protection)'; then
  deny "Changing or deleting branch protection is blocked by the local git guard."
fi

has '(^|[;&|]|\s)gh\b[^;&|]*\sruleset\b[^;&|]*\s(delete|edit)\b' &&
  deny "Changing or deleting branch protection is blocked by the local git guard."

exit 0
