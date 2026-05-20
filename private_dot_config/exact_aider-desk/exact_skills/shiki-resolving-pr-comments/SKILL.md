---
name: shiki-resolving-pr-comments
description: Use when addressing unresolved PR review comments, whether fetched from GitHub or provided by user. Guides analysis of feedback, planning fixes with chat history context, and crafting polite objections when feedback is technically unsound.
---

# Resolving PR Comments

Systematic workflow for addressing unresolved PR review comments with technical rigor.

## Overview

PR comments require thoughtful evaluation before action. This skill guides you through reading feedback, leveraging conversation context, planning fixes, and—when appropriate—crafting respectful refusal responses.

**Core principle:** Evaluate feedback technically. Fix what's valid. Object to what's wrong—politely and with reasoning.

## When to Use

Use this skill when:

- Addressing unresolved PR review comments
- User provides PR feedback to process
- Need to plan fixes across multiple comments
- Feedback requires pushback with explanation

Do not use when:

- Requesting a code review (use shiki-requesting-code-review)
- Performing the review yourself (use shiki-review)
- Already know exactly what to fix (just fix it)

## Input Sources

### GitHub PR Comments

Fetch unresolved comments via GitHub CLI:

```bash
# List open review threads
gh pr view <PR_NUMBER> --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false)'

# Or fetch all comments
gh pr view <PR_NUMBER> --comments
```

### User-Provided Comments

Accept comments pasted directly:

```
User: Here are the unresolved comments from my PR:
1. "Consider using early return here"
2. "This function is too long"
3. "Missing error handling for edge case X"
```

## Workflow

### Phase 1: Gather and Parse

1. **Collect all unresolved comments**
   - Fetch from GitHub OR accept user-provided list
   - Number each comment for tracking

2. **Categorize by type**
   - Blocking: Security, correctness, breaking changes
   - Important: Logic errors, missing coverage, poor patterns
   - Minor: Style, naming, documentation
   - Questionable: May be incorrect or context-missing

3. **Check chat history for context**
   - Review prior discussion about these files/functions
   - Note any architectural decisions already made
   - Identify if feedback conflicts with established direction

### Phase 2: Evaluate Each Comment

For each comment, determine:

```
1. UNDERSTAND: What is the reviewer asking for?
2. VERIFY: Is this technically correct for THIS codebase?
3. CHECK: Does this conflict with prior decisions?
4. DECIDE: Fix, discuss, or decline?
```

**Decision matrix:**

| Condition | Action |
|-----------|--------|
| Feedback is correct and actionable | Plan fix |
| Feedback is correct but needs clarification | Ask question |
| Feedback conflicts with established architecture | Decline with explanation |
| Feedback is technically incorrect | Object with reasoning |
| Feedback lacks context reviewer didn't have | Provide context, offer alternative |
| Feedback is valid but YAGNI applies | Object, explain unused |

### Phase 3: Plan Fixes

For comments requiring fixes:

1. **Group related changes**
   - Multiple comments on same file/function
   - Dependencies between fixes

2. **Order by priority**
   - Blocking issues first
   - Then important
   - Then minor

3. **Draft implementation plan**
   - What changes to make
   - What tests to add/update
   - What to verify after

### Phase 4: Craft Objections

When objecting to feedback, respond with:

**Structure:**
```
1. Acknowledge the concern
2. Provide technical reasoning
3. Reference evidence (code, tests, prior decisions)
4. Offer alternative if applicable
```

**Examples:**

Reviewer suggests removing "legacy" code:
```
This code path handles backward compatibility for clients on API v1.
Removing it would break existing integrations. The bundle ID check on
line 42 is the actual issue—I've fixed that instead.
```

Reviewer suggests feature that's unused:
```
Grepped the codebase—nothing calls this endpoint currently. Per YAGNI,
I'd suggest removing it rather than building out metrics tracking.
Happy to add it back if there's planned usage I'm not aware of.
```

Reviewer's suggestion would break functionality:
```
This would cause [specific breakage]. The current implementation
handles [edge case] which the tests on lines 120-145 verify.
Open to discussing alternative approaches that preserve this behavior.
```

**Tone guidelines:**

- State facts, not defensiveness
- Reference specific code/tests/docs
- Offer alternatives when possible
- No performative agreement or excessive gratitude
- No "I think" hedging—be direct

## Responding in GitHub Threads

**Reply in the thread**, not as a top-level PR comment.

For each resolved comment:
- Reply with brief explanation of fix, OR
- Reply with reasoning for declining

Mark threads as resolved only after addressing them.

## Integration with Other Skills

| Situation | Skill |
|-----------|-------|
| Need to understand feedback before acting | shiki-receiving-code-review |
| Feedback requires debugging first | shiki-systematic-debugging |
| Changes need verification before claiming done | shiki-verification-before-completion |
| Planning multi-file changes | shiki-code-change-discipline |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Batch implementing without reading all comments | Parse ALL comments first, they may be related |
| Performative agreement with wrong feedback | Evaluate technically, push back when appropriate |
| Defensive objection tone | State facts, reference evidence, offer alternatives |
| Fixing symptoms reviewer noticed, not root cause | Trace to actual issue before implementing |
| Ignoring chat history context | Prior decisions may explain current implementation |
| Marking resolved without response | Always reply in thread explaining action taken |

## Checklist

Before starting:
- [ ] All unresolved comments collected
- [ ] Comments numbered and categorized
- [ ] Chat history reviewed for context

For each comment:
- [ ] Understand what's being asked
- [ ] Verify technical correctness
- [ ] Check for conflicts with prior decisions
- [ ] Decision made: fix, discuss, or decline

For fixes:
- [ ] Related changes grouped
- [ ] Implementation plan drafted
- [ ] Changes verified after implementation

For objections:
- [ ] Response acknowledges concern
- [ ] Technical reasoning provided
- [ ] Evidence referenced
- [ ] Alternative offered if applicable

After completion:
- [ ] All threads have replies
- [ ] Resolved threads marked resolved
