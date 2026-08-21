# quipu — FAZ 6 SPEC: genişletilmiş CI matrisi (uçtan uca senaryolar)

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: `docs/PLAN.md` §6 FAZ 6, §7 (risk tablosu), §9 (durum).
> Ön koşul: FAZ 5 tamam (PR #6 merged, `c4b200c`) — 179 iddia (177 geçti + 2 skip), üç OS CI yeşil.
> Numara önekleri: **G-n** (bulgu), **I-n** (sözleşme), **T-n** (test). A/B/C/D/K/AM/Ö/E/F/H ile çakışmaz.
>
> **Bu faz yeni çekirdek kod üretmez.** Plan'ın sözü: "bu faz projenin kendisidir, cilası değil" —
> avenoxbeyin bozuk yayınlandı çünkü ikinci bir makinede hiç çalıştırılmadı. Bu faz, zincirin
> (init → capture → index → search → remember) üç OS'ta **tek senaryoda** kanıtını kurar.

## 0. Bu fazın tek cümlelik ölçütü

> **`init → capture → index → search` (ve git'li uzantısı) zinciri, tests/run.sh içinde uçtan uca
> senaryolar olarak yazılır; mevcut üç-OS CI matrisi değişmeden bu senaryoları her platformda koşar.**

FAZ 1 Adım 2'deki CI matrisi zaten `[ubuntu-latest, macos-latest, windows-latest]` üzerinde
`tests/run.sh`'i koşuyor. Bu faz ayrı bir matris kurmaz; senaryo kapsamını genişletir.

## 1. Bulgular (G-1…G-5)

`docs/FAZ6-BULGULAR.md`'de resmileşir; özet (hepsi `[kaynak: <dosya:satır>]`):

- **G-1** CI tek iş + tek kapı: `ci.yml` üç OS'ta `sh tests/run.sh` koşuyor
  (`ci.yml:22-23`) → FAZ 6 yeni job demek değil, senaryo eklentisi demek.
- **G-2** Parçalar ayrı testleniyor, zincir yok: `init + context` (`run.sh:246`), `index`
  (`run.sh:410`), `search` (`run.sh:489`) ayrı bölümler; tek senaryoda birleşik akış testi yok.
- **G-3** `quipu index` özet satırının **çıktı şekli** hiç doğrulanmamış (`idx_summary`, 4 sayı,
  `quipu:955-957`); artımlı sayımlar (reuse/stale/drop) davranış olarak var, şekil olarak yok.
- **G-4** Capture flag-modu (`--event/--tool/--path`, `quipu:374-381`) stdin fixture'ı olmadan
  satır üretir → zincir testlerinde JSON fixture'a gerek yok, hermetic.
- **G-5** Git'li e2e zinciri hiç kurulmamış: parçalar ayrı (T-57…T-64, T-69, T-70; `remember --git`
  ayrı bölüm); `commit → capture --git → yeniden koşu` dürüst davranışı (H-9) zincir içinde
  doğrulanmamış.

## 2. Senaryo testleri (I-1…I-6)

- **I-1** Yeni koşucu, yeni CI işi, yeni çatı YOK. Senaryolar `tests/run.sh` içinde mevcut
  TMP-vault deseniyle yazılır (`mk_*_vault` + `QUIPU_VAULT="$TMP/x" sh "$ROOT/quipu" …`).
  `ci.yml` değişmez.
- **I-2** **Zincir senaryosu:** boş vault → `quipu init` → `note.md` yaz → flag-modu capture
  (`--event PostToolUse --tool Write --path note.md`, G-4) → `quipu index` → `quipu search`
  sorgusu `note.md`'yi döndürür. Tek test içinde tek vault, adım sırası birebir.
- **I-3** **Katlama kanıtı:** zincirin Türkçe versiyonu — not içeriği "İstanbul ışık" → index →
  `quipu search istanbul` isabet eder (indeks katlaması = sorgu katlaması, zincir boyunca).
  §4.2'nin zincir formu.
- **I-4** **İndeks özet şekli:** ilk koşuda tam satır `# indekslendi N (yeniden 0, bayat N,
  düştü 0)`; ikinci koşu (değişiklik yok) `yeniden N, bayat 0`; bir dosya değişince `bayat 1,
  yeniden N-1`. Sayılar awk alan ayıklamasıyla doğrulanır (dil bağımsız); tam satır
  `QUIPU_LANG=en` ile kilitlenir.
- **I-5** **Git zinciri:** `init --git` → başlangıç commit → `note.md` ekle → `capture --git` →
  `index` → `search` isabet → `remember --git` → `git add -A && git commit` → `capture --git`
  tekrar → **yeni satır YOK** (commit diff'i tüketti — H-9 dürüst davranışı zincirde kanıtlanır).
- **I-6** **Doctor tam vault üzerinde:** zincir vault'unda `quipu doctor` exit 0; özet satırının
  (`doc_summary`) son sayısı `0` (hata yok) — dil bağımsız alan ayıklamasıyla.

## 3. Testler (T-72…T-77)

- **T-72** Zincir: init → flag-capture → index → search isabet (I-2). Her adımın exit kodu ayrı
  doğrulanır; son adımda yol satırı `note.md` içerir.
- **T-73** Katlamalı zincir (I-3): `search istanbul` → `note.md` döner; `search İstanbul`
  (büyük İ) aynı sonucu verir (katlama zincir boyunca).
- **T-74** İlk index koşusu özet satırı: `(yeniden 0, bayat N, düştü 0)`, N = dosya sayısı.
- **T-75** İkinci koşu + tek dosya değişimi: `yeniden N, bayat 0` → değişim sonrası `bayat 1`.
- **T-76** Git zinciri (I-5): commit sonrası ikinci `capture --git` → activity.log'da yeni
  `gitdiff` satırı yok (sayım eşit kalır).
- **T-77** Doctor tam vault (I-6): exit 0 + özet "0 hata".

**Kırılganlık dersleri (FAZ 2/3/4/5 aynen):** i18n'ye bakan iddialarda `QUIPU_LANG=en`
izolasyonu; satır sayımı `awk 'END{print NR}'` ile (`wc -l` değil); çok baytlı `awk index()`,
ASCII `grep` serbest; `RC=$?` alınıp kullanılmayan satır yok; test sayısı raporlanmış.

## 4. Belge güncellemeleri

- **I-7** `docs/PLAN.md`: §6 FAZ 6 ✅ (tarih, PR, test sayısı), §9 durum + "sıradaki: FAZ 7".
- **I-8** README: CI bölümü yoksa eklenmez; senaryolar test dokümantasyonu gerektirmez.

## 5. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/FAZ6-BULGULAR.md` — G-1…G-5 `[kaynak]` etiketleriyle resmileşir | her G-n dosya:satır kaynaklı |
| **1** | Zincir + katlama senaryoları (T-72…T-73) | regresyon kapısı + 2 test |
| **2** | İndeks özet şekli + git zinciri + doctor (T-74…T-77) | 4 test |
| **3** | PLAN.md güncellemesi (I-7) | §6 FAZ 6 ✅, §9 güncel |

## 6. Yasak desenler (devralınan + yeni)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) · ham
kullanıcı verisi `awk -v` (§4.16) · çok baytlı `sed` sınıfı (§4.1) · çok baytlı `grep` kalıbı
(§4.17) · **yeni test koşucusu/çatı** (I-1) · **ci.yml'de yeni job** (I-1) · **senaryoda
fixture JSON'a bağımlılık** (G-4: flag-modu kullanılır).

## 7. Çıkış koşulu

1. Dilim 0: `FAZ6-BULGULAR.md` G-1…G-5'i cevaplıyor.
2. **Regresyon kapısı:** mevcut 179 iddia (FAZ 5 çıktısı, 177+2 skip) aynen yeşil.
3. `sh tests/run.sh` üç OS'ta yeşil (yerel tek OS + üç OS CI — T-72…T-77 dahil).
4. `shellcheck -s sh quipu tests/run.sh` sessiz.
5. Dal + PR, üç OS CI yeşil olmadan merge yok.

## 8. Kapsam dışı

- **Yeni CI işi / matris değişikliği** — mevcut matris yeterlidir (G-1).
- **Ölçek/perf testi** (sentetik 5k-not vault) — FAZ 7'nin işi.
- **Dil katlama doğruluğu, `mtime` taşınabilirliği, `tr` sırası, POSIX uyumu** — Adım 2'de
  zaten kapsandı, tekrarlanmaz (PLAN FAZ 6 notu).
- **DZ-4 bilinmeyen bayrak tanısı** — FAZ 7'nin işi.
