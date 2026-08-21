# quipu — FAZ 9 SPEC: kurulum deneyimi (mülakat + kimlik + ajan bağlama)

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: 2026-08-22 avenoxbeyin (github.com/avenoxai/avenoxbeyin) incelemesi — özellikle
> `SETUP.md` runbook'u — + quipu'nun mevcut veri-odaklı primitifleri.
> Ön koşul: FAZ 7 tamam. V1-DUZELTME ve FAZ 8'den **bağımsız**, paralel yürütülebilir.
> Numara önekleri: **U-n** (bulgu), **V-n** (sözleşme), **T-110…T-120** (test). Çakışma yok.
>
> **Bu fazın işi:** quipu'nun motoru çalışıyor ama kurulumu "repo'yu klonla, PATH'e koy".
> avenoxbeyin tek yapıştırmayla mülakat yapıp kişiselleştirilmiş bir vault kuruyor. Bu faz o
> deneyimi quipu'ya getirir — **macOS'a, `brew`'a, `python3`'e ve şablon motoruna bulaşmadan.**

## Ön bilgi (yeni oturum için)

- Repo: tek dosya POSIX `sh` CLI (`quipu`) + `lib/*.awk` + veri dizinleri (`i18n/`, `layout/`,
  `fold/`, `persona/`, `adapters/`). Derinlik: `docs/PLAN.md`.
- **Yasak desenler:** `declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine
  dayanan KOD (§4.11) · ham kullanıcı verisini `awk -v` ile geçirmek (§4.16) · çok baytlı `sed`
  sınıfı (§4.1) · çok baytlı `grep` kalıbı (§4.17) · `python3` · macOS'a özgü araç.
- Testler: `sh tests/run.sh`. Yardımcılar: `t`, `assert_eq`, `ok`, `not_ok`, `skip`, `mkvault`,
  `mk_index_vault`, `mk_search_vault`, `i18n key`, `layout_names`, `comp_name`, `cmd_name`,
  `TMP`, `ROOT`, `LIB`, `TAB`.
- `i18n/en.txt` ile `i18n/tr.txt` anahtar kümeleri birebir aynı olmak ZORUNDA;
  `layout/emoji.txt` ile `layout/plain.txt` slug kolonları da.
- Suite yerelde ~52 dk. `/tmp` kullanmayın; repo altında `.probe$$`. `docs/` `.gitignore`'da.

## 0. Bu fazın tek cümlelik ölçütü

> **Bir ajan `docs/KURULUM.md`'yi okuyup kullanıcıyla konuşarak çalışan, adı konmuş,
> ajanına bağlanmış bir vault kurabilir — ve hiçbir adımda platforma özgü araç gerekmez.**

## 1. Bulgular (U-1…U-5)

`docs/FAZ9-BULGULAR.md`'de resmileşir, her biri `[kaynak: <dosya>:<satır>]` etiketli.

- **U-1** quipu'nun kurulumu README §"Install": repo'yu klonla, `quipu`'yu PATH'e koy.
  Mülakat, kişiselleştirme, companion adı, ajan bağlama otomasyonu **yok**. `init` teknik bir
  komut: klasörler + köprü dosyaları + tohumlar.
- **U-2** Persona **zaten veri**: `persona/en.md`, `persona/tr.md`; `init` dil zincirine göre
  birini kopyalıyor (`quipu:559-581`, `cp` → `<companion>/companion.md`), kullanıcı
  düzenlemesi yalnız-yoksa kuralıyla korunuyor. → Kişiselleştirme için sınıf değişimi gerekmez.
- **U-3** Layout **zaten veri**: `layout/emoji.txt` + `layout/plain.txt` (`slug<TAB>ad`),
  açıklamalar `layout_<slug>` i18n anahtarları; `init` klasörleri bu dosyadan üretiyor
  (`quipu:531-544` civarı, `mkdir -p` + `.gitkeep`) ve `AGENTS.md` gövdesini de aynı dosyadan
  yazıyor (`quipu:583-606`).
- **U-4** avenoxbeyin'in `SETUP.md`'si **kod değil, ajan runbook'u**: 6 faz — makine adından
  `JohnOS` türetme, Türkçe mülakat (isim, bio, companion adı, opsiyonel klasörler, mem0),
  `brew install obsidian`, `template/` kopyalama, `{{OS_NAME}}`/`{{COMPANION}}` placeholder
  doldurma, `osacompile` + Swift/AppKit ile 🧠 ikonlu `.app`, doğrulama + Türkçe rapor.
  **Alınacak fikir:** runbook + mülakat + son doğrulama raporu.
  **Alınmayacak:** `{{...}}` placeholder mekanizması (quipu'da config + i18n var), `brew`,
  Obsidian kurulumu, macOS launcher, `python3`, mem0.
- **U-5** `doctor` zaten kurulum doğrulayıcısı: araçlar, lehçeler, gönderilen dosyalar, vault,
  ajan yüzeyleri (`claude hooks: installed/not installed`), uyarılar; özet `%d ok, %d warn,
  %d fail` ve `FAIL > 0` iken exit 1 (`quipu:304-312`). → Runbook'un doğrulama fazı bunu çağırır.

## 2. Runbook (V-1)

- **V-1** `docs/KURULUM.md` — **ajanın çalıştıracağı** runbook, quipu'nun kendi üslubunda
  (avenoxbeyin `SETUP.md`'si biçim örneğidir, içeriği değil). Fazlar:

  - **Faz 0 — Ön koşul.** `quipu doctor` koş; `fail` varsa dur ve eksiği söyle (U-5).
    Platforma özgü kurulum YOK: quipu'nun gereksinimi POSIX sh + sed/awk/grep/tr/git.
  - **Faz 1 — Mülakat.** Kullanıcının dilinde, konuşma diliyle: (1) adın, (2) AI ortağının adı,
    (3) dil (`tr`/`en`), (4) yerleşim (`emoji`/`--plain`), (5) vault yolu.
    **mem0 sorusu YOK** (kapsam dışı, §8).
  - **Faz 2 — Kurulum.** `quipu init --lang <dil> [--plain] [--user <ad>] [--companion <ad>]`.
  - **Faz 3 — Kimlik.** `companion.md`'nin kişiselleştiğini ve `.quipu/config`'te `user=`/
    `companion=` satırlarının bulunduğunu doğrula.
  - **Faz 4 — Ajan bağlama.** Kullanıcının ajanına göre dallanır: Claude Code → README
    §"Claude Code"daki `settings.json` hook'ları (dördü) + **yeniden başlat** uyarısı;
    Codex → `adapters/codex/hooks.json` kopyalama + yeniden başlat; hook'suz ajan →
    `capture --git` + `remember` + `context --bridge` üçlüsü.
  - **Faz 5 — İlk indeks ve doğrulama.** `quipu index` (soğuk vault uzun sürebilir — ölçüm:
    5000 not 2150-2367 s Windows msys), bir `quipu search` denemesi, `quipu doctor` tekrar,
    sonra kullanıcının dilinde rapor: ne kuruldu, ilk çalıştırma nasıl, "sihri göster" adımı
    (bir şey konuş → oturumu kapat → tekrar aç → devamlılığı gör).

  Runbook **hiçbir yerde** `brew`, `python3`, `osacompile`, `swift`, `apt`, `winget`
  çağırmaz — statik testle kilitlenir (T-119).

## 3. Kimlik verisi (V-2…V-5)

- **V-2** `.quipu/config` iki yeni anahtar: `user=` ve `companion=`. Okuma deseni mevcut
  `awk -F= -v k=...` çağrılarının aynısı (`layout=`/`lang=`/`fold=` gibi). Yazma: `init`
  `--user <ad>` ve `--companion <ad>` bayraklarını alır; **yalnız satır yoksa** yazar
  (`layout=` deseni), mevcut değeri **asla üzerine yazmaz**.
- **V-3** `companion.md` tohumu kişiselleştirilir: `persona/<dil>.md` içindeki iki `%s`
  yer tutucusu (companion adı, kullanıcı adı) `printf` ile doldurulur.
  **Literal `{{...}}` şablon mekanizması YASAK** (§4.11 ruhu: şablon motoru yazma).
  `persona/*.md` **veri** kalır; `%s` sırası dosyanın başındaki tek satırlık yorumda belgelenir.
  Ad verilmemişse persona dosyası bugünkü gibi kopyalanır (geriye uyum) — bu durumda `%s`
  yerine i18n'den gelen nötr karşılıklar (`persona_default_companion`, `persona_default_user`)
  konur, dosyada ham `%s` **kalmaz**.
- **V-4** `AGENTS.md` köprü gövdesi companion adını kullanır. `bridge_companion` zaten `%s`
  alıyor (`i18n/en.txt:77` = `Companion persona: %s/companion.md`) — klasör adı yerine
  "ad + yol" biçimine geçer; iki dilde de güncellenir.
- **V-5** `doctor`'a kimlik satırı: `user=` veya `companion=` yoksa **warn**
  (`doc_identity_missing`). Desen `doc_layout_missing`'in kopyası.

## 4. Kapsam klasörleri kararı (V-6)

- **V-6** Kullanıcının istediği ek klasörler (`⚔️ 200-Goals`, `🔐 400-Vault` gibi) **`layout/*.txt`'e
  eklenmez**. Gerekçe: layout dosyası quipu'nun malıdır, `doctor` iki dosyanın slug eşitliğini
  kilitler ve her yeni slug iki i18n anahtarı ister. Runbook kullanıcıya klasörü elle açmasını
  söyler; `index` zaten vault'taki **tüm** `.md` dosyalarını tarıyor, yani ek klasör hiçbir
  değişiklik gerektirmez. Bu karar `docs/KURULUM.md`'de açıkça yazılır.

## 5. Testler (T-110…T-120)

- **T-110** `init --user Ada --companion Kuz` → config'te `user=Ada` ve `companion=Kuz`.
- **T-111** İkinci `init --user Baska` → **mevcut `user=Ada` değişmedi** (V-2).
- **T-112** `companion.md` içinde `Kuz` ve `Ada` geçiyor; ham `%s` **geçmiyor**.
- **T-113** Ad verilmeden `init` → `companion.md` oluşuyor, ham `%s` **geçmiyor**
  (i18n nötr karşılıkları kullanılmış).
- **T-114** Kullanıcı `companion.md`'ye satır ekler → ikinci `init` onu koruyor (mevcut
  yalnız-yoksa garantisinin regresyonu).
- **T-115** `AGENTS.md` köprü gövdesinde companion adı görünüyor; ham `bridge_companion`
  anahtarı görünmüyor.
- **T-116** `doctor`: `user=`/`companion=` yok → warn, exit 0. Dil bağımsız alan ayıklaması.
- **T-117** `--user` argümansız → exit 2 + `err_missing_arg`; `--companion --bogus` gibi
  bilinmeyen bayrak → exit 2 + `err_unknown_flag` (V1/FAZ 7 `-*)` kolunun regresyonu).
- **T-118** i18n: `persona_default_*`, `doc_identity_missing` iki dilde de var, anahtar
  kümeleri eşit.
- **T-119** **Statik runbook kapısı:** `docs/KURULUM.md` içinde `brew`, `python3`, `osacompile`,
  `swift`, `apt-get`, `winget` dizgeleri **geçmiyor** (ASCII `grep`).
- **T-120** `docs/KURULUM.md` beş fazın hepsini içeriyor ve her fazda çağrılan quipu komutu
  gerçekten var (`doctor`, `init`, `index`, `search`, `context`, `remember` dışında komut adı
  geçmiyor — `usage` listesiyle karşılaştırma).

## 6. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/FAZ9-BULGULAR.md` — U-1…U-5 `[kaynak]` etiketli | her U-n kaynaklı |
| **1** | V-2 (`--user`/`--companion`, config) + T-110/T-111/T-117 | 3 test |
| **2** | V-3/V-4 (persona `%s`, köprü) + T-112…T-115/T-118 | 5 test, ham `%s` yok |
| **3** | V-5 (doctor) + T-116 | 1 test |
| **4** | V-1/V-6 (`docs/KURULUM.md`) + T-119/T-120 | 2 test, statik kapı yeşil |

## 7. Yasak desenler (devralınan + yeni)

Ön bilgideki liste · **`{{...}}` placeholder / şablon motoru yazmak** (V-3: `printf '%s'`) ·
**`persona/*.md`'yi koda taşımak** (veri kalır) · **`layout/*.txt`'e kullanıcı klasörü eklemek**
(V-6) · **runbook'ta platforma özgü paket yöneticisi çağırmak** (T-119) · **mevcut config
değerini üzerine yazmak** (V-2) · mem0 / harici servis.

## 8. Çıkış koşulu

1. Dilim 0: `FAZ9-BULGULAR.md` U-1…U-5'i cevaplıyor.
2. **Regresyon kapısı:** mevcut iddialar aynen yeşil; ad verilmeden `init` bugünkü davranışı
   koruyor (yalnız `%s` doldurma farkı).
3. `sh tests/run.sh` yeşil, `shellcheck -s sh quipu tests/run.sh` sessiz.
4. `docs/KURULUM.md` bir ajan tarafından uçtan uca **fiilen koşulmuş** ve boş bir dizinde
   çalışan bir vault üretmiş (elle doğrulama, rapora yazılır).
5. Üç OS CI yeşil olmadan merge yok.

## 9. Kapsam dışı

- **mem0 / semantik hafıza servisi** — quipu'nun kararına aykırı (PLAN §1).
- **Obsidian kurulumu, masaüstü launcher, ikon üretimi** — platforma bağlı; quipu üç OS iddia
  ediyor. İstenirse ayrı ve opsiyonel bir belge olur, çekirdeğe girmez.
- **Hook dosyalarını quipu'nun otomatik yazması** — runbook kullanıcıya gösterir, quipu
  `settings.json`'a dokunmaz (installer yok kararı, PLAN §5).
- **Obsidian not sözleşmeleri** (frontmatter/wikilink/status) — FAZ 10'un işi.
