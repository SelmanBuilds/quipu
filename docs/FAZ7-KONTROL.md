# quipu — FAZ 7 çıktı kontrol listesi

> **Bu dosya ne?** FAZ 7'yi uygulayan kod ajanının çıktısını incelemek için gözden geçirme
> protokolü ve bu turda **fiilen yapılan denetimin sonucu**. Kaynaklar: `docs/FAZ7-SPEC.md`
> (L-1…L-5, J-1…J-11, T-78…T-87), `docs/FAZ7-BULGULAR.md` (L-1…L-5), `docs/FAZ6-KONTROL.md`
> (protokol deseni + ortak süreç bulgusu).
>
> **Denetim tabanı — KRİTİK:** FAZ 7 kodu `dea829c` ("faz6+faz7: uçtan uca senaryolar, DZ-4,
> search --brief, ölçek + avenoxbeyin yerleşimi") ile FAZ 6 ile birlikte tek commit'te birleşti.
> Bu denetim **HEAD (`ecca473`)** üzerinden yapılmıştır. Doğrulama: `git diff dea829c ecca473 --
> quipu tests/run.sh i18n/ lib/` **boş** — `ecca473` yalnız `docs/` altına yeni belgeler ekledi,
> kod tarafı `dea829c` ile birebir aynı. Çalışma ağacındaki commit'lenmemiş FAZ 8/9
> değişiklikleri bu denetimin **dışındadır**.
>
> **Tarih:** 2026-08-22 · **Durum:** **İNCELENDİ** — kod düzeyinde denetlendi, testler bu
> turda **koşulmadı** (kullanıcı talimatı: test suite ~52 dk sürüyor). Ölçek testinin (T-85)
> gerçek süresi de bu turda **ölçülmedi**; yalnız kodun/yorumların/PLAN'ın iddia ettiği önceki
> ölçüm (2150-2367 s) rapor edilir, kaynağı belirtilerek.
>
> **ÖNEMLİ BULGU (FAZ 6 ile ortak):** `dea829c`/`ecca473` yalnız yerel `faz6-faz7` dalındadır;
> `origin/faz6`/`origin/faz7` yok, PR açılmamış, üç OS CI hiç koşmamış. FAZ7-SPEC §9 madde 5
> ("Dal + PR, üç OS CI yeşil olmadan merge yok") **şu an karşılanmadığı** anlamına gelir; §9
> madde 6'nın istediği **`v1.0.0` etiketi de yok** (`git tag -l` boş döndü) — bu iki ayrı,
> ilişkili açık kalemdir, aşağıda §10'da işaretlenmiştir.

---

## 0. Girdi kontrolü

- `git log --oneline`: FAZ 7 kodu `dea829c` (FAZ 6 ile birleşik commit); HEAD `ecca473` kod
  farkı taşımıyor (doğrulandı, bkz. üst not).
- `sh tests/run.sh` çıktısı — **bu turda koşulmadı**.
- `shellcheck` çıktısı — **bu turda koşulmadı**.
- `git tag -l` — **boş**, `v1.0.0` yok.
- Commit mesajı kendi kapanış özetini taşıyor; ayrı bir ajan raporu dosyası yok.

## 0.1 Ön kapı — FAZ 6 `[STATİK]`

- [x] FAZ 6 kodu (T-72…T-77) aynı commit'te (`dea829c`) FAZ 7'den **önce** yazılmış sırayla
      duruyor (`tests/run.sh:956-1058` FAZ 6, `:1060-1190` FAZ 7) — commit mesajının kendisi
      de FAZ 6'yı FAZ 7'den önce anlatıyor.
- [~] FAZ7-SPEC'in ön koşulu "FAZ 6 tamam (T-72…T-77 yeşil, üç OS CI yeşil)" — T-72…T-77'nin
      kod olarak var olduğu doğrulandı (bkz. `FAZ6-KONTROL.md`) ama **hiçbiri bu turda
      koşulmadı, üç OS CI de hiç koşmadı** (FAZ 6 ile ortak süreç boşluğu). Kapı **kod
      düzeyinde** açık, **doğrulama düzeyinde** açık değil.

Kapı kod düzeyinde açık kabul edilip denetime devam edildi (FAZ 6 kendi belgesinde ayrıca
işaretlendi, burada tekrar edilmiyor).

## 1. Kapsam doğrulama

| Dilim | İçerik | Çıkış koşulu | Durum |
|---|---|---|---|
| 0 | `docs/FAZ7-BULGULAR.md` — L-1…L-5 `[kaynak]` etiketli | her L-n dosya:satır kaynaklı | [x] — §2 |
| 1 | DZ-4 (J-1…J-4) + T-78…T-81 | regresyon kapısı + 4 test | [x] — §3/§4 |
| 2 | `--brief` (J-5/J-6) + T-82…T-84 | 3 test | [x] — §3/§4 |
| 3 | Ölçek testi (J-7) + T-85…T-87 | 3 test, süre sınırları üç OS'ta | [~] kısmi — §3 J-7 |
| 4 | Belge + v1 kapanışı (J-8…J-11) | PLAN §9 "sıradaki: v2" | [~] kısmi — §3 J-10 |

**Kapsam dışı ihlali kontrolü:** `search.awk` akış tabanlı iki-geçişli sürüm yazılmamış (v2
notu olarak bırakılmış — README + PLAN); durumlu `capture --git` eklenmemiş; Codex canlı
doğrulaması yapılmamış (iptal, bilinçli); Cursor/Windsurf/OpenCode adaptörü eklenmemiş; MCP
sunucusu yok. Hepsi spec'e uygun biçimde dışarıda bırakılmış.

**Ek not (FAZ 6 ile ortak):** aynı commit'e "yerleşim" (klasör taksonomisi) işi de
bindirilmiş — bu FAZ7-SPEC'in konusu değil, `docs/FAZ6-KONTROL.md` §1'de kaydedildi, burada
tekrar edilmiyor.

## 2. Kaynak bulgular (Dilim 0 — L-1…L-5)

`docs/FAZ7-BULGULAR.md` beşini `[kaynak]`/`[ölçüm]`/`[doğrulanmadı]` etiketleriyle cevaplıyor;
HEAD üzerinden tek tek açıldı:

- **L-1** [STATİK — doğrulandı] Dört döngünün (`capture`/`init`/`context`/`remember`) `*)`
  dalı bilinmeyen her sözcüğü `err_missing_arg` ile öldürüyordu (FAZ 7 öncesi hâl); `search`'te
  `-*` sessizce sorgu kelimesi oluyordu. Alıntılanan satır metinleri (`*) _q_die
  err_missing_arg 2 ;;`) HEAD'de **hâlâ birebir aynı metinle** duruyor, yalnız üstlerine yeni
  `-*)` dalları eklenmiş (bkz. §3 J-3/J-4) — BULGULAR'ın "bağlayıcı satır metni birebir
  alıntılanmıştır, kayma sonrası grep ile bulunur" önlemi doğrulandı: `grep -n "err_missing_arg
  2 ;;"` HEAD'de hâlâ eşleşiyor.
- **L-2** [STATİK — doğrulandı] `_q_die`'ın eski hâli (`$1` dışında argüman taşımıyor) BULGULAR'da
  alıntılanan beş satırlık gövdeyle uyumlu; HEAD'de bu gövde J-2 ile genişletilmiş (§3'te
  detaylı) ama BULGULAR'ın tarif ettiği **eski davranış** (`key [code]`) hâlâ bir alt yol
  olarak korunuyor.
- **L-3** [STATİK — doğrulandı] `lib/search.awk`'ın FAZ 7 öncesi hâlinde `folded[n]` bellekte
  tutulup emit satırına konmuyordu (BULGULAR'ın alıntıladığı `printf` dört alanlıydı). HEAD'de
  beşinci alan eklenmiş (§3 J-5).
- **L-4** [STATİK — doğrulandı] FAZ 7 öncesi test paketinde dört haneli doküman sayısı üreten
  bir döngü yoktu; ölçülen tek şey 448 KB'lık tek payload'du (`tests/run.sh` mevcut
  `T-85` öncesi hâlde). J-7 bu boşluğu kapatıyor — kısmen (§3'te not edildi).
- **L-5** [ÖLÇÜM + STATİK — doğrulandı, kod hâlâ tutarlı] Katlama boru hattının (`sed -f
  fold/$_q_prof.sed | tr 'A-Z' 'a-z'`) sırası HEAD'de aynen duruyor (`quipu` içinde index ve
  search'te aynı iki satır, PLAN 4.3 sırasıyla); "kelime sınırında kesim ASCII varsayımından
  daha güvenli" sonucu J-5'in `snippet()` fonksiyonunda **birebir uygulanmış** (§3/§4'te
  doğrulandı). Sınırlama 2'nin (gawk karakter/mawk bayt) önerdiği `fold=tr` sabitlemesi
  `mk_search_vault`'ta (`tests/run.sh:508-511`, `fold=tr`+`lang=en`) ve ölçek vault'unda
  (`tests/run.sh:1146`, `fold=tr`+`lang=en`) **uygulanmış** — BULGULAR'ın test rehberliği
  birebir izlenmiş.

Sonuç: L-1…L-5 hepsi `[kaynak]` etiketli, HEAD'de doğrulanabilir, hiçbiri asılsız "ölçüldü"
iddiası taşımıyor.

## 3. Sözleşme denetimi (J-n → kanıt)

### DZ-4: bilinmeyen bayrak tanısı (J-1…J-4)

- **J-1** [STATİK — uygulandı] `err_unknown_flag` her iki dilde, `key=value` biçiminde:
  `i18n/en.txt:12` (`unknown flag: %s`), `i18n/tr.txt:12` (`bilinmeyen bayrak: %s`).
- **J-2** [STATİK — uygulandı] `_q_die` genişletildi (`quipu:84-102`): `_q_dk=$1; shift;
  _q_dc=${1:-1}; [ "$#" -eq 0 ] || shift` ile kod ayrıştırılıyor, kalan `$#>0` ise
  `_q_dfmt=$(_q_msg "$_q_dk")` + `printf "$_q_dfmt\n" "$@" >&2`, yoksa eski yol
  (`_q_msg "$_q_dk" >&2`) **birebir korunmuş**. Mevcut `key [code]` çağrıları (ör.
  `_q_die err_missing_arg 2`) kalan argüman taşımadığı için otomatik olarak eski dala düşüyor
  — geriye uyumluluk kod seviyesinde garanti, spesifik bir "eski çağrıları değiştirme" adımı
  gerekmemiş.
- **J-3** [STATİK — uygulandı] Dört döngüye (`capture:377`, `init:468`, `context:717`,
  `remember:799`) `-*) _q_die err_unknown_flag 2 "$1" ;;` eklenmiş; `*)` dalları (eski
  `err_missing_arg`) yerinde kalmış, sırada `-*)`'den **sonra** duruyor — pozisyonel argüman
  davranışı dokunulmamış.
- **J-4** [STATİK — uygulandı] `search` döngüsüne de aynı desen (`quipu:996`); `*)` dalı hâlâ
  bare kelimeleri sorguya ekliyor (`quipu:998-1004`, davranış J-4'ün istediği gibi yalnız
  `-` önekli argümanlarda değişti).

### `search --brief` (J-5…J-6)

- **J-5** [STATİK — uygulandı] `lib/search.awk`'a `brief`/`snip` parametreleri `-v` ile
  geçiriliyor (`quipu:1039-1041`, sabit sayısal değerler — ham kullanıcı verisi değil, §6
  yasak deseniyle çelişmiyor); emit satırı brief=1 iken 5 sütun basıyor
  (`lib/search.awk:129-132`: `printf "%.3f%c%s%c%s%c%s%c%s%c", score,9,path,9,title,9,tags,9,
  snippet(folded[d],snip),10`). `snippet()` fonksiyonu (`lib/search.awk:153-159`) yalnız
  `substr`/`length` kullanıyor, marker eklemiyor, ilk boşluğa geri sararak kelime sınırında
  kesiyor — L-5'in "risk yalnız ilk 120 baytta hiç boşluk yoksa" notuyla tutarlı bir fallback
  (`cut` düz döner) bırakılmış, testlerde bu dal `fold=tr` sabitlemesiyle bilinçli olarak
  tetiklenmiyor (BULGULAR'ın önerdiği gibi).
- **J-6** [STATİK — uygulandı] `_q_brief -eq 1 && _q_paths -eq 1` → `err_conflict`
  (`quipu:1006-1008`); `--brief` yalnız `search`'te tanımlı, başka döngüde geçmiyor
  (`grep -n brief quipu` yalnız arama komutunda eşleşiyor).

### i18n (J-11)

- **J-11** [STATİK — uygulandı] `usage_search` satırına `--brief` notu eklenmiş, tek satır,
  iki dilde: `i18n/en.txt:6` (`... (--brief: 120-byte snippet)`), `i18n/tr.txt:6`
  (`... (--brief: 120 baytlık künye)`).

### Ölçek testi (J-7)

- **J-7** [STATİK — kısmi] Sentetik 5000 `.md` vault, tek üreteç döngüsü (fixture değil,
  `tests/run.sh:1148-1153`); `quipu index` özet `5000 0 5000 0` (T-85, `tests/run.sh:1163`);
  `search ortakterim --limit 5000` → 5000 isabet (T-86); `--brief` şekli ölçek vault'unda da
  kilitli (T-87). **Ancak SPEC metninin kendisi "index < 120s, search < 30s" diyor**
  (`docs/FAZ7-SPEC.md:62`) — HEAD'deki kod bu sınırı **uygulamıyor**: index testi (T-85) `[
  $((END - START)) -lt 3600 ]` kullanıyor (`tests/run.sh:1173`), yani 120s değil **3600s**
  sınır. Bu, spec metninin sayısal iddiasıyla **doğrudan çelişen**, ama bilinçli ve
  gerekçelendirilmiş bir sapma: kod içi yorum (`tests/run.sh:1170-1172`) ve `docs/PLAN.md:603`
  gerçek ölçümü açıkça yazıyor — Windows msys'te 5000 dosyalık ilk indeksleme **2150-2367
  saniye (~36-39 dakika)** sürüyor, yani spec'in öngördüğü 120 saniyenin **~18-20 katı**.
  3600s sınırı yorumda "askıda kalma/regresyon tavanı, performans iddiası değil" olarak
  açıklanıyor; gerçek sayı her koşuda `# info:` satırıyla basılıyor. `search` tarafında
  (T-86) spec'in 30s sınırı **birebir korunmuş** (`tests/run.sh:1182`, `-lt 30`) ve gerçek
  ölçüm (1 s) bu sınırın çok altında — orada sapma yok.

  **Sonuç: J-7 "index < 120s" maddesi uygulanmadı; onun yerine dürüstçe belgelenmiş, çok daha
  gevşek bir tavan (3600s) kondu ve gerçek sayı ölçülüp PLAN.md'ye yazıldı.** Bu bir gizli
  ihlal değil — spec'in orijinal 120s hedefinin gerçekçi olmadığı bu fazda **ölçümle**
  keşfedilmiş ve tavanın kendisi bilinçli olarak gevşetilmiş; ama FAZ7-SPEC.md'nin metni
  **düzeltilmemiş** (hâlâ "index < 120s" yazıyor), yalnız PLAN.md §7 risk satırı güncel sayıyı
  taşıyor. Bu, gelecekte SPEC'i okuyan birinin yanlış beklentiye kapılmasına yol açar —
  KONTROL'ün amacı gereği burada açıkça işaretlendi.

### Belge (J-8…J-10)

- **J-8** [STATİK — uygulandı] README "Large vaults" bölümü (`README.md` HEAD'de mevcut,
  satır ~103) iki aşamalı deseni, `.quipu/index.tsv` büyüklük notunu, "Honest ceilings"
  altında bellek tavanını (`folded[]` tüm indeksi belleğe alıyor, v2 adayı) ve
  `QUIPU_CTX_MAX`'ın vault büyüklüğünden bağımsız olduğunu ayrı ayrı yazıyor — spec'in
  istediği dört alt-madde de var.
- **J-9** [STATİK — büyük ölçüde uygulandı]
  - §5 Cursor/Windsurf/OpenCode satırlarına **"iptal (2026-08-21 kararı)"** notu birebir var
    (`docs/PLAN.md` §5 tablosu, üç satırda da aynı metin).
  - §7 "İndeks bağlam sınırı" satırı ölçek testine + `--brief`'e bağlanmış, dürüst tavan v2'ye
    taşınmış (`docs/PLAN.md:603`) — uygulandı.
  - §7 "Codex hook şeması" satırına iptal notu var (`docs/PLAN.md:613`) — uygulandı.
  - §8 avenoxbeyin bölümüne "iptal (2026-08-21 kararı)" notu var, bölüm silinmemiş
    (`docs/PLAN.md:619-621`) — uygulandı.
  - §6 FAZ 6 ✅, FAZ 7 ✅ var; §9 durum satırı var ve **"sıradaki: v2 adayları (MCP paketi,
    akış sürümü)"** metnini taşıyor (`docs/PLAN.md:708-711`) — uygulandı.
- **J-10** [STATİK — kısmi] README son geçişi (search `--brief` + `-*` davranış notu) var
  (§ yukarıda). **Ancak merge sonrası `v1.0.0` etiketi YOK** (`git tag -l` boş) — bu, üstteki
  "PR/merge hiç olmadı" bulgusunun doğal sonucu (etiket "merge sonrası" konur, merge henüz
  yok). PLAN.md'nin kendisi de bunu örtük biçimde kabul ediyor: §9'daki "Yazılmış sözleşmeler"
  bölümünde `V1-DUZELTME-SPEC.md`'nin "**v1.0.0 etiketinden önce** girmesi tercih edilir"
  yazıyor (`docs/PLAN.md:720`) — yani tag'in henüz atılmadığı PLAN.md'nin kendi metninde de
  doğrulanıyor. §7 risk tablosunun "kalan tek açık kalemler dürüstçe listelenir" isteği
  kısmen karşılanmış: Codex canlı doğrulaması [iptal] ve akış tabanlı search tavanı (v2)
  satırları var, ama **MCP** yalnız §9 "Sıradaki" cümlesinde geçiyor, §7 risk tablosunun
  kendi satırı olarak yok (küçük, gerekçesi tartışmalı bir eksik — MCP zaten §2/§3'te ayrı bir
  "v1'e alınmayacak" satırına sahip, `docs/PLAN.md:115`).

## 4. Test incelemesi (T-78…T-87)

HEAD'de `tests/run.sh:1060`, `:1104`, `:1143` başlıklı üç blokta, spec numaralandırmasıyla
birebir:

**DZ-4 (T-78…T-81):**

- **T-78** (`tests/run.sh:1069-1074`) — `capture --bogus` exit 2 + stderr tam olarak
  `unknown flag: --bogus` (i18n şablonundan runtime'da üretilip karşılaştırılıyor,
  `tests/run.sh:1066`, hardcode değil).
- **T-79** (`tests/run.sh:1077-1083`) — `for _c in init context remember` döngüsüyle üç komut,
  aynı iddia — DRY, spec'in istediği "üç komuta bir bilinmeyen bayrak" testini tek döngüde
  karşılıyor.
- **T-80** (`tests/run.sh:1085-1092`) — `search --bogus` exit 2 + flag adını içeren mesaj **ve**
  stdout'un **boş** olduğu ayrıca doğrulanıyor (`tests/run.sh:1092`, spec'in istemediği ama
  mantıklı bir ek kontrol: sorgu olarak da işlenmediği kanıtı).
- **T-81** (`tests/run.sh:1096-1101`) — `capture --event` (değersiz) hâlâ `err_missing_arg`
  metnini basıyor **ve** mesajın `unknown`/`--bogus` içermediği ayrıca `grep -qE` ile
  doğrulanıyor — regresyon kapısı iki yönlü (eski mesaj aynı KALDI + yeni mesaj SIZMADI).

**--brief (T-82…T-84):**

- **T-82** (`tests/run.sh:1112-1119`) — 5 sütun (`NF==5`), künye ≤120 bayt her satırda, kısa
  alanın (`body-doc.md`) tam katlanmış metnini index.tsv'den okuyup birebir karşılaştırıyor
  (kesim yok kanıtı).
- **T-83** (`tests/run.sh:1121-1129`) — künyenin son karakteri boşluk değil **ve** tam
  katlanmış alanda kesim noktasından hemen sonraki bayt boşluk — iki taraflı word-boundary
  kanıtı, spec'in istediğinden daha güçlü.
- **T-84** (`tests/run.sh:1138-1141`) — `--brief --paths` exit 2 + `err_conflict` mesajı.

**Ölçek (T-85…T-87):**

- **T-85** (`tests/run.sh:1160-1174`) — 5000 doküman, `idx_nums` ile `5000 0 5000 0`,
  `index.tsv` satır sayısı ayrıca `awk 'END{print NR}'` ile 5000 doğrulanıyor (çift kontrol);
  süre `# info:` ile basılıyor; sınır **3600s** (spec'in 120s'i değil — §3 J-7'de işlendi).
- **T-86** (`tests/run.sh:1176-1183`) — `search ortakterim --limit 5000` → tam 5000 satır;
  süre sınırı **30s**, spec'e uygun.
- **T-87** (`tests/run.sh:1185-1190`) — `--limit 50 --brief` ölçek vault'unda 5 sütun + ≤120
  bayt + tam 50 satır (`--limit` ölçekte de tutarlı).

**Kırılganlık dersleri:** `QUIPU_LANG=en` her i18n'ye bakan iddiada var; süre ölçümü `date
+%s` + `[ $((END-START)) -lt N ]` deseni, mevcut 448 KB testinden devralınmış
(`tests/run.sh:1163,1177,1181`); satır sayımı `awk`; fixture yok (üreteç). Başıboş
`t;`/`RC=$?` taraması bu turda satır satır yapılmadı — **[doğrulanmadı]**.

**Test sayısı:** PLAN.md "**226 geçti + 2 skip** (228 iddia; baz 179 + T-72…T-87 = 46 yeni
iddia + yerleşim diliminde 3)" diyor (`docs/PLAN.md:698-699`). Bu rakam **bu turda yeniden
doğrulanmadı** — kaynağı `docs/PLAN.md:698`, test suite koşulmadan teyit edilemez.

## 5. Regresyon kapısı

- **[ÇALIŞTIR — doğrulanmadı]** Mevcut N iddia (FAZ 6 çıktısı) aynen yeşil mi — koşulmadı.
- `search` bare-kelime davranışı ve `_q_die` çağrıları değişmedi iddiası — **kod düzeyinde**
  doğrulandı (T-81'in ikinci kısmı zaten bunu statik olarak da kanıtlıyor: eski `err_missing_arg`
  çağrıları satır satır aynı metinle duruyor, §2 L-1 notu).

## 6. Yasak desen taraması (§8)

`lib/search.awk`'ta `--brief` kesim mantığı yalnız `substr`/`length`/`index` kullanıyor, regex
yok (`grep -n "match\|gsub\|~" lib/search.awk` ile HEAD'de dolaylı olarak doğrulandı — brief
bloğu ve `snippet()` fonksiyonu içinde regex operatörü yok). Künyeye marker eklenmemiş
(`snippet()` çıktısı ham `substr`). 5000 dosya fixture olarak commit edilmemiş — `tests/run.sh`
içinde `awk`/shell döngüsüyle üretiliyor (`tests/run.sh:1148-1153`), `git show --stat dea829c`
çıktısında `tests/fixtures/` altına 5000 yeni dosya **yok**. `declare -A`/`${var,,}`/`[[ ]]`/
`=~`/`local ` taraması FAZ 7'nin eklediği kod bölgelerinde **sıfır eşleşme**.

## 7. Kırmızı bayraklar — denetimde fiilen görülenler

1. **J-7 süre sınırı sapması (en önemli bulgu):** SPEC metni "index < 120s" diyor, kod
   "index < 3600s" uyguluyor. Gerekçeli ve PLAN.md'de dürüstçe ölçülüp yazılmış, ama
   **FAZ7-SPEC.md'nin kendisi güncellenmemiş** — ileride spec'i tek başına okuyan biri yanlış
   beklentiye düşer. Düzeltme önerisi burada **uygulanmıyor** (görev kapsamı dışı), yalnız
   raporlanıyor.
2. **v1.0.0 etiketi yok:** J-10/exit-koşulu 6 açık. Merge olmadığı için beklenen bir sonuç,
   ama kabul listesinde ayrı satır olarak işaretlenmesi gerekiyor.
3. **PR/CI süreç boşluğu:** FAZ 6 ile ortak — dal push edilmemiş, üç OS CI hiç koşmamış.
4. **§7 risk tablosunda MCC/MCP ayrı satır olarak yok:** küçük, J-10'un "kalan açık kalemler"
   listesini tam karşılamıyor; MCP zaten başka bir yerde (§2/§3) "v1'e alınmayacak" olarak
   işaretli olduğu için pratik etkisi düşük.
5. **Ölçek testinin gerçek süresi bu turda yeniden ölçülmedi:** yalnız kod yorumlarındaki ve
   PLAN.md'deki önceki ölçüm (2150-2367s) rapor edildi; bu turun kendi makinesinde tekrar
   koşulmadı.

## 8. Belge tamamlığı

- [x] `docs/FAZ7-BULGULAR.md` var, L-1…L-5 `[kaynak]`/`[ölçüm]` etiketli, FAZ5/FAZ6-BULGULAR
      deseninde (Kaynak yöntemi + Zaman referansı + Sözleşme karşılığı üst bloğu var).
- [x] README "Large vaults" + "Honest limits" bölümleri tam (J-8).
- [x] `docs/PLAN.md` §5/§7/§8/§6/§9 güncellemelerinin çoğu var (J-9).
- [~] `docs/PLAN.md` §7 risk tablosunda MCP'nin kendi satırı yok (J-10 kısmi, küçük).
- [ ] `v1.0.0` etiketi yok (J-10 açık kalemi, merge olmadığı için beklenen).

## 9. Koşulacak doğrulamalar (bu turda YAPILMADI — sıradaki tur için)

1. `sh tests/run.sh` — yerel tam paket; özet satırı PLAN.md'nin "226 geçti + 2 skip" iddiasıyla
   karşılaştırılmalı.
2. `shellcheck -s sh quipu tests/run.sh` — sıfır bulgu (PLAN.md "0.11.0 sessiz" diyor,
   bu turda tekrar doğrulanmadı).
3. Elle: 5000 dokümanlık ölçek testinin bu makinede gerçek süresi — PLAN.md'nin 2150-2367s
   iddiasının hâlâ geçerli olup olmadığı (makine yüküne göre değişebilir, testin kendisi
   bunu her koşuda `# info:` ile bastığı için ayrı bir ölçüm gerekmez, yalnız suite
   koşulduğunda görülür).
4. Dal push edilip PR açıldığında üç OS CI sonucu; yeşilse `v1.0.0` etiketi (J-10).

## 10. Kabul koşulları — tek bakışta

- [x] Dilim 0 eksiksiz; `FAZ7-BULGULAR.md` L-1…L-5'i etiketli cevaplıyor
- [x] J-1…J-6, J-8, J-9, J-11 kod/i18n/README/PLAN düzeyinde birebir uygulanmış
- [~] J-7 kısmi — ölçek testi var ve doğru şeyi sınıyor, ama süre sınırı SPEC metninden
      (120s → 3600s) **saptı**; sapma gerekçeli ve PLAN.md'de belgelenmiş, SPEC.md metni
      güncellenmemiş
- [~] J-10 kısmi — README/PLAN son geçişi tam, `v1.0.0` etiketi yok, §7 risk tablosunda MCP
      ayrı satır değil
- [x] T-78…T-87 var, spec'e uyuyor, iki yönlü/çift kontrollü (T-79, T-81, T-83, T-85)
- [ ] **[doğrulanmadı]** Yerel `sh tests/run.sh` bu turda koşulmadı
- [ ] **[doğrulanmadı]** Üç OS CI hiç koşmadı — dal push edilmemiş, PR yok
- [x] §8 yasak desenlerin hiçbiri FAZ 7 eklemelerinde yok
- [x] Kapsam dışı ihlali yok

**Verdict:** FAZ 7'nin **çoğu sözleşme maddesi (J-1…J-6, J-8, J-9, J-11) spec'e birebir
uyuyor** ve T-78…T-87 sağlam, iki yönlü testler. **İki madde kısmi:** J-7'nin süre sınırı
spec metninden (120s → 3600s) bilinçli ve gerekçeli biçimde sapmış ama SPEC.md metni
güncellenmemiş; J-10'un v1 kapanış adımı (etiket) henüz atılmamış — bu da dal hiç merge
edilmediği için beklenen bir sonuç. Açık kalan süreç kalemi FAZ 6 ile ortak: dal push
edilmemiş, PR yok, üç OS CI hiç koşmamış, yerel test suite bu turda koşulmadı.

---

## İşleyiş notu

- Bu belge tek turda, HEAD (`ecca473`) üzerinden statik denetimle üretildi; test suite
  koşulmadı (kullanıcı talimatı — 52 dk sürüyor), ölçek testinin gerçek süresi bu makinede
  yeniden ölçülmedi.
- Bulgular **L-n/J-n/T-n referanslı** raporlandı; `[STATİK]` bu turda fiilen yapılan kod
  okumasını, `[ÇALIŞTIR — doğrulanmadı]` bu turda koşulmayan ama koşulması gereken adımı
  işaret eder.
- Kullanıcı onayı olmadan repo'da komut koşulmadı; test suite çalıştırma ve etiketleme
  (`v1.0.0`) bu tur kapsamı dışında tutuldu.
