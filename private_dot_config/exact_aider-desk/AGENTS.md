# AIDERDESK CONFIGURATION

## OVERVIEW

Managed AiderDesk profiles, shared rules, and a Shiki skill library.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Agent identity and behavior | `exact_agents/<agent>/config.json` | Provider/model, instructions, tool approvals, subagent settings |
| Agent display order | `exact_agents/order.json` | Map of profile IDs to numeric positions |
| Agent-scoped rules | `exact_agents/<agent>/exact_rules/` | Markdown rules attached to individual profiles |
| Shared rules | `exact_rules/` | `.md` plus `.mdc` rules with activation metadata |
| Skill definitions and support files | `exact_skills/<skill>/` | `SKILL.md`, optional scripts, templates, and CSV references |
| Commands | `exact_commands/` | Currently contains only `.gitkeep` |
| Operational notes | `exact_docs/tooling-preflight-NOTES.md` | Supporting documentation for tooling preflight |

## CONFIGURATION CONVENTIONS

- Keep profile directory names, JSON `id` values, and `order.json` entries
  consistent when adding or renaming agents.
- Preserve JSON nesting for `toolApprovals`, `toolSettings`, and `subagent`.
  Approval values and shell allow/deny patterns change the agent's authority.
- Shared `.mdc` rules carry YAML fields such as `description`, `globs`, and
  `alwaysApply`; scoped `.md` copies may contain only the rule body.
  Compare both locations when changing a rule; preserve their distinct scope.
- Keep skill frontmatter and referenced support files together. The library's
  dispatch, review, commit, and recovery workflows describe deployed behavior;
  editing these files does not activate those workflows for the current task.

## DEPLOYMENT BOUNDARY

- The root hook `.chezmoiscripts/run_onchange_after_link-aider-desk-home.sh.tmpl`
  links existing `agents`, `rules`, `commands`, `prompts`, and `skills` directories
  from `~/.config/aider-desk` into `~/.aider-desk`.
- The hook skips missing managed directories; `exact_docs` is not in its link map.
  Existing real destinations are backed up before links replace them.
- Keep app-managed `extensions`, `tmp`, `data`, and `runtime` out of that map.
  Project `.aider-desk/tasks/` content is task state, not profile source.
- Classic Aider uses sibling `../private_aider/aider.conf.yml`; changes there do
  not configure these AiderDesk agents.

## SHIKI PLAN SCRIPT CAVEATS

- `exact_skills/shiki-plan/scripts/requirements.txt` declares `networkx>=3.0`
  and `mistletoe>=1.4.0`.
- `analyze_dependencies.py <tasks.md> [output_dir]` calls `AnalysisEngine.run`,
  which rewrites the input task file with derived dependency metadata.
- The CLI also writes `dependency-graph.mmd`, `parallelization-analysis.md`, and
  `parallelization-analysis.json`; the output directory defaults to the input's
  parent. Use a disposable input copy for future execution checks.
- `test_analyze_dependencies.py` uses `unittest` for rendering/AST checks.
  `test_full_analysis_pipeline` is a `pass` placeholder; a green suite does not
  establish end-to-end dependency analysis or input-rewrite coverage.
