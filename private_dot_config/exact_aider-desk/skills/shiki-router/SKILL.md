---
name: shiki-router
description: "Classify user requests into 7 workflow types and auto-route to appropriate Shiki skill. Type 1-3: Discovery/Planning, Type 4: Implementation, Type 5: Debugging, Type 6: Verification, Type 7: Ideation."
license: Apache-2.0
---

# Shiki Router

Classify user requests into 7 workflow types and auto-route to appropriate Shiki skill.

## When to Use

**Before activating ANY skill, classify the request type and route accordingly.**

## The 7 Workflow Types

| Type | Name | Triggers | Entry Skill |
|------|------|----------|-------------|
| **1** | Discovery | "I have an idea...", "explore", "what if" | `shiki-start` |
| **2** | Requirements | "Create PRD", "requirements", "specs" | `shiki-prd` |
| **3** | Task Breakdown | "Break into tasks", "implementation plan" | `shiki-plan` |
| **4** | Implementation | "Implement", "build", "fix", "add" | Via Decision Point Gate |
| **5** | Debugging | "Bug", "error", "crash", "failing" | `shiki-systematic-debugging` |
| **6** | Verification | "Verify", "review", "check quality" | `shiki-verify` |
| **7** | Ideation | "Brainstorm", "generate ideas", "think of" | `shiki-brainstorming` |

## Type 1 - Discovery

**Keywords:** explore, discover, thinking about, what if, idea

**Action:** `shiki-start` → `shiki-summarize` → `shiki-prd`

**Example:**
```
User: "I have an idea for a new dashboard feature"
Route: shiki-start
```

## Type 2 - Requirements

**Keywords:** PRD, requirements, user stories, acceptance criteria, specs

**Action:** `shiki-prd`

**Example:**
```
User: "Create a PRD for the authentication system"
Route: shiki-prd
```

## Type 3 - Task Breakdown

**Keywords:** break down, tasks, implementation plan

**Precondition:** PRD exists

**Action:** `shiki-plan`

**Example:**
```
User: "Break this PRD into implementation tasks"
Route: shiki-plan
```

## Type 4 - Implementation

**Keywords:** implement, build, fix, add, proceed with, continue

**Action:** Complete Decision Point Gate → appropriate implementation skill

### Implementation Routing Logic

```
Implementation Request
        │
        ▼
Bug detected? ──YES──► shiki-systematic-debugging
        │ NO
        ▼
Multiple failures ──YES──► shiki-dispatching-parallel-agents
  across domains?         │
        │ NO              │
        ▼                 │
User says "all"? ◄────────┘
        │
   YES ─┴──► tasks > 10? ──YES──► shiki-two-stage-review-execution
        │           │ NO
        │           ▼
        │    shiki-implement
        ▼ (NO)
User says specific task ──► shiki-implement (single task)
```

### Implementation Routing Rules

| Condition | Action | Skill |
|-----------|--------|-------|
| Bug keywords | Debug first | `shiki-systematic-debugging` |
| Multiple independent failures | Parallel investigation | `shiki-dispatching-parallel-agents` |
| "all" + tasks > 10 | Two-stage review | `shiki-two-stage-review-execution` |
| "all" + tasks ≤ 10 | Direct execution | `shiki-implement` |
| Specific task | Single task | `shiki-implement` |

### Bug Detection Keywords

**Keywords:** bug, error, failure, crash, not working, broken, fix, stack trace, exception, test failing

**Examples:**
```
User: "Fix the bug in the payment module"
Route: shiki-systematic-debugging

User: "Tests are failing with NullPointerException"
Route: shiki-systematic-debugging
```

### Implementation Examples

**Large project (all tasks):**
```
User: "Proceed with all 54 tasks"
Route: shiki-two-stage-review-execution
```

**Small project (all tasks):**
```
User: "Implement all 7 tasks"
Route: shiki-implement
```

**Specific task:**
```
User: "Implement task 3: Create API client"
Route: shiki-implement
```

## Type 5 - Debugging

**Keywords:** bug, error, crash, failure, test failing, not working, broken, exception, stack trace

**Action:** `shiki-systematic-debugging`

**Example:**
```
User: "The app crashes when I try to login"
Route: shiki-systematic-debugging
```

## Type 6 - Verification

**Keywords:** verify, review, check quality, audit, validate

**Action:** `shiki-verify` (spec-driven) or `shiki-review` (code quality)

**Example:**
```
User: "Verify the implementation meets requirements"
Route: shiki-verify

User: "Review the code for quality issues"
Route: shiki-review
```

## Type 7 - Ideation

**Keywords:** brainstorm, generate ideas, think of, explore solutions

**Action:** `shiki-brainstorming`

**Example:**
```
User: "Brainstorm ways to improve the search feature"
Route: shiki-brainstorming
```

## Quick Reference Table

| User Says | Type | Route To |
|-----------|------|----------|
| "I have an idea for X" | 1 Discovery | `shiki-start` |
| "Create a PRD for X" | 2 Requirements | `shiki-prd` |
| "Break down into tasks" | 3 Task Breakdown | `shiki-plan` |
| "Implement X" | 4 Implementation | Decision Point Gate |
| "Fix this bug" | 4 Implementation → Bug | `shiki-systematic-debugging` |
| "Proceed with all tasks" | 4 Implementation → All | Decision Point Gate |
| "Verify the code" | 6 Verification | `shiki-verify` |
| "Review for quality" | 6 Verification | `shiki-review` |
| "Brainstorm ideas" | 7 Ideation | `shiki-brainstorming` |

## Decision Point Gate

For Type 4 (Implementation), you MUST complete the Decision Point Gate before proceeding.

**See `using-shiki` for the complete Decision Point Gate template.**

## Integration

This router is used by:
- **using-shiki** - Entry point for all Shiki workflows
- **shiki-mode-enforcer** - Mode-specific routing validation
- **shiki-compact-recovery** - Restoring workflow state

## Remember

- Always classify the request type before activating any skill
- Use the Decision Point Gate for Type 4 (Implementation) requests
- Follow the routing logic to choose the appropriate implementation skill
- Bug detection takes priority in Type 4 requests
