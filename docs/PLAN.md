# quipu — Uygulama Planı

> **Bu dosya ne?** Sıfırdan yazılacak bir projenin tam planı. Başka bir Claude Code
> oturumunda, hiçbir ön bilgi olmadan açılıp uygulanabilecek şekilde yazıldı.
> Buradaki tüm teknik bulgular **ölçülmüş ve doğrulanmıştır** — tahmin değildir.
> Kanıtlar "Doğrulanmış Bulgular" bölümünde, yeniden üretme komutlarıyla birlikte.
>
> **Tarih:** 2026-08-19 · **Durum:** FAZ 1 Adım 1 tamam (ilkeller + testler), Adım 2 (CI) sürüyor
> **İsim notu:** `quipu` seçildi. Değiştirmek istersen tüm dosyada tek find/replace yeter.

---

## 1. Proje nedir

**quipu**, kodlama ajanlarına oturumlar arası kalıcı hafıza kazandıran, sıfır bağımlılıklı,
tamamen çevrimdışı ve ücretsiz bir sistem. Aynı zamanda bir "ikinci beyin" vault yapısı sunar.

**Ad nereden geliyor:** Quipu, İnkaların düğümlü iplerle tuttuğu kayıt sistemi — hiçbir
teknoloji olmadan, nesiller boyu bilgi saklayan bir araç. Projenin tezi bu.

### Katı gereksinimler (pazarlık konusu değil)

| # | Gereksinim | Anlamı |
|---|---|---|
| 1 | **Sıfır bağımlılık** | Sadece POSIX sh + sed + awk + grep + tr + git. Python yok, Node yok, Bun yok, jq yok. |
| 2 | **%100 çevrimdışı** | Hiçbir veri makineden çıkmaz. API anahtarı yok. |
| 3 | **Tamamen ücretsiz** | Sıfır token maliyeti, sıfır abonelik. |
| 4 | **Çok platformlu** | Windows + macOS + Linux, hepsinde CI ile doğrulanmış. |
| 5 | **Çok dilli** | Türkçe ve İngilizce birinci sınıf; diğer diller profil dosyasıyla. |
| 6 | **Çok ajanlı** | Claude Code, Codex, OpenCode, Cursor, Windsurf ve hook'suz ajanlar. |
| 7 | **Depolama: düz Markdown** | Veritabanı yok. Dosyalar kullanıcının, kilitlenme yok. |

### İlham alınan iki proje

- **[avenoxbeyin](https://github.com/avenoxai/avenoxbeyin)** (25⭐, tek commit) — vault yapısı,
  `CLAUDE.md` kimlik dosyası, companion persona fikri. **Kodu alınmayacak** (üç kritik hatası var,
  bkz. Bölüm 8). Sadece yapı ve fikir ilham.
- **[claude-mem](https://github.com/thedotmack/claude-mem)** (91k⭐, v13.15.2) — çoklu ajan
  entegrasyon deseni, `AGENTS.md` köprüsü, `PostToolUse` yakalama fikri. **Kodu alınmayacak**
  (Node+Bun+worker+SQLite+Chroma gerektiriyor, gereksinim 1-3'ü ihlal ediyor).

### Temel tez — neden bedavaya yapılabiliyor

claude-mem semantik arama için Chroma vektör veritabanı ve ayrı bir AI worker'ı kullanmak
zorunda, **çünkü onun worker'ı ayrı bir süreç ve içinde model yok.**

quipu'nun böyle bir sorunu yok: **Claude (veya hangi ajansa) zaten döngüde, zaten çalışıyor,
zaten ödenmiş.** Semantik katman = zaten oradaki modelin kendisi. Vektör veritabanı satın
almaya gerek yok.

---

## 2. Mimari

```
┌─ ÇEKİRDEK: tek dosya POSIX sh CLI ──────────────── %100 taşınabilir
│    quipu index | search | capture | remember | doctor
│    Sözleşme BUDUR. Her ajan, her OS, sadece shell'den çağırır.
│    Hook'lar sadece "otomatik çağırıcı" — zorunlu değil.
│
├─ EVRENSEL KÖPRÜ: AGENTS.md etiketli blok ───────── hook'suz her ajan
│    <!-- quipu:start --> son oturum + aktif konular <!-- quipu:end -->
│    Ajan hook desteklemese bile bağlamı görür.
│
├─ ADAPTÖRLER (opsiyonel yükseltme) ──────────────── hook varsa gerçek zamanlı
│    claude-code · codex · opencode · cursor · windsurf
│    hook yoksa → git-diff tabanlı yakalama
│
└─ DİL PAKETLERİ (kod değil, veri) ───────────────── i18n
     i18n/{tr,en}.txt         → arayüz metinleri
     fold/{tr,latin,...}.sed  → dile özgü arama katlama profili
```

### Dört katman (veri akışı)

```
KATMAN 0 — YAKALAMA (otomatik, mekanik, 0 maliyet)
  PostToolUse hook (async) → awk ile stdin JSON ayrıştır → activity.log'a tek satır:
      2026-08-19T19:40 | Edit | 500-Knowledge/not.md
  AI yok. Bu bir OLGU kaydı, özet değil. Hook'suz ajanlarda: git-diff ile.
        ↓
KATMAN 1 — SIKIŞTIRMA (model zaten oradayken, 0 maliyet)
  PreCompact  → "bağlam sıkışmadan ÖNCE hafızayı yaz" (asıl kayıp anı burası)
  SessionEnd  → activity.log'u oku, Last-Session.md + Threads.md güncelle
  claude-mem bunun için ayrı API çağrısı yapıyor; biz bağlam içindeyiz → marjinal maliyet ≈ 0
        ↓
KATMAN 2 — İNDEKS (mekanik, 0 maliyet)
  .quipu/index.tsv:  yol │ başlık │ etiketler │ mtime │ KATLANMIŞ_ARAMA_ALANI
  activity.log hangi dosyaların değiştiğini söyler → sadece onlar yeniden indekslenir
        ↓
KATMAN 3 — HİBRİT ARAMA (0 maliyet, %100 çevrimdışı)
  Sözcüksel yarı : katlanmış grep / BM25 (awk) → aday listesi (anında, kesin)
  Semantik yarı  : indeks küçük → ajan okur, anlamla seçer
                   ↑ "embedding modeli" = zaten çalışan ajanın kendisi
  `quipu search` ikisini birleştirir
```

---

## 3. Verilmiş kararlar

| Karar | Seçim | Gerekçe |
|---|---|---|
| Kabuk | **POSIX sh** (`#!/bin/sh`) | macOS hâlâ bash 3.2 (2007) gönderiyor. dash/busybox de çalışsın. `declare -A`, `${var,,}`, `[[ ]]`, `=~` **YASAK**. |
| İsim | **quipu** | Bkz. Bölüm 1. |
| Repo | **Yeni repo, sıfırdan** | avenoxbeyin fork'u değil — taşınacak kodun neredeyse tamamı zaten değişiyor. |
| Depolama | Düz Markdown + TSV indeks | Gereksinim 7. |
| Hafıza yazımı | **Append-only**, üzerine yazma YOK | Çoklu ajan aynı vault'ta çalışırsa üzerine yazma = veri kaybı + git çakışması. |
| Senkron | `git remote` (opsiyonel) | claude-mem'in ücretli Pro özelliği, bizde bedava. |
| MCP sunucusu | **v1'e alınmayacak** | MCP bir çalışma zamanı ister (node/python) → gereksinim 1 ihlali. v2'de opsiyonel paket olarak değerlendirilir. |
| Dil | Kod/README İngilizce, Türkçe birinci sınıf | Global erişim + kimlik. |

---

## 4. Doğrulanmış bulgular (KRİTİK — yeniden keşfetmeyin)

Bunların hepsi 2026-08-19'da Windows 11 + Git Bash üzerinde ölçüldü.

### 4.1 `sed` köşeli parantez sınıfları çok baytlı UTF-8'i BOZAR

En kritik bulgu. `[ÀÁÂÄ]` gibi sınıflar bayt bazlı eşleşir; `Ü`=`0xC3 0x9C` ve `Ä`=`0xC3 0x84`
ortak `0xC3` baytında çakışır.

```
GİRDİ    : Über MÜNCHEN Café NAÏVE Señor Straße João
BOZUK    : UUber MUUNCHEN CafU?E NAU?VE SeU?or StraU?e JoUao      ← [ÀÁÂÄ] sınıfı
DÜZELTME : uber munchen cafe naive senor strasse joao             ← tek tek s///
```

**KURAL: Çok baytlı karakterlerde asla karakter sınıfı kullanma. Her karakter için ayrı `s///`.**

### 4.2 Türkçe arama ham `grep -i` ile bozuk

| Sorgu | `grep -i` | Katlamalı |
|---|---|---|
| `İstanbul` | 1/2 | **2/2** |
| `IŞIK` | 1/2 | **2/2** |
| `çalışma` | **0/2 — hiç bulamıyor** | **2/2** |

Türkçe profili özel: **`I → ı → i`** (İngilizce'de `I → i`). Bu yüzden dil başına ayrı profil şart.

### 4.3 Katlama sırası zorunlu: önce ASCII'ye katla, SONRA `tr`

BSD `tr` (macOS) bayt bazlıdır ve çok baytlı metni bozar. Doğru sıra her platformda güvenli:

```sh
fold_profile < girdi | tr 'A-Z' 'a-z'    # ← katlamadan sonra saf ASCII, bayt-güvenli
```

Doğrulandı: Japonca, Kiril ve emoji bu sırada bozulmadan geçiyor (`uber 日本語 Привет 🔮 cafe`).

### 4.4 `stat` platforma göre değişir

```sh
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
#         └─ GNU/Linux, msys                └─ BSD/macOS
```
`stat -f %m` Git Bash'te **hata verir** — avenoxbeyin'in hatası tam olarak buydu.

### 4.5 Bağlam enjeksiyonu: küçük bir JSON zarfı gerekiyor

> **FAZ 0 düzeltmesi (Ö-5).** Bu bölümün ilk hâli "JSON'a hiç gerek yok" diyordu; bu
> fazla iyimserdi. Canlı ölçüm iki farklı yol olduğunu gösterdi.

Dokümantasyon `SessionStart`, `UserPromptSubmit` ve `UserPromptExpansion` olaylarında
düz stdout'un bağlama eklendiğini söylüyor:

> "The exceptions are `UserPromptSubmit`, `UserPromptExpansion`, and `SessionStart`, where
> Claude Code adds plain-text stdout as context that Claude can see and act on."

**Ama iki farklı etiketle geliyor** (canlı oturumda gözlendi):

| Yol | Etiket | Değerlendirme |
|---|---|---|
| JSON `hookSpecificOutput.additionalContext` | `hook additional context:` | **temiz, amaçlanan yol** |
| Düz stdout | `hook success: <ham baytlar>` | bağlama ulaşıyor, ama "başarı raporu" olarak |

claude-mem 13.15.2 düz stdout kullanmıyor; JSON döndürüyor:
```js
{ continue: true, suppressOutput: true,
  hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: <metin> } }
```

**Sonuç:** temiz enjeksiyon için JSON zarfı gerekiyor → FAZ 1'e `lib/jsonemit.awk`
(JSON *yazıcı*) kalemi eklendi. **Sıfır bağımlılık yine korunuyor** — §4.11'deki
`sprintf("%c",92)` tekniğiyle jq/python olmadan JSON üretmek mümkün; sadece kod biraz büyüyor.

### 4.6 `PreCompact` gerçekten var

Desteklenen olaylar (2026-08 itibarıyla): `SessionStart`, `Setup`, `UserPromptSubmit`,
`UserPromptExpansion`, `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`,
`PostToolUseFailure`, `PostToolBatch`, `Notification`, `MessageDisplay`, `SubagentStart`,
`SubagentStop`, `TaskCreated`, `TaskCompleted`, `Stop`, `StopFailure`, `TeammateIdle`,
`InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`,
`WorktreeCreate`, `WorktreeRemove`, **`PreCompact`**, `PostCompact`, `Elicitation`,
`ElicitationResult`, `SessionEnd`.

`PreCompact` kritik: hafızanın kaybolduğu asıl an bağlam sıkıştırmasıdır.

### 4.7 Windows'ta hook çalıştırma deseni

`.sh` doğrudan çalışmaz; `shell` alanı kullanılır (`"bash"` | `"powershell"`, Git Bash
kuruluysa varsayılan `bash`). claude-mem'in üretim kodundaki desen:

```sh
command -v cygpath >/dev/null 2>&1 && { _W=$(cygpath -w "$_P"); [ -n "$_W" ] && _P="$_W"; }
```

91k⭐'lı bir üründe çalıştığı kanıtlı. Ağır işler için `"async": true` kullanılıyor.

### 4.8 `awk` ile JSON alan çıkarımı — regex DEĞİL, elle tarama

> **FAZ 0 düzeltmesi (Ö-3). Bu bölümün ilk hâlindeki regex tabanlı snippet SİLİNDİ.**

Regex tabanlı `field()` fonksiyonu bir `.awk` dosyasına yazıldığında patladı:
```
awk: fatal: invalid regexp: unbalanced [: /"hook_event_name"[[:space:]]*:...
```
Kök neden: ters-slash'lar her alıntılama katmanında (heredoc → kabuk → dosya yazımı)
yarıya iniyor; awk string katmanı bir kat daha yiyor → regex bozuluyor. Snippet
"bir kere çalıştı" diye güvenilemez.

**Kullanılacak sürüm:** `lib/jsonfield.awk` — regex yok, elle karakter tarama,
ters-slash `sprintf("%c", 92)` ile üretiliyor. Gerçek yakalanmış payload'la doğrulandı:

```
hook_event_name = [PostToolUse]
tool_name       = [Read]
file_path       = [C:\Users\SelmanBuilds\.claude\jobs\df68423a\tmp\taskbar_overflow.png]
--- camelCase kontrolü: toolName=[] toolInput=[] hookEventName=[]  ← hepsi boş, doğru
```

Doğrulandı: `\"` → `"`, `\n` → gerçek satır sonu, `\t`, `\r`, UTF-8 korunuyor; bulunmayan
alan boş dize döndürüyor (çökmüyor).

**Bilinen iki sınır — FAZ 1 Adım 1 durumu:**
1. **Kapsamsız arama — DÜZELTİLDİ.** `jsonfield_from(s, key, start)` + `jf_anchor` eklendi;
   tuzak testiyle kanıtlandı (`tests/fixtures/trap-before.json`): `tool_response` içindeki
   `"file_path"`, `tool_input`'tan önceyse kapsamsız sürüm yanlış (TUZAK.md), kapsamlı
   doğru (dogru.md) döndürüyor. Teorik risk değildi.
2. **Sınırsız girdi — yumuşatıldı.** 448 KB tek satırlık gerçekçi payload ölçümü: tam satır
   33 ms, sınırlı önek 37 ms — önek aslında biraz daha yavaş. Karakter döngüsü yalnızca
   çıkarılan değer üzerinde koşuyor, `index()` hızlı tarıyor. `head -c 65536` **ucuz
   sigorta** olarak kalır (bellek sınırı + `tool_response`'a hiç dokunmama), performans
   şartı değildir. `RAW=$(cat)` yine de **kullanılmaz** (akış okunur).

**Yan not:** `awk -f prog.awk '{...}' dosya` çalışmaz — `-f` ile satır içi program
karıştırılamaz. Hep `-f` + `-f` kullan.

### 4.9 Emoji'li klasör adları Git Bash'te sorunsuz

`🔮 850-Companion/` oluşturuldu, yazıldı, okundu — sorun yok. Ancak OneDrive senkronlu
dizinlerde risk olabilir; kurulumda kontrol edilmeli.

### 4.10 Ölçülen ortam (referans)

`perl` **Git for Windows ile birlikte gelir** (`C:\Program Files\Git\usr\bin\perl.exe`,
`sed`/`awk` ile aynı paket). `python3` **yok** (Windows Store stub'ı). `jq` **yok**.
`node` v24 ve `rg` 15.2.0 var ama **garanti sayılmamalı** — `rg` sadece opsiyonel hızlandırıcı.
`shellcheck` ve `checkbashisms` **yok** → FAZ 6 CI'da kurulacak.

### 4.11 KURAL: kaçış dizisine dayanan kod yazma (FAZ 0 · Ö-3)

§4.1 (sed çok baytlı sınıf hatası) ve Ö-3 (awk regex çökmesi) aynı hastalığın iki yüzü.
Genel kural:

> **Ters-slash ve çok baytlı karakterleri asla literal olarak yazma. Kod noktasından üret:
> `sprintf("%c", 92)`. Hiçbir alıntılama katmanı bozamaz.**

Bu kural `jsonfield.awk`, `jsonemit.awk` ve tüm `fold/*.sed` profilleri için bağlayıcıdır.

### 4.12 `PostToolUse` şeması DOĞRULANDI (FAZ 0 · Ö-6)

Alan adları tam olarak **`tool_name`** ve **`tool_input.file_path`**. Hepsi snake_case,
camelCase varyant **yok**. Gerçek yakalanmış payload'la doğrulandı (simülasyon değil).

Ham stdin'de bulunan diğer alanlar (claude-mem 13.15.2 adaptöründen, bağımsız ikinci kaynak):
`session_id`, `cwd`, `prompt`, `tool_response`, `transcript_path`, `agent_id`, `agent_type`,
`permission_mode`, `model`, `turn_id`, `stop_hook_active`, `last_assistant_message`; ve
`SessionStart` için `source` (`startup|resume|clear`).

**Payload çok büyük olabilir:** ölçülen örnek **458 KB** — `tool_response` bir görüntünün
base64'ünü taşıyordu. `quipu capture` asla tüm stdin'i belleğe almamalı. İhtiyaç duyulan
alanlar baştadır: **ilk eşleşmede dur, `tool_response`'a hiç dokunma.**

### 4.13 YASAK: `conhost.exe` / `cmd.exe` sarmalayıcısı (FAZ 0 · Ö-7)

`conhost.exe --headless cmd.exe /d /c ...` deseniyle çalıştırılan hook'ların stdout'una
**3456 ANSI escape baytı** ve **3446 imleç konumlandırma dizisi** karışıyor — ve sadece
gürültü değil, **veri bozuluyor**:

```
"tool_use_id":"toolu__015hFqYvgmSCUQuGojU1L5QR"
              └─ çift alt çizgi; gerçek değer toolu_015hFq...
```

Satır kaydırma sınırında karakter tekrarlanıyor, 3446 kaydırmanın her birinde.

**Doğru desen** (claude-mem 13.15.2 üretiminde kanıtlı):
```json
{ "type": "command", "shell": "bash", "command": "<sh komutu>",
  "timeout": 120, "async": true }
```

### 4.14 Hook `command` alanı doğrudan `.sh` OLAMAZ (FAZ 0 · Ö-2)

Claude Code hook'ları Node `child_process.spawn` ile başlatır:

| Çağrı | Sonuç |
|---|---|
| `spawn("<yol>/probe.sh", …)` | ❌ **`EFTYPE`** — süreç hiç başlamıyor |
| `spawn("bash", ["<yol>/probe.sh", …])` | ✅ exit=0, stdin tam |
| `spawn("sh",   ["<yol>/probe.sh", …])` | ✅ exit=0, stdin tam |

Zorunlu desen: `command: "bash"` + `args: ["<mutlak yol>", "<etiket>"]`, ya da §4.13'teki
`shell: "bash"`. Sessiz başarısızlık değil, sert hata — yanlış yapılandırma fark edilir.

### 4.15 Hook yapılandırması çalışan oturuma sıcak yüklenmez (FAZ 0 · Ö-4)

`.claude/settings.json` mid-session yazılıp hook tetiklenmeye çalışıldı → hiçbir capture
düşmedi. Bu kasıtlı güvenlik davranışı: yapılandırma oturum başında okunuyor, aksi hâlde
bir repo açmak mid-session kod çalıştırabilirdi.

**Etkisi:** adaptör testleri (FAZ 3+) oturum yeniden başlatması gerektirir. Kurulum
betiği kullanıcıya bunu açıkça söylemeli.

### 4.16 `awk -v` kaçış dizilerini İŞLER — ham veri stdin/dosyadan geçer (FAZ 1 Adım 3)

`awk -v X="$değer"` değerdeki `\n`, `\t`, `\uXXXX` benzeri dizileri çözer. Canlı yakalandı:
`context --json` ilk sürümü bağlamı `-v JE_CTX=...` ile geçiriyordu; Windows yolu
`C:\Users\alice\...` → `C:Users\u0007lice...\t...` olarak **BOZULDU** (`\U`→U, `\a`→BEL,
`\t`→tab). Test 52 başlangıçta yakalayamadı çünkü test verisinde ters-slash yoktu.

**KURAL: `-v` yalnız sabit/kontrollü değerler için (mod adı, anahtar, katlanmış sorgu).**
Kullanıcı verisi stdin ya da dosya üzerinden geçer — awk her ikisini bayt bayt okur,
kaçış çözmez. Düzeltme: `lib/emit_hookctx.awk` bağlamı stdin'den okur; test 52 gerçek
Windows yoluyla güçlendirildi.

---

## 5. Ajan entegrasyon yüzeyleri

claude-mem'in kaynak kodundan çıkarıldı (`src/services/integrations/`).

| Ajan | Yapılandırma yüzeyi | Mekanizma |
|---|---|---|
| Claude Code | `~/.claude/settings.json` (+ plugin) | yerel hook |
| Codex CLI | `~/.codex/config.toml` (`hooks` özellik bayrağı) | yerel hook |
| OpenCode | `opencode.json` → `plugin: []` + `plugins/*.js` | JS eklenti |
| Cursor | `cursor-hooks/hooks.json` | hook |
| Windsurf | `.windsurf/` | hook |
| **Hepsi / bilinmeyen** | **`AGENTS.md` — etiketli blok** | **evrensel köprü** |

**Evrensel köprü deseni:** `AGENTS.md` içine `<!-- quipu:start -->` … `<!-- quipu:end -->`
etiketleri arasına sadece kendi bloğunu yaz, kullanıcının içeriğine dokunma. claude-mem
Codex'i zamanla AGENTS.md'den yerel hook'lara taşımış — yani **AGENTS.md taban, hook yükseltme.**

---

## 6. Uygulama fazları

### FAZ 0 — Doğrulama ✅ TAMAMLANDI (2026-08-19)

| # | Madde | Sonuç |
|---|---|---|
| 1 | `PostToolUse` şeması `tool_name` / `tool_input.file_path` mi | ✅ **DOĞRULANDI** (gerçek payload) → §4.12 |
| 2 | `SessionStart` çıktısı bağlama giriyor mu | ✅ evet — JSON yolu temiz, düz stdout farklı etiketle → §4.5 |
| 3 | `PreCompact` tetikleniyor mu | ⏳ oturum yeniden başlatması gerekiyor — **FAZ 3'ü etkiler, FAZ 1'i engellemez** |
| 4 | Windows'ta `.sh` çalıştırma | ✅ **DOĞRULANDI** — doğrudan `.sh` = `EFTYPE` → §4.14 |

Planın 1 numaralı riski **kapandı**: Katman 0 tasarımı olduğu gibi geçerli, git-diff
fallback'ine inmeye gerek yok. Ayrıntılı ölçüm kaydı: `FAZ0-BULGULAR.md`.

Probe hook'ları `.claude/settings.json` + `.claude/faz0/` içinde duruyor; bir sonraki
Claude Code açılışında madde 3 kendiliğinden kapanacak.

---

### FAZ 1 — Çekirdek CLI (tek dosya, POSIX sh)

**Sıralama kararı: CI, FAZ 1'in ortasına girer.** Ne önce ne sonra:

| Adım | İş | Neden bu sırada |
|---|---|---|
| **1** | İlkeller + test koşucusu | Test edilecek bir şey olmadan CI tiyatrodur |
| **2** | CI matrisi (yeşil) | CLI yüzeyi büyümeden platform tabanı sağlamlaşsın |
| **3** | CLI yüzeyi | Her komut üç OS'ta doğrulanarak eklenir |

Gerekçe: bulunan en kötü üç hata — `sed` çok baytlı sınıf (§4.1), kaçış katmanı çökmesi
(§4.8), BSD `stat` (§4.4) — **hepsi tam olarak bu ilkellerde**. CLI'ı bitirip sonra CI
eklemek, macOS/BSD kırılmalarını geniş yüzeyde aynı anda keşfetmek demek: avenoxbeyin'in hatası.

#### Adım 1 — İlkeller ve testler

- **`lib/jsonfield.awk`** (okuyucu) — FAZ 0'dan taşınır, §4.8'deki iki sınırı düzeltilerek:
  `jsonfield_from(s, key, startpos)` varyantı + sınırlı önek okuma (`head -c 65536`).
  `RAW=$(cat)` **kullanılmaz** (akış, değişken değil).
- **`lib/jsonemit.awk`** (yazıcı, YENİ) — `"`, `\`, satır sonu, tab, kontrol karakterleri
  kaçırır. §4.11 kuralı geçerli: ters-slash `sprintf("%c",92)` ile üretilir.
  Kullanım: `{"hookSpecificOutput":{"hookEventName":"…","additionalContext":"…"}}`
- **`fold/{tr,latin,default}.sed`** — §4.1-4.3 bağlayıcı: karakter sınıfı yok, her karakter
  ayrı `s///`; sıra **önce katla, sonra `tr 'A-Z' 'a-z'`**; Türkçe `I → ı → i`.
- **`i18n/{tr,en}.txt`** — key=value, awk ile okunur.
- **`tests/run.sh`** — harici çatı yok, `assert_eq` yeterli. Kapsam:

| Test | Kaynak |
|---|---|
| `jsonfield`: `\"`, `\n`, `\t`, `\r`, UTF-8, eksik alan | §4.8 |
| `jsonfield_from`: `tool_response` içindeki tuzak alan eşleşmemeli | §4.8 |
| Sınırlı önek: 458 KB payload'da doğru alanlar, sınırlı sürede | §4.12 |
| `jsonemit` → `jsonfield` gidiş-dönüş | yeni |
| Katlama: tr/de/fr/es doğruluk + ja/zh/Kiril/emoji bozulmazlık | §4.1-4.3 |
| `mtime()` taşınabilirliği | §4.4 |
| POSIX uyumu (`shellcheck -s sh`) | §3 |

> **Fixture olarak gerçek payload:** FAZ 0'da yakalanan 458 KB'lık payload en değerli test
> verisi — ANSI bozulması, base64 `tool_response` ve boyut baskısı bir arada.
> `tests/fixtures/`'a alınmalı, **ama önce temizlenmeli**: kullanıcı yolları, `session_id`,
> `transcript_path` ve base64 gövdesi kısaltılarak. Ham hâliyle commit edilmez.

#### Adım 2 — CI matrisi

`.github/workflows/ci.yml`, `[ubuntu-latest, macos-latest, windows-latest]`. Kritik detaylar:
- **Her adımda `shell: bash`** — `windows-latest` varsayılanı PowerShell'dir ve UTF-8
  kodlamasını bozar; katlama testleri buna duyarlı.
- macOS runner = **BSD `sed`/`awk`/`tr`/`stat`** → §4.1-4.4'ün gerçek sınavı.
- `shellcheck -s sh` üç OS'ta da koşar.
- `.gitattributes` ile `*.sh text eol=lf` + `core.autocrlf false` — CRLF `#!/bin/sh`
  satırını bozar, Windows'ta commit sırasında sessizce oluşur.

**Çıkış koşulu:** üç OS'ta yeşil.

#### Adım 3 — CLI yüzeyi

```
quipu doctor    # ortam teşhisi: hangi araç var, hangi ajan kurulu, ne bozuk
quipu capture   # activity.log'a satır ekle (sınırlı önek okur)
quipu index     # .quipu/index.tsv üret/güncelle (artımlı)
quipu search    # katlanmış sözcüksel + BM25 (indeks küçükse ajan anlamla seçer)
quipu init      # .quipu/ + AGENTS.md köprü bloğu (vault taksonomisi FAZ 2'de)
quipu context   # son oturum bağlamı; --json EVENT → §4.5 zarfı
```

`quipu doctor`, FAZ 0'ın envanterini (§4.10) kalıcı bir komuta çevirir.

Sıralama gerekçesi: `doctor` önce (teşhis), sonra `yakala → indeksle → ara` zinciri
(katman sırası), `init`/`context` sonda (vault varsayar). `context --json`, FAZ 3
adaptörünün yalnızca bir yapılandırma dosyası olabilmesinin şartıdır (§4.5 zarfını
üretir). `remember` (Last-Session/Threads talimatı) FAZ 3'e (SessionEnd) ertelendi.

**Yasak desenler** (CI veya kod incelemesinde zorlanır):
`declare -A` · `${var,,}` · `[[ ]]` · `=~` (POSIX değil) · `conhost`/`cmd` sarmalayıcısı
(§4.13) · hook `command`'ında doğrudan `.sh` (§4.14) · kaçış dizisine dayanan kod (§4.11)
· ham kullanıcı verisini `awk -v` ile geçirmek (§4.16)

#### Depo yapısı

```
quipu/
├── quipu                      # tek dosya POSIX sh CLI
├── lib/{jsonfield,jsonemit,index,capture,search,block,emit_hookctx}.awk
├── fold/{tr,latin,default}.sed
├── i18n/{tr,en}.txt
├── tests/run.sh + tests/fixtures/ + tests/drivers/
├── docs/PLAN.md               # bu dosya buraya taşınır
├── docs/FAZ0-BULGULAR.md
├── .github/workflows/ci.yml
├── .gitattributes             # *.sh text eol=lf
└── .gitignore                 # .quipu/, activity.log, capture-*.jsonl, .claude/faz0/
```

Lisans ilk commit'ten önce seçilmeli (avenoxbeyin MIT, claude-mem Apache-2.0).

### FAZ 2 — Vault iskeleti + kimlik
- Klasör yapısı (avenoxbeyin'den ilham, emoji opsiyonel — `--plain` bayrağı olsun)
- `AGENTS.md` (evrensel) + `CLAUDE.md` (ona işaret eden ince dosya)
- Companion persona **veri olarak** (`companion.md`), kod değil → dil paketi gibi değiştirilebilir

### FAZ 3 — Claude Code adaptörü (referans uygulama)
- `SessionStart` → bağlam enjeksiyonu (**JSON zarfı**, `lib/jsonemit.awk` — bkz. §4.5)
- `PostToolUse` (async) → `quipu capture`
- `PreCompact` → "şimdi hafızayı yaz" uyarısı
- `SessionEnd` → append-only özet + `git commit`

### FAZ 4 — Diğer adaptörler
Codex → OpenCode → Cursor/Windsurf. Her biri **sadece bir yapılandırma dosyası** olmalı;
yeni kod gerekiyorsa çekirdek CLI yanlış tasarlanmış demektir.

### FAZ 5 — Hook'suz fallback
- `quipu capture --git` : çalışma ağacını son commit'le karşılaştır, değişenleri çıkar
- `AGENTS.md` blok enjeksiyonu (etiketli, kullanıcı içeriğine dokunmadan)

### FAZ 6 — Genişletilmiş CI matrisi (entegrasyon)
CLI yüzeyi (Adım 3) tamamlanınca Adım 2'nin matrisi **ayrı bir matris kurmadan** büyür;
aynı `[ubuntu-latest, macos-latest, windows-latest]` üzerinde uçtan uca senaryolar eklenir:
- indeks üretimi (`quipu index` çıktısı),
- arama isabeti (katlanmış sorgu → beklenen adaylar),
- `init → capture → index → search` zinciri.
Adım 2'de zaten kapsananlar (dil katlama doğruluğu, `mtime` taşınabilirliği, `tr` sırası,
POSIX uyumu) tekrarlanmaz.

> **Bu faz projenin kendisidir, cilası değil.** avenoxbeyin bozuk yayınlandı çünkü ikinci bir
> makinede hiç çalıştırılmadı. Bölüm 4'teki üç hatanın hepsini bu matris otomatik yakalardı.

---

## 7. Bilinen riskler ve dürüst sınırlar

| Risk | Not |
|---|---|
| ~~`PostToolUse` şeması doğrulanmadı~~ | ✅ **KAPANDI** — FAZ 0'da gerçek payload'la doğrulandı (§4.12) |
| `jsonfield` kapsamsız arama | `index(s,key)` tüm string'i tarar; `tool_response` içindeki literal `"file_path"` yanlış eşleşebilir. → `jsonfield_from` + sınırlı önek (§4.8) |
| Büyük payload | Ölçülen örnek 458 KB (base64 `tool_response`). `capture` asla tüm stdin'i belleğe almamalı (§4.12) |
| CRLF satır sonu | `*.sh text eol=lf` yoksa Windows'ta commit sırasında CRLF girer ve `#!/bin/sh` bozulur. → ✅ **KAPANDI** (Adım 2: `*.sh eol=lf`; Adım 3: uzantısız `quipu` için `/quipu text eol=lf`) |
| Hook config sıcak yüklenmez | Adaptör testleri oturum yeniden başlatması gerektirir; kurulum betiği bunu söylemeli (§4.15) |
| İndeks bağlam sınırı | Semantik katman indeksi ajanın okumasına dayanır. Birkaç bin nota kadar rahat; ötesinde iki aşamalı daralt-sonra-oku gerekir. |
| Başlık/etiket boost'u | Katlanmış terim ham başlıkla karşılaştırıldığı için ×2/×1.5 ağırlık yalnız ASCII başlıklarda ateşler. Geri çağırma etkilenmez (katlanmış alan başlığı zaten içerir), yalnız sıralama. |
| Negatif IDF | Tek dokümanlı vault'ta BM25 IDF negatife düşer; `search.awk` bunu `matched` bayrağıyla telafi eder (dokümanın kendi duman testi bunu gerektiriyor). |
| "Semantik" ≠ kosinüs benzerliği | Model yargısı. Anlamda daha iyi, kapsayıcı geri çağırmada daha zayıf. Farklı kalite profili — dürüstçe belgelenmeli. |
| Katlama kayıplı | `açık` ve `acık` çakışır. Bilinçli tercih, belgelenmeli. |
| `activity.log` şişmesi | `PostToolUse` çok sık tetiklenir; rotasyon şart. → ✅ **KAPANDI** (Adım 3: 256 KB eşik, tek nesil `.1` rotasyonu — `QUIPU_LOG_MAX` ile ayarlanır) |
| macOS/BSD test edilmedi | Bölüm 4 bulguları Windows+Git Bash'te ölçüldü. BSD `sed`/`awk`/`tr` farklılıkları CI'da doğrulanmalı. |
| Emoji klasörler + OneDrive | Kurulumda kontrol et. `--plain` alternatifi sun. |

---

## 8. avenoxbeyin'e bildirilecek hatalar (ayrı iş)

Bu üç hata hem repoda hem `avenox.lol/beyin.md`'de **birebir** duruyor ve macOS'ta da geçerli.
`beyin.md` sadece sahibinin düzeltebileceği bir dosya (avenox.lol'de barınıyor) — bu yüzden
PR yerine **önce issue** açılmalı.

1. **`python3` bağımlılığı sessizce her şeyi öldürüyor** — üç hook da JSON kaçışını `python3`'e
   yaptırıyor; yoksa `ESC` boş kalır, `echo` hiç çalışmaz, **hata da vermez**. Hafıza enjeksiyonu
   tamamen sessizce ölür. (JSON zarfının kendisi gerekli — §4.5 — ama onu üretmek için
   `python3`'e hiç gerek yok; awk ile üretilebilir, bkz. §4.11.)
2. **`stat -f %m` BSD'ye özel** — Linux/Git Bash'te hata verir, `MODIFIED=0` kalır, her oturum
   yanlış "hafıza güncellenmedi" alarmı düşer. Döngü ters çalışıyor.
3. **Literal `\n` hatası** — `CTX="${CTX}${REFLECTION}\n\n"` bash'te çift tırnak içinde gerçek
   satır sonu üretmez; `od -c` ile doğrulandı (`\` `n` = 0x5C 0x6E). JSON kaçışından sonra
   enjekte edilen metinde satır sonu yerine gözle görünür `\n` yazıları çıkıyor.

**Repo durumu (2026-08-19):** 25⭐, 1 boş fork, 0 issue, 0 PR, tek commit (2026-06-29),
~7 hafta sessiz. Sahibi (`avenoxai`) çok aktif — 24 repo, 250 takipçi, aynı gün başka
repolara push atmış. Yani hesap canlı, repo terk. **0 PR** olduğu için bakımcının PR
birleştirip birleştirmediğine dair kanıt yok → önce ucuz bir issue ile yanıt verip
vermediğini test et.

---

## 9. Durum ve sonraki adım

**Tamamlanan:** FAZ 0 ✅ (2026-08-19) — 4 maddeden 3'ü doğrulandı, 1'i (PreCompact) FAZ 3'e
ertelendi. FAZ 1 Adım 1 ✅ — ilkeller + `tests/run.sh`. FAZ 1 Adım 2 ✅ — üç OS'ta yeşil CI
matrisi (`b63fb5f`; macOS runner = BSD `sed`/`awk`/`tr`/`stat` sınavı). FAZ 1 Adım 3 ✅
(2026-08-20) — altı komutlu CLI yüzeyi: `doctor`, `capture`, `index`, `search`, `init`,
`context`; yerelde 80/80, 2 SKIP (shellcheck yerelde yok, CI kuruyor).

**Sıradaki:** Adım 3'ün commit + push'u → shellcheck ve üç OS CI'sının Adım 3 kodunda
yeşile alınması. Sonra FAZ 2: vault taksonomisi + kimlik (`companion.md`, `Threads.md`).

### Çalışmaya başlarken
1. Bu dosyayı ve `FAZ0-BULGULAR.md`'yi oku (ölçüm ayrıntıları orada).
2. `.claude/faz0/jsonfield.awk` → `lib/`'e taşı, §4.8'deki iki sınırı düzelt.
3. `tests/run.sh` yazılmadan CLI yüzeyine geçme.
4. `git init` + `.gitattributes` (`*.sh text eol=lf`) ilk commit'ten **önce**.
5. Lisans ilk commit'ten **önce** seçilmeli — avenoxbeyin MIT, claude-mem Apache-2.0.

### Referans dosyalar
- `FAZ0-BULGULAR.md` — 258 satır, her bulgu yeniden üretme yoluyla
- `.claude/faz0/` — probe betiği, gerçek payload, çalışan `jsonfield.awk`
  (commit edilmez, `.gitignore`'a girer; FAZ 3'e kadar yerinde kalabilir)
