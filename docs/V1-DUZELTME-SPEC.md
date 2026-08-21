# quipu — V1 DÜZELTME SPEC: katlama profilinin sabitlenmesi + indeksin kendini yenilemesi

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: 2026-08-22 oturumunda canlı akış koşularak bulunan iki kusur.
> Ön koşul: FAZ 7 + yerleşim işi tamam (dal `faz6-faz7`, commit `dea829c`) — 226 iddia yeşil.
> Numara önekleri: **P-n** (bulgu), **R-n** (sözleşme), **T-88…T-95** (test). Önceki fazlarla çakışmaz.
>
> **Bu iş yeni yetenek eklemez.** İki sessiz bozulma yolunu kapatır. `v1.0.0` etiketinden
> **önce** girmesi tercih edilir: kusur şu an dalda duruyor ve indeksi sessizce bozabiliyor.

## Ön bilgi (yeni oturum için)

- Repo: tek dosya POSIX `sh` CLI (`quipu`, ~1050 satır) + `lib/*.awk` + veri dizinleri
  (`i18n/`, `layout/`, `fold/`, `persona/`, `adapters/`). Derinlik için `docs/PLAN.md`.
- **Yasak desenler:** `declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine
  dayanan KOD (§4.11) · ham kullanıcı verisini `awk -v` ile geçirmek (§4.16) · çok baytlı `sed`
  karakter sınıfı (§4.1) · çok baytlı `grep` kalıbı (§4.17) · `python3` bağımlılığı.
- Testler: `sh tests/run.sh`, sıfır çatı. Yardımcılar: `t`, `assert_eq name expected actual`,
  `ok`, `not_ok`, `skip`, `mkvault d`, `mk_index_vault d`, `mk_search_vault d`, `mk_git_vault d`,
  `git_commit d msg`, `log_line dir`, `idx_nums file`, `i18n key`, `layout_names`, `comp_name`,
  `cmd_name`, `TMP`, `ROOT`, `LIB`, `TAB`.
- Satır sayımı `awk 'END{print NR}'`; `wc -l` yasak. i18n metnine bakan iddialarda `QUIPU_LANG=en`.
- `i18n/en.txt` ve `i18n/tr.txt` anahtar kümeleri birebir aynı olmak ZORUNDA (tests/run.sh
  "i18n tr/en key sets identical"). `layout/emoji.txt` ve `layout/plain.txt` slug kolonları da.
- **Suite yerelde ~52 dakika sürüyor** (5000 dokümanlık ölçek testi T-85). Geliştirirken bölümü
  izole koşun; tam suite'i bir kez, sonda koşun.
- shellcheck kurulu değil; `npx --yes shellcheck -s sh quipu tests/run.sh` ile alınabilir.
  Suite `command -v shellcheck` bulamazsa 2 iddiayı `skip` eder — normal, 2 skip beklenen değer.
- `docs/` `.gitignore`'da; buradaki belgeler commit edilmez.
- Geçici dizin olarak `/tmp` KULLANMAYIN — bu makinede msys `/tmp` süreçler arası tutarsız.
  Repo altında `.probe$$` açıp silin.

## 0. Bu işin tek cümlelik ölçütü

> **Katlama profili vault'a bir kez yazılır ve bir daha kendiliğinden değişmez; aranabilir indeks
> ajan oturumu bitince kendini yeniler.**

## 1. Bulgular (P-1…P-6)

`docs/V1-DUZELTME-BULGULAR.md`'de resmileşir; her bulgu `[kaynak: <dosya>:<satır>]` etiketli
olmak zorunda ve satır numaraları yazılmadan önce doğrulanır (aşağıdakiler 2026-08-22 doğrulu).

- **P-1** `init` config'e yalnız iki satır yazıyor: `layout=` (`quipu:503`) ve `lang=`
  (`quipu:509` güncelleme, `quipu:511` ekleme). **`fold=` hiç yazılmıyor.**
- **P-2** Katlama profili her çağrıda yeniden türetiliyor ve zincir **iki yerde kopyalanmış**:
  `index` (`quipu:914-924`) ve `search` (`quipu:1016-1024`). İkisi de: config `fold=` →
  `_q_lang` = `tr` ise `tr`, aksi halde `default`. `_q_lang` zinciri (`quipu:45-64`):
  `QUIPU_LANG` → config `lang=` → `LC_ALL`/`LANG` → `en`.
- **P-3** Sonuç **karışık indeks**. Ölçüm (2026-08-22): `init --lang tr`, `QUIPU_LANG` yok →
  `dpi.md` 5. sütunu `# dpi  ikinci monitorde taskbar tasmasi.` (tr katlaması). Aynı vault'a
  `QUIPU_LANG=en` ile ikinci not eklenip `index` koşulunca eski satır *yeniden kullanılıyor*
  (mtime değişmedi) ama yeni satır `default` profille giriyor:
  `# dpi 2  Üçüncü monitörde ölçek`. `QUIPU_LANG=en search monitor` yalnız eski satırı buluyor;
  yeni not **hiçbir sorguyla bulunamıyor**. `index` bunu `yeniden N` diye rapor ediyor, uyarı yok.
- **P-4** Aynı bozulma `--lang` verilmeden kurulan vault'ta locale üzerinden tetikleniyor:
  config'te `lang=` satırı olmayınca `_q_lang` `LC_ALL`/`LANG`'a düşüyor → terminal locale'i
  değişince profil değişiyor.
- **P-5** Hiçbir adaptör `quipu index` koşmuyor. `adapters/claude-code.json` ve
  `adapters/codex/hooks.json` yalnız `remember`, `context --json`, `capture` çağırıyor.
  `doctor` bayatlığı görüp uyarıyor (`quipu:241`, `quipu:245`, `doc_index_stale`) ama düzeltmiyor.
- **P-6** Bu koku testlerde maskeliydi: FAZ 6 zincir testleri Türkçe katlama isteyen her vault'ta
  elle `printf 'fold=tr\n' >> .quipu/config` yapıyor. **R-1 sonrası bu satırlar kaldırılmalı ve
  testler yine geçmeli** — P-6'nın kanıtı budur.

## 2. Profilin sabitlenmesi (R-1…R-4)

- **R-1** `init` profili **bir kez** türetir ve config'e `fold=<profil>` olarak yazar.
  Türetme: init sırasındaki `_q_lang` sonucu `tr` ise `tr`, aksi halde `default`. Yazım deseni
  `layout=`'un birebir aynısı (`quipu:503`): satır yoksa ekle.
- **R-2** **Mevcut `fold=` değeri asla üzerine yazılmaz** — `lang=` için yapılan `sed` güncellemesi
  (`quipu:509`) `fold=` için YAPILMAZ. Gerekçe: profil değişikliği tüm indeksi geçersiz kılar,
  kullanıcı `latin` yazmış olabilir. İkinci `init --lang en`, `fold=tr`'yi bozmaz.
  README'ye tek satır: profili değiştirmek istiyorsan config'i elle düzelt ve `index --full` koş.
- **R-3** `doctor`: config'te `fold=` yoksa **warn** (`doc_fold_missing`); değer var ama
  `fold/<değer>.sed` yoksa **fail** (`doc_fold_unknown`). Desen `doc_layout_missing`'in birebir
  kopyası (`quipu:229`). `doctor` `FAIL > 0` iken 1, aksi halde 0 dönüyor (`quipu:310-312`) —
  bu davranış korunur.
- **R-4** İki kopya profil zinciri tek yardımcıya çıkarılır: `_q_fold_prof` (config `fold=` →
  `_q_lang` → `default`), `index` ve `search` onu çağırır. Davranış **birebir korunur**; amaç
  P-2'nin sebebini (kopya kod) ortadan kaldırmak.

## 3. İndeksin kendini yenilemesi (R-5…R-6)

- **R-5** Adaptörlerde `SessionEnd` komutu `remember`'dan sonra `index` de koşar:
  `adapters/claude-code.json` ve `adapters/codex/hooks.json` (Windows karşılığı
  `commandWindows` alanı dahil — `set QUIPU_HOOK=1&& ...` deseni). Artımlı koşu yalnız bayat
  dosyaya dokunur.
  README'ye **dürüst not**: soğuk/büyük vault'ta ilk indeks uzundur — 5000 not için ölçüm
  2150-2367 s (Windows msys, `tests/run.sh` T-85 her koşuda basıyor) — bu yüzden ilk indeksi
  elle alın.
- **R-6** `QUIPU_HOOK=1` iken `index` özet satırını basmaz. Şu an `QUIPU_HOOK` yalnız `_q_die`
  içinde kullanılıyor (`quipu:98`); özet `quipu:978-981`'de koşulsuz basılıyor. FAZ 5'in H-7
  kuralı (hook yolunda stdout boş kalır) `index` için de geçerli olmalı.

## 4. Testler (T-88…T-95)

- **T-88** `init --lang tr` → config'te `fold=tr`; `init` (bayrak yok, `LC_ALL=C`) → `fold=default`.
- **T-89** `init --lang tr` sonra `init --lang en` → `lang=en` oldu ama **`fold=tr` değişmedi** (R-2).
- **T-90** Kullanıcı config'e elle `fold=latin` yazmış → `init` dokunmuyor.
- **T-91** P-3 regresyonu: `init --lang tr` → not yaz → `index` → `QUIPU_LANG=en` ile ikinci not +
  `index` → **iki satırın da** 5. sütunu katlanmış (Türkçe karakter yok) ve
  `QUIPU_LANG=en search monitor` **iki notu da** döndürüyor.
- **T-92** `doctor`: `fold=` satırı silinmiş vault → warn ve exit 0; `fold=yokboyleprofil` →
  fail ve exit 1. Dil bağımsız alan ayıklaması (`doc_summary`'nin son sayısı = fail).
- **T-93** `_q_fold_prof` tek kaynak: config `fold=latin` iken `index` ve `search` aynı profili
  kullanıyor — kanıt olarak `latin` katlamasına özgü bir dizge (ör. `Straße` → `strasse`)
  hem index.tsv 5. sütununda hem sorgu isabetinde görünür.
- **T-94** Adaptör verisi (statik, mevcut T-54…T-56 deseni): iki JSON'da `SessionEnd` komutu
  `index` içeriyor; `commandWindows` alanı da içeriyor.
- **T-95** `QUIPU_HOOK=1 quipu index` → **stdout boş**, exit 0, `index.tsv` güncellenmiş.
- **P-6 kanıtı:** FAZ 6 zincir testlerindeki elle `printf 'fold=tr\n' >> .quipu/config` satırları
  kaldırılır; T-72/T-73 ve git zinciri testleri yine geçer.

## 5. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/V1-DUZELTME-BULGULAR.md` — P-1…P-6 `[kaynak]` etiketli | her P-n dosya:satır kaynaklı |
| **1** | R-1/R-2 + T-88…T-90 | 3 test |
| **2** | R-3/R-4 + T-91…T-93 | 3 test, kopya zincir kalmadı |
| **3** | R-5/R-6 + T-94/T-95 | 2 test |
| **4** | P-6 temizliği + README/PLAN notları | zincir testleri elle `fold=` satırı olmadan geçiyor |

## 6. Yasak desenler (devralınan + yeni)

Ön bilgideki liste · **`fold=` değerini `init`'te üzerine yazmak** (R-2) · **profil zincirini iki
yerde bırakmak** (R-4) · **`index` özetini hook yolunda basmak** (R-6) · adaptörlere `--full`
koymak (artımlı olmalı).

## 7. Çıkış koşulu

1. Dilim 0: `V1-DUZELTME-BULGULAR.md` P-1…P-6'yı cevaplıyor.
2. **Regresyon kapısı:** 226 iddia (+ yeni testler) yeşil, `sh tests/run.sh` exit 0.
3. `shellcheck -s sh quipu tests/run.sh` sessiz.
4. Üç OS CI yeşil olmadan merge yok.

## 8. Kapsam dışı

- `quipu index`'in performans optimizasyonu (toplu boru hattı) — v2 adayı, PLAN §9.
- Var olan vault'lar için göç betiği (profil değişince `index --full` gerekir; kullanıcıya not).
- Yeni katlama profili eklemek (`fold/*.sed` kümesi değişmez).
