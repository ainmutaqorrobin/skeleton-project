# Developer Guideline

> Last updated: 05 April 2026, 01:43 AM MYT

## Purpose

This file is for contributors changing the `skeleton-project` repository itself. It explains how to update this template repo cleanly so future projects and future contributors inherit consistent rules and structure.

## What This File Covers

- Updating repository guidance
- Updating AI instruction sources
- Regenerating generated AI docs
- Knowing which files should and should not be edited directly
- Knowing what to include in a commit when the skeleton itself changes

It does not repeat the full technical standards for apps. Those belong in the template content and AI rule sources.

## Source Of Truth

Use these locations intentionally:

- Human-facing repo guidance:
  - `README.md`
  - `GUIDELINE.md`
  - `TEMPLATE.md`
- AI instruction source templates:
  - `.ai/rules/`
- Generated AI files:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `apps/*/AGENTS.md`
  - `apps/*/CLAUDE.md`

## What To Edit

If you are changing the skeleton's developer-facing documentation:

- Edit `README.md`, `GUIDELINE.md`, and/or `TEMPLATE.md`

If you are changing guidance that Claude Code or Codex should follow:

- Edit the matching file in `.ai/rules/`
- Re-run the sync script
- Commit the generated `AGENTS.md` and `CLAUDE.md` outputs together with the source template change

If you are changing example/template content inside the skeleton:

- Edit the relevant file under `apps/`, `packages/`, root docs, or config files
- Update docs if the change alters expected contributor workflow

## Do Not Edit These Directly

These are generated from `.ai/rules/`:

- `AGENTS.md`
- `CLAUDE.md`
- `apps/api/AGENTS.md`
- `apps/api/CLAUDE.md`
- `apps/frontend/AGENTS.md`
- `apps/frontend/CLAUDE.md`
- `apps/common/AGENTS.md`
- `apps/common/CLAUDE.md`
- `apps/docker/AGENTS.md`
- `apps/docker/CLAUDE.md`
- `apps/packages/AGENTS.md`
- `apps/packages/CLAUDE.md`

If one of those files needs different content, change `.ai/rules/` and regenerate.

## When To Run The Sync Script

Run one of these only after editing `.ai/rules/`:

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-agent-docs.ps1
```

macOS or Linux:

```bash
bash ./scripts/sync-agent-docs.sh
```

Do not run the sync script for normal code or doc changes that do not affect `.ai/rules/`.

## Commit Checklist For Skeleton Changes

Before committing changes to this repo, check the following:

- If you changed human docs, the related docs were updated consistently
- If you changed `.ai/rules/`, the generated AI files were regenerated
- If you changed repo workflow meaningfully, `.ai/RULES_STATUS.md` was updated when appropriate
- Generated files were not hand-edited
- The diff is intentional and not just tooling noise

## Typical Change Scenarios

If you update developer workflow wording:

- Edit `README.md`, `GUIDELINE.md`, or `TEMPLATE.md`
- Do not regenerate AI files unless AI guidance also changed

If you update AI behavior or tool-specific instructions:

- Edit `.ai/rules/...`
- Run the sync script
- Commit both the source rule and generated outputs

If you update both human workflow and AI workflow:

- Update the human docs
- Update `.ai/rules/...`
- Run the sync script
- Update `.ai/RULES_STATUS.md` if the rules were meaningfully reviewed

## Related Files

- `README.md`: high-level project overview
- `GUIDELINE.md`: contributor workflow for maintaining this skeleton repo
- `TEMPLATE.md`: broader narrative reference
- `.ai/rules/`: source templates for AI instruction files
- `.ai/RULES_STATUS.md`: human-tracked last review timestamp for AI rules
