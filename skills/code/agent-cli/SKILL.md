---
name: agent-cli
description: Optional command line and MCP server for a macOS app, so Claude Code, Codex, and scripts can drive it (list, add, change, search, act) through the running app. Use when the user wants agents to work with their Mac app or its data, asks for a CLI, an MCP server, or automation for the app, says "Claude should be able to use my app", or asks how agents reach an app on another Apple platform.
argument-hint: "<cli-name, like tasks or mail>"
---

# Agent CLI

Voice and paths follow [CONVENTIONS.md](../../../CONVENTIONS.md).

This skill is macOS only, by design: the CLI reaches the app through a Unix
socket, and only a Mac has a shell next to the app. For the other
platforms, see "Other platforms" at the end.

Give the app a command line, so an agent can do everything a person can
do in the window: `tasks items add --title "Call the dentist"`. The app
binary is the CLI. Each command goes to the running app over a private
socket, runs there like a button press, and the window updates live.

```text
Claude Code --bash--> tasks items add ...  --socket--> Tasks.app (runs the command, saves, redraws)
Claude Desktop --MCP--> tasks mcp           --socket--> same commands, same app
```

## CLI, MCP, or App Intents

| Way in | Who uses it | Ship it |
| --- | --- | --- |
| CLI | Claude Code, Codex, scripts, people in Terminal | Always. Agents learn it from `--help`, and it costs no context until used |
| MCP (`tasks mcp`) | Claude Desktop and other clients with no shell | Optional. The same commands, one tool each. One line to register |
| App Intents | Siri, Spotlight, Shortcuts | Separate work. Agents cannot call them |

The CLI talks to the running app, never to the database file. Then there is
one writer, the app's checks and side effects run, and the window shows the
change at once. If the app is closed, the CLI opens it in the background.
Rules and reasons: [rules.md](rules.md).

## 1. List the commands

Read the user stories (`docs/stories/`). Write each thing a person does as
a command, `<noun> <verb>`, and mark it:

- **read**: `items list`, `items show`, `status`. Safe to run any time.
- **write**: `items add`, `items update`, `open`. Changes data, can be undone.
- **destructive**: `items delete`, `mail send`. Only reports what it would
  do until `--yes` is given.

Add `status` (is it running, what is open, counts) and `open <page>` (show
a page in the window), so an agent can see and steer the app.

Check: every M1 story has its commands, and each command is marked.

## 2. Add the files

```bash
"${CLAUDE_SKILL_DIR}/scripts/add-agent-cli.sh" <app-folder> <cli-name>
```

It copies `Sources/<App>/Agent/` (core, socket, CLI, MCP, example
commands) and `Main.swift`, moves `@main` to `Main.swift`, starts the socket
in the main view's `.task`, and makes `build.sh` link
`~/.local/bin/<cli-name>`. Apps not made from the template: do the same
by hand, following the script.

Check: the script printed "added the agent CLI", and `swift build` passes.

## 3. Write the commands

Replace the examples in `Agent/AgentCommands.swift`. Each command has a
name, a one-line summary, its params, a full example, its mark
(`readOnly` or `destructive`), and a `run` that uses the same model code
as the window's buttons. Never copy logic: call the function the button
calls.

- Every model an agent touches gets `var uuid: UUID = UUID()`. Commands
  show the first 8 characters as `id`, and accept any unique start of it.
- Results are small JSON objects: the fields an agent needs, not the
  whole model. Lists take `--limit` and `--offset`, and return `total`
  and `nextOffset`.
- Errors throw `AgentError` with a message that says how to fix it:
  "no item with id 3f2a. Run `tasks items list`".

All the rules: [rules.md](rules.md).

Check: `<cli-name> help` lists every command from step 1, and
`<cli-name> help <command>` shows its params and example.

## 4. Build and install

```bash
./build.sh
<cli-name> help
```

`build.sh` installs the app and links `~/.local/bin/<cli-name>` to the
binary inside it, so the CLI always matches the app. If the shell cannot
find it, the user adds `~/.local/bin` to `PATH` in `~/.zshrc`.

The link is outside the project. Claude adds it to `tools/footprint.sh` in
the same change (CONVENTIONS section 4): `clean` removes it, and the next
`./build.sh` puts it back.

Check: `<cli-name> --version` prints the app's version, and
`tools/footprint.sh` lists `~/.local/bin/<cli-name>`.

## 5. Test

```bash
"${CLAUDE_SKILL_DIR}/scripts/check-agent-cli.sh" <cli-name> <app-folder>
```

It starts a test copy of the app on `.work/check.store`, with its socket
in `.work/sock/`, checks help, JSON output, error codes, every read
command, and the MCP tool list, then quits the test copy. Then Claude runs
each write command once by hand on the same test database, from the app's
folder. The CLI starts a new test copy, never the real app:

```bash
APP_STORE="$PWD/.work/check.store" APP_AGENT_SOCKET="$PWD/.work/sock/check.sock" <cli-name> items add --title "Test" --json
```

and looks at the test window: the change shows without a reload. Claude
quits that test copy when done.

Check: the script prints `PASS agent CLI`, and no test copy of the app is
still running.

## 6. Teach agents

Write `.claude/skills/<cli-name>/SKILL.md` in the app's repo from
[teach-agents.md](teach-agents.md): what the app is, the safety rules,
the main commands, and "run `<cli-name> help` for the rest". To use the
app from any folder, also copy it to `~/.claude/skills/<cli-name>/` when the
user wants that. That copy is outside the project: Claude adds it to
`tools/footprint.sh` as "listed only" ([teach-agents.md](teach-agents.md),
"Where to put it"). Add
one line to the app's `CLAUDE.md`: "Drive the app with `<cli-name>`. See
`.claude/skills/<cli-name>/SKILL.md`."

Check: a fresh `claude -p "List my starred items with <cli-name>"` finds
the CLI and answers from real data.

## 7. MCP, when the user wants it

For Claude Desktop, or to get one approval prompt per tool:

```bash
claude mcp add --scope user <cli-name> -- ~/Applications/<App>.app/Contents/MacOS/<App> mcp
codex mcp add <cli-name> -- ~/Applications/<App>.app/Contents/MacOS/<App> mcp
```

Claude Desktop: add it to `~/Library/Application Support/Claude/claude_desktop_config.json`
under `mcpServers`, with the full path and `"args": ["mcp"]`. More in
[teach-agents.md](teach-agents.md).

All three registrations live outside the project, in the user's own agent
settings. Claude asks before making each one, and lists each in
`tools/footprint.sh` with the command that removes it.

Check: `claude mcp list` shows the server as connected.

## Other platforms

iOS, iPadOS, tvOS, watchOS, and visionOS apps have no shell beside them and
no Unix socket an agent can reach, so this skill does not apply there.

| Way in | For | Ship it |
| --- | --- | --- |
| App Intents | Siri, Spotlight, Shortcuts, the Action button, and any agent that can run a shortcut | Yes: this is the app's agent-facing surface. Recipes in `bama:os-integrations`, [ios.md](../os-integrations/ios.md) |
| HTTP debug server | Claude during development, driving a simulator or device with `curl` | Development builds only, never in a release build. Call the Skill tool with `debug-server-architect` when the session lists it |

Check: on a non-Mac target, every story action that an agent should reach
is an `AppIntent`, and no socket or debug server code compiles into the
Release configuration.

Done when, on the Mac, every command from step 1 runs through the CLI
against the running app, `check-agent-cli.sh` prints `PASS agent CLI`, the
app's repo has the agent skill from step 6, a fresh Claude Code session can
do a real task with it, and `tools/footprint.sh` lists every file or
registration this skill made outside the project. On other platforms, done
when the check under "Other platforms" holds.
