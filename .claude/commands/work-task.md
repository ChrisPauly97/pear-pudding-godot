# Work Task

Execute a single task.

## Input

Task ID (e.g., `TID-001`). Find the corresponding file under `tasks/goals/`.

## Steps

1. Read `docs/human/specification.md`.
2. Find and read the task file for the given ID.
3. Check the `Type` field. If `human-action`, follow the **Human-Action Flow** below. Otherwise continue.
4. **Lock check**: inspect the Lock section of the task file.
   - If `Session` is set and `Expires` is in the future → **abort**. Report: "Task is locked by session `<session>` until `<expiry>`. Wait for it to expire or for that session to release it."
   - If `Session` is `none`, the Lock section is absent, or `Expires` is in the past → proceed.
5. Read the parent `goal.md` for broader context.
6. Read relevant docs in `docs/agent/`.
7. **Acquire lock**: write the following to the Lock section of the task file before doing any further work:
   - `Session`: the current worktree name (e.g. `charming-meitner`); if not in a named worktree, use the current branch name.
   - `Acquired`: current UTC timestamp in ISO 8601 format.
   - `Expires`: `Acquired` + 30 minutes.
   - For long operations (Build phase), renew `Expires` (extend by 30 min) before it elapses to prevent false expiry.
8. **Plan**: write the Plan section in the task file.
   - If complexity is high or information is insufficient: present the plan and wait for approval.
   - Otherwise: proceed directly to Build.
9. **Build**: implement the plan.
10. Fill in "Changes Made" and "Documentation Updates" in the task file.
11. Update agent docs (`docs/agent/`) if relevant.
12. Update task status to `done` in the task file, `goal.md`, and `tasks/index.md`.
13. **Release lock**: set `Session: none`, `Acquired: —`, `Expires: —` in the task file.
14. Check for related backlog items (`tasks/backlog/`). Fix code-related ones opportunistically and note in Changes Made.
15. Log any new inconsistencies or gaps discovered during this task as backlog items.
16. Commit: `TID-XXX: <description>`.

## Human-Action Flow

For tasks with `Type: human-action`:

1. Read the task file's Context and Research Notes to understand what the human needs to do.
2. Present the required changes clearly: which file, which sections, what content to add or modify.
3. Wait for the user to confirm the changes are done.
4. Update task status to `done` in the task file, `goal.md`, and `tasks/index.md`.
5. Commit: `TID-XXX: <description>`.

## Branch

Work on the goal's branch: `claude/GID-XXX--short-name`. Create it if it doesn't exist.
