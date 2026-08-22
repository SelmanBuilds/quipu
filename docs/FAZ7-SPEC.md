# quipu — FAZ 7 SPEC: kapatıcı (DZ-4 bayrak tanısı + arama ölçeği + v1 kapanışı)

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: `docs/PLAN.md` §7 (DZ-4, indeks bağlam sınırı), §5/§8 (iptal kararları 2026-08-21), §9.
> Ön koşul: FAZ 6 tamam (T-72…T-77 yeşil, üç OS CI yeşil).
> Numara önekleri: **L-n** (bulgu), **J-n** (sözleşme), **T-n** (test). Çakışma yok.
>
> **Kapsam kararları (2026-08-21, sahip onayı):** avenoxbeyin issue işi iptal; Cursor/Windsurf/
> OpenCode adaptörleri iptal; Codex canlı doğrulaması iptal (ChatGPT üyeliği yok — adaptör kodu
> repo'da KALIR, yalnızca doğrulama kalemi düşer). Bu faz v1'i dürüst şekilde kapatan son koddur.

## 0. Bu fazın tek cümlelik ölçütü

> **Bilinen tek açık koku (DZ-4) kapanır; arama ölçeği iddiası ölçülür ve iki aşamalı "daralt →
> kısa künyelerle seç → oku" deseni `--brief` ile ürüne girer; PLAN.md iptal kararlarıyla
> güncellenir ve v1 etiketlenir.**

## 1. Bulgular (L-1…L-5)

`docs/FAZ7-BULGULAR.md`'de resmileşir; özet (hepsi `[kaynak: <dosya:satır>]`):

- **L-1** (DZ-4) Bilinmeyen bayrak `err_missing_arg` basıyor: capture (`quipu:365`), init
  (`quipu:455`), context (`quipu:696`), remember (`quipu:777`); search'te `-*` sessizce **sorgu
  kelimesi** oluyor (`quipu:971-977`). Yanlış tanı: "argüman eksik" ≠ "bilinmeyen bayrak".
- **L-2** `_q_die` yalnız `key [code]` alır (`quipu:84-90`) → bayrak adını mesaja geçirecek
  argüman mekanizması yok; `_q_msg` format dizgesini döndürür (`quipu:68-83`).
- **L-3** `search --brief` YOK: çıktı 4 sütun (`search.awk:111`); katlanmış alan bellekte
  (`folded[n]`, `search.awk:42`) ama basılmıyor → büyük aday kümesinde ajanın aralarından
  anlamla seçmesi için künye yok.
- **L-4** Ölçek iddiası hiç ölçülmemiş: PLAN §7 "birkaç bin nota kadar rahat" satırı ölçümsüz;
  sentetik ölçek testi yok.
- **L-5** Katlanmış alan **saf ASCII** (fold → `tr 'A-Z' 'a-z'`, §4.3) → bayt-sınırlı künye
  kesimi güvenlidir; çok baytlı kopma olamaz.

## 2. DZ-4: bilinmeyen bayrak tanısı (J-1…J-4)

- **J-1** Yeni i18n anahtarı `err_unknown_flag`: tr `bilinmeyen bayrak: %s`, en
  `unknown flag: %s` (aynı `key=value` satır biçimi).
- **J-2** `_q_die` genişler: `_q_die key [code [arg…]]` — mesaj formatı kalan arglarla
  printf'lenir (L-2: `_q_msg` format döndürür, printf dizisi POSIX sh'te geçerli). Mevcut
  `key [code]` çağrıları **değişmez** (geriye uyumlu, regresyon kapısı kilitler).
- **J-3** capture/init/context/remember argüman döngülerine `-*)` dalı eklenir:
  `_q_die err_unknown_flag 2 "$1"`. `*)` dalları yerinde kalır (DZ-4 yalnız bayrak tanısıdır;
  pozisyonel-argüman davranışı kapsam dışı).
- **J-4** search döngüsünde `-*` → `err_unknown_flag` (bilinen `--limit`/`--paths`/`--brief`
  dışında). Bare kelimeler sorgu kalmaya devam eder. **Davranış değişikliği** — T-80 ile
  kilitlenir, README search bölümüne bir satır not.

## 3. `quipu search --brief` (J-5…J-6)

- **J-5** `--brief`: 5. sütun **künye** = katlanmış alanın ilk **120 baytı**, kelime sınırında
  kes (son boşluğa kadar), işaretleyici YOK (L-5: bayt kesimi güvenli). 120 bayttan kısaysa
  tamamı. `search.awk` `-v brief=1 -v snip=120` alır; emit satırına künye eklenir.
  İki aşamalı desenin ikinci adımı: `search --limit 50 --brief` → ajan künyelerden anlamla
  seçer → dosyaları okur.
- **J-6** `--brief` ile `--paths` karşılıklı dışlar (`err_conflict`); `--brief` yalnız search'te.

## 4. Ölçek testi (J-7)

- **J-7** Sentetik vault: 5000 `.md` (~100 bayt içerik, tek üreteç döngüsü, fixture YOK) →
  `quipu index` özet `N=5000`; `quipu search` ortak terim → beklenen isabet sayısı; süre
  sınırları (üç OS, Windows msys dahil): **index < 3600s, search < 30s**. Gerekçe: ilk ölçüm
  Windows msys'te 5000 notluk soğuk `index`'in 2150-2367 s (iki koşu) sürdüğünü gösterdi —
  dosya başına ~6 süreç doğuşu (alt kabuk + awk/sed/tr) msys'te pahalı; sınır bu ölçüme göre
  bir **askıda kalma/regresyon tavanı** olarak gevşetildi, performans iddiası değil (kayıt:
  `docs/PLAN.md` §7 "İndeks bağlam sınırı", §9 FAZ 7). `--brief` şekli ölçek vault'unda da
  kilitlenir. Bu test PLAN §7'nin "birkaç bin not" iddiasını kanıta çevirir.

## 5. Testler (T-78…T-87)

**DZ-4 (otomatik):**

- **T-78** `capture --bogus` → exit 2, stderr `--bogus` içerir (J-2 arg geçirme kanıtı),
  `QUIPU_LANG=en` ile "unknown flag" kilitlenir.
- **T-79** init/context/remember için aynı: her komuta bir bilinmeyen bayrak → exit 2 + tanı
  (döngüyle 3 komut; capture T-78'de).
- **T-80** `search --bogus` → exit 2 + "unknown flag" (sorgu kelimesi OLMADI, J-4).
- **T-81** Regresyon: `_q_die err_missing_arg 2` çağrıları değişmedi — `capture --event`
  argsız → exit 2, mesaj "required argument missing" (QUIPU_LANG=en), `--bogus` metni içermez.

**--brief (otomatik):**

- **T-82** Şekil: 5 sütun, 5. sütun TAB'la ayrık; künye ≤ 120 bayt; kısa dokümanın künyesi tam
  katlanmış metin (kesim yok).
- **T-83** Kelime sınırı: 120 baytlık kesim kelime ortasında kopmaz (son boşluğa kadar; künye
  son karakteri boşluk değildir).
- **T-84** `--brief --paths` → exit 2 (`err_conflict`).

**Ölçek (otomatik, süre sınırlı):**

- **T-85** 5000 dosya → `index` özet `5000` + süre < 3600s.
- **T-86** `search` ortak terim → beklenen isabet sayısı + süre < 30s.
- **T-87** `--brief` ölçek vault'unda: 5 sütun + künye ≤ 120 bayt.

**Kırılganlık dersleri (devralınan):** i18n iddialarında `QUIPU_LANG=en`; süre ölçümü
`date +%s` ile, `[ $((END - START)) -lt N ]` deseni (mevcut 448 KB testindeki gibi); satır
sayımı awk; fixture maskeli.

## 6. Belge güncellemeleri (J-8…J-11)

- **J-8** README: "Büyük vault" bölümü — iki aşamalı desen (`search --limit 50 --brief` →
  künyelerle seç → dosyaları oku), index.tsv büyüklük notu, **dürüst tavan**: `search.awk`
  indeksi belleğe alır; on binlerce notta akış tabanlı iki-geçişli sürüm gerekir (v2 notu).
  `QUIPU_CTX_MAX` bağlam sınırının zaten vault büyüklüğünden bağımsız olduğu yazılır.
- **J-9** `docs/PLAN.md`:
  - §5: Cursor/Windsurf/OpenCode satırlarına "iptal (2026-08-21 kararı)" notu.
  - §7: DZ-4 satırı ✅ KAPANDI; "İndeks bağlam sınırı" satırı güncellenir (ölçek testi +
    `--brief`; dürüst tavan v2'ye taşınır); "Codex hook şeması" satırına iptal notu (adaptör
    kodda kalır, canlı doğrulama düşer).
  - §8: avenoxbeyin bölümüne "iptal (2026-08-21 kararı)" notu — bölüm tarihsel kayıt olarak
    silinmez, işaretlenir.
  - §6: FAZ 6 ✅, FAZ 7 ✅; §9: durum + "sıradaki: v2 adayları (MCP paketi, akış sürümü)".
- **J-10** v1 kapanışı: README son geçiş (search `--brief`, `-*` davranış notu dahil); merge
  sonrası `v1.0.0` etiketi; §7 risk tablosu son hâli — kalan tek açık kalemler dürüstçe
  listelenir (MCP v2, akış tabanlı search tavanı, Codex canlı doğrulaması [iptal]).
- **J-11** `usage_search` satırına `--brief` notu (tr + en, tek satır).

## 7. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/FAZ7-BULGULAR.md` — L-1…L-5 `[kaynak]` etiketli | her L-n dosya:satır kaynaklı |
| **1** | DZ-4 (J-1…J-4) + T-78…T-81 | regresyon kapısı + 4 test |
| **2** | `--brief` (J-5/J-6) + T-82…T-84 | 3 test |
| **3** | Ölçek testi (J-7) + T-85…T-87 | 3 test, süre sınırları üç OS'ta |
| **4** | Belge + v1 kapanışı (J-8…J-11) | PLAN §9 "sıradaki: v2" |

## 8. Yasak desenler (devralınan + yeni)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) · ham
kullanıcı verisi `awk -v` (§4.16) · çok baytlı `sed` sınıfı (§4.1) · çok baytlı `grep` kalıbı
(§4.17) · **`--brief` için `substr` dışında kesim mantığı (regex kırpma yok)** · **künyeye
marker eklemek** (J-5: yok) · **5000 dosyayı fixture olarak commit etmek** (J-7: üreteç).

## 9. Çıkış koşulu

1. Dilim 0: `FAZ7-BULGULAR.md` L-1…L-5'i cevaplıyor.
2. **Regresyon kapısı:** mevcut N iddia (FAZ 6 çıktısı) aynen yeşil; `search` bare-kelime
   davranışı ve `_q_die` çağrıları değişmedi (T-81 kilitler).
3. `sh tests/run.sh` üç OS'ta yeşil (yerel + CI, T-78…T-87 dahil).
4. `shellcheck -s sh quipu tests/run.sh` sessiz.
5. Dal + PR, üç OS CI yeşil olmadan merge yok.
6. Merge sonrası: PLAN §9 durum satırı + `v1.0.0` etiketi (J-10).

## 10. Kapsam dışı

- **`search.awk` akış tabanlı iki-geçişli sürümü** — on binlerce notun çözümü; v2 adayı,
  dürüst tavan olarak README/PLAN'de yazılır (J-8/J-9).
- **Durumlu `capture --git`** (commit'siz çoğaltma filigranı) — FAZ 5'ten beri kapsam dışı (H-9).
- **Codex canlı doğrulaması** — iptal (2026-08-21: ChatGPT üyeliği yok).
- **Cursor/Windsurf/OpenCode adaptörleri, avenoxbeyin issue'su** — iptal (2026-08-21 kararı).
- **MCP sunucusu** — v2 adayı (PLAN §3).
