---
tracker:
  kind: linear
  project_slug: daniel-bernal
  api_key: $LINEAR_API_KEY
polling:
  interval_ms: 30000
workspace:
  root: ~/symphony_workspaces
hooks:
  after_create: |
    git clone https://github.com/afterxleep/flowdeck.git .
    git worktree add -b kai/${ISSUE_IDENTIFIER} . main
agent:
  max_concurrent_agents: 3
codex:
  command: codex app-server
  approval_policy: never
  turn_timeout_ms: 3600000
  stall_timeout_ms: 300000
---

You are working on Linear issue {{ issue.identifier }}: {{ issue.title }}

{{ issue.description }}

Follow the repo AGENTS.md. Write tests first. Commit and push when done. Open a PR.
