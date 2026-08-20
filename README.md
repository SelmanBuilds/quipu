# quipu

Persistent cross-session memory for coding agents — zero dependencies, 100% offline, plain Markdown storage.

- **Zero dependencies**: POSIX sh + sed + awk + grep + tr + git only (no Python, Node, jq).
- **100% offline**, **free**: nothing leaves your machine, no API keys, zero token cost.
- **Cross-platform**: Windows, macOS, Linux — CI-verified on all three.
- **Multilingual**: Turkish and English first-class; other languages via profiles.
- **Multi-agent**: Claude Code, Codex, OpenCode, Cursor, Windsurf, and hook-less agents.
- **Storage**: plain Markdown, no database — your files, no lock-in.

## Why it's free

The semantic layer is the model already in your loop. claude-mem needs a separate vector
database and AI worker because its worker is a separate process with no model inside.
quipu has no such problem: the agent is already running and paid for — the semantic layer
*is* the model itself, so there is no vector database to buy.

## Install

Clone this repository and put the `quipu` script on your `PATH`. Prerequisites:
POSIX sh plus `sed`, `awk`, `grep`, `tr`, and `git`.

## Commands

```
quipu doctor    # environment diagnostics: tools present, agents installed, what's broken
quipu init      # create .quipu/ + five layout folders + AGENTS.md/CLAUDE.md bridges (--plain: ASCII folder names)
quipu capture   # append one line to activity.log (reads a bounded prefix)
quipu index     # build/refresh .quipu/index.tsv (incremental)
quipu search    # folded lexical search + BM25
quipu context   # recent-session context; --json EVENT emits the hook envelope
quipu remember  # mechanical digest: activity.log → <sessions>/YYYY-MM-DD.md + Last-Session.md pointer (--dry-run/--git/--limit)
```

## End-to-end example

```
$ quipu init --lang tr
quipu vault kuruldu: <vault>
dil ayarlandı: tr
yerleşim: emoji
AGENTS.md köprü bloğu hazır
companion.md tohumlandı
sıradaki: quipu index
$ printf '# Çalışma notu\n\nİstanbul üzerine.\n' > not.md
$ quipu index
# indekslendi 3 (yeniden 0, bayat 3, düştü 0)
$ quipu capture < tests/fixtures/posttooluse.json
$ tail -1 .quipu/activity.log
2026-08-20T10:10 | PostToolUse | Read | C:\Users\alice\projects\demo\taskbar_overflow.png
$ quipu search çalışma --paths
not.md
$ quipu context --json SessionStart
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"…"}}
$ quipu doctor; echo $?
özet: 26 ok, 0 uyarı, 0 hata
0
```

Outputs are Turkish because the vault was initialized with `--lang tr`.

## Claude Code

The `adapters/claude-code.json` adapter wires quipu into Claude Code's local hooks:
`SessionStart` injects recent-session context, `PostToolUse` captures `Edit|Write|NotebookEdit|Read`
events into `activity.log` (async, silent), `UserPromptSubmit` nudges the model to write memory
once a staleness threshold is crossed, and `SessionEnd` (backed by a `SessionStart`-chained
`remember`) writes the mechanical digest.

Merge this `hooks` block into `~/.claude/settings.json` (identical to `adapters/claude-code.json`,
which you can also copy):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "shell": "bash",
                     "command": "QUIPU_HOOK=1 quipu remember && QUIPU_HOOK=1 quipu context --json SessionStart",
                     "timeout": 10 } ] }
    ],
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "shell": "bash",
                     "command": "QUIPU_HOOK=1 quipu context --json UserPromptSubmit",
                     "timeout": 10 } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|NotebookEdit|Read",
        "hooks": [ { "type": "command", "shell": "bash",
                     "command": "QUIPU_HOOK=1 quipu capture",
                     "timeout": 10, "async": true } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "shell": "bash",
                     "command": "QUIPU_HOOK=1 quipu remember",
                     "timeout": 30 } ] }
    ]
  }
}
```

`quipu` must be on your `PATH` for the hooks. On Windows, Git for Windows puts only
`cmd/` on `PATH` — if a hook reports `Executable not found in $PATH: bash`, add
`C:\Program Files\Git\bin` to `PATH` (or write the absolute bash path in the `shell` field).

If `quipu` is not on `PATH`, write its absolute path in each `command`. The cygpath
conversion pattern for Windows is documented in PLAN §4.7 — it is **not** embedded in
the adapter.

**Restart Claude Code after editing `settings.json` — hook configuration is not loaded
into a running session.**

`quipu remember --git` auto-commits the vault (`--git` is opt-in; the adapter never
commits by itself).

Env knobs: `QUIPU_CTX_MAX`, `QUIPU_NUDGE_AFTER`, `QUIPU_LOG_MAX`, `QUIPU_HOOK`.

## Codex

The `adapters/codex/hooks.json` adapter wires quipu into Codex CLI's local hooks:
`SessionStart` chains `remember` + context injection, `UserPromptSubmit` nudges the model,
`PostToolUse` captures `apply_patch` events into `activity.log` (async, silent), and
`SessionEnd` runs the `remember` digest.

Copy `adapters/codex/hooks.json` to `~/.codex/hooks.json` (global) or `.codex/hooks.json`
(project-scoped). There is no installer. Hooks are **enabled by default** — no `config.toml`
flag is required; to disable them, set `[features] hooks = false`.

`quipu` must be on your `PATH` for the hooks.

**Restart Codex after installing the hook file — hook configuration is read once at session
setup; there is no watcher.**

Windows: the `commandWindows` fields run under `cmd.exe /C` via the
`set QUIPU_HOOK=1&& quipu …` pattern. A POSIX env prefix (`QUIPU_HOOK=1 quipu …`) is not
valid in `cmd.exe`. This is not yet verified against a live Codex install.

Honest limits: only `apply_patch` is captured. `Bash` commands and `Read` are not captured
(Codex has no `Read` tool), and file deletions (`+++ /dev/null`) are skipped.

## Status

FAZ 1-4 complete: the seven-command CLI (doctor, init, capture, index, search,
context, remember), three-OS CI, five-folder vault taxonomy, the Claude Code
adapter (`adapters/claude-code.json` — hooks only, no installer), multi-schema
capture (agent-agnostic, dispatch by payload shape), and the Codex adapter
(`adapters/codex/hooks.json` — config only, no installer). OpenCode, Cursor, and
Windsurf adapters are postponed (2026-08-20). See [docs/PLAN.md](docs/PLAN.md).

## Honest limits

- **Folding is lossy**: `açık` and `acık` collapse together — a deliberate trade-off.
- **"Semantic" ≠ cosine similarity**: model judgment, better on meaning but weaker on exhaustive recall.
- **Index context limit**: comfortable up to a few thousand notes; beyond that, two-stage narrow-then-read.

## License

MIT — see [LICENSE](LICENSE).
