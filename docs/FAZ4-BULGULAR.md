# FAZ 4 — Kaynak Bulguları (Dilim 0)

**Belgeleme tarihi:** 2026-08-20 · **Yöntem:** birincil kaynak okuma (`openai/codex`
`codex-rs` + resmi doküman). Doğrulama modeli **"doküman + unverified"** — canlı ölçüm
**YOK** (Codex bu makinede kurulu değil). Bu dosyada **"ölçüldü" iddiası yoktur**: her madde
kaynağına `[kaynak: …]` ile bağlanır; kaynakta fiilen kanıtlanamayanlar ek olarak
`[doğrulanmadı]` taşır. A-1…A-6, `docs/FAZ4-SPEC.md` §1'in Dilim 0 çıktısıdır; tasarım
buna göre yapılır.

---

## A-1 — `hooks.json` şeması [kaynak: hook_config.rs, discovery.rs]

- `type`: `"command"` | `"mcp_tool"` | `"prompt"` | `"agent"`; yalnız `command`/`mcp_tool`
  çalışır, diğerleri "not supported" atlanır.
- **`shell` alanı YOK.** Komut alanları: `command`, `commandWindows` (alias `command_windows`),
  `timeout`, `async`, `statusMessage`, `additionalContextLimit`.
- Kabuk global `CommandShell`'den: Unix `$SHELL`→`/bin/sh -lc`; Windows `$COMSPEC`→`cmd.exe /C`.
- `matcher` handler'da değil **grubunda**: `{ "matcher": …, "hooks": […] }`. Sözdizimi hibrit:
  `*`/`""` = tümü; `[a-zA-Z0-9_|]` = tam-ad (`|` böler); regex karakteri içerirse Rust `regex::is_match`.
- `timeout` varsayılan 600s (min 1); **`SessionEnd` 1s varsayılan, 3s tavan, zorla senkron**;
  `async` varsayılan false; `additionalContextLimit` varsayılan 2500 token.
- Kök sarmalayıcı zorunlu: `{ "description", "hooks": { … } }`; kök seviyede event → unknown field RED.
- Alan adları camelCase, event adları PascalCase (11 event). Konumlar `~/.codex/hooks.json` +
  `<repo>/.codex/hooks.json`, additive birleşim.

## A-2 — araç adları [kaynak: hook_names.rs, apply_patch.rs, shell_command.rs, mcp.rs, common.rs]

- Dosya düzenleme = **`apply_patch`**, shell = **`Bash`** (canonical). `Read`/`Edit`/`Write`/
  `NotebookEdit`/`shell` ayrı dosya aracı **yok**; `Edit`/`Write` yalnız matcher alias'ı (payload'a
  asla serileşmez), `Read` alias'ı bile yok.
- MCP araç adı `mcp__<server>__<tool>`. Matcher `[canonical]+[aliases]` listesine karşı test edilir
  → `Edit|Write` matcher'ı `apply_patch`'i yakalar.

## A-3 — `PostToolUse` payload'ı [kaynak: post-tool-use schema, post_tool_use.rs, apply_patch.rs]

- Top-level snake_case: `session_id`, `turn_id`, `cwd`, `hook_event_name`, `model`, `permission_mode`,
  `tool_name`, `tool_input`, `tool_response`, `tool_use_id`, `transcript_path`. `additionalProperties:
  false` → **top-level `file_path` yok**.
- `tool_input` tipsiz (`true`); **`tool_input.file_path` YOKTUR.** `Bash` → `tool_input={command}`;
  `apply_patch` → `tool_input={command: <patch metni>}` (dosya yolu patch metninin içinde); MCP →
  sunucu şeması.

## A-4 — `additionalContext` enjeksiyonu [kaynak: output_parser.rs]

- Zarf: `{ continue, stopReason, systemMessage, suppressOutput, hookSpecificOutput: { hookEventName
  (zorunlu, camelCase), additionalContext (string) } }`.
- Enjeksiyon: `SessionStart`/`SubagentStart`/`UserPromptSubmit` → JSON **ve** plain stdout;
  `PreToolUse`/`PostToolUse` → yalnız JSON (plain yok sayılır); `Stop`/`PreCompact`/`PostCompact`/
  `PermissionRequest` → yok; `SessionEnd` çıktı şeması bile yok (advisory).

## A-5 — Windows [kaynak: command_runner.rs, command_runner_tests.rs]

- `commandWindows` (primary) / `command_windows` (alias) yalnız Windows'ta `command`'ın yerine geçer.
- Windows'ta komut `cmd.exe /C "<komut>"` (tek tırnaklı ham argüman) çalışır. **`QUIPU_HOOK=1 quipu …`
  POSIX env-öneki cmd.exe'de geçersiz** (`VAR=1 cmd` sözdizimi değil) `[doğrulanmadı — mekanizma
  kaynakta, fiili test yok]`.

## A-6 — feature bayrağı [kaynak: features/lib.rs, legacy.rs, registry.rs]

- Kanonik anahtar `hooks` (`CodexHooks`, `Stable`, **`default_enabled: true` → hook'lar varsayılan
  AÇIK**); `[features] hooks = false` kapatır; deprecated alias `codex_hooks`.
- Okuma oturum kurulumunda **bir kez**; watcher yok → **yeniden başlatma gerekir.**
