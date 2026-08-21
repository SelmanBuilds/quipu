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
quipu init      # create .quipu/ + ten layout folders + AGENTS.md/CLAUDE.md bridges (--plain: ASCII folder names)
quipu capture   # append event line(s) to activity.log (stdin or --event/--tool/--path; --git: multi-line tree diff)
quipu index     # build/refresh .quipu/index.tsv (incremental)
quipu search    # folded lexical search + BM25
quipu context   # recent-session context; --json EVENT emits the hook envelope; --bridge writes it to AGENTS.md
quipu remember  # mechanical digest: activity.log → <sessions>/YYYY-MM-DD.md + Last-Session.md pointer (--dry-run/--git/--limit)
```

## Vault layout

`quipu init` creates ten folders (emoji names by default, ASCII with `--plain`):

- **📥 000-Inbox** — capture point for quick, unprocessed notes
- **📥 000-Inbox/Dump** — unsorted dump inside the inbox
- **🎯 100-Command-Center** — dashboard and daily entry point
- **🏰 300-Projects** — active work, one subfolder per project
- **🧠 500-Knowledge** — long-lived notes and references
- **🛠️ 600-Arsenal** — tools, scripts and reusable snippets
- **📆 700-Sessions** — per-session memory, written by `quipu remember`
- **🔮 850-Companion** — companion persona and identity
- **📦 900-Archive** — finished or frozen material
- **📋 Templates** — note templates; copy them, do not edit in place

### Migration and `--plain`

`init` never renames or deletes. A vault created before this layout change keeps its old
folders (`📥 100-Inbox`, `🚧 300-Projects`, `📚 500-Knowledge`) and gains the new ones —
moving notes is yours to do; there is no migration script. `Dashboard.md` is seeded only if
absent, exactly like `Threads.md` and `companion.md`, and never touched again. `📋 Templates`
is deliberately empty: no template note is seeded, because it would enter the index and match
every search.

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

## Search

`quipu search <terms>` folds the query with the vault's fold profile, scores the index with
BM25, and prints the best `--limit` rows (10 by default) as TAB-separated columns:

```
<score>  <path>  <title>  <tags>
```

- `--paths` — print the path column only, one per line: `quipu search dpi --paths | xargs $EDITOR`.
- `--brief` — append a fifth column holding a 120-byte snippet, for the two-stage pattern
  described in [Large vaults](#large-vaults). Mutually exclusive with `--paths` (exit 2).
- Unknown `-`-prefixed arguments are rejected instead of being silently taken as query words:
  `quipu search --nope taskbar` prints `unknown flag: --nope` and exits 2. Bare words are still
  query terms, so `quipu search dpi scale` searches for both.

## Large vaults

The index is meant to be *read* by the agent, and an agent has a context budget. Once the vault
outgrows a single read, the supported pattern is two-stage: **narrow with `--brief`, judge from
the snippets, then read only the notes you picked.**

```
$ quipu search taskbar --limit 50 --brief
0.706	taskbar.md	Taskbar overflow	windows,ui	# taskbar overflow  #windows #ui  the taskbar overflow chevron hides pinned apps whenever the dpi scale of the second
0.675	dpi.md	DPI notes	windows	# dpi notes  #windows  per-monitor dpi awareness, and how the taskbar reacts to it.
$ cat taskbar.md          # the agent opens the two or three it chose, not all fifty
```

Fifty snippets cost a fraction of fifty files, and the choice between them is exactly the
judgement the model in the loop is already good at.

**`--brief` output shape.** The fifth column is TAB-separated like the others and carries the
first **120 bytes** of the folded search field, cut back to the last word boundary. There is no
ellipsis and no marker — nothing to strip before use. A note whose folded field is shorter than
120 bytes prints all of it. `--brief` together with `--paths` is a contradiction (a snippet is
not a path) and exits 2.

**Index size.** `.quipu/index.tsv` is one line per note: path, title, tags, mtime, and the
folded search field capped at 2000 characters. That cap applies to the *index* only — the note
is never modified, and every hit still points at the complete file.

**Honest ceilings.**

- `lib/search.awk` loads the whole index into memory: each line's folded field goes into a
  `folded[]` array before any scoring happens. A few thousand notes are comfortable; tens of
  thousands need a streaming two-pass scorer that never holds the corpus at once. That rewrite
  is a **v2 candidate** — v1 makes no promise beyond the few-thousand range.
- Indexing spawns roughly six child processes per changed file (a subshell plus `awk` for the
  metadata, a subshell plus `sed | tr | awk` for the folded field), so the first index of a
  5000-note vault is slow where `fork` is expensive: **measured 2150-2367 s (~36-39 min) across two runs on Windows
  msys**, and far less on Linux and macOS. Searching that same 5000-row index took **1 s**, so
  the cost is indexing, not querying — and later index runs are incremental, touching only
  changed files. Both numbers come from `tests/run.sh` (T-85/T-86), which prints them on every
  run.
- The snippet is cut with `awk` `substr`/`length`, which count characters in gawk and bytes in
  mawk: identical under `fold=tr`/`fold=latin` (the folded field is ASCII there), but in a
  `fold=default` vault the 120 limit is characters or bytes depending on the platform's awk, and
  a multi-byte character can be split if the first 120 bytes contain no space at all.

**`QUIPU_CTX_MAX` is a different limit.** It bounds the *context* output — the `activity.log`
slice and the `Threads.md` section emitted by `quipu context` (4096 bytes by default). It does
not bound `.quipu/index.tsv`, and a growing vault does not change what it means.

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

## Hook-less agents

Agents without a local hook surface (or where you cannot install one) get two fallbacks
in the core — no config file required:

- **`quipu capture --git`** — diff the working tree against the last commit and append one
  `gitdiff | git | <path>` line per changed Markdown file to `activity.log`. Silent on
  success (0 bytes on stdout). Run it manually before `quipu remember`.
- **`quipu context --bridge`** — write the recent-session context into a dedicated
  `<!-- quipu:context:start -->` / `<!-- quipu:context:end -->` block in `AGENTS.md`; the
  static `<!-- quipu:start -->` block (created by `init`) is left untouched. The agent
  reads `AGENTS.md` to see its memory.

`capture --git` has honest limits (no `Read` events, stateless re-runs) — see
[Honest limits](#honest-limits).

## Status

FAZ 1-5 complete: the seven-command CLI (doctor, init, capture, index, search, context,
remember), three-OS CI, ten-folder vault taxonomy, the Claude Code adapter
(`adapters/claude-code.json` — hooks only, no installer), multi-schema capture
(agent-agnostic, dispatch by payload shape), the Codex adapter
(`adapters/codex/hooks.json` — config only, no installer), and hook-less fallbacks
(`capture --git` + `context --bridge`). OpenCode, Cursor, and Windsurf adapters are
postponed (2026-08-20). See [docs/PLAN.md](docs/PLAN.md).

## Honest limits

- **Folding is lossy**: `açık` and `acık` collapse together — a deliberate trade-off.
- **"Semantic" ≠ cosine similarity**: model judgment, better on meaning but weaker on exhaustive recall.
- **Index context limit**: comfortable up to a few thousand notes; beyond that, two-stage
  narrow-then-read with `--brief` — see [Large vaults](#large-vaults) for the memory,
  process-spawn, and snippet-unit ceilings.
- **`capture --git` is stateless**: it diffs the tree, so it cannot see `Read` events
  (content unchanged), and two runs without a commit append the same files twice — commit
  (or `quipu remember --git`) before re-running. Deletions are captured; the index later
  `drop`s them.

## License

MIT — see [LICENSE](LICENSE).
