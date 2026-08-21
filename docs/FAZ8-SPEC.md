# quipu — FAZ 8 SPEC: yansıtıcı hafıza + "hafıza yazmadan bitti" yakalayıcısı

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: 2026-08-22 avenoxbeyin (github.com/avenoxai/avenoxbeyin) incelemesi + quipu'nun
> mevcut primitifleri.
> Ön koşul: FAZ 7 tamam; **V1-DUZELTME tercihen önce** (katlama profili sabitlenmiş olsun).
> Numara önekleri: **S-n** (bulgu), **Y-n** (sözleşme), **T-96…T-108** (test). Çakışma yok.
>
> **Bu fazın tek işi:** quipu mekanik defteri tutuyor, anlamı model üretiyor ama **hiçbir yere
> yazmıyor**. Bu faz modele yazacak bir yer, yazması için bir istem ve yazmadığında yakalanacağı
> bir kanca verir — hepsini quipu'nun kendi mekaniğiyle, avenoxbeyin'in üç kırık yolunu
> tekrarlamadan.

## Ön bilgi (yeni oturum için)

- Repo: tek dosya POSIX `sh` CLI (`quipu`) + `lib/*.awk` + veri dizinleri (`i18n/`, `layout/`,
  `fold/`, `persona/`, `adapters/`). Derinlik: `docs/PLAN.md`.
- **Yasak desenler:** `declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine
  dayanan KOD (§4.11) · ham kullanıcı verisini `awk -v` ile geçirmek (§4.16) · çok baytlı `sed`
  sınıfı (§4.1) · çok baytlı `grep` kalıbı (§4.17) · **`python3`** · **`stat -f`/`stat -c`
  doğrudan** (yalnız mevcut `mtime()` sarmalayıcısı, `quipu:130`).
- Testler: `sh tests/run.sh`. Yardımcılar: `t`, `assert_eq`, `ok`, `not_ok`, `skip`, `mkvault`,
  `mk_index_vault`, `mk_search_vault`, `mk_git_vault`, `git_commit`, `log_line`, `idx_nums`,
  `i18n key`, `layout_names`, `comp_name`, `cmd_name`, `TMP`, `ROOT`, `LIB`, `TAB`.
- Satır sayımı `awk 'END{print NR}'`; i18n iddialarında `QUIPU_LANG=en`; `i18n/en.txt` ile
  `i18n/tr.txt` anahtar kümeleri birebir aynı olmak ZORUNDA.
- Suite yerelde ~52 dk (ölçek testi). Geliştirirken bölümü izole koşun.
- `/tmp` kullanmayın (msys tutarsız); repo altında `.probe$$`.
- `docs/` `.gitignore`'da.

## 0. Bu fazın tek cümlelik ölçütü

> **Her oturum dosyasında modelin dolduracağı bir yansıma bloğu vardır; blok boş kaldıysa
> bir sonraki oturum bunu bağlamda görür — ve bu tespit hiçbir `mtime` okumasına dayanmaz.**

## 1. Bulgular (S-1…S-5)

`docs/FAZ8-BULGULAR.md`'de resmileşir, her biri `[kaynak: <dosya>:<satır>]` etiketli
(numaralar yazılmadan önce doğrulanır; aşağıdakiler 2026-08-22 doğrulu).

- **S-1** `remember` yalnız **mekanik** yazıyor: `lib/digest.awk` çıktısı + i18n başlıkları
  (`digest_range`, `digest_tools`, `digest_files`). Ölçülmüş örnek:
  `## 01:42 / Aralık: … (2 olay) / Araçlar: Read 1, Write 1 / Dokunulan dosyalar (en çok 10):
  -  2  gizli.md`. Not **içeriği** hiçbir yere sızmıyor (ölçüldü: gizli dizge yalnız notun
  kendisinde bulunuyor). Oturum dosyası: `<sessions>/YYYY-MM-DD.md`, append (`quipu:875`);
  `Last-Session.md` yalnız işaretçi, `block.awk` marker bloğuyla (`quipu:879`).
- **S-2** `Threads.md` tohumlanıyor (`threads_seed_title`/`threads_seed_note`) ve `context`
  okuyor (`_q_ctx_text`, `quipu:638`) ama **hiçbir şey onu güncellemiyor** — bakımsız dosya.
- **S-3** Hatırlatma mekaniği zaten var: `QUIPU_NUDGE_AFTER` (varsayılan 50), iki filigran
  `.quipu/remembered` + `.quipu/nudged` (`quipu:736-763`), mesaj `ctx_precompact` — metni
  şu an "update Threads.md and append today's session summary to the %s folder"
  (`i18n/en.txt:65`). Eksik olan hatırlatma değil, **"yazdı mı?" tespiti**.
- **S-4** `lib/block.awk` idempotent marker bloğu yazıyor ve `-v start/end` ile hedef marker
  değiştirilebiliyor (FAZ 5 DZ-5; testler T-68/T-71). Kullanımları: `context --bridge`
  (`quipu:772`), `remember`'ın `Last-Session.md`'si (`quipu:879`), `init`'in `AGENTS.md`
  köprüsü. → Modelin yazacağı bölge için hazır primitif.
- **S-5** avenoxbeyin aynı işi yapıyor ve **üç yerden kırık** (ölçüldü):
  1. JSON kaçışını `python3 -c json.dumps`'a yaptırıyor, `2>/dev/null` + `[ -n "$ESC" ] &&`
     ile koruyor → `python3` yoksa hook **sessizce hiçbir şey basmıyor**, exit 0
     (`template/.claude/hooks/session-start.sh`, `prompt-counter.sh`).
  2. `stat -f %m` BSD-only (`session-end.sh`) → Git Bash'te kırılıyor (quipu FAZ 0 ölçümü,
     `docs/PLAN.md:164`), `MODIFIED=0` sabitleniyor, her oturum yanlış uyarıyla açılıyor.
  3. Bağlam dizgisinde **literal `\n`** var: `CTX="${CTX}…\n${LAST_SESSION}\n\n"` çift tırnak
     içinde yorumlanmıyor, `printf '%s'` de yorumlamıyor → modele iki karakterlik `\n` çöpü
     gidiyor (ölçüldü: `cat -A` çıktısında `\nDun API…`).
  4. **Tasarım kırılganlığı:** okuyucu `sed -n '/^## Session:/,/^## Previous/p'` aralığına
     bağlı; yazan taraf serbest metin yazan model. Model başlığı değiştirirse devamlılık
     sessizce ölüyor. Doğrulayıcı yok, test yok.
  → **Bu fazın tasarım kısıtı:** yazar/okuyucu sözleşmesi **prozayla değil marker'la** zorlanır.

## 2. Yansıma bloğu (Y-1)

- **Y-1** Yeni komut YOK. `remember`, oturum dosyasına mekanik bölümü yazdıktan sonra, dosyada
  yansıma bloğu **yoksa** onu ekler:

  ```
  <!-- quipu:reflect:start -->
  ### <reflect_head_what>

  ### <reflect_head_where>

  ### <reflect_head_threads>

  <!-- quipu:reflect:end -->
  ```

  **Kritik:** blok **yalnız-yoksa** eklenir. `block.awk` blok içeriğini *değiştirme*
  semantiğine sahiptir (S-4) — o burada kullanılamaz, çünkü aynı gün ikinci `remember`
  modelin yazdığını silerdi. Tespit: marker satırının varlığı (`awk 'index($0, "quipu:reflect:start")'`),
  varsa **hiç dokunulmaz**. Ekleme append'tir; append-only garantisi bozulmaz.

## 3. Boşluk tespiti ve istem (Y-2…Y-4)

- **Y-2** **Blok doluluk tespiti** `awk` ile marker aralığında yapılır: başlık satırları
  (`### ` ile başlayanlar), marker satırları ve boş satırlar sayılmaz; kalan en az bir satır
  varsa blok **dolu**. `mtime` KULLANILMAZ (S-5.2'den kaçınma). Bu tespit tek yerde yaşar
  (`_q_reflect_filled <dosya>`), hem `context` hem `remember` onu çağırır.
- **Y-3** **Yakalayıcı:** `remember` koşarken bir önceki oturum dosyasının bloğu boşsa,
  `.quipu/needs_reflection` dosyasına tek satır yazılır (gün + olay sayısı). Bir sonraki
  `context --json SessionStart` bu satırı bağlamın **başına** koyar (`ctx_reflect_missed`) ve
  dosyayı **siler** — tek atış. avenoxbeyin'in fikri, `stat` yerine dosya varlığı ve
  içerik tespiti ile.
- **Y-4** **İstem:** `context --json SessionStart` çıktısı, bugünün oturum dosyası varsa ve
  bloğu boşsa `ctx_reflect_ask` satırını ekler: modelden oturum sonunda bloğu doldurmasını
  ister, blok yolunu ve marker adını **açıkça** yazar. `ctx_precompact` metni de yansıma
  bloğuna işaret edecek şekilde güncellenir (S-3: şu an yalnız Threads.md ve klasör adı diyor).

## 4. Sözleşmenin veriye taşınması (Y-5…Y-6)

- **Y-5** Yeni i18n anahtarları (tr + en, küme eşitliği zorunlu):
  `reflect_head_what`, `reflect_head_where`, `reflect_head_threads`,
  `ctx_reflect_ask`, `ctx_reflect_missed`.
- **Y-6** `AGENTS.md` köprü gövdesine **hafıza protokolü** paragrafı eklenir (i18n'den, koda
  gömülü değil): oturum sonunda yansıma bloğunu doldur, `Threads.md`'yi güncelle, quipu bu
  metinleri asla yeniden yazmaz. avenoxbeyin'in `template/CLAUDE.md` protokolünün karşılığı,
  ama **veri olarak**. `init`'in mevcut köprü gövdesi döngüsü (`quipu:583-606`) genişletilir.

## 5. Testler (T-96…T-108)

**Blok yaşam döngüsü:**
- **T-96** İlk `remember` → oturum dosyasında bir yansıma bloğu var, üç başlık i18n'den geliyor.
- **T-97** Model bloğa satır yazar → aynı gün ikinci `remember` → **yazılan satır korunuyor**,
  ikinci blok eklenmiyor (marker sayısı 1).
- **T-98** Blok dışına yazılan kullanıcı metni de korunuyor (append-only regresyonu).
- **T-99** Boş blok → `_q_reflect_filled` "boş" diyor; başlık ve boş satırlar doluluk saymıyor.
- **T-100** Bir satır içerik → "dolu".

**Yakalayıcı:**
- **T-101** Boş bloklu bir önceki gün + `remember` → `.quipu/needs_reflection` yazıldı.
- **T-102** `context --json SessionStart` → bağlamda `ctx_reflect_missed` var **ve** dosya silindi.
- **T-103** İkinci `context --json SessionStart` → mesaj **yok** (tek atış).
- **T-104** Dolu blok → `needs_reflection` hiç yazılmıyor.

**İstem ve metin kilitleri (`QUIPU_LANG=en`):**
- **T-105** Bugünün bloğu boş → `SessionStart` bağlamında `ctx_reflect_ask` var, içinde oturum
  dosyasının yolu ve `quipu:reflect` marker adı geçiyor.
- **T-106** `ctx_precompact` güncel metni yansıma bloğuna işaret ediyor.
- **T-107** `AGENTS.md` köprü gövdesinde hafıza protokolü paragrafı var; ham i18n anahtarı
  (`reflect_`/`ctx_reflect`) **görünmüyor** (eksik anahtar kanıtı olurdu).

**Statik dürüstlük kapıları (S-5'in tekrarlanmadığının kanıtı):**
- **T-108** `quipu` içinde `python3` geçmiyor; `stat ` yalnız `mtime()` sarmalayıcısında
  (`quipu:130`) geçiyor — sayım sabitlenir; `lib/*.awk` ve `quipu` içinde literal ters bölü yok
  (mevcut hijyen testi bunu zaten kilitliyor, yansıma metinleri onu bozmamalı).

## 6. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/FAZ8-BULGULAR.md` — S-1…S-5 `[kaynak]` etiketli, avenoxbeyin bulguları ölçümle | her S-n kaynaklı |
| **1** | Y-1 + Y-5 (anahtarlar) + T-96…T-98 | 3 test, blok yalnız-yoksa |
| **2** | Y-2/Y-3 + T-99…T-104 | 6 test, `mtime` kullanılmıyor |
| **3** | Y-4 + T-105/T-106 | 2 test |
| **4** | Y-6 + T-107/T-108 + belgeler | protokol veri olarak, statik kapılar yeşil |

## 7. Yasak desenler (devralınan + yeni)

Ön bilgideki liste · **`block.awk`'ı yansıma bloğu için kullanmak** (içeriği silerdi — Y-1) ·
**doluluk tespitini `mtime` ile yapmak** (S-5.2) · **modelin yazdığı metni ayrıştırmaya /
doğrulamaya çalışmak** (quipu formatı zorlar, anlamı zorlamaz) · **hafıza protokolünü koda
gömmek** (Y-6: i18n verisi) · `needs_reflection`'ı vault'un görünür ağacına yazmak
(`.quipu/` altında kalır).

## 8. Çıkış koşulu

1. Dilim 0: `FAZ8-BULGULAR.md` S-1…S-5'i cevaplıyor, avenoxbeyin iddiaları **ölçümle** destekli.
2. **Regresyon kapısı:** mevcut iddialar aynen yeşil; `remember`'ın mekanik çıktısı ve
   `Last-Session.md` işaretçisi **değişmedi**.
3. `sh tests/run.sh` yeşil, `shellcheck -s sh quipu tests/run.sh` sessiz.
4. Üç OS CI yeşil olmadan merge yok.

## 9. Kapsam dışı

- **mem0 / harici semantik katman** — quipu'nun "semantik katman zaten döngüdeki model" kararını
  bozar (PLAN §1, README "Why it's free").
- **`Last-Session.md`'yi üzerine yazmak** — avenoxbeyin öyle yapıyor, append-only'yi bozar.
- **Modelin yazdığı yansımanın içerik denetimi** — şema yok, doğrulayıcı yok; yalnız blok var.
- **`Threads.md`'yi quipu'nun güncellemesi** — modelin işi kalır; quipu yalnız hatırlatır.
- **Prompt sayacı** (avenoxbeyin'in 15'te tek atışı) — quipu'nun `QUIPU_NUDGE_AFTER` filigranı
  bu işi zaten satır sayısıyla yapıyor.
