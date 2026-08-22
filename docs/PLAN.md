# quipu — Uygulama Planı

> **Bu dosya ne?** Sıfırdan yazılacak bir projenin tam planı. Başka bir Claude Code
> oturumunda, hiçbir ön bilgi olmadan açılıp uygulanabilecek şekilde yazıldı.
> Buradaki tüm teknik bulgular **ölçülmüş ve doğrulanmıştır** — tahmin değildir.
> Kanıtlar "Doğrulanmış Bulgular" bölümünde, yeniden üretme komutlarıyla birlikte.
>
> **Tarih:** 2026-08-22 · **Durum:** FAZ 7'ye kadar kod+testler yerelde tamam ve commit'li (son: FAZ6+FAZ7 `dea829c`, docs geri getirme `ecca473`) — **ama dal hiç push edilmedi**: `git branch -a` çıktısında `origin/faz6-faz7` yok, PR açılmamış, üç OS CI hiç koşmamış; iki fazın da çıkış koşulu ("Dal + PR, üç OS CI yeşil olmadan merge yok") bu yüzden **karşılanmadı** (`git tag -l` de boş, `v1.0.0` etiketi yok). FAZ 8 (yansıtıcı hafıza) kodu ve artık `docs/FAZ8-BULGULAR.md` da yazıldı (Dilim 0 çıkış koşulu karşılandı) ama diff **hâlâ commit edilmedi**. FAZ 9'un runbook'u (`docs/KURULUM.md`) da yazıldı, ama `sh tests/run.sh` yeşil doğrulanmadı ve şu haliyle **FAIL verir** — sebep içerik değil, testin kendi hatası: T-120 (`tests/run.sh:1461`) `tr '\n' ' '` ile sonda boşluk bırakıyor, `assert_eq` boşluksuz bekliyor; ayrıca T-120'nin `capture` kelimesini yasaklayan iddiası `FAZ9-SPEC.md` §2'nin hook'suz fallback anlatımıyla çelişiyor, karara bağlanmadı. `FAZ7-SPEC.md:62`'deki 120s eşiği de gerçek `tests/run.sh` sınırı 3600s ile hâlâ uyumsuz (J-7). Ayrıntı: Bölüm 6 ve 9.
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

**Köprü sapması (FAZ 5, H-11):** yukarıdaki diyagram "son oturum + aktif konular"ı
`<!-- quipu:start -->` bloğunun içinde çiziyor. Uygulamada dinamik bağlam **ayrı** bir
bloktadır: statik `quipu:start` bloğu `init`'in malı kalır (kurulum rehberi); `context
--bridge` bağlamı ikinci `<!-- quipu:context:start/end -->` bloğuna yazar.

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
| Taksonomi | Beş klasör: `100-Inbox`, `300-Projects`, `500-Knowledge`, `700-Sessions`, `850-Companion`; emoji varsayılan, `--plain` ASCII'ye düşürür | `docs/FAZ2-SPEC.md` §0 (K-1/K-2), §3; klasör adı değişikliği = kullanıcı vault'unda taşıma |

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

### 4.17 grep çok baytlı kalıpları eşleştirmeyebilir

Windows'ta GNU grep 3.0, `LANG=en_US.UTF-8` altında 4 baytlık emoji kalıplarını eşleştirmiyor:

```sh
printf '[🔮 850-Companion]\n' | grep -q '🔮' && echo hit || echo miss   # miss
printf '[🔮 850-Companion]\n' | awk 'index($0, "🔮") {print "hit"}'      # hit
```

| Araç | Sonuç |
|---|---|
| `grep -q` | eşleşmiyor |
| `grep -qF` | eşleşmiyor (`-F` de kurtarmıyor) |
| `awk index()` | eşleşiyor |
| `grep 'OneDrive'` (ASCII) | eşleşiyor |

> **KURAL:** Çok baytlı bir dizgeyi metinde ararken `grep` kullanma; `awk index()` kullan.
> ASCII dizgeler için `grep` güvenlidir.

### 4.18 FAZ 3 ölçümü: `PreCompact` çıktısı modele ULAŞMIYOR; `SessionEnd` güvenilmez (FAZ 3 · E-0)

Claude Code 2.1.237 üzerinde canlı ölçüldü (`docs/FAZ3-BULGULAR.md`'de tüm
payload'lar ve yeniden üretme yolları):

1. **`PreCompact` tetikleniyor ama çıktısı bağlama girmiyor.** `trigger:"auto"`
   payload'ı yakalandı; aynı oturumda modele soruldu: `SessionStart` zarfı görünüyor,
   `PreCompact` zarfı **hiç görünmüyor** — sıkıştırmadan hemen sonra bile.
   → FAZ 3 talimat mekanizması `UserPromptSubmit` + bayatlık eşiği üzerine kuruldu.
2. **`SessionEnd` güvenilmez:** print modunda, `/exit`'te ve kill'de hiç ateşlenmiyor;
   `/clear` geçişinde (`reason:"clear"`) ve bazı temiz bitişlerde (`reason:"other"`)
   ateşleniyor. → `quipu remember` adaptörde `SessionStart` zincirinde de koşuyor
   (filigran idempotent yapıyor).
3. **`SessionStart source` değerleri:** `startup | resume | clear | compact` — dördü
   de canlı ölçüldü. `compact` her otomatik sıkıştırma sonrası yeniden ateşleniyor ve
   bağlam enjeksiyonu o anda da çalışıyor.
4. **Async hook çıktısı bağlama "system-reminder" olarak giriyor** → adaptörün
   `PostToolUse` hook'u (`quipu capture`) stdout'a hiçbir şey yazmaz; gürültü sıfır.
5. **Windows hook spawn PATH'i `bash`'i bulamıyor** (Git yalnız `cmd` dizinini PATH'e
   koyar) → "Executable not found in $PATH: bash" (non-blocking, oturum devam eder).
   README'ye Git `bin` PATH notu eklendi.
6. **Hook `env` anahtarı yok** (iki mekanizma da ölçüldü) → adaptör komutları
   `QUIPU_HOOK=1 quipu …` biçiminde.

---
## 5. Ajan entegrasyon yüzeyleri

claude-mem'in kaynak kodundan çıkarıldı (`src/services/integrations/`).

| Ajan | Yapılandırma yüzeyi | Mekanizma |
|---|---|---|
| Claude Code | `~/.claude/settings.json` (+ plugin) | yerel hook |
| Codex CLI | `~/.codex/config.toml` (`hooks` özellik bayrağı) | yerel hook |
| OpenCode | `opencode.json` → `plugin: []` + `plugins/*.js` | JS eklenti — **iptal (2026-08-21 kararı)** |
| Cursor | `cursor-hooks/hooks.json` | hook — **iptal (2026-08-21 kararı)** |
| Windsurf | `.windsurf/` | hook — **iptal (2026-08-21 kararı)** |
| **Hepsi / bilinmeyen** | **`AGENTS.md` — etiketli blok** | **evrensel köprü** |

**Evrensel köprü deseni:** `AGENTS.md` içine `<!-- quipu:start -->` … `<!-- quipu:end -->`
etiketleri arasına sadece kendi bloğunu yaz, kullanıcının içeriğine dokunma. claude-mem
Codex'i zamanla AGENTS.md'den yerel hook'lara taşımış — yani **AGENTS.md taban, hook yükseltme.**

**İptal notu (2026-08-21):** OpenCode, Cursor ve Windsurf adaptörleri v1'e alınmadı. Bu üç
ajan evrensel köprüden geçer: `AGENTS.md` bloğu (`context --bridge`) + `capture --git`. Satırlar
tarihsel kayıt olarak tabloda kalır; v2'de yeniden değerlendirilir.

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

### FAZ 2 — Vault iskeleti + kimlik ✅
- Klasör yapısı (avenoxbeyin'den ilham, emoji opsiyonel — `--plain` bayrağı olsun)
- Yerleşim 2026-08-22'de avenoxbeyin taksonomisine yaklaştırıldı (on klasör, veri odaklı: `layout/*.txt` + `layout_*` i18n anahtarları); sapmaların gerekçesi: `📆 700-Sessions` KALIR (`remember` oraya yazar), Companion'a `Core.md`/`Journal.md` EKLENMEDİ (quipu bunları hiç yazmaz → ölü dosya), `Threads.md` KÖKTE kalır (`_q_ctx_text` kökten okur), `000-Inbox` seçildi çünkü eski `100-Inbox` yeni `100-Command-Center` ile numara çakıştırıyordu
- `AGENTS.md` (evrensel) + `CLAUDE.md` (ona işaret eden ince dosya)
- Companion persona **veri olarak** (`companion.md`), kod değil → dil paketi gibi değiştirilebilir

### FAZ 3 — Claude Code adaptörü (referans uygulama) ✅
- `SessionStart` → `quipu remember` + bağlam enjeksiyonu (`quipu context --json SessionStart`)
- `PostToolUse` (async) → `quipu capture` (matcher `Edit|Write|NotebookEdit|Read`)
- `UserPromptSubmit` → bayatlık nudge'ı (`quipu context --json UserPromptSubmit`)
- `SessionEnd` → `quipu remember` (mekanik sindirim, filigran idempotent)

Tamamlandı (2026-08-20): `quipu remember` + filigran (`.quipu/remembered`, append-only
`<sessions>/YYYY-MM-DD.md`, `Last-Session.md` işaretçisi, `--dry-run/--git/--limit`), ortak
toplayıcı `lib/digest.awk`, `context` çıktı sınırı (`QUIPU_CTX_MAX`, varsayılan 4096) +
`UserPromptSubmit` bayatlık nudge'ı (`QUIPU_NUDGE_AFTER`, varsayılan 50, `.quipu/nudged`) —
**PreCompact dalı ölçümle düştü: çıktı modele ulaşmıyor (§4.18)** —, `adapters/claude-code.json`,
`doctor` hook kontrolü, `QUIPU_HOOK` sessiz-başarı bayrağı, README "Claude Code" bölümü;
testler 117 → 155 geçti + 2 skip (157 iddia). Üç OS CI yeşil (PR #3, 39d79cd).

### FAZ 4 — Çok-şemalı capture + Codex adaptörü ✅
Çok-şemalı capture (ajan-agnostik, payload şekline göre): `tool_input.file_path` varsa onu
kullan (Claude Code şeması, regresyonsuz), yoksa `apply_patch`'in unified diff'inden dosya
yolları çıkar; Codex adaptörü (`adapters/codex/hooks.json`, config-only) bunun üzerine oturur.
**Cursor/Windsurf/OpenCode ertelendi** (2026-08-20 kararı; OpenCode JS plugin gerektiriyor,
config-only değil).

### FAZ 5 — Hook'suz fallback ✅
- `quipu capture --git` : çalışma ağacını son commit'le karşılaştır, değişenleri çıkar
  (durumsuz; READ yakalanmaz; commit'siz iki koşu çoğaltır — §7 risk satırı)
- `quipu context --bridge` : son-oturum bağlamını AGENTS.md'deki ayrı
  `<!-- quipu:context:start/end -->` bloğuna yazar (statik `quipu:start` bloğu init'in malı kalır)

### FAZ 6 — Genişletilmiş CI matrisi (entegrasyon) ◐ (kod+yerel test tamam / PR+CI eksik)
CLI yüzeyi (Adım 3) tamamlanınca Adım 2'nin matrisi **ayrı bir matris kurmadan** büyüdü;
aynı `[ubuntu-latest, macos-latest, windows-latest]` üzerinde uçtan uca senaryolar eklendi:
- indeks üretimi (`quipu index` özet satırının tam şekli + artımlı sayımlar — T-74/T-75),
- arama isabeti (katlanmış sorgu → beklenen adaylar; zincir içinde `İstanbul`/`istanbul` — T-73),
- `init → capture → index → search` zinciri (T-72) ve git'li uzantısı: `commit → capture --git`
  sonrası **yeni satır yok** (H-9 dürüstlüğü zincirde kanıtlı — T-76), zincir vault'unda
  `doctor` 0 hata (T-77).
Adım 2'de zaten kapsananlar (dil katlama doğruluğu, `mtime` taşınabilirliği, `tr` sırası,
POSIX uyumu) tekrarlanmadı. Yeni koşucu, yeni CI işi, `ci.yml` değişikliği yok — kapsam
`tests/run.sh` içinde büyüdü (`docs/FAZ6-SPEC.md` I-1, `docs/FAZ6-BULGULAR.md` G-1).

> **Bu faz projenin kendisidir, cilası değil.** avenoxbeyin bozuk yayınlandı çünkü ikinci bir
> makinede hiç çalıştırılmadı. Bölüm 4'teki üç hatanın hepsini bu matris otomatik yakalardı.

**Denetim (`docs/FAZ6-KONTROL.md`, 2026-08-22):** G-1…G-5, I-1…I-8, T-72…T-77 doğru
uygulanmış, sözleşme ihlali yok (I-7 kısmi: PR referansı yok — tam olarak aşağıdaki
madde yüzünden, PR hiç açılmadı).

**Çıkış koşulu karşılanmadı (2026-08-22 doğrulandı):** FAZ6-SPEC'in çıkış koşulu "Dal +
PR, üç OS CI yeşil olmadan merge yok". `dea829c` ve `ecca473` yalnız yerel `faz6-faz7`
dalında duruyor; `git branch -a` çıktısında `origin/faz6-faz7` yok, PR açılmamış, üç OS
CI hiç koşmamış. Kod ve testler yerelde geçiyor (bkz. Bölüm 9) ama sözleşmenin şart
koştuğu çok-platform doğrulaması eksik — bu yüzden faz burada ✅ değil ◐ işaretlendi.

### FAZ 7 — Kapatıcı: DZ-4 + arama ölçeği + v1 ◐ (kod+yerel test tamam / PR+CI eksik)
- **DZ-4 kapandı:** `_q_die key [code [arg…]]` mesaj formatına argüman geçirir; capture / init /
  context / remember / search döngülerinde `-*) _q_die err_unknown_flag 2 "$1"` → `unknown flag:
  --nope`, exit 2. `err_missing_arg` çağrıları bit-birebir korundu (T-81 kilitler).
  **Davranış değişikliği:** `search`'te `-` önekli bilinmeyen argüman artık sessizce sorgu
  kelimesi olmuyor; bare kelimeler sorgu kalıyor.
- **`search --brief`:** 5. sütun = katlanmış alanın ilk 120 baytı, kelime sınırında kesilmiş,
  marker yok (`substr` dışında kesim mantığı yok). İki aşamalı desenin ikinci adımı:
  `search --limit 50 --brief` → ajan künyelerden seçer → yalnız seçtiklerini okur.
  `--paths` ile karşılıklı dışlar (`err_conflict`).
- **Ölçek ölçüldü:** 5000 dokümanlık sentetik vault (üreteç, fixture değil) — `index` 5000/5000,
  `search` ortak terimde 5000 isabet. Ölçüm: index 2150-2367 s (iki koşu), search 1 s (Windows msys).
  Test sınırı 3600 s bir **askıda kalma/regresyon tavanı**, performans iddiası değil; gerçek
  sayı her koşuda `# info:` satırıyla basılır.
- İptaller (2026-08-21 sahip kararı): avenoxbeyin issue'su, Cursor/Windsurf/OpenCode
  adaptörleri, Codex canlı doğrulaması (adaptör kodu repo'da kalır).

**Denetim (`docs/FAZ7-KONTROL.md`, 2026-08-22):** L-1…L-5, J-1…J-6, J-8, J-9, J-11 doğru
uygulanmış; **J-7 ve J-10 kısmi** — ayrıntı `FAZ7-KONTROL.md`'de. J-7 somut sapma:
`FAZ7-SPEC.md:62` "index < 120s" diyor ama `tests/run.sh:1173` `-lt 3600` uyguluyor.
Sapmanın gerekçesi (ölçülen 2150-2367 s) Bölüm 7 "İndeks bağlam sınırı" satırında ve
Bölüm 9'da var, ama `FAZ7-SPEC.md` bu güncellemede **hiç düzeltilmedi** — bkz. Bölüm 9
Açık kalemler.

**Çıkış koşulu karşılanmadı (2026-08-22 doğrulandı):** FAZ7-SPEC'in çıkış koşulu da FAZ 6
ile aynı ("Dal + PR, üç OS CI yeşil olmadan merge yok") ve aynı sebeple karşılanmadı —
`origin/faz6-faz7` yok, PR yok, CI koşmadı. Bkz. FAZ 6 altındaki not.

### FAZ 8 — Yansıtıcı hafıza ◐ (2026-08-22, kod+bulgular tamam / commit+yeşil suite eksik)

> **◐ işareti bu dosyada:** kod ve testler yazılmış ama kapanış koşulları (spec §6
> Dilim 0) tamamlanmamış — ne "✅ tamam" ne "hiç başlanmadı", aradaki gerçek durum.

Kod ve testler çalışma ağacında duruyor, **henüz commit edilmedi**:
- Y-1: oturum dosyasına yansıma bloğu, yalnız-yoksa append (`quipu:990-1004`) —
  `block.awk` kasıtlı kullanılmadı (blok içeriğini değiştirir, modelin yazdığını silerdi).
- Y-2: `_q_reflect_filled()` (`quipu:160-179`) — marker aralığında awk ile doluluk
  tespiti, `mtime` okuması yok (S-5.2).
- Y-3: kaçırılan yansıma bayrağı `.quipu/needs_reflection`'a yazılır (`quipu:1059`),
  bir sonraki `SessionStart`'ta okunup silinir (`quipu:843-845`, tek atış).
- Y-4: `ctx_reflect_ask` (`quipu:867-874`) — bugünkü oturum dosyası var ve blok boşsa
  modele doldurma isteği; `ctx_precompact` de güncellendi (`i18n/en.txt:70`).
- Y-5: beş yeni anahtar tr+en'de, iki dosyanın anahtar kümesi birebir eşit.
- Y-6: `bridge_reflect` i18n anahtarı AGENTS.md köprüsüne bağlandı (`quipu:677`).
- T-96…T-108: hepsi `tests/run.sh:1191-1360` içinde yazılı.

**Eksik — FAZ 8 bu yüzden hâlâ ✅ değil (2026-08-22 güncellendi):**
- ~~`docs/FAZ8-BULGULAR.md` hiç yazılmadı~~ → ✅ **yazıldı** (194 satır) — spec §6 Dilim 0
  çıkış koşulu (S-1…S-5 kaynaklı) artık karşılandı.
- `sh tests/run.sh` ile yeşil doğrulama **hâlâ yapılmadı** — suite bu haliyle zaten kırık,
  ama artık FAZ 8'in kendi hatasından değil: T-120'nin sondaki-boşluk hatası yüzünden
  (`tests/run.sh:1461`, bkz. Bölüm 9 Açık kalemler).
- Değişiklikler **hâlâ commit edilmedi**, çalışma ağacında duruyor.

### FAZ 9 — Kurulum deneyimi ◐ (2026-08-22, kimlik dilimi+runbook tamam / test hatası+spec çelişkisi eksik)

Aynı commit'lenmemiş diff'in içinde, kimlik kısmı (V-2…V-5) kodlanmış: `init
--user/--companion`, persona `%s` doldurma, `doctor` kimlik satırı; T-110…T-118
testleri yazıldı. `docs/FAZ9-BULGULAR.md` (185 satır) Dilim 0 bulgularını taşıyor.
V-1 (`docs/KURULUM.md`, 146 satır, ajan runbook'u) de artık yazıldı.

**Eksik (2026-08-22 güncellendi):**
- ~~V-1 yok~~ → ✅ **yazıldı** (`docs/KURULUM.md`).
- T-120 **kendi hatasıyla** FAIL veriyor, içerikten bağımsız: `tests/run.sh:1461`
  `CMDS120=$(... | sort -u | tr '\n' ' ')` sonda boşluk bırakıyor, `assert_eq`'in beklediği
  literal `'context doctor index init remember search'` boşluksuz — çıkarılan küme tam
  doğru (`context doctor index init remember search `), yalnız sondaki boşluk yüzünden
  eşitlik tutmuyor. `docs/KURULUM.md` ne yazarsa yazsın bu haliyle FAIL verir.
- T-120'nin dördüncü iddiası (`tests/run.sh:1472` civarı) `KURULUM.md`'de `capture`
  kelimesinin **hiç geçmemesini** şart koşuyor, ama `FAZ9-SPEC.md` §2 hook'suz fallback'i
  `capture --git + remember + context --bridge` üçlüsü olarak anlatıyor. `KURULUM.md`
  testi esas alıp yazıldı (fallback `capture` denmeden anlatıldı, git-diff kısmı için
  README'ye yönlendirildi) — spec ile test arasındaki bu çelişki bir karar bekliyor,
  bkz. Bölüm 9 Açık kalemler.

---

## 7. Bilinen riskler ve dürüst sınırlar

| Risk | Not |
|---|---|
| ~~`PostToolUse` şeması doğrulanmadı~~ | ✅ **KAPANDI** — FAZ 0'da gerçek payload'la doğrulandı (§4.12) |
| PreCompact enjeksiyonu | ✅ **KAPANDI** — FAZ 3'te canlı ölçüldü: `PreCompact` çıktısı modele **ulaşmıyor** (§4.18); talimat `UserPromptSubmit` + bayatlık eşiğine taşındı (`QUIPU_NUDGE_AFTER`) |
| `jsonfield` kapsamsız arama | `index(s,key)` tüm string'i tarar; `tool_response` içindeki literal `"file_path"` yanlış eşleşebilir. → `jsonfield_from` + sınırlı önek (§4.8) |
| Büyük payload | Ölçülen örnek 458 KB (base64 `tool_response`). `capture` asla tüm stdin'i belleğe almamalı (§4.12) |
| CRLF satır sonu | `*.sh text eol=lf` yoksa Windows'ta commit sırasında CRLF girer ve `#!/bin/sh` bozulur. → ✅ **KAPANDI** (Adım 2: `*.sh eol=lf`; Adım 3: uzantısız `quipu` için `/quipu text eol=lf`) |
| Hook config sıcak yüklenmez | Yapılandırma çalışan oturuma yüklenmez; README "Claude Code" bölümü yeniden başlatma uyarısını taşıyor (C-27, §4.15) |
| İndeks bağlam sınırı | Semantik katman indeksi ajanın okumasına dayanır. "Birkaç bin nota kadar rahat" iddiası FAZ 7'de **ölçüye çevrildi** (5000 dokümanlık sentetik vault). İki aşamalı daralt-sonra-oku artık üründe: `search --limit 50 --brief` her adaya 120 baytlık künye basar, ajan künyelerden seçer, yalnız seçtiklerini okur. **Ölçülmüş performans tavanı:** 5000 notluk `quipu index` Windows msys'te **2150-2367 s (~36-39 dakika, iki koşu)** sürüyor (ölçüm: T-85, her koşuda `# info:` satırıyla basılır; aynı indekste arama 1 s — T-86; dosya başına ~6 süreç doğuşu — alt kabuk + awk meta, alt kabuk + sed→tr→awk flat; msys'te `fork` pahalı) — Linux/macOS'ta çok daha hızlı. Bu bir doğruluk hatası değil, süreç-doğuşu maliyeti. **Dürüst bellek tavanı:** `search.awk` indeksin tamamını belleğe alır (her satır `folded[]`'e girer, `lib/search.awk:52`) → on binlerce notta akış tabanlı iki geçişli sürüm gerekir; **v2 adayı** (`docs/FAZ7-SPEC.md` §10). **Künye birimi:** kesim `awk` `substr`/`length` ile yapılır; gawk karakter, mawk bayt sayar — `fold=tr`/`fold=latin` vault'ta katlanmış alan ASCII olduğu için fark yok, `fold=default` vault'ta 120 sınırı platforma göre karakter ya da bayt olur ve ilk 120 baytta hiç boşluk yoksa çok baytlı karakter bölünebilir (F7 ölçümü). |
| Başlık/etiket boost'u | Katlanmış terim ham başlıkla karşılaştırıldığı için ×2/×1.5 ağırlık yalnız ASCII başlıklarda ateşler. Geri çağırma etkilenmez (katlanmış alan başlığı zaten içerir), yalnız sıralama. |
| Negatif IDF | Tek dokümanlı vault'ta BM25 IDF negatife düşer; `search.awk` bunu `matched` bayrağıyla telafi eder (dokümanın kendi duman testi bunu gerektiriyor). |
| "Semantik" ≠ kosinüs benzerliği | Model yargısı. Anlamda daha iyi, kapsayıcı geri çağırmada daha zayıf. Farklı kalite profili — dürüstçe belgelenmeli. |
| Katlama kayıplı | `açık` ve `acık` çakışır. Bilinçli tercih, belgelenmeli. |
| `activity.log` şişmesi | `PostToolUse` çok sık tetiklenir; rotasyon şart. → ✅ **KAPANDI** (Adım 3: 256 KB eşik, tek nesil `.1` rotasyonu — `QUIPU_LOG_MAX` ile ayarlanır) |
| macOS/BSD test edilmedi | Bölüm 4 bulguları Windows+Git Bash'te ölçüldü. BSD `sed`/`awk`/`tr` farklılıkları CI'da doğrulanmalı. |
| grep çok baytlı kalıp | Windows'ta GNU grep 3.0 4 baytlık emoji kalıplarını eşleştirmiyor. → ✅ **KAPANDI** (FAZ 2: testlerde `awk index()`'e geçildi, §4.17) |
| Emoji klasörler + OneDrive | Kurulumda kontrol et. `--plain` alternatifi sun. |
| Yerleşim yeniden adlandırma | Bu değişiklikten önce kurulmuş vault'lar iki klasör kümesine sahip olur (eski + yeni); `init` append-only — asla yeniden adlandırmaz veya silmez; taşıma kullanıcının elinde; v1 etiketi atılmadığı için göç betiği kapsam dışı |
| Codex hook şeması | `[doğrulanmadı]` — kaynak tabanlı (codex-rs); canlı Codex doğrulaması **iptal (2026-08-21 kararı: ChatGPT üyeliği yok)**. Adaptör kodu (`adapters/codex/hooks.json`) repo'da kalır; şema `[doğrulanmadı]` etiketiyle dürüstçe duruyor, README "Codex" bölümü de bunu yazıyor. |
| `capture --git` durumsuz | Git-diff yalnız içerik değişimini görür: `Read` yakalanmaz; commit'siz iki koşu aynı dosyaları çoğaltır (kullanıcı `capture --git`'i `remember --git`'ten önce koşar). Silme yakalanır, index `drop`'a bırakılır. |
| ~~Bilinmeyen bayrak tanısı~~ | ✅ **KAPANDI (FAZ 7)** — eski hâl: CLI `*)` kolları bilinmeyen bayrakta `err_missing_arg` basıyordu ("argüman eksik"), kalıtsal koku (DZ-4), FAZ 5 kapsam dışı bırakmıştı. FAZ 7'de `_q_die` argümanlı format alır ve `search` döngüsüne `-*) _q_die err_unknown_flag 2 "$1"` kolu eklendi → `unknown flag: --nope`, exit 2. **Davranış değişikliği:** `-` önekli bilinmeyen argüman artık sessizce sorgu kelimesi sayılmıyor; bare kelimeler sorgu kalır. |

---

## 8. avenoxbeyin'e bildirilecek hatalar (ayrı iş) — **iptal (2026-08-21 kararı)**

> **İptal notu (2026-08-21):** avenoxbeyin issue'su açılmayacak; bu bölüm **silinmez, tarihsel
> kayıt** olarak kalır. İçindeki üç hata quipu'nun tasarım kararlarının gerekçesi olduğu için
> değerlidir: 1 → §4.11 (kaçışı koddan üret, `python3` yok), 2 → §4.4 (`stat` üçlü fallback),
> 3 → literal `\n` yasağı. Aşağıdaki metin 2026-08-19 durumunu anlatır, güncellenmez.

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
`context`; `faz1-adim3` dalı → PR #1 (`f7c55aa`→`c2a8e92`), üç OS CI'sı yeşil; yerelde
83/83, shellcheck 0.10.0 sessiz.
FAZ 2 ✅ (2026-08-20) — vault taksonomisi + kimlik: emoji varsayılan / `--plain` yerleşim,
beş klasör + `.gitkeep`, `companion.md` ve `Threads.md` tohumları (yalnızca-yoksa, append-only),
`AGENTS.md` köprü gövdesi + `CLAUDE.md` ince işaretçi, `_q_mdlist` tek-kaynak indeks dışlaması,
doctor layout/companion/OneDrive kontrolleri; `docs/FAZ2-SPEC.md` sözleşmesi; inceleme sonrası
düzeltmeler D1-D4 (`faz2` dalı → PR #2, `9831a36`); üç OS CI'sı yeşil; yerelde 117/117, shellcheck
0.10.0 sessiz.
FAZ 3 ✅ (2026-08-20) — Claude Code adaptörü (referans uygulama): `quipu remember` mekanik
sindirimi (filigran `.quipu/remembered`, append-only `<sessions>/YYYY-MM-DD.md`,
`Last-Session.md` işaretçisi, `--dry-run/--git/--limit`), ortak toplayıcı `lib/digest.awk`,
`context` çıktı sınırı (`QUIPU_CTX_MAX`) + `UserPromptSubmit` bayatlık nudge'ı
(`QUIPU_NUDGE_AFTER`) — PreCompact çıktısının modele ulaşmadığı ölçüldü (§4.18) —,
`adapters/claude-code.json`, `doctor` hook kontrolü, `QUIPU_HOOK` sessiz-başarı bayrağı,
README "Claude Code" bölümü; FAZ3-SPEC sözleşmesi C-1..C-36; yerelde 155 geçti + 2 skip
(shellcheck PATH dışı; shellcheck.exe sessiz); üç OS CI yeşil (PR #3, 39d79cd).

FAZ 4 ✅ (2026-08-20) — çok-şemalı capture + Codex adaptörü: `lib/capture.awk` ajan-agnostik
dağıtım (`tool_input.file_path` varsa Claude Code şeması aynen, yoksa `apply_patch` unified
diff'inden dosya yolları — regex yok), `adapters/codex/hooks.json` (config-only, installer
yok), `docs/FAZ4-BULGULAR.md` (A-1…A-6, `[kaynak]`/`[doğrulanmadı]` etiketli); yerelde
162 geçti + 2 skip (164 iddia; baz 156 + T-45 + T-50…T-56), shellcheck sessiz; üç OS CI yeşil
(PR #5, `eb045dc`). Dürüst sınırlar: yalnız `apply_patch` yakalanır; `Bash`/`Read`/silme
yakalanmaz. Canlı Codex doğrulaması açık `[doğrulanmadı]` (Codex bu makinede kurulu değil).

FAZ 5 ✅ (2026-08-21) — hook'suz fallback: `capture --git` (git-diff + `ls-files --others`,
`_q_md_filter` tek kaynak, `_q_norm_path`/`_q_rotate_log`/`_q_append_line` paylaşımlı —
kopyalanmaz) + `context --bridge` (`_q_ctx_text` global ayarlayıcı, block.awk `-v start/end`
genelleştirmesi, `err_conflict`/`bridge_updated` i18n anahtarları); yerelde 177 geçti + 2 skip
(179 iddia; baz 164 + T-57…T-71), shellcheck sessiz; üç OS CI yeşil (PR #6, `c4b200c`).
Dürüst sınırlar: git-diff durumsuz (`Read` yok, commit'siz iki koşu çoğaltır); hook'suz ajan
davranışı `[doğrulanmadı]`.

FAZ 6 ◐ (2026-08-21, kod+yerel test tamam / PR+CI eksik — bkz. Bölüm 6) — genişletilmiş CI matrisi: `init → capture → index → search` zinciri
tek vault'ta, her adımın exit kodu ayrı (T-72), Türkçe katlama zincir boyunca (`istanbul` ==
`İstanbul`, T-73), `index` özet satırının tam şekli + artımlı sayımlar (T-74/T-75), git zinciri
`capture --git → index → search → remember --git → commit → capture --git` sonunda yeni satır
yok (H-9, T-76), zincir vault'unda `doctor` 0 hata (T-77); `docs/FAZ6-BULGULAR.md` (G-1…G-5,
`[kaynak: dosya:satır]` etiketli). Yeni koşucu / CI işi / `ci.yml` değişikliği yok.

FAZ 7 ◐ (2026-08-21, kod+yerel test tamam / PR+CI eksik — bkz. Bölüm 6) — kapatıcı: DZ-4 kapandı (`_q_die key [code [arg…]]`, `err_unknown_flag`,
beş argüman döngüsünde `-*)` kolu; T-78…T-81), `search --brief` (5. sütun = 120 baytlık künye,
kelime sınırında, marker yok, `--paths` ile dışlar; T-82…T-84), 5000 dokümanlık ölçek testi
(üreteç, fixture değil; index 5000/5000 ve ortak terimde 5000 isabet; T-85…T-87),
`docs/FAZ7-BULGULAR.md` (L-1…L-5). Yerelde **226 geçti + 2 skip** (228 iddia; baz 179 +
T-72…T-87 = 46 yeni iddia + yerleşim diliminde 3), shellcheck 0.11.0 sessiz (`quipu` + `tests/run.sh`; PATH dışı
olduğu için suite'te 2 skip). **Ölçümler:** 5000 not `index` 2150-2367 s (iki koşu; makine yüküne göre), aynı indekste `search`
1 s (Windows msys) — her koşuda `# info:` satırıyla basılır; test sınırı 3600 s bir askıda
kalma tavanıdır, performans iddiası değil. Dürüst sınırlar: `search.awk` indeksi belleğe alır
(on binlerce not → akış tabanlı iki geçişli sürüm, v2); `--brief` kesimi gawk'ta karakter /
mawk'ta bayt sayar (`fold=default` vault'ta sınır platforma bağlı).

Yerleşim (2026-08-22) — vault on klasörlü avenoxbeyin taksonomisine yaklaştırıldı ve yerleşim testleri, klasör satırları ile açıklamaları `layout/*.txt` dosyalarından ve `layout_*` i18n anahtarlarından okuyan veri odaklı yapıya geçti.

**Açık kalemler (2026-08-22 güncellendi, öncelik sırasıyla):**
1. `tests/run.sh:1461` — T-120'nin `tr '\n' ' '` sondaki-boşluk hatasını düzelt. İçerik
   sorunu değil, testin kendi hatası: çıkarılan küme (`context doctor index init remember
   search`) tam doğru, `assert_eq` boşluksuz bekliyor. Suite'i kıran, şu an bilinen tek kalem
   bu — `docs/KURULUM.md` yazılmış olmasına rağmen bu haliyle FAIL verir.
2. T-120 ↔ `FAZ9-SPEC.md` §2 `capture` çelişkisini karara bağla: T-120 `KURULUM.md`'de
   `capture` kelimesinin hiç geçmemesini şart koşuyor, spec hook'suz fallback'i
   `capture --git + remember + context --bridge` olarak anlatıyor. `KURULUM.md` testi esas
   alıp yazıldı; ya testi ya spec'i düzelt.
3. `sh tests/run.sh` tam koşusu — hâlâ yeşil doğrulanmadı (yukarıdaki iki kalem
   çözülmeden koşulursa zaten FAIL verir; suite ~52 dk sürüyor).
4. FAZ 8 + FAZ 9-kimlik değişikliklerini commit et — kod ve testler hâlâ çalışma ağacında,
   commit edilmedi.
5. `faz6-faz7` dalını push et + PR aç + üç OS CI koştur — `origin/faz6-faz7` yok
   (`git branch -a` ile doğrulandı), PR açılmamış, CI hiç koşmamış; FAZ6-SPEC ve
   FAZ7-SPEC'in çıkış koşulu ("Dal + PR, üç OS CI yeşil olmadan merge yok") bu yüzden
   karşılanmadı. `git tag -l` de boş — `v1.0.0` etiketi yok.
6. `FAZ7-SPEC.md:62`'deki "index < 120s" sınırını gerçek `tests/run.sh:1173` sınırı olan
   3600s ile uyumlu hale getir (J-7 sapması) — gerekçe (ölçülen 2150-2367s) zaten Bölüm 7
   ve Bölüm 9'da var, ama spec dosyası hiç güncellenmedi.
7. V1-DUZELTME uygula (`docs/V1-DUZELTME-SPEC.md`) — FAZ 10'un zorunlu ön koşulu; sözleşme
   tablosunda hâlâ "bekliyor".

**Sıradaki (v2 adayları, FAZ 8/9 kapanınca):** MCP paketi (§3), `search.awk`'ın akış
tabanlı iki geçişli sürümü (bellek tavanı), `quipu index`'in toplu-boru hattına çevrilmesi
(~2400 s'lik msys tavanının tek gerçek çözümü). v1 kapsamında açık kalan tek kalem:
Codex canlı doğrulaması — iptal (2026-08-21, ChatGPT üyeliği yok), adaptör kodu repo'da kalır.

### Yazılmış sözleşmeler (2026-08-22) — ayrı oturumlarda yürütülür

Her dosya kendi kendine yeterlidir (ön bilgi bölümü, yasak desenler, doğrulanmış
`[kaynak: dosya:satır]` etiketleri, test numara bloğu). Sıra:

| # | Dosya | Konu | Durum (2026-08-22) |
|---|---|---|---|
| 1 | `docs/V1-DUZELTME-SPEC.md` | `fold=` config'e sabitlenir (sessiz karışık indeks kapanır) + `SessionEnd` artımlı `index` koşar. T-88…T-95 | **bekliyor** — hâlâ uygulanmadı; FAZ8-SPEC bunu "tercihen önce" diyordu, atlanmış |
| 2 | `docs/FAZ8-SPEC.md` | Yansıtıcı hafıza: oturum dosyasında modelin dolduracağı `quipu:reflect` bloğu, boşluk tespiti (`mtime` YOK), "hafıza yazmadan bitti" yakalayıcısı. T-96…T-108 | **kod+testler+`FAZ8-BULGULAR.md` yazıldı** (Dilim 0 çıkış koşulu karşılandı), **commit edilmedi**; suite hâlâ yeşil doğrulanmadı (T-120'nin kendi hatasıyla zaten FAIL veriyor) — bkz. Bölüm 6 |
| 3 | `docs/FAZ9-SPEC.md` | Kurulum deneyimi: `docs/KURULUM.md` ajan runbook'u, `user=`/`companion=` kimliği, persona `%s` doldurma. T-110…T-120 | **kimlik dilimi (V-2…V-5) + V-1 runbook (`KURULUM.md`) yazıldı**, commit'siz diff'te; T-120 sondaki-boşluk hatasıyla FAIL veriyor + `capture` kelimesi konusunda spec ile test çelişkisi çözülmedi |
| 4 | `docs/FAZ10-SPEC.md` | Obsidian sözleşmeleri: `index.tsv` 7 sütun (`status`/`type`), `search --tag/--status`, `links.tsv` + `quipu links`, durum alfabesi veri olur. T-130…T-142 | **bekliyor** — uygulamaya hiç başlanmadı; ön-ölçüm `docs/FAZ10-BULGULAR.md` yazıldı; V1-DUZELTME **zorunlu** önce (şema değişiyor) |

Üçü de avenoxbeyin incelemesinden çıktı (2026-08-22): quipu motor, avenoxbeyin deneyim.
Alınmayan kalemler açıkça kapsam dışı: mem0/harici semantik katman, `Last-Session.md`
overwrite, macOS launcher, `python3`, `{{...}}` şablon motoru.

### Tasarım kaydı (docs/) — 2026-08-22 üretilen yeni belgeler

Bu turda yedi yeni belge `docs/` altına yazıldı (hepsi untracked, henüz commit edilmedi):

| Belge | Satır | Ne işe yarar |
|---|---|---|
| `FAZ8-BULGULAR.md` | 194 | FAZ 8 Dilim 0 çıkış koşulu — artık karşılandı (bkz. Bölüm 6, FAZ 8) |
| `FAZ9-BULGULAR.md` | 185 | FAZ 9 Dilim 0 bulguları (bkz. Bölüm 6, FAZ 9) |
| `FAZ10-BULGULAR.md` | 277 | FAZ 10 uygulama öncesi ön-ölçüm — kod henüz yazılmadı |
| `KURULUM.md` | 146 | FAZ 9 V-1 ajan runbook'u — kurulum akışını baştan sona anlatır (bkz. Bölüm 6, FAZ 9) |
| `AVENOXBEYIN-KARSILASTIRMA.md` | 96 | **Sentez belgesi, sözleşme değil** — avenoxbeyin avantajları → quipu karşılığı eşlemesini tek yerde okunur hale getirir. Kaynak dört sözleşme `FAZ8-SPEC.md`/`FAZ9-SPEC.md`/`FAZ10-SPEC.md`/`V1-DUZELTME-SPEC.md`'dir; bir satır değiştiğinde doğru olan onlardır, bu belge değil |
| `FAZ6-KONTROL.md` | 246 | FAZ 6 çıktı kontrol listesi + bu turda fiilen yapılan denetimin sonucu (bkz. Bölüm 6, FAZ 6) |
| `FAZ7-KONTROL.md` | 336 | FAZ 7 çıktı kontrol listesi + denetim sonucu, J-7/J-10 kısmi bulgusu dahil (bkz. Bölüm 6, FAZ 7) |

Bunların dışında orijinal 22 SPEC/BULGULAR/KONTROL/DUZELTME belgesi hâlâ git HEAD'de sağlam
ama çalışma ağacında silinmiş durumda — bkz. Bölüm 9, Açık kalemler madde 8.

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
