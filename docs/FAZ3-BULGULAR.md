# FAZ 3 — Ölçüm Bulguları (E-0)

**Ölçüm tarihi:** 2026-08-20 · **Ortam:** Windows 11 Pro 26200, Git Bash,
Claude Code **2.1.237**, model sonnet-5 / opus-5 (Claude Pro), quipu repo kökü.

**Yöntem (C-3/C-4):** `.claude/settings.json`'a beş olay için `bash` + mutlak yol
desenli probe hook'ları yazıldı (`.claude/faz3/probe.sh`); her çağrı ham stdin'i,
argümanları ve ortamı `.claude/faz3/capture-<olay>.jsonl`'a döktü. Ölçüm oturumları:
print modu (`claude -p`), interaktif TTY (hub PTY üzerinden) ve borulu-stdin
interaktif modu (`printf … | claude`). Tüm payload'lar temizlenerek
`tests/fixtures/`'a alındı (C-4: yollar `alice/demo`, `session_id`/`transcript_path`
maskeli).

---

## Ö-1 ✅ `PreCompact` tetikleniyor — payload şeması yakalandı

`--autocompact 100k` ile print modunda **canlı üç kez** tetiklendi (trigger her
seferinde `auto`). Payload:

```json
{"session_id":"…","transcript_path":"…","cwd":"…","prompt_id":"…",
 "hook_event_name":"PreCompact","trigger":"auto","custom_instructions":null}
```

- `trigger` alanı var, ölçülen değer: `auto`. Manuel `/compact` **ölçülemedi**
  (hub PTY üzerinden sürülen TUI ilk turdan sonra girişi işlemiyor; `claude` 2.1.237 +
  claude-mem eklentisinin stdout seli altında). Dal kararını etkilemez — aşağıya bakın.
- `custom_instructions: null` — bu olayda talimat taşıma alanı yok.

## Ö-2 ❌ **"ulaşmıyor"** — `PreCompact` çıktısı modele ulaşmıyor (kesin ölçüm)

İki bağımsız canlı deney:

1. **Borulu oturum, zorlanmış sıkıştırma:** `--autocompact 100k` ile büyük dosya
   okutuldu, sıkıştırma gerçekleşti (`SessionStart source=compact` + `PreCompact`
   capture doğrulandı), sonra modele soruldu. Modelin cevabı (özgün):
   > QUIPU_FAZ3_MARKER_PRECOMPACT — **NO.** It has not appeared anywhere in my
   > context … including after the compaction that just occurred.
   >
   > QUIPU_FAZ3_MARKER_SESSIONSTART — **YES.** … appeared twice … once before
   > compaction, once again just now after compaction.

   Aynı probe, aynı JSON zarfı: `SessionStart` çıktısı modele ulaşıyor, `PreCompact`
   çıktısı ulaşmıyor. Fark **olaydan** kaynaklanıyor, zarftan değil.
2. **Print modu akışı:** `PreCompact` hook'u 3 kez koştu; `stream-json` akışında
   `hook_response` kaydı dahi üretilmedi (`SessionStart`/`PostToolUse` çıktıları
   akışta vardı). Dokümantasyonla uyumlu: §4.5'in stdout-enjeksiyon listesinde
   `PreCompact` yok.

**Bağımsız doğrulama:** claude-mem 13.15.3 (üretimde, 91k⭐) `hooks/hooks.json`'ı
`Setup`, `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `PreToolUse`, `Stop`
kaydediyor — **`PreCompact` ve `SessionEnd` yok.**

## Ö-3 ⚠️ `SessionEnd` güvenilmez; `reason` alanı var, değerleri ölçüldü

| Yol | `SessionEnd` ateşlendi mi |
|---|---|
| print modu (`-p`, temiz çıkış) | ❌ hiç |
| borulu-stdin, tek prompt, temiz çıkış | ❌ |
| TTY `/exit` (temiz çıkış kodu 0) | ❌ |
| `hub stop` (SIGTERM) / SIGKILL | ❌ |
| `/clear` geçişi | ✅ `reason:"clear"` |
| `--continue` oturumunun temiz bitişi | ✅ `reason:"other"` |

Payload şeması: `session_id`, `transcript_path`, `cwd`, (`prompt_id` bazı
durumlarda), `hook_event_name`, **`reason`**. Ölçülen değerler: `clear`, `other`.
Crash ayrımı için `reason` **var ama** crash (kill) yolunda hook hiç çalışmıyor.

**Tasarım etkisi:** `remember`'ı yalnız `SessionEnd`'e bağlamak sindirimin nadiren
yazılması demek. → **AM-1** (aşağıda).

## Ö-4 ✅ `SessionStart` `source` değerleri: dördü de canlı ölçüldü

| Değer | Tetikleyici | Ölçüm |
|---|---|---|
| `startup` | taze oturum | ✅ |
| `resume` | `claude --continue` | ✅ |
| `clear` | `/clear` (yeni oturum `source:clear` ile başlar) | ✅ |
| `compact` | otomatik sıkıştırma sonrası **yeni SessionStart** | ✅ **spec'te yoktu** |

`compact` bulgusu önemli: her sıkıştırmadan sonra `SessionStart` hook'u **yeniden**
koşuyor ve çıktısı **bağlama giriyor** (Ö-2'deki model cevabı bunu doğruladı).
claude-mem'in üretim matcher'ı `startup|clear|compact` — birebir örtüşüyor.
`resume`'da bağlam enjeksiyonu gereksiz olabilir (spec Ö-4'ün sorusu): resume'da
bağlam zaten süreklidir; enjeksiyon yine de zararsız (4 KB sınırlı, C-16).

## Ö-5 ✅ `async` hook çıktısı bağlama GİRİYOR — "system-reminder" olarak

Borulu oturumda async `PostToolUse` probe'unun stdout'u (`QUIPU_FAZ3_MARKER_PTU_ASYNC`)
modelin bağlamında **tekrar tekrar** göründü (model cevabı: "It appears repeatedly in
system-reminder blocks"). Yani:

- async çıktı modele ulaşıyor, ama geç ve "hatırlatma" biçiminde — **gürültü riski gerçek**
  (spec Ö-5'in korktuğu şey doğru çıktı).
- **Adaptörün `PostToolUse` hook'u `quipu capture` çağırır — capture stdout'a hiçbir
  şey yazmaz** → gürültü sıfır. Tasarım zaten doğruydu; ölçüm bunu zorunlu kılıyor:
  adaptörde `PostToolUse` dışında hiçbir hook async olmayacak.

---

## Ek bulgular (ölçüldü, spec dışı)

### E-1 ✅ Proje `.claude/settings.json` hook'ları interaktif oturumlarda YÜKLENİYOR

FAZ 0'ın ertelediği madde kapandı: interaktif TTY oturumları proje settings
hook'larını okuyor ve koşuyor. FAZ 0'ın Ö-4 "sıcak yüklenmez" bulgusu ayrı ve doğru
(mid-session yazma), bu onunla çelişmiyor.

### E-2 ⚠️ Windows'ta hook spawn PATH'i `bash`'i BULAMIYOR (canlı hata)

Git for Windows PATH'e yalnız `C:\Program Files\Git\cmd` (git.exe) koyuyor;
`bash.exe` (`C:\Program Files\Git\bin`) yok. Windows-ana süreçten başlatılan
oturumlarda `shell:"bash"` / `command:"bash"` hook'ları şunu üretiyor:

```
UserPromptSubmit hook error
Failed with non-blocking status code: Error occurred while executing hook command:
Executable not found in $PATH: "bash"
```

- **Non-blocking:** oturum devam ediyor (canlı doğrulandı), ama hata satırı
  transkripte ve TUI'a düşüyor — kullanıcı görüyor.
- claude-mem aynı sorunu üretimde yaşamış; çözümleri hook komutu içinde
  `export PATH="$($SHELL -lc 'echo $PATH' 2>/dev/null):$PATH"`.
- **Adaptör etkisi:** README'ye Windows notu: `C:\Program Files\Git\bin` PATH'te
  değilse ekleyin (C-27'nin "Windows yol notu" bunu kapsar). Adaptör kendi PATH'ini
  onarmaz — komutlar sade kalır (C-23 ruhu).

### E-3 ⚠️ Hook `env` anahtarı YOK — iki mekanizma da ölçüldü, ikisi de çalışmıyor

- Hook girişi içinde `"env": {…}` → **sessizce yok sayılıyor** (hook koştu, env
  ulaşmadı).
- settings kökünde `"environmentVariables": {…}` → hook sürecine ulaşmadı.

**C-25 etkisi:** `QUIPU_HOOK=1` hook env'iyle set edilemiyor. **AM-2:** adaptör
komutları `QUIPU_HOOK=1 quipu …` biçiminde yazılır (POSIX env öneki; `shell:"bash"`
altında çalışır). `|| true` yine kullanılmaz (C-25'in gerekçesi geçerli: elle
çalıştırmada hatalar görünür kalsın). **T-47 düzeltmesi:** "her `command`
`quipu ` ile başlıyor" sınaması `^QUIPU_HOOK=1 quipu ` olarak güncellenir.

### E-4 `claude -p` print modunda hook'lar KOŞUYOR (FAZ 0 bilmiyordu)

`SessionStart`, `UserPromptSubmit`, `PostToolUse` print modunda canlı yakalandı.
Yalnız `SessionEnd`/`PreCompact` farklı davranıyor (Ö-1/Ö-3).

---

## Dal kararı (C-6)

**Ö-2 = "ulaşmıyor" → §4.3 dalı: `UserPromptSubmit` + bayatlık eşiği (C-19/C-20).**

Gerekçe: üç bağımsız kanıt (canlı model cevabı ×2, akış analizi, claude-mem üretim
yapılandırması). `PreCompact` hook'u adaptöre **konmaz**; `context --json PreCompact`
kod yolu (C-18) yazılmaz.

## Tasarım değişiklikleri (ölçüme dayalı)

| # | Değişiklik | Gerekçe |
|---|---|---|
| AM-1 | Adaptör `SessionStart` zinciri: `QUIPU_HOOK=1 quipu remember && QUIPU_HOOK=1 quipu context --json SessionStart`; `SessionEnd`: `QUIPU_HOOK=1 quipu remember` | Ö-3: SessionEnd güvenilmez. remember filigranla idempotent → çift çağrı zararsız (C-2). SessionStart'ta koşan remember bir önceki oturumun sindirimini yazar; `source=compact` yeniden-başlatması oturum ortası sindirim yazar — ikisi de tasarım gereği (C-8 çok bölümü destekler) |
| AM-2 | Komutlar `QUIPU_HOOK=1 quipu …`; T-47 öneki buna göre | E-3: hook env mekanizması yok |
| AM-3 | `PreCompact` dalı düştü; `UserPromptSubmit` hook'u adaptöre eklendi: `QUIPU_HOOK=1 quipu context --json UserPromptSubmit` | Ö-2 |
| AM-4 | README Windows notu: Git `bin` PATH + §4.15 yeniden başlatma uyarısı | E-2 |

## Fixture'lar (C-4)

`tests/fixtures/`: `sessionstart.json` (startup) · `sessionstart-resume.json` ·
`sessionstart-compact.json` · `precompact.json` · `sessionend-clear.json` ·
`sessionend-other.json` · `userpromptsubmit.json`. Maskeleme: `alice/demo` yolları,
`b5792953-…` sabit session id. Ham yakalamalar `.claude/faz3/` altında (gitignore'lu).

## Canlı katman (C-33) — sonuçlar dosyanın sonunda

Adaptör yapılandırması gerçek oturumlarda koşuldu; tam sonuç aşağıdaki
"C-33 canlı katman — KOŞULDU" bölümünde. CI yeşilliği bu adımın yerine geçmez.

---

## C-33 canlı katman — KOŞULDU ✅ (2026-08-20, gerçek adaptör yapılandırmasıyla)

`adapters/claude-code.json` birebir kopyalanıp test vault'una (`.claude/faz3/livevault`,
gitignore'lu) kuruldu; `quipu` PATH'e eklendi; iki ayrı Claude Code 2.1.237 oturumu
koşuldu (yeniden başlatılmış oturumlar — §4.15):

| C-33 maddesi | Sonuç |
|---|---|
| `SessionStart` bağlam enjeksiyonu görünüyor mu | ✅ model "recent activity" başlığını ve `activity.log` satırını birebir alıntıladı |
| `PostToolUse` `activity.log`'a satır düşürüyor mu | ✅ 4 satır yakalandı (Read ×2, Write ×1, Read ×1) |
| `SessionEnd`/`SessionStart` sonrası `<sessions>/` dosyası oluştu mu | ✅ `700-Sessions/2026-08-20.md`: iki `## HH:MM` bölümü, doğru araç/dosya sayaçları |
| `Last-Session.md` işaretçi bloğu | ✅ `2026-08-20 · N events · 700-Sessions/2026-08-20.md` |
| Hook hata satırı var mı | ✅ yok — iki oturum da RC=0 |

### Canlı katmanda bulunan eksik: Windows yolu yakalama

İlk canlı oturumda `activity.log`'a **mutlak Windows yolları** düştü
(`C:\Users\…\livevault\500-Knowledge\hello.md`) — Claude Code Windows'ta yolları
ters-bölü biçimde veriyor, vault-relative şerit eşleşemiyordu. Düzeltme: `quipu capture`
artık `[A-Za-z]:*` biçimindeki yolları `cygpath -u` ile POSIX'e çeviriyor; sonuç
vault'un **içindeyse** vault-relative yapılıyor, değilse özgün baytlar korunuyor
(vault dışı yollar zaten mutlak olmalı). Test eklendi (`capture: Windows path becomes
vault-relative`, cygpath yoksa SKIP). Yerel paket: **154 geçti, 0 hata, 2 skip**.
