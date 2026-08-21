# quipu — FAZ 4 SPEC (REVİZE): çok-şemalı capture + Codex adaptörü

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: `docs/PLAN.md` §2 (dört katman), §5 (ajan yüzeyleri), §6 FAZ 4, §4.18 (FAZ 3 ölçüm dersleri).
> Ön koşul: FAZ 3 tamam (PR #3 merged, `39d79cd`) + `docs/FAZ3-DUZELTME.md` uygulandı.
> Sözleşme numaraları **K-n** (FAZ 3'ün C-n'leriyle, FAZ 2'nin B-n/D-n'leriyle çakışmaz).
>
> **Revizyon nedeni:** İlk FAZ4-SPEC "Codex ≈ Claude Code, capture aynı çalışır, çekirdeğe dokunulmaz"
> öncülü üzerine kuruluydu. Kaynak araştırması (birincil kaynak: `openai/codex` `codex-rs` + resmi
> doküman) bu öncülü **çürüttü**: Codex `tool_input.file_path` üretmiyor (`apply_patch` patch metni,
> `Bash` komut üretiyor; `Read` aracı hiç yok). Bu yüzden FAZ 4 artık **capture'ı ajan-agnostik
> çok-şemalı yapan** bir çekirdek işidir; Codex adaptörü bunun üzerine config-only oturur.
> Doğrulama modeli **"doküman + unverified"**: canlı ölçüm yok (Codex bu makinede kurulu değil);
> her iddia `[kaynak: …]` ve gerektiğinde `[doğrulanmadı]` taşır.

## 0. Bu fazın tek cümlelik ölçütü

> **`quipu capture` ajan-agnostik çok-şemalı olur; Codex adaptörü bunun üzerine yalnızca bir
> `hooks.json` + `config.toml` bayrak dokümanı olarak oturur.** Claude Code şeması regresyonsuz
> korunur; Codex'in `apply_patch` şeması eklenir.

FAZ 3'ün "adaptör config dosyasından ibarettir, yeni çekirdek kod = core yanlış tasarlandı"
ilkesi Claude Code'da tuttu çünkü `PostToolUse` payload'ı `capture`'ın beklediği biçimdeydi.
Kaynak araştırması bunun **ajan-özgü bir şans** olduğunu gösterdi — başka ajanlar aynı şemayı
üretmiyor. Bu faz, bu ilkenin yanlış genellemesini düzeltir: capture çok-şemalı olur, adaptörler
config-only kalır.

---

## 1. Kaynak araştırması — yerleşik bulgular (A-1…A-6)

Dilim 0'ın çıktısıdır; tasarım buna göre yapılır. **Canlı doğrulama yok**, tüm iddialar
`[kaynak]`, kaynakta fiilen kanıtlanamayanlar ek olarak `[doğrulanmadı]`.

### A-1 — `hooks.json` şeması [kaynak: hook_config.rs, discovery.rs]

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

### A-2 — araç adları [kaynak: hook_names.rs, apply_patch.rs, shell_command.rs, mcp.rs, common.rs]

- Dosya düzenleme = **`apply_patch`**, shell = **`Bash`** (canonical). `Read`/`Edit`/`Write`/
  `NotebookEdit`/`shell` ayrı dosya aracı **yok**; `Edit`/`Write` yalnız matcher alias'ı (payload'a
  asla serileşmez), `Read` alias'ı bile yok.
- MCP araç adı `mcp__<server>__<tool>`. Matcher `[canonical]+[aliases]` listesine karşı test edilir
  → `Edit|Write` matcher'ı `apply_patch`'i yakalar.

### A-3 — `PostToolUse` payload'ı [kaynak: post-tool-use schema, post_tool_use.rs, apply_patch.rs]

- Top-level snake_case: `session_id`, `turn_id`, `cwd`, `hook_event_name`, `model`, `permission_mode`,
  `tool_name`, `tool_input`, `tool_response`, `tool_use_id`, `transcript_path`. `additionalProperties:
  false` → **top-level `file_path` yok**.
- `tool_input` tipsiz (`true`); **`tool_input.file_path` YOKTUR.** `Bash` → `tool_input={command}`;
  `apply_patch` → `tool_input={command: <patch metni>}` (dosya yolu patch metninin içinde); MCP →
  sunucu şeması.

### A-4 — `additionalContext` enjeksiyonu [kaynak: output_parser.rs]

- Zarf: `{ continue, stopReason, systemMessage, suppressOutput, hookSpecificOutput: { hookEventName
  (zorunlu, camelCase), additionalContext (string) } }`.
- Enjeksiyon: `SessionStart`/`SubagentStart`/`UserPromptSubmit` → JSON **ve** plain stdout;
  `PreToolUse`/`PostToolUse` → yalnız JSON (plain yok sayılır); `Stop`/`PreCompact`/`PostCompact`/
  `PermissionRequest` → yok; `SessionEnd` çıktı şeması bile yok (advisory).

### A-5 — Windows [kaynak: command_runner.rs, command_runner_tests.rs]

- `commandWindows` (primary) / `command_windows` (alias) yalnız Windows'ta `command`'ın yerine geçer.
- Windows'ta komut `cmd.exe /C "<komut>"` (tek tırnaklı ham argüman) çalışır. **`QUIPU_HOOK=1 quipu …`
  POSIX env-öneki cmd.exe'de geçersiz** (`VAR=1 cmd` sözdizimi değil) `[doğrulanmadı — mekanizma
  kaynakta, fiili test yok]`.

### A-6 — feature bayrağı [kaynak: features/lib.rs, legacy.rs, registry.rs]

- Kanonik anahtar `hooks` (`CodexHooks`, `Stable`, **`default_enabled: true` → hook'lar varsayılan
  AÇIK**); `[features] hooks = false` kapatır; deprecated alias `codex_hooks`.
- Okuma oturum kurulumunda **bir kez**; watcher yok → **yeniden başlatma gerekir.**

---

## 2. Çekirdek: `quipu capture` çok-şemalı olur

### 2.1 Şema dağıtımı (ajan-agnostik)

`lib/capture.awk` tek bir satır `EVENT<TAB>TOOL<TAB>PATH` üretmek yerine, **payload şekline göre**
birden çok satır üretebilir hâle gelir:

| Durum | Davranış |
|---|---|
| `tool_input.file_path` dolu | **Mevcut davranış aynen** (Claude Code şeması) — regresyonsuz |
| `tool_name == "apply_patch"` ve `tool_input.file_path` yok | `tool_input.command` içindeki unified diff'ten dosya yolları çıkar (§2.2) |
| ikisi de yok | hiçbir satır üretilmez (çıkış 0, sessiz) |

- **K-1** Şema dağıtımı `tool_name`'e değil, **payload şekline** dayanır: `file_path` varsa onu
  kullan; yoksa `apply_patch`'in diff'i aranır. Böylece Claude Code şeması birebir korunur (regresyon
  kapısı §10) ve gelecekteki Cursor/Windsurf şemaları aynı dağıtıma eklenir.
- **K-2** `apply_patch` dalı ajan-agnostik davranır: içinde "Codex" geçmez; kriter "`tool_input.command`
  bir unified diff içeriyor ve `+++ b/` başlığı var"dır.

### 2.2 `apply_patch` diff ayrıştırması

`tool_input.command` (JSON'dan çözülmüş değer; satır sonları gerçek `\n`) satırlarına bölünür.
Her satır için:

- **K-3** Satır `+++ b/` (baytlar: `+` `+` `+` `SPACE` `b` `/`) ile başlıyorsa, 6 baytlık önekten
  sonrası **dosya yoludur**. `substr` ile alınır — **regex yok, elle tarama** (PLAN §4.8/§4.11).
- **K-4** Yol `/dev/null` ise atlanır (silme); bir rename'de eski ad (`--- a/`) yakalanmaz — dürüst sınır.
- **K-5** Her yol TAB/CR/LF'den temizlenir (mevcut `gsub` bloğunun aynısı); boş kalan yol atlanır.
- **K-6** Her geçerli yol için `hook_event_name<TAB>apply_patch<TAB><yol>` satırı basılır. Tek bir
  `apply_patch` birden çok dosyaya dokunursa **birden çok satır** üretilir. `TOOL` alanı ham araç adı
  `apply_patch` olur (mevcut "ham araç adı" davranışıyla tutarlı).
- **K-7** `Bash` **yakalanmaz** (matcher zaten dışlar; ayrıca PATH boş olur ve digest onu atlar).
  `Read` yakalanmaz — Codex'te `Read` aracı yok (A-2). `mcp__*` kapsam dışı (§11). Bunlar dürüst
  sınırlardır, README'de yazılır.

### 2.3 Shell döngüsü

`quipu capture` stdin modunda artık tek tuple değil **çok satır** işler:

- **K-8** `_q_out` (awk çıktısı) satırlara bölünür; rotasyon **bir kez** (döngüden önce) yapılır;
  her satır için Windows yolu normalizasyonu (mevcut cygpath bloğu) + vault-relative şerit +
  TAB/CR/LF temizliği + `activity.log`'a ekleme uygulanır.
- **K-9** `capture` tüm yollarda **stdout'a sıfır bayt** yazar (Ö-5/FAZ 3 dersi değişmez).
- **K-10** Bayrak modu (`capture --event --tool --path`) **değişmez**; genelleştirme yalnız stdin
  moduna girer.

---

## 3. Adaptör: `adapters/codex/hooks.json`

**Kod değil, veri** — genelleştirilmiş capture üzerine config-only.

### 3.1 Hedef yapı (A-1'in teyit ettiği şema)

```json
{
  "description": "quipu memory hooks for Codex CLI",
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command",
                     "command": "QUIPU_HOOK=1 quipu remember && QUIPU_HOOK=1 quipu context --json SessionStart",
                     "commandWindows": "set QUIPU_HOOK=1&& quipu remember&& set QUIPU_HOOK=1&& quipu context --json SessionStart",
                     "timeout": 10 } ] }
    ],
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command",
                     "command": "QUIPU_HOOK=1 quipu context --json UserPromptSubmit",
                     "commandWindows": "set QUIPU_HOOK=1&& quipu context --json UserPromptSubmit",
                     "timeout": 10 } ] }
    ],
    "PostToolUse": [
      { "matcher": "apply_patch",
        "hooks": [ { "type": "command",
                     "command": "QUIPU_HOOK=1 quipu capture",
                     "commandWindows": "set QUIPU_HOOK=1&& quipu capture",
                     "timeout": 10, "async": true } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command",
                     "command": "QUIPU_HOOK=1 quipu remember",
                     "commandWindows": "set QUIPU_HOOK=1&& quipu remember",
                     "timeout": 3 } ] }
    ]
  }
}
```

> `commandWindows` değerleri `[doğrulanmadı]` (cmd `set` sözdizimi kaynaktan, fiili test yok).
> `set VAR=1&& komut` biçiminde `&&` değerden **boşluksuz** biter (cmd'nin `set` boşluk tuzağı).
> Canlı Codex doğrulamasında geçersiz çıkarsa §11'e geri düşer.

### 3.2 Bağlayıcı kurallar

- **K-11** Dört olay FAZ 3'ün Claude Code zincirinin aynısı: `SessionStart` = `remember` + `context`;
  `UserPromptSubmit` = nudge; `PostToolUse` (async) = `capture`; `SessionEnd` = `remember`.
  `PreCompact` bloğu **konmaz** (FAZ 3 Ö-2 dersi; Codex'te de enjeksiyon yok, A-4).
- **K-12** `SessionEnd`'in `timeout`'u **3** (A-1: tavan 3s, zorla senkron). `remember` bayraksız
  koştuğu için hızlıdır; ayrıca `SessionStart` zincirinde de koştuğundan `SessionEnd` kesilse bile
  filigran idempotenti kapatır (AM-1 deseni).
- **K-13** `PostToolUse` matcher'ı **`apply_patch`** (canonical; `Edit|Write` alias'ı da yakalar —
  A-2). FAZ 3'ün `Edit|Write|NotebookEdit|Read` matcher'ı **kopyalanmaz** (Codex'te `Read` yok).
- **K-14** `shell` alanı **yazılmaz** (A-1: Codex'te yok). `command` Unix'te `/bin/sh -lc`, Windows'ta
  `cmd.exe /C` ile çalışır.
- **K-15** `|| true` yok; `QUIPU_HOOK=1` (Unix) ve `commandWindows` `set` öneki (Windows) sessiz-başarı
  sağlar (C-25/AM-2 gerekçesi). `"env": {}` kalıntısı yok.
- **K-16** `conhost`/`cmd.exe` sarmalayıcısı, doğrudan `.sh` yolu, `"env"` anahtarı YASAK (C-21/C-22/E-3).

### 3.3 Kurulum — installer YOK (C-26 dersi)

- **K-17** `adapters/codex/hooks.json` → `~/.codex/hooks.json` (global) veya `.codex/hooks.json`
  (proje). `config.toml`'a **bayrak gerekmez** (A-6: varsayılan açık); yalnızca kapatmak için
  `[features] hooks = false` — README bunu **"hooks varsayılan açıktır, kapatma istersen `false`"**
  olarak anlatır (eski "hooks=true gerekir" ifadesi YANLIŞTIR).
- **K-18** README'ye yeniden başlatma uyarısı (A-6: watcher yok).

---

## 4. i18n — DEĞİŞİKLİK YOK

- **K-19** Yeni i18n anahtarı gerekmez (`capture` sessiz; yeni komut yok). `i18n/{tr,en}.txt` dokunulmaz.

---

## 5. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/FAZ4-BULGULAR.md` — §1'deki A-1…A-6'yı `[kaynak]`/`[doğrulanmadı]` etiketleriyle resmileştir (araştırma zaten yapıldı) | A-1…A-6 kaynaklı, "ölçüldü" iddiası yok |
| **1** | `lib/capture.awk` + `quipu capture` shell döngüsü (§2) + fixture'lar + testler | mevcut 156 iddia aynen yeşil (regresyon yok) + T-50…T-53 |
| **2** | `adapters/codex/hooks.json` (§3) + statik testler | T-54…T-56 |
| **3** | README "Codex" bölümü, PLAN §6/§7/§9 | §10 |

**Neden Dilim 1, Dilim 2'den önce:** genelleştirilmiş capture olmadan adaptörün `PostToolUse`
dalı çalışmaz. Önce çekirdek yetenek, sonra onu tüketen veri dosyası.

---

## 6. Testler

### 6.1 Capture genelleştirmesi (fixture'lı, otomatik)

`tests/fixtures/` içine temizlenmiş Codex payload'ları girer (C-4 deseni): `codex-apply-patch.json`
(tek dosyalı diff), `codex-apply-patch-multi.json` (çok dosyalı), `codex-apply-patch-delete.json`
(`/dev/null`). Path'ler `alice/demo` maskeli.

| # | Test |
|---|---|
| T-50 | Tek dosyalı `apply_patch` → `activity.log`'da `PostToolUse \| apply_patch \| <+++ b/ yolu>` bir satır |
| T-51 | Çok dosyalı `apply_patch` → dosya başına bir satır (sayı doğru) |
| T-52 | `/dev/null` (`+++ /dev/null`) → o dosya için satır yok |
| T-53 | Claude Code payload'u (mevcut fixture) → davranış **değişmedi** (regresyon) |

- **K-20** Diff ayrıştırması `substr`/`index` ile; regex yok (PLAN §4.8). Testler bayt-bayt yol
  karşılaştırması yapar.
- **K-21** Yeni fixture'lar temizlenmiş olmalı (gerçek kullanıcı yolu / session_id / transcript yok).

### 6.2 Adaptör (statik dizge kontrolü, C-31 ruhu)

| # | Test |
|---|---|
| T-54 | Dört olay anahtarı var; `PreCompact` anahtarı **yok** (K-11) |
| T-55 | `"shell"` alanı, `"env"` anahtarı, `conhost`, `cmd.exe`, `.sh` komutu yok (K-14/K-16) |
| T-56 | `command` alanları `QUIPU_HOOK=1 quipu ` ile başlıyor; `commandWindows` alanları mevcut; `async` yalnız `PostToolUse`'da (tam bir kez); `PostToolUse.matcher == "apply_patch"` |

- **K-22** FAZ 2/3 test dersleri aynen: çok baytlı `awk index()`, ASCII `grep` serbest; yeni iddia
  i18n'ye bakmıyor (K-19).

---

## 7. Belge güncellemeleri

- **K-23** `README.md`: "Codex" bölümü — hooks.json kopyalama yeri (global/proje), `hooks` varsayılan
  açık notu, Windows `commandWindows` notu, **yeniden başlatma uyarısı**, dürüst sınırlar
  (yalnız `apply_patch` yakalanır; `Bash`/`Read`/silme yakalanmaz).
- **K-24** `docs/PLAN.md`: §6 FAZ 4 ✅ (revize: çok-şemalı capture + Codex adaptörü; Cursor/Windsurf/
  OpenCode ertelendiği açıkça yazılır), §7 risk tablosuna `Codex hook şeması` satırı (`[doğrulanmadı]`,
  canlı ölçüm açık), §9 durum + sıradaki (FAZ 5 hook'suz fallback).
- **K-25** `docs/FAZ4-BULGULAR.md` yeni dosya (FAZ3-BULGULAR.md deseninde, `[kaynak]`/`[doğrulanmadı]`).

---

## 8. Yasak desenler (devralınan + yeni)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) · ham
kullanıcı verisini `awk -v` ile geçirmek (§4.16) · çok baytlı `sed` sınıfı (§4.1) · çok baytlı
`grep` kalıbı (§4.17) · tırnaksız yol değişkeni · `conhost`/`cmd` sarmalayıcısı (§4.13) · hook
`command`'ında doğrudan `.sh` (§4.14) · `~/.codex/hooks.json` programatik düzenleme (C-26 ruhu) ·
**`apply_patch` diff ayrıştırmasında regex (§2.2)**

---

## 9. Çıkış koşulu

1. Dilim 0: `docs/FAZ4-BULGULAR.md` A-1…A-6'yı `[kaynak]`/`[doğrulanmadı]` ile cevaplıyor.
2. **Regresyon kapısı:** mevcut 156 iddia aynen yeşil (Claude Code şeması değişmedi, K-1).
3. `sh tests/run.sh` üç OS'ta yeşil (yerel tek OS'u kanıtlar; üç OS CI ile).
4. `./.claude/tools/shellcheck.exe -s sh quipu tests/run.sh` sessiz.
5. `adapters/codex/hooks.json` yasak desenlerden arınmış (T-55/T-56).
6. Dal + PR, üç OS CI yeşil olmadan merge yok.

> **Not:** İlk revizyonun "çekirdek değişmedi" koşulu **kalkmıştır** — bu faz çekirdeği (`capture`)
> bilinçli ve ajan-agnostik biçimde değiştirir. Yerine regresyon kapısı (madde 2) geçmiştir.

---

## 10. Kapsam dışı

- **Cursor, Windsurf, OpenCode** — 2026-08-20 kullanıcı kararıyla ertelendi. Cursor/Windsurf'ün
  file-centric payload'ı (§5 PLAN) bu fazın çok-şemalı dağıtımına **ileride** aynı desenle eklenir;
  OpenCode JS plugin gerektiriyor (config-only değil) — ayrı karar.
- **`mcp__*` araçları** — sunucuya özgü şema; ilk fazda yakalanmaz.
- **`Bash` komutlarından dosya yolu çıkarımı** — kırılgan; yakalanmaz (K-7).
- **Silme/rename yakalama** — `/dev/null` atlanır, eski ad korunmaz (K-4).
- **Araç adı normalizasyonu** (`apply_patch` → `Edit`) — ham ad korunur; gelecekte istenirse ayrı katman.
- **Canlı Codex doğrulaması** — Codex kurulu değil; `[doğrulanmadı]` bayrağı kurulana dek açık.
- `quipu install`, git-diff capture (`capture --git`) → FAZ 5, MCP sunucusu → v1 dışı.
