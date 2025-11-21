# Task Master: How-to Guide for PRD Updates & Task Management

A practical guide for managing your Task Master workflow, including updating tasks when PRDs change and keeping your task list lean as it grows.

## Table of Contents

1. [Overview](#overview)
2. [Updating Tasks When PRD Changes](#updating-tasks-when-prd-changes)
3. [Managing Large Task Lists (100+ Tasks)](#managing-large-task-lists-100-tasks)
4. [Workflow Best Practices](#workflow-best-practices)
5. [Troubleshooting](#troubleshooting)

---

## Overview

Task Master is designed to evolve with your project. This guide covers two common scenarios:

- **PRD Updates**: Your requirements change mid-project, and you need to reflect those changes in your task list
- **Scale Management**: Your task list grows beyond a manageable size (100+ tasks), and you need strategies to keep your context window lean for AI agents

The strategies here balance maintaining complete historical records with keeping active work focused and efficient.

---

## Updating Tasks When PRD Changes

### Quick Reference

| Scenario | Command | Best For |
|----------|---------|----------|
| Update from specific task onward | `task-master update --from=N --prompt="..."` | Mid-project changes affecting downstream tasks |
| Update with research | `task-master update --from=N --prompt="..." --research` | Changes requiring best-practice investigation |
| Add new PRD to project | `task-master parse-prd new-prd.txt --append` | Additive features or new phases |
| Update all future tasks broadly | `task-master update --from=4 --prompt="Context change"` | Architecture/framework shifts |

### Scenario 1: Minor Updates to Specific Tasks

**Situation**: You've decided to use MongoDB instead of PostgreSQL, and this affects tasks 4 onwards.

**Steps**:

1. Update the PRD document to reflect the MongoDB decision
2. In your AI editor (Cursor, Windsurf, etc.), ask the agent:

   ```text
   We've decided to use MongoDB instead of PostgreSQL. 
   Please update all future tasks (from ID 4) to reflect this change.
   ```

3. Or use the CLI directly:

   ```bash
   task-master update --from=4 --prompt="Now we are using MongoDB instead of PostgreSQL."
   ```

**What happens**:

- Tasks 1-3 (assuming they're database-agnostic or already completed) remain unchanged
- Tasks 4+ are rewritten to incorporate MongoDB instead of PostgreSQL
- Completed tasks remain untouched
- The dependency chain is respected

### Scenario 2: Updates Requiring Research

**Situation**: You're switching frameworks (e.g., Express → Fastify) and want Task Master to research current best practices before updating tasks.

**Steps**:

1. Update your PRD
2. Ask your AI agent:

   ```text
   We're switching from Express to Fastify. 
   Please update all future tasks to reflect this change, 
   researching best practices for this migration.
   ```

3. Or via CLI:

   ```bash
   task-master update --from=5 --prompt="Update to use Fastify, researching best practices" --research
   ```

**What happens**:

- Task Master uses Perplexity (or your configured research model) to find current best practices
- Tasks are updated with informed recommendations
- You get a more robust task description reflecting the latest approaches

**Note**: This requires `PERPLEXITY_API_KEY` to be configured in your environment.

### Scenario 3: Major PRD Changes (Additive Features)

**Situation**: Your project is progressing well, and you want to add a new phase or feature set without disrupting the existing task breakdown.

**Steps**:

1. Create a new PRD file for the new feature/phase:

   ```text
   .taskmaster/docs/prd-phase-2.txt
   ```

2. Parse it with the append flag:

   ```bash
   task-master parse-prd .taskmaster/docs/prd-phase-2.txt --append
   ```

3. Or ask your AI agent:

   ```text
   Please parse the new PRD at .taskmaster/docs/prd-phase-2.txt 
   and append the tasks to our existing task list.
   ```

**What happens**:

- New tasks are added to your task list with IDs continuing from the previous count
- Existing tasks remain unchanged
- You can now see the full picture of both phases
- Tasks are tagged or separated so you can understand which PRD they came from

### Best Practices for PRD Updates

**✅ DO**:

- Update incrementally using the `--from` flag rather than re-parsing the entire PRD
- Preserve completed tasks—they're valuable for historical context and retrospectives
- Use the `--research` flag when architecture/framework decisions require investigation
- Keep your PRD in version control so you can track what changed and when
- Run `task-master list` after updates to verify the changes look correct

**❌ DON'T**:

- Re-parse the entire PRD every time something changes (this loses all progress)
- Manually edit `tasks.json` without understanding task dependencies
- Forget to regenerate task files after major updates with `task-master generate`
- Ignore task dependencies when making updates—let Task Master handle the dependency chain

---

## Managing Large Task Lists (100+ Tasks)

### The Problem

As projects grow, task lists can balloon to 100+ items (completed + pending). This has two issues:

1. **Context Window Bloat**: When you feed 100+ tasks to your AI agent, you consume token budget quickly
2. **Cognitive Overload**: Large lists make it harder to understand what's actually active right now

### The Solution: Tag-Based Workflow with Archival

Task Master natively supports **tags** for managing different task contexts. Combine this with a simple archival strategy to keep everything organized.

### Architecture Overview

```text
.taskmaster/
├── tasks.json                    # Active tasks only
├── tasks-archive.json            # Historical completed tasks
└── archived/
    ├── task_001.txt
    ├── task_002.txt
    └── ...                       # Completed task files
```

### Implementation Steps

#### Step 1: Set Up Tags

Create three main tag contexts:

```bash
# These are conceptual—Task Master manages them automatically
# Just think of your workflow as having three phases:
# - active: Tasks currently being worked on
# - backlog: Planned work not yet started
# - completed: Finished tasks (to be archived)
```

#### Step 2: Move Tasks to Tags

As tasks are completed, move them from `active` to `completed`:

```bash
# Move task 5 from active to completed
task-master move --from=5 --from-tag=active --to-tag=completed

# Move multiple tasks
task-master move --from=5,6,7 --from-tag=active --to-tag=completed
```

Or ask your AI agent:

```text
Please move tasks 5, 6, and 7 to the completed tag.
```

#### Step 3: Archive Completed Tasks Periodically

When you have 20+ completed tasks, archive them:

**Manual archival process**:

1. Export completed tasks (you can query your tasks.json):

   ```bash
   # Extract completed tasks from tasks.json and save to archive
   cat .taskmaster/tasks.json | jq '.tasks[] | select(.status == "done")' > archive-batch-$(date +%Y%m%d).json
   ```

2. Move completed task files to `archived/` directory:

   ```bash
   mkdir -p .taskmaster/archived
   mv .taskmaster/tasks/task_001.txt .taskmaster/tasks/task_002.txt .taskmaster/archived/
   ```

3. Update `tasks.json` to remove archived tasks:

   ```bash
   # Keep only non-completed tasks in tasks.json
   cat .taskmaster/tasks.json | jq '.tasks[] | select(.status != "done")' > tasks-temp.json
   mv tasks-temp.json .taskmaster/tasks.json
   ```

4. Maintain a separate `tasks-archive.json` for historical reference:

   ```bash
   # Append archived batch to the archive file
   cat archive-batch-$(date +%Y%m%d).json >> .taskmaster/tasks-archive.json
   ```

**Or create a script** (save as `scripts/archive-tasks.sh`):

```bash
#!/bin/bash

# Archive completed tasks from Task Master
# Usage: ./scripts/archive-tasks.sh

ARCHIVE_DIR=".taskmaster/archived"
ARCHIVE_FILE=".taskmaster/tasks-archive.json"
TASKS_FILE=".taskmaster/tasks.json"
BATCH_TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$ARCHIVE_DIR"

# Extract completed tasks
jq '.tasks[] | select(.status == "done")' "$TASKS_FILE" > "$ARCHIVE_DIR/batch-$BATCH_TIMESTAMP.json"

# Archive the task files themselves
for task_file in .taskmaster/tasks/task_*.txt; do
    if grep -q '"status": "done"' "$TASKS_FILE"; then
        mv "$task_file" "$ARCHIVE_DIR/" 2>/dev/null || true
    fi
done

# Keep only active/pending tasks in tasks.json
jq '{metadata: .metadata, tasks: [.tasks[] | select(.status != "done")]}' "$TASKS_FILE" > "$TASKS_FILE.tmp"
mv "$TASKS_FILE.tmp" "$TASKS_FILE"

# Append to archive file
if [ -f "$ARCHIVE_FILE" ]; then
    jq -s '.[0] + {tasks: (.[0].tasks + .[1].tasks)}' "$ARCHIVE_FILE" "$ARCHIVE_DIR/batch-$BATCH_TIMESTAMP.json" > "$ARCHIVE_FILE.tmp"
    mv "$ARCHIVE_FILE.tmp" "$ARCHIVE_FILE"
else
    jq '{archived_batches: [.]} "$(cat "$ARCHIVE_DIR/batch-$BATCH_TIMESTAMP.json")" > "$ARCHIVE_FILE"
fi

echo "✅ Archived $(jq '.tasks | length' "$ARCHIVE_DIR/batch-$BATCH_TIMESTAMP.json") completed tasks"
echo "📊 Active tasks remaining: $(jq '.tasks | length' "$TASKS_FILE")"
```

Make it executable:

```bash
chmod +x scripts/archive-tasks.sh
```

Run periodically:

```bash
./scripts/archive-tasks.sh
```

#### Step 4: Keep Your AI Agent Focused

When working with AI agents, provide only the active task list:

```text
Here are your current active tasks (from .taskmaster/tasks.json):
[show only active tasks]

Please tell me what you think the next priority should be.
```

This keeps your context window lean and focused on what matters right now.

### Workflow: The Lean Task Management Cycle

```text
Week 1-2: Active Tasks (15-20 items)
    ↓
    Complete tasks → Mark as done
    ↓
Week 3: Mid-cycle Review
    ↓
    Archive 10-15 completed tasks
    ↓
    Active tasks back to 15-20 items
    ↓
Week 4: Repeat
```

### Querying Your Archive Later

Once tasks are archived, you can still find them:

```bash
# Find archived tasks related to "authentication"
jq '.tasks[] | select(.description | contains("authentication"))' .taskmaster/tasks-archive.json

# View completion statistics
jq '.tasks | length' .taskmaster/tasks-archive.json  # Total archived
jq '.tasks[] | .completedDate' .taskmaster/tasks-archive.json | head -5  # Recent completions
```

---

## Workflow Best Practices

### 1. Keep Your Primary Tasks List Under 50 Items

**Why**: Reduces context window usage and keeps focus clear for AI agents.

**How**: Archive completed tasks when active list grows past 50.

### 2. Version Control Your Task History

Always commit your archive files:

```bash
git add .taskmaster/tasks-archive.json
git add .taskmaster/archived/
git commit -m "Archive: Completed batch of [X] tasks - [date]"
```

This gives you historical insights for retrospectives and planning.

### 3. Tag Tasks for Multi-Phase Projects

If you have multiple features or work streams:

```bash
task-master create-tag user-auth
task-master create-tag api-integration
task-master create-tag ui-redesign

# Move relevant tasks to their tags
task-master move --from=3,4,5 --from-tag=main --to-tag=user-auth
```

This lets you work on one feature at a time without losing sight of others.

### 4. Review Task Dependencies Before Major Updates

```bash
# Check dependency structure
task-master validate-dependencies

# Fix any issues
task-master fix-dependencies
```

This prevents broken dependency chains after updates.

### 5. Regenerate Task Files After Updates

After any significant change to `tasks.json`:

```bash
task-master generate
```

This ensures individual task files (task_001.txt, task_002.txt, etc.) stay in sync with the manifest.

### 6. Use Comments in Your PRD for Future Changes

In your PRD, document decisions that might change:

```markdown
## Architecture Decision: Database

Current choice: PostgreSQL
Rationale: ACID compliance, complex queries
Change considerations: If we need real-time sync, consider MongoDB

## Framework: Express

Current choice: Express.js
Rationale: Lightweight, large ecosystem
Change considerations: If performance critical at scale, evaluate Fastify
```

When requirements change, you have context for why the original decision was made.

---

## Troubleshooting

### Q: I re-parsed the entire PRD and lost my progress. Can I recover?

**A**: If you're using git:

```bash
git log --oneline .taskmaster/tasks.json  # Find the last good commit
git checkout <commit-hash> -- .taskmaster/tasks.json
git checkout <commit-hash> -- .taskmaster/tasks/
```

**Going forward**: Use `task-master update --from=N` for mid-project changes instead of re-parsing.

### Q: My task list is at 150 items and my AI is running out of context. What do I do?

**A**: Immediately archive completed tasks:

```bash
./scripts/archive-tasks.sh
```

Then configure your AI agent to only read active tasks:

- Update your `.cursor/rules/dev_workflow.mdc` to exclude archived tasks
- Or manually provide only the active task subset when prompting

### Q: I'm not sure if a task is really done. Should I mark it complete?

**A**: No—only mark tasks complete once verified. Before marking:

1. Check the task's test strategy (in task_XXX.txt)
2. Run any required tests or validations
3. Ask your AI agent: "Does this meet the acceptance criteria?"
4. Only then: `task-master set-status --id=5 --status=done`

### Q: I have multiple PRDs. Should I parse them all at once or separately?

**A**: Parse them separately with `--append`:

   ```bash
   task-master parse-prd prd-v1.txt          # Initial parse
   task-master parse-prd prd-v2.txt --append # Phase 2
   task-master parse-prd prd-v3.txt --append # Phase 3
   ```

This gives you clear separation and lets you track which PRD each task came from.

### Q: The update command didn't work as expected. What happened?

**A**: Check these things:

1. Are the tasks you're updating marked as `pending` or `done`?

   ```bash
   # Check status
   task-master list | grep "task 4"
   ```

2. Did you use the correct `--from` ID?

   ```bash
   # Should only affect tasks 4 onwards
   task-master update --from=4 --prompt="..."
   ```

3. Did you regenerate files after update?

   ```bash
   task-master generate
   ```

If still not working, check the logs:

```bash
TASKMASTER_LOG_LEVEL=debug task-master update --from=4 --prompt="test"
```

---

## Additional Resources

- [Task Master Documentation](https://docs.task-master.dev/)
- [Task Master GitHub Repository](https://github.com/eyaltoledano/claude-task-master)
- [Task Master Discord Community](https://discord.gg/fWJkU7rf)
- [Command Reference](https://docs.task-master.dev/technical-capabilities/command-reference)

---

## Summary Checklist

**When PRD Changes**:

- [ ] Update your PRD document
- [ ] Use `task-master update --from=N` (not re-parse)
- [ ] Include `--research` flag if best-practices matter
- [ ] Verify changes with `task-master list`
- [ ] Regenerate files with `task-master generate`

**When Task List Grows Large**:

- [ ] Archive completed tasks regularly
- [ ] Keep active list under 50 items
- [ ] Maintain `tasks-archive.json` for historical reference
- [ ] Use tags for multi-phase projects
- [ ] Commit archive changes to git

**Before Major Updates**:

- [ ] Validate dependencies: `task-master validate-dependencies`
- [ ] Review task status: `task-master list`
- [ ] Communicate context to AI agent
- [ ] Have a git commit point if something goes wrong
