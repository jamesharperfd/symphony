# Symphony (Swift)

A Swift implementation of the [Symphony spec](https://github.com/openai/symphony/blob/main/SPEC.md) — a long-running daemon that orchestrates coding agents (Codex) against Linear issues.

## What it does

- Polls Linear for active issues (Todo / In Progress)
- Creates isolated per-issue workspaces
- Launches `codex app-server` for each issue with a rendered prompt from `WORKFLOW.md`
- Streams agent events, tracks retries with exponential backoff
- Cleans up workspaces for completed/cancelled issues

## Usage

```
symphony [--workflow path/to/WORKFLOW.md]
```

Defaults to `WORKFLOW.md` in the current working directory.

## Development

```
swift test      # run all tests
swift build     # build the executable
swift run symphony
```

## Architecture

- `SymphonyCore` — data models, WorkflowLoader, ConfigLayer, LinearClient, WorkspaceManager, AgentRunner, Orchestrator
- `Symphony` — CLI entry point

## Status

Implementation in progress. See Linear issues DB-187 → DB-189.
