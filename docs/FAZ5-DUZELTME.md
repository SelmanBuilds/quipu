# quipu — FAZ 5 SPEC düzeltme talimatı (uygulama öncesi denetim)

> `docs/FAZ5-SPEC.md` **uygulamaya alınmadan önce** beş bağımsız ajanla repo'ya karşı denetlendi.
> Sonuç: SPEC bugünkü haliyle **uygulanamaz** — biri yapısal üç engel var. Bu dosya, SPEC'e
> işlenecek düzeltmelerin bağlayıcı listesidir. Kapsam **yalnızca** bunlar; başka refaktör yok.
>
> **Karar (kullanıcı):** E1 için **FAZ 4 önce uygulanır**, FAZ 5 sırası korunur. Yani bu dosya
> FAZ 5'i FAZ 4'ten bağımsız hale getirmez; FAZ 5'in FAZ 4'e olan bağımlılığını **dürüst ve
> denetlenebilir** hale getirir.
>
> Numara öneki: **DZ-n**. F/H/T (FAZ 5) ve A/B/C/D/K/AM/Ö/E ile çakışmaz.
>
> **Ölçülen tek sayı:** `sh tests/run.sh` (bu makine, 2026-08-20) → `# pass 154, fail 0, skip 2`
> = **156 iddia**. Bu sayı ölçüldü, projeksiyon değil.

---

## Engel özeti (neden bu dosya var)

| # | Engel | Kanıt |
|---|---|---|
| **E1** | FAZ 4 ön koşulu sahte — SPEC dört yerde "FAZ 4 tamam" varsayıyor | `main`=FAZ 3 merge; `faz4` dalında yalnız doküman commit'i; `grep apply_patch` → 0; `adapters/` yalnız `claude-code.json`; `FAZ4-BULGULAR.md` yok; `PLAN.md:8,627` "FAZ 4 sırada"; `FAZ4-KONTROL.md:12` "ajan çıktısı bekleniyor" |
| **E2** | H-3, `set -eu` altında betiği abort ettirir | `quipu:10` `set -eu`; commit'siz repoda `git diff --name-only HEAD` → exit 128 |
| **E3** | H-4'ün "aynı kriter"i mevcut değil | `_q_mdlist` (`quipu:120-130`) üreticidir, filtre değil; `.quipu/` dışlaması `find -prune`'da, awk süzgecinde değil |

---

## DZ-1 — FAZ 4 bağımlılığı dürüstleşir (E1)

### Sorun

SPEC dört yerde FAZ 4'ün bittiğini **olgu olarak** yazıyor: `:5` (ön koşul), `:45` (H-5 "FAZ 4'ün
çok-satırlı loop'u paylaşılır"), `:84` (Dilim sırası gerekçesi), `:131` (§9.2 "mevcut N iddia —
FAZ 4 çıktısı"). Hiçbiri doğru değil. Bu, sözleşmeyi okuyan kod ajanını iki yanlıştan birine
sürükler: ya olmayan yardımcıyı çağırır, ya §8'de yasaklanan ikinci inline kopyayı yazar.

### İstenen düzeltme

1. `:5` ön koşul satırı **kapı** haline getirilir:

   > Ön koşul: FAZ 3 tamam (PR #3 merged) + **FAZ 4 merge edilmiş olmalı**. FAZ 4 merge
   > edilmeden FAZ 5 Dilim 1 başlamaz. Kontrol: `adapters/codex/hooks.json` mevcut **ve**
   > `lib/capture.awk` `apply_patch` dalını içeriyor **ve** `main`'de FAZ 4 merge commit'i var.

2. `:45` (H-5) ve `:84`, K-8'e **ada** değil, **sözleşmeye** atıf yapar: paylaşılacak yardımcının
   adı, imzası ve sınırı FAZ 4 çıktısında sabitlenmiş olmalı. FAZ 4 KONTROL'ünden geçerken bu
   yardımcının **çağrılabilir bir fonksiyon** olduğu doğrulanır (bugün `quipu:335-362` inline).
3. `:131` (§9.2) "FAZ 4 çıktısı" ifadesi sayıyla değiştirilir → DZ-9.

### Not (FAZ 4 ajanına taşınacak)

FAZ 4 uygulanırken K-8'in çok-satırlı loop'u **fonksiyon olarak** çıkarılmalıdır; inline
bırakılırsa FAZ 5 H-5/H-6 karşılanamaz. Çıkarılacak sınır bugün `quipu:335-362`
(cygpath normalizasyonu `:335-346` + vault-relative şerit `:348` + TAB/CR/LF temizliği `:349-350`
+ rotasyon `:352-360` + append `:362`). Bu, FAZ 4'ün kapsamına eklenmiş **yeni bir gereksinim
değildir** — K-8 zaten bunu istiyor; yalnız "fonksiyon olsun" şartı açık yazılmalı.

---

## DZ-2 — H-3: unborn HEAD guard'ı (E2, kritik)

### Sorun

Hiç commit'i olmayan repoda `git diff --name-only HEAD` stderr'a `fatal: ambiguous argument
'HEAD'` yazar ve **exit 128** verir. `quipu:10`'daki `set -eu` bunu betik abort'una çevirir.
Sonuç: H-8 ("değişiklik yoksa da sessiz exit 0") ve H-7 ("stdout'a 0 bayt") **birlikte** kırılır —
üstelik hook zarfı içinde çalışırken.

SPEC bu durumu hiç anmıyor; T-57…T-64 test repoları commit attığı için testler de yakalamaz.

### İstenen davranış

| Durum | Davranış |
|---|---|
| git yok | sessiz exit 0 (H-2) |
| repo değil | sessiz exit 0 (H-2) |
| repo var, **commit yok** (unborn HEAD) | abort YOK; yalnız `ls-files --others` sonucu işlenir |
| repo var, commit var | H-3 aynen (diff + ls-files) |

### Uygulama

Diff'ten önce `git rev-parse --verify --quiet HEAD` guard'ı; her git çağrısı alt-kabukta ve
stderr susturulmuş (mevcut `remember --git` deseni, `quipu:753-761`):

```sh
if (cd "$_q_v" && git rev-parse --verify --quiet HEAD >/dev/null 2>&1); then
  _q_ch=$( (cd "$_q_v" && git diff --name-only HEAD 2>/dev/null) )
else
  _q_ch=""
fi
_q_un=$( (cd "$_q_v" && git ls-files --others --exclude-standard 2>/dev/null) )
```

`cd` **alt-kabukta** kalmalı; guard'sız `cd "$_q_v"` betiğin kalanını vault'ta çalıştırır.

### Yeni test

- **T-69** Repo var, hiç commit yok, bir untracked `.md` → exit 0, stdout boş, `activity.log`'da
  o dosya için satır **var** (unborn HEAD abort etmiyor, `ls-files` yolu çalışıyor).

---

## DZ-3 — H-4: ortak `.md` filtresi çıkarılır (E3)

### Sorun

H-4 "`_q_mdlist` dışlamasıyla **aynı kriter** (`quipu:120-130`), ikinci bir dışlama mantığı
yazılmaz" diyor. Üç noktada tutmuyor:

1. `_q_mdlist` bir **üreticidir** — kendi `find`'ını koşar. Git çıktısını filtrelemek için
   çağrılamaz.
2. `.quipu/` dışlaması `find -prune`'da yapılıyor (`.git`, `.quipu`, `node_modules`), awk
   süzgecinde değil. awk yalnız tam eşleşmeyle `AGENTS.md`/`CLAUDE.md` atıyor.
3. Sonuç: bugünkü kriter git çıktısına uygulansa `.quipu/foo.md` **geçerdi** — H-4'ün açıkça
   dışladığı dosya.

### İstenen düzeltme

`_q_md_filter` adında, **stdin→stdout** çalışan tek bir yardımcı çıkarılır. Kriter tek yerde
tanımlanır; hem `_q_mdlist` hem `capture --git` bu yardımcıyı çağırır.

Kriter (yol, vault-relative, `/` ayraçlı):

- `.md` ile biter (`substr` ile; regex yok),
- tam eşleşme `AGENTS.md` veya `CLAUDE.md` **değil**,
- `.quipu/`, `.git/`, `node_modules/` **önekiyle başlamaz** (`index($0, "…") == 1`).

Önek testi `index()` ile yapılır — çok baytlı `grep` kalıbı (§4.17) ve çok baytlı `sed` sınıfı
(§4.1) yasakları böylece kendiliğinden karşılanır. Filtre programı sabit literaldır; `awk -v`'ye
ham veri geçmez (§4.16 uyumlu).

`_q_mdlist` bu yardımcıyı çağıracak şekilde sadeleşir. **Bu bir davranış değişikliği değildir** —
mevcut `_q_mdlist` testleri regresyon kapısıdır ve aynen yeşil kalmalıdır.

### Yeni test

- **T-70** `.quipu/` altındaki bir `.md` git çıktısında görünse bile satır üretilmez (T-61'in
  `.quipu/` dalı, filtre yardımcısına karşı; bugünkü kriterin gerçekten kapsamadığı vaka).

---

## DZ-4 — H-1/H-15: karşılıklı dışlamanın kendi hata anahtarı olur

### Sorun

H-1 (`--git` + `--event/--tool/--path`) ve H-15 (`--bridge` + `--json`) çakışmalarında repo emsali
`_q_die err_missing_arg 2` (`quipu:306,312`). Basılacak metin: `zorunlu argüman eksik` /
`missing required argument`. Durum ise "argüman eksik" değil, "seçenekler birbirini dışlıyor".
Kullanıcıya yanlış tanı veren bir mesaj.

### İstenen düzeltme

Yeni i18n anahtarı **`err_conflict`** (tr + en), exit kodu **2** (mevcut argüman hatalarıyla aynı).
Her iki çakışma da bunu kullanır.

**H-18 revize:** "tek yeni anahtar" değil, **iki** yeni anahtar — `bridge_updated` + `err_conflict`.
`capture --git` hâlâ sessiz olduğu için başarı yolunda anahtar gerektirmez.

Mevcut `*)` kolunun (bilinmeyen bayrak) `err_missing_arg` kullanması **bu fazın kapsamı dışıdır**;
kalıtsal koku olarak PLAN §7'ye not düşülür, burada düzeltilmez.

---

## DZ-5 — H-12: `-v` tek başına yetmez, BEGIN koşullu olmalı

### Sorun

`lib/block.awk:13-14` işaretçileri **koşulsuz** atıyor:

```awk
BEGIN {
  start = "<!-- quipu:start -->"
  end   = "<!-- quipu:end -->"
```

awk `-v` atamasını BEGIN'den **önce** yapar; BEGIN sonra değeri **ezer**. Yani
`awk -v start=… -f block.awk` çağrısı hiçbir şey değiştirmez ve `--bridge` sessizce **statik
bloğu** hedefler — H-11'in "statik blok dokunulmaz" garantisinin tam tersi.

### Uygulama

BEGIN'de koşullu varsayılan; repo emsali `lib/index.awk:26` (`if (max + 0 == 0) max = 2000`):

```awk
BEGIN {
  if (start == "") start = "<!-- quipu:start -->"
  if (end   == "") end   = "<!-- quipu:end -->"
```

§4.16 ihlali değildir: `PLAN.md:335` `-v`'yi sabit/kontrollü değerler için açıkça serbest
bırakıyor; işaretçiler kaçış içermeyen sabit literaldır.

### Yeni test

- **T-71** `-v start/end` **verilmeden** çağrıldığında varsayılan işaretçilerin **tam metni**
  (`<!-- quipu:start -->` / `<!-- quipu:end -->`) korunur. Mevcut T-68 kilidi yalnız `quipu:start`
  **alt-dizisini** grep'liyor (bkz. DZ-8); literal kilidi bu testle kurulur.

---

## DZ-6 — H-13: "blok yoksa sona eklenir" sözleşmeye yazılır

`lib/block.awk` blok yoksa bloğu **dosya sonuna ekler** (`lib/block.awk:9` başlık yorumu, `:51-57`
END bloğu). İlk `context --bridge` koşusunun fiili davranışı budur. SPEC §3 yalnız "idempotent +
kullanıcı içeriği korunur" diyor; append davranışı örtük kalmış. H-13'e tek cümle eklenir:

> Blok yoksa AGENTS.md'nin **sonuna** eklenir; varsa yerinde değiştirilir. İkisi de kullanıcı
> içeriğini korur.

---

## DZ-7 — H-14: `_q_ctx_text` sözleşmesi tanımlanır

### Sorun

H-14 "ortak yardımcı `_q_ctx_text`" diyor ama **imzasını** tanımlamıyor. Belirtilmezse implementer
en doğal şeyi yapar — `_q_text=$(_q_ctx_text)` — ve komut yerine koyma **son satır sonunu söker**;
AGENTS.md'de bozuk/gömülü blok kalır.

### İstenen sözleşme

- `_q_ctx_text` **global ayarlayıcıdır**: `_q_text` değişkenini kurar, stdout'a yazmaz, argüman
  almaz. Repo emsali `_q_add_act`/`_q_add_idx` (`quipu:561-564`).
- Kapsam: `quipu:557-618` (activity + index + Threads.md, `QUIPU_CTX_MAX` kırpması dahil).
- **Nudge bloğu (`quipu:620-652`) helper'ın DIŞINDA kalır.** `_q_ev`'e bağımlıdır ve yalnız
  `--json UserPromptSubmit` içindir; `--bridge` çıktısına **sızmamalıdır**.
- Vault guard (`quipu:552-555`) ve çıkış zarfı (`:654-661`) helper'ın dışında kalır.
- AGENTS.md'ye yazarken `printf '%s' "$_q_text" | awk … -f lib/block.awk` deseni kullanılır
  (init kalıbı, `quipu:491-508`). `echo` kullanılmaz.

JSON dalı bu değişiklikten etkilenmez: bağlam ham tutulup aşağı akışta `je_esc` ile kaçışıyor
(`lib/emit_hookctx.awk:8-9`, `lib/jsonemit.awk:14-33`).

---

## DZ-8 — §6: test deseni tarifi yanlış, iki test dürüstleşir

### DZ-8a — geçici git repo deseni

SPEC §6 ve `FAZ5-BULGULAR.md:87-88` "`mktemp -d` + `git init -q` + `git -c user.email=…
-c user.name=…` (C-32/T-40 ile aynı)" diyor. `tests/run.sh`'te böyle bir desen **yok**:

- `mktemp -d` hiç kullanılmıyor; paylaşılan tek temp var: `TMP=${TMPDIR:-/tmp}/quipu-tests-$$`
  + `mkdir -p "$TMP"` (`tests/run.sh:21-22`).
- Tek `git init -q "$TMP/vr40"` (`:693`).
- Kimlik `git -c` ile değil, **env** ile: `GIT_AUTHOR_NAME/EMAIL`, `GIT_COMMITTER_NAME/EMAIL`
  (`:694-695`).
- Yeniden kullanılabilir yardımcı değil — `vr40` testine gömülü inline blok.

§6 bu gerçek kalıba göre yeniden yazılır. T-57…T-64 için ek olarak: `git diff --name-only HEAD`
anlamlı olsun diye kurulumda **commit** atılmalı (T-69 hariç — o zaten unborn HEAD'i sınıyor).

### DZ-8b — T-62 "git yok" dalı dürüst sınıra çekilir

`tests/run.sh`'te PATH manipülasyonu yok; `git`i yokmuş gibi göstermek shim/PATH kesme gerektirir
ve kabuğun `command not found` çıktısı stderr'e sızarak testi flaky yapar. H-2 zaten `git
rev-parse` başarısızlığını tek dal olarak ele aldığı için **"repo değil" dalı aynı kodu örter**.

T-62 yeniden yazılır: yalnız **"repo değil"** sınanır (exit 0, satır yok, stdout boş). "git yok"
`[doğrulanmadı]` olarak dürüstçe açık bırakılır; istenirse `command -v git` + `skip` ile işaretlenir.

### DZ-8c — T-68 kilidi zayıf

T-68'i kilitleyen mevcut testler: `tests/run.sh:238, 240, 259, 260, 326, 332, 333, 656-657`.
Üç tüketiciyi de (AGENTS.md `quipu:508`, CLAUDE.md `:512`, Last-Session.md `:749`) örtüyorlar
**ama hiçbiri işaretçinin tam metnini doğrulamıyor** — yalnız `quipu:start` alt-dizisini
grep'liyorlar. Literal kilidi DZ-5'teki **T-71** ile kurulur.

---

## DZ-9 — N = 156 (ölçüldü)

§5 ve §9.2'deki "mevcut N iddia" yer tutucusu **156** ile değiştirilir.

`sh tests/run.sh` (bu makine, 2026-08-20): `# pass 154, fail 0, skip 2` → **156 iddia**.

Dikkat: test numaralayıcısı `ok 158`'e kadar sayıyor. Fark, `tests/run.sh:227` ve `:241`'deki
**iki başıboş `t;`**'den geliyor — `NUM`'u artırıp hiçbir iddiaya bağlanmıyorlar. Regresyon kapısı
**`pass + skip`** üzerinden okunur, `NUM` üzerinden değil.

`FAZ4-KONTROL.md:124`'teki "157" ve "164" değerleri yanlıştır (157 = birbirini dışlayan if/else
dallarını çift sayan naif toplam; 164 = hiç gerçekleşmemiş projeksiyon — T-50…T-56 yazılmadı,
`tests/run.sh`'teki en yüksek T-n = T-49). FAZ 4 kapısı da 156'dan başlamalıdır.

**Yeni toplam beklentisi:** 156 + T-57…T-71 (15 test) = **171 iddia**, testler birebir yazılırsa.

---

## DZ-10 — Belge yükümlülükleri netleşir

### DZ-10a — README (H-19)

Bugünkü başlık yapısı: `# quipu` → `## Why it's free` → `## Install` → `## Commands` →
`## End-to-end example` → `## Claude Code` → `## Status` → `## Honest limits` → `## License`.

"Hook'suz ajanlar" bölümü `## Claude Code` ile `## Status` arasına girer. Ayrıca **yanlışa düşen
satırlar** düzeltilir:

- `README.md:29` — `quipu capture # append **one line** to activity.log` → `--git` çok satır üretir.
- `README.md:32` — `quipu context` satırında `--bridge` hedefi yok.
- `README.md:121-122` (`## Status`) — zaten bayat (FAZ 3'te kalmış). H-19 kapsamına alınır.
- `## Honest limits` — H-9 sınırları (READ yakalanmaz, commit'siz koşu çoğaltır) buraya bağlanır
  ya da yeni bölümden buraya atıf verilir; iki yerde ayrı ayrı yazılmaz.

### DZ-10b — PLAN §2 sapması belgelenir (H-20)

`PLAN.md:62`'deki köprü diyagramı "son oturum + aktif konular"ı `<!-- quipu:start -->` bloğunun
**içinde** çiziyor. H-11 ise dinamik bağlamı ayrı `quipu:context` bloğuna alıyor. Karar doğru
(statik blok init'in malı kalır), ama sapma hiçbir yerde yazılı değil. H-20, PLAN §2'ye bir cümle
ekler: dinamik bağlam ikinci, ayrı bir bloktadır.

### DZ-10c — `quipu install` erteleme zinciri

`FAZ4-SPEC.md:305` `install`'ı "→ FAZ 5" diye ertelemişti; `FAZ5-SPEC.md:145` ise "v1 dışı
(PLAN §3)" diyor — ama **PLAN §3 `install`'dan hiç bahsetmiyor**, orada yalnız MCP satırı var.
§10 düzeltilir: `(PLAN §3)` atfı yalnız MCP'de kalır; `install` için gerekçe **C-26**
("installer yok") olarak açık yazılır.

---

## DZ-11 — BULGULAR satır referansları düzeltilir

`FAZ5-BULGULAR.md` "her biri kesin `dosya:satır` referansı taşır" diyor; üç referans kaymış
(FAZ 4 değil, FAZ 3'ün kendi commit'leri kaydırmış):

| Bulgu | Yazan | Doğru |
|---|---|---|
| F-2 | `lib/block.awk:12-13` | **`lib/block.awk:13-14`** (12 = `BEGIN {`) |
| F-3 (activity) | `quipu:560-571` | **`quipu:559-571`** (559 = yorum) |
| F-5 | `quipu:759-767` | **`quipu:753-761`** (759-767 = kapanış `fi`'leri + `remember_ok`) |
| F-1 (i18n) | `i18n/en.txt:73-78` | **`:74-77`** (73 = `# bridge` yorumu, 78 = `bridge_claude`) |

F-1 ve F-4'ün `quipu` referansları birebir doğrudur, dokunulmaz.

Ayrıca F-5'in lafzı düzeltilir: `remember --git`'te açık bir `exit 0` **yok** — iç içe `if`'ler
sessizce atlanıp akış `remember_ok`'a düşüyor ve komut örtük 0 ile bitiyor. "Guard + sessiz exit 0"
değil, **"koşullu atlama + örtük başarı"**. `capture --git` bu desenden yalnız ön koşulu
(`command -v git` + `rev-parse --git-dir`) devralır; `remember`'ın `git add -A && ! git diff
--cached --quiet` boru hattını **devralmaz**.

---

## DZ-12 — Housekeeping (kapsam dışı, ayrı commit)

`tests/run.sh:227` ve `:241`'deki **iki başıboş `t;`** SPEC §6'nın kendi yasakladığı desendir
("başıboş `t;` yok") ve bugün repoda mevcuttur. FAZ 5'in kapsamına **sokulmaz**; ayrı bir
housekeeping commit'ine bırakılır. Buraya yazılmasının nedeni: DZ-9'daki 156↔158 farkının
açıklaması budur, bir sonraki sayım tartışmasını önler.

---

## Düzeltme sonrası değişen madde listesi (tek bakışta)

| Madde | Durum |
|---|---|
| H-1 | `err_conflict` kullanır (DZ-4) |
| H-3 | unborn HEAD guard'ı eklenir (DZ-2) |
| H-4 | `_q_md_filter` çıkarılır; `.quipu/`/`.git/`/`node_modules/` önek testi açık yazılır (DZ-3) |
| H-5, H-6 | FAZ 4 kapısına bağlanır; paylaşılacak yardımcının fonksiyon olması şart (DZ-1) |
| H-12 | BEGIN koşullu varsayılan (DZ-5) |
| H-13 | append davranışı yazılır (DZ-6) |
| H-14 | `_q_ctx_text` imzası + nudge dışarıda (DZ-7) |
| H-15 | `err_conflict`, exit 2 (DZ-4) |
| H-18 | iki yeni anahtar: `bridge_updated` + `err_conflict` (DZ-4) |
| H-19, H-20 | README satırları + PLAN §2 sapması + install zinciri (DZ-10) |
| §5, §9.2 | N = **156** (DZ-9) |
| §6 | git test deseni düzeltilir; T-62 daraltılır (DZ-8) |
| §10 | `install` gerekçesi C-26 (DZ-10c) |
| Yeni testler | **T-69** unborn HEAD · **T-70** `.quipu/` filtresi · **T-71** varsayılan işaretçi literali |

**Değişmeyenler (denetimden temiz çıktı):** H-2, H-7, H-8, H-9, H-10, H-11, H-16, H-17, §8 yasak
listesi, numaralandırma (F/H/T çakışmıyor, T-57…T-68 boşta), dürüstlük etiketleri.
