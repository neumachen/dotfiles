---
name: shiki-code-change-discipline
description: "Mandatory inspection and minimal-change discipline for code modifications. Use before any file edit to understand existing code, find dependencies, and preserve conventions."
license: Apache-2.0
---

# Code Change Discipline

Mandatory inspection before any code modification. Ensures changes are minimal, informed, and preserve existing conventions.

## When to Use

Use this skill when:

- About to modify any source file
- About to add new functionality
- About to fix a bug
- About to refactor code

Do not use when:

- Only reading files for analysis
- Creating brand new files in empty directories
- Modifying configuration files only

## Rules

### Rule: Inspect before edit

**When:** About to modify any file

**Then:** Complete inspection checklist

**Inspection checklist:**
1. Read the file completely - understand current implementation
2. Find call sites - who uses this code? (`grep`, `semantic_search`)
3. Find imports/dependencies - what does this code use?
4. Identify tests - what tests cover this code?
5. Understand patterns - what conventions does this codebase follow?

**Never:** Modify a file without reading it first.

### Rule: Minimal change principle

**When:** Implementing any change

**Then:** Apply minimal change rules

**Minimal change rules:**
- Make the smallest change that accomplishes the task
- Do not refactor adjacent code unless explicitly tasked
- Do not "improve" code outside the task scope
- Do not add features not specified in the task
- Preserve existing code style, naming, and patterns

**Exception:** If adjacent code must change to accomplish the task, document why.

### Rule: Preserve existing conventions

**When:** Writing new code or modifying existing code

**Then:** Match existing patterns

**Conventions to preserve:**
- Error handling patterns (how errors are created, wrapped, returned)
- Naming conventions (case, abbreviations, prefixes)
- Code organization (where helpers go, how modules are structured)
- Testing patterns (table-driven vs individual, assertion style)
- Comment style (when and how comments are used)

**Detection method:**
- Find 2-3 similar functions/files in the codebase
- Extract common patterns
- Apply same patterns to new code

### Rule: Document assumptions

**When:** Making any assumption about behavior

**Then:** State assumption explicitly

**Assumption examples:**
- "Assuming this function is not called concurrently"
- "Assuming error handling follows the pattern in service.go"
- "Assuming tests should go in the same directory"

### Rule: Risk assessment before commit

**When:** Completing implementation

**Then:** Assess and report risk

**Risk assessment checklist:**
- What could this change break?
- What's the blast radius (one file, one package, whole system)?
- Are there edge cases not covered by tests?
- Does this change require updates elsewhere (docs, config, migrations)?

### Rule: Complexity threshold for fast path

**When:** Change is trivial

**Then:** Use fast path with reduced inspection

**Fast path criteria (ALL must be true):**
- Change affects ≤ 1 file
- Change is ≤ 10 lines
- Change is isolated (no API changes, no new dependencies)
- Change type is: typo fix, comment update, simple bug fix with clear cause

**Fast path inspection:**
- Read the affected file (still required)
- Skip call site analysis
- Skip broader pattern analysis
- Proceed to implementation

**If any criterion fails:** Use full inspection.

## Process

1. Read task requirements
2. Identify files to modify
3. Check fast path criteria
4. **If fast path:** Read affected file, implement, verify
5. **If full path:** Complete full inspection checklist for each file
6. Identify existing patterns to preserve
7. Plan minimal change
8. Implement change
9. Verify tests pass
10. Assess risk
11. Document any assumptions

## Preconditions

Before using this skill, verify:

- Task requirements are clear
- Files to modify are identified
- Inspection can be completed (files readable)

## Postconditions

After completing this skill, verify:

- All modified files were read before editing
- Change is minimal and focused
- Existing conventions preserved
- Assumptions documented
- Risk assessed

## Success Metrics

This skill is successful when:

- No file modified without prior reading
- Change diff is minimal for task scope
- No "drive-by" refactoring
- Existing patterns matched
- Risk explicitly stated

## Integration

This skill is invoked by:
- **shiki-implement** - Before any file modification
- **shiki-two-stage-review-execution** - During task execution
- **shiki-systematic-debugging** - Before implementing fixes

## Common Situations

**Situation:** Adding new function to existing file

**Pattern:**
- Read entire file first
- Find similar functions, note their structure
- Write new function matching existing style
- Place in appropriate location (grouped with related functions)

**Situation:** Fixing bug in complex function

**Pattern:**
- Read function and its callers
- Understand all code paths
- Make minimal fix at root cause
- Do not refactor the function
- Add test for bug scenario

**Situation:** Unclear existing conventions

**Pattern:**
- Search for 3+ similar examples
- If patterns conflict, ask for clarification
- If no patterns found, state assumption and proceed

**Situation:** Change requires modifying multiple files

**Pattern:**
- Inspect each file before modifying
- Understand how files relate to each other
- Plan changes across files before starting
- Implement in dependency order (dependencies first, dependents second)
