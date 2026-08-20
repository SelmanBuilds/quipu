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
quipu init      # create .quipu/ + AGENTS.md bridge block
quipu capture   # append one line to activity.log (reads a bounded prefix)
quipu index     # build/refresh .quipu/index.tsv (incremental)
quipu search    # folded lexical search + BM25
quipu context   # recent-session context; --json EVENT emits the hook envelope
```

## End-to-end example

```
$ quipu init --lang tr
quipu vault kuruldu: <vault>
dil ayarlandı: tr
AGENTS.md köprü bloğu hazır
$ printf '# Çalışma notu\n\nİstanbul üzerine.\n' > not.md
$ quipu index
# indekslendi 1 (yeniden 0, bayat 1, düştü 0)
$ quipu capture < tests/fixtures/posttooluse.json
$ tail -1 .quipu/activity.log
2026-08-20T10:10 | PostToolUse | Read | C:\Users\alice\projects\demo\taskbar_overflow.png
$ quipu search çalışma --paths
not.md
$ quipu context --json SessionStart
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"…"}}
$ quipu doctor; echo $?
özet: 20 ok, 0 uyarı, 0 hata
0
```

Outputs are Turkish because the vault was initialized with `--lang tr`.

## Status

FAZ 1 is complete: the six-command core CLI, primitives, and the three-OS CI matrix.
FAZ 2 — vault taxonomy and identity — is next. See [docs/PLAN.md](docs/PLAN.md).

## Honest limits

- **Folding is lossy**: `açık` and `acık` collapse together — a deliberate trade-off.
- **"Semantic" ≠ cosine similarity**: model judgment, better on meaning but weaker on exhaustive recall.
- **Index context limit**: comfortable up to a few thousand notes; beyond that, two-stage narrow-then-read.

## License

MIT — see [LICENSE](LICENSE).
