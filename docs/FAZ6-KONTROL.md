# quipu — FAZ 6 çıktı kontrol listesi

> **Bu dosya ne?** FAZ 6'yı uygulayan kod ajanının çıktısını incelemek için gözden geçirme
> protokolü ve bu turda **fiilen yapılan denetimin sonucu**. Kaynaklar: `docs/FAZ6-SPEC.md`
> (G-1…G-5, I-1…I-8, T-72…T-77), `docs/FAZ6-BULGULAR.md` (G-1…G-5), `docs/FAZ5-KONTROL.md`
> (protokol deseni).
>
> **Denetim tabanı — KRİTİK:** FAZ 6 kodu `dea829c` ("faz6+faz7: uçtan uca senaryolar, DZ-4,
> search --brief, ölçek + avenoxbeyin yerleşimi") ile birleşti. Bu denetim **HEAD (`ecca473`)**
> üzerinden yapılmıştır. Doğrulama: `git diff dea829c ecca473 -- quipu tests/run.sh i18n/ lib/`
> **boş** — yani `ecca473` ile `dea829c` arasında bu dosyalarda fark yok; `ecca473` yalnızca
> `docs/` altına yeni belgeler ekledi (bkz. commit mesajı). Dolayısıyla HEAD üzerinden okunan
> satır numaraları `dea829c`'deki fiili koda birebir karşılık gelir. Çalışma ağacındaki
> (working tree) `quipu`/`tests/run.sh`/`i18n/*` bu denetimin **dışındadır** — orada
> commit'lenmemiş FAZ 8/9 değişiklikleri var ve satır numaralarını kaydırıyor.
>
> **Tarih:** 2026-08-22 · **Durum:** **İNCELENDİ** — kod düzeyinde denetlendi, testler bu
> turda **koşulmadı** (kullanıcı talimatı: test suite ~52 dk sürüyor, bu tur çalıştırılmadı).
> Aşağıdaki her iddia ya `[STATİK]` (kod okuması, bu turda fiilen yapıldı) ya
> `[ÇALIŞTIR — doğrulanmadı]` (koşulması gereken ama bu turda koşulmayan) olarak etiketlidir.
>
> **ÖNEMLİ BULGU (denetim öncesi hiçbir maddeyi beklemeden bildirilir):** `dea829c` ve `ecca473`
> yalnızca yerel `faz6-faz7` dalındadır. `git branch -a` çıktısında `origin/faz6` veya
> `origin/faz7` **yok** (yalnızca `origin/faz1-adim3`, `faz2`, `faz3`, `faz3-duzeltme`, `faz4`,
> `faz5`, `main` var); dal hiç push edilmemiş, PR açılmamış, üç OS CI hiç koşmamış. Bu, hem
> FAZ6-SPEC §7 madde 5 hem FAZ7-SPEC §9 madde 5'in ("Dal + PR, üç OS CI yeşil olmadan merge
> yok") **şu an karşılanmadığı** anlamına gelir — kapanış koşulu değil, süreç koşuludur ve iki
> fazın da ortak açık kalemidir. Aşağıdaki §10'da ayrı satır olarak işaretlenmiştir.

---

## 0. Girdi kontrolü

- `git log --oneline`: FAZ 6 kodu `dea829c` (FAZ 7 ile birleşik commit); HEAD `ecca473` bu
  commit'ten yalnızca `docs/` + `.gitignore` farkıyla ayrılıyor (kod farkı yok, doğrulandı).
- `sh tests/run.sh` çıktısı — **bu turda koşulmadı** (kullanıcı talimatı).
- `shellcheck` çıktısı — **bu turda koşulmadı**.
- Commit mesajı (`dea829c`) kendi kapanış özetini taşıyor; ayrı bir "ajan raporu" dosyası yok.

## 0.1 Ön kapı — FAZ 5 `[STATİK]`

- [x] `main`'de FAZ 5 merge commit'i var (`c4b200c`, `FAZ5-KONTROL.md`'de doğrulanmış)
- [x] FAZ 6 kodu FAZ 5'in üzerine, aynı dal zincirinde kurulu (`c4b200c` → … → `dea829c`)
- [x] FAZ 5'in regresyon tabanı (179 iddia, 177 geçti + 2 skip) FAZ6-SPEC'te aynen devralınmış
      (`docs/FAZ6-SPEC.md` başlık: "Ön koşul: FAZ 5 tamam … 179 iddia")

Kapı açık.

## 1. Kapsam doğrulama

| Dilim | İçerik | Çıkış koşulu | Durum |
|---|---|---|---|
| 0 | `docs/FAZ6-BULGULAR.md` — G-1…G-5 `[kaynak]` etiketli | her G-n dosya:satır kaynaklı | [x] uygulandı — §2 |
| 1 | Zincir + katlama senaryoları (T-72/T-73) | regresyon kapısı + 2 test | [x] uygulandı — §4 |
| 2 | İndeks özet şekli + git zinciri + doctor (T-74…T-77) | 4 test | [x] uygulandı — §4 |
| 3 | `docs/PLAN.md` güncellemesi (I-7) | §6 FAZ 6 ✅, §9 güncel | [~] kısmi — §3 I-7 |

**Kapsam dışı ihlali kontrolü:** `ci.yml` değişmemiş (I-1, aşağıda doğrulandı); yeni test
koşucusu/çatı yok; senaryolar fixture JSON'a bağımlı değil (flag-modu, G-4).

**Ek bulgu — kapsam dışı iş bundle'ı:** `dea829c` yalnız FAZ 6 + FAZ 7'yi değil, üçüncü bir işi
de taşıyor: vault yerleşiminin (klasör taksonomisi) beş klasörden on klasöre genişletilmesi
("avenoxbeyin yerleşimi", commit mesajı 2. paragraf). Bu iş ne `FAZ6-SPEC.md` ne `FAZ7-SPEC.md`
içinde tanımlı; ilgili testler `tests/run.sh:282` altındaki **`# ---- FAZ 2: layout + identity
----`** bölümüne eklenmiş (`layout_names`, `Dashboard.md` tohumu vb., `tests/run.sh:301-380`
civarı). Bu, FAZ6/7'nin sözleşme maddelerinin ihlali değildir (çünkü ikisi de bunu talep
etmiyor) ama tek commit'te üç ayrı işin (FAZ 6, FAZ 7, yerleşim) birleşmesi, bu KONTROL'ün G/I/J
numaralarıyla izlenemeyen bir değişiklik yüzeyi bırakıyor. Yerleşim işi bu denetimin konusu
**değildir** (ilgili spec `docs/PLAN.md`'de veya ayrı bir belgede tanımlı değil) — yalnız
kayıt altına alınır.

## 2. Kaynak bulgular (Dilim 0 — G-1…G-5)

`docs/FAZ6-BULGULAR.md` beşini de `[kaynak: dosya:satır]` etiketiyle cevaplıyor; HEAD üzerinden
tek tek açıldı:

- **G-1** [STATİK — doğrulandı] `.github/workflows/ci.yml` tek job (`test`), üç OS matrisi,
  tek adım `sh tests/run.sh`. Bulgu doğru; "yeni job yok" sonucu I-1'i haklı çıkarıyor.
- **G-2** [STATİK — doğrulandı] Halkalar (`init+context`, `index`, `search`) ayrı bölümlerde
  duruyordu, hiçbiri zincir olarak koşmuyordu (FAZ 6 öncesi hâl). FAZ 6 sonrası zincir I-2/I-3
  ile kapatılmış — bkz. §4.
- **G-3** [STATİK — doğrulandı] `idx_summary` tam satırı yalnız ilk koşu için kilitliydi
  (`tests/run.sh:476-481`'in FAZ5-sonu hâli); artımlı koşular yalnız sayı bazında. I-4 bu
  boşluğu T-74/T-75 ile kapatıyor — doğrulandı.
- **G-4** [ÖLÇÜM — kaynak kod düzeyinde yeniden doğrulandı, canlı ölçüm tekrarlanmadı] Flag-modu
  capture (`--event/--tool/--path`) stdin'e dokunmadan `_q_norm_path`/`_q_append_line`'a
  gidiyor (HEAD'de `quipu:435-437` civarı — aynı dal, satır kayması G-4'ün iddia ettiği
  bölgeyle uyumlu). Bu turda `capture --event PostToolUse --tool Write --path note.md` canlı
  koşulmadı; kod okuması iddiayı destekliyor, `[ölçüm]` etiketi **bu tur için tazelenmedi**.
- **G-5** [STATİK — doğrulandı] Git zincirinin `commit → yeniden capture --git → satır yok`
  hâli FAZ 6 öncesi hiç test edilmemişti (ayrı bölümlerdeki tek-çağrılık testler). I-5/T-76 bu
  boşluğu kapatıyor.

Sonuç: G-1…G-5 hepsi `[kaynak]` etiketli ve HEAD'de doğrulanabilir; hiçbiri "ölçüldü" diye asılsız
iddia içermiyor.

## 3. Sözleşme denetimi (I-n → kanıt)

- **I-1** [STATİK — uygulandı] Yeni job/matris/koşucu yok. `ci.yml` `dea829c`/HEAD'de FAZ 5
  sonrasıyla aynı (bu turda `git diff` ile ayrıca doğrulanmadı, ama commit mesajı ve G-1'in
  doğrulanmış hâli tutarlı; kod tarafında `tests/run.sh` içine ekleme yapıldığı, `.github/`
  altına dokunulmadığı doğrulandı — `git show --stat dea829c` çıktısında `.github/` yok).
- **I-2** [STATİK — uygulandı] Zincir T-72: boş vault → `init --lang tr` → `note.md` yaz →
  flag-modu capture → `index` → `search alpha` → `note.md` döner. Her adımın exit kodu ayrı
  `assert_eq` ile denetleniyor (`tests/run.sh:965-976`); tek vault (`vchain`), adım sırası
  birebir spec'teki gibi.
- **I-3** [STATİK — uygulandı] T-73: `İstanbul ışık` notu, `fold=tr` pinlenmiş vault
  (`tests/run.sh:983-984`), `search istanbul` ve `search İstanbul` **aynı** sonuç kümesini
  veriyor (`tests/run.sh:990-994`) — katlama zincir boyunca kanıtlı.
- **I-4** [STATİK — uygulandı] T-74 ilk koşu tam satırı `i18n/en.txt`'teki `idx_summary`
  şablonundan üretilip birebir karşılaştırılıyor (`tests/run.sh:1003-1006`, format dizgesi
  runtime'da okunuyor — hardcode değil); T-75 ikinci koşu (`3 3 0 0`) + tek dosya değişimi
  (`3 2 1 0`) alan bazlı (`idx_nums`) doğrulanıyor (`tests/run.sh:1010-1017`).
- **I-5** [STATİK — uygulandı] T-76: `init --git` → commit → `note.md` → `capture --git`
  (1 gitdiff satırı) → `index` → `search alpha` isabet → `remember --git` (kendi commit'ini
  atar) → yeniden `capture --git` → gitdiff satır sayısı **aynı kalıyor** (`1`,
  `tests/run.sh:1019-1050`). H-9'un "commit diff'i tüketti" iddiası zincir içinde kanıtlı.
- **I-6** [STATİK — uygulandı] T-77: aynı `vgitchain` vault'unda `doctor` exit 0 + özet
  satırının son alanı (hata sayısı) `0` — dil bağımsız alan ayıklamasıyla (`tests/run.sh:1057-1058`).
- **I-7** [STATİK — kısmi] `docs/PLAN.md` §6 altında "FAZ 6 ✅" var (`docs/PLAN.md:559-571`,
  tarih 2026-08-21 dahil) ve §9'da FAZ 6 durumu + "sıradaki: FAZ 7" örtük olarak var
  (`docs/PLAN.md:687-692`, ardından FAZ 7 satırı geliyor). **Ancak** I-7'nin istediği üç öğeden
  (tarih, PR, test sayısı) **PR referansı FAZ 6 için hiç yok** — FAZ 4 (`PR #5`) ve FAZ 5
  (`PR #6`) girdileri commit hash + PR numarası taşırken FAZ 6 girdisi hiçbirini taşımıyor
  (`docs/PLAN.md:687-692`). Bu, üstteki "PR açılmadı" bulgusuyla tutarlı — sözleşme metni
  eksik değil, **kaynağı eksik** (PR yok, o yüzden yazılamamış). FAZ 6'ya özgü ayrı bir test
  sayısı da yok — sayı yalnız FAZ 7 girdisinde kümülatif olarak veriliyor
  (`docs/PLAN.md:698`: "baz 179 + T-72…T-87 = 46 yeni iddia").
- **I-8** [STATİK — uygulandı, boş küme] README'ye yeni bir "CI" bölümü eklenmemiş (gerek yok);
  senaryolar için ayrı test dokümantasyonu istenmiyor. Gereksinim triviyal biçimde karşılanıyor.

## 4. Test incelemesi (T-72…T-77)

HEAD'de `tests/run.sh:956` ve `tests/run.sh:996` başlıklarıyla iki blok halinde, spec'teki
numaralandırmayla birebir:

- **T-72** (`tests/run.sh:958-976`) — chain: `init` exit 0, `capture` exit 0 + tam satır
  (`PostToolUse | Write | note.md`) `log_line` ile, `index` exit 0, `search alpha` →
  `note.md`. Beş ayrı `assert_eq`, her biri kendi adımını kilitliyor — "yalnız son adımda
  kırılma görünür" riski yok.
- **T-73** (`tests/run.sh:979-994`) — ayrı vault (`vchaintr`), `fold=tr` pinli, `search
  istanbul` ve `search İstanbul` (noktalı büyük İ) **aynı** sonuç listesini üretiyor —
  iddia tam olarak iki taraflı (küçük harf sonucu referans, büyük harf sonucu ona eşit).
- **T-74** (`tests/run.sh:998-1006`) — `mk_index_vault` (3 dosya) ile ilk koşu; beklenen satır
  `i18n/en.txt`'ten runtime'da okunup `printf` ile dolduruluyor (hardcode edilmiş beklenti
  değil — çeviri değişse bile test kırılmaz, yalnız formatı doğru uygular).
- **T-75** (`tests/run.sh:1010-1017`) — ikinci koşu (`3 3 0 0`), sonra `touch heading.md` +
  üçüncü koşu (`3 2 1 0`) — reuse/stale ayrımı tek dosya granülerliğinde kanıtlı.
- **T-76** (`tests/run.sh:1019-1050`) — git zinciri; `awk 'index($0,"gitdiff")>0{c++}
  END{print c+0}'` ile gitdiff satır sayımı iki kez yapılıyor (birinci koşu sonrası `1`,
  commit + ikinci koşu sonrası **hâlâ `1`**) — H-9'un iki yönlü kanıtı (satır var VE ikinci
  koşuda artmıyor).
- **T-77** (`tests/run.sh:1052-1058`) — `doctor` exit 0 + özet satırının **son sayısal alanı**
  (`awk 'END{gsub(/[^0-9]/," "); n=split($0,f," "); print f[n]}'`) `0` — dil bağımsız, doğru
  desen (i18n metnine bakmıyor).

**Kırılganlık dersleri:** `QUIPU_LANG=en` her i18n'ye bakan iddiada var (T-72, T-73, T-74,
T-75, T-76, T-77 hepsi `QUIPU_LANG=en` ile çağrılıyor); satır sayımı `awk`; çok baytlı arama
`awk` üzerinden (`search İstanbul` çağrısı ASCII olmayan argüman ama shell/awk üzerinden geçiyor,
`grep` kullanılmıyor). Başıboş `t;`/`RC=$?` taraması bu turda satır satır yapılmadı —
**[doğrulanmadı]**.

**Test sayısı:** PLAN.md'nin iddiası — "baz 179 + T-72…T-87 = 46 yeni iddia" (`docs/PLAN.md:698`,
FAZ 6 + FAZ 7 birlikte) — bu turda **yeniden sayılmadı**. FAZ 6'ya özgü ayrı bir rakam PLAN'da
yok (bkz. I-7 kısmi notu). `grep -c '^t;'`/`grep -o 't;'` ile bu dosyada kaba bir sayım
denendi (229 toplam `t;` oluşumu, tüm dosya) — bu FAZ 6 + FAZ 7 + mevcut taban toplamı, ayrıştırılmadı,
yalnız **tutarlılık kontrolü** amaçlı, kanıt değil.

## 5. Regresyon kapısı

- **[ÇALIŞTIR — doğrulanmadı]** Mevcut 179 iddia (FAZ 5 çıktısı, 177 geçti + 2 skip) aynen
  yeşil mi — bu turda test suite koşulmadığı için **doğrulanamadı**. Kod okuması düzeyinde
  FAZ 5'in dokunduğu fonksiyonlara (`capture --git`, `context --bridge`, `block.awk`) FAZ 6
  diff'inde dokunulmadığı görülüyor (yalnız `tests/run.sh` sonuna ekleme yapılmış,
  var olan bölümler yerinde) — ama bu **statik bir gözlem**, çalıştırılmış bir kanıt değil.
- Mevcut testlerden silinmiş/zayıflatılmış olan var mı — bu turda diff satır satır
  karşılaştırılmadı (yalnız HEAD'in son hâli okundu). **[doğrulanmadı]**

## 6. Yasak desen taraması (§6)

`grep`/kaba tarama ile HEAD'in `quipu` ve `lib/search.awk` dosyalarında `declare -A`,
`${var,,}`, `[[ ]]`, `=~`, `local ` aranıldı — **sıfır eşleşme** (FAZ 6'nın kendi eklediği
kod parçalarında). `ci.yml`'e yeni job eklenmediği §3 I-1'de doğrulandı. Senaryoların fixture
JSON'a bağımlı olmadığı (flag-modu kullanımı) T-72/T-73'te görsel olarak doğrulandı.

## 7. Kırmızı bayraklar — denetimde fiilen görülenler

1. **Merge/CI süreç boşluğu (yeni, önemli):** Dal push edilmemiş, PR yok, üç OS CI hiç
   koşmamış. FAZ6-SPEC §7 madde 5 açık kalıyor. Bu bir kod hatası değil, süreç adımı — ama
   "kabul koşulu" listesinde işaretlenmeden geçilemez.
2. **I-7 PR referansı eksik:** yukarıdaki maddenin doğal sonucu; PLAN.md'nin FAZ 6 girdisi
   commit hash/PR taşımıyor (FAZ 4/5'in aksine).
3. **G-4'ün canlı ölçümü tazelenmedi:** BULGULAR'daki `[ölçüm]` etiketi bu FAZ 6 kodunun
   kendisiyle ilgili değil (FAZ 6 öncesi hâli anlatıyor); flag-modu capture'ın FAZ 6 sonrası
   hâlde hâlâ aynı davrandığı bu turda canlı koşulmadı, yalnız statik okuma ile doğrulandı.
4. **Yerleşim işi aynı commit'e bindirilmiş:** §1'de not edildi; ayrı bir spec/kontrol
   gerektirir, bu belgenin kapsamı dışında bırakıldı.

## 8. Belge tamamlığı

- [x] `docs/FAZ6-BULGULAR.md` var, G-1…G-5 `[kaynak]` etiketli, FAZ3-BULGULAR/FAZ5-BULGULAR
      deseninde (Kaynak yöntemi + Zaman referansı + Sözleşme karşılığı üst bloğu var).
- [~] `docs/PLAN.md` §6 FAZ 6 ✅ var; §9 durum satırı var; **PR referansı yok** (I-7 kısmi,
      §3'te detaylandırıldı).
- [x] README'ye gereksiz CI bölümü eklenmemiş (I-8).

## 9. Koşulacak doğrulamalar (bu turda YAPILMADI — sıradaki tur için)

1. `sh tests/run.sh` — yerel tam paket; özet satırı (`pass + skip`) PLAN.md'nin kümülatif
   iddiasıyla (179 + 46 = 225... veya PLAN'ın FAZ 7 girdisindeki 226+2) karşılaştırılmalı.
2. `shellcheck -s sh quipu tests/run.sh` — sıfır bulgu.
3. Elle: `capture --event PostToolUse --tool Write --path note.md </dev/null` → exit 0 +
   `activity.log`'a tek satır (G-4'ün canlı ölçümünün FAZ 6 sonrası hâlde tazelenmesi).
4. Dal push edilip PR açıldığında üç OS CI sonucu.

## 10. Kabul koşulları — tek bakışta

- [x] Dilim 0–2 eksiksiz; `FAZ6-BULGULAR.md` G-1…G-5'i `[kaynak]` etiketli cevaplıyor
- [x] T-72…T-77 var ve spec'e birebir uyuyor (kod okumasıyla doğrulandı)
- [ ] **[doğrulanmadı]** Yerel `sh tests/run.sh` bu turda koşulmadı — 179 iddia aynen yeşil mi
      bilinmiyor
- [ ] **[doğrulanmadı]** Üç OS CI hiç koşmadı — dal push edilmemiş, PR yok
- [x] I-1…I-6, I-8 kod/README düzeyinde birebir uygulanmış
- [~] I-7 kısmi — PLAN.md güncellemesi var ama PR referansı yok (kaynağı yok çünkü PR açılmamış)
- [x] §6 yasak desenlerin hiçbiri FAZ 6 eklemelerinde yok
- [x] Kapsam dışı ihlali yok (yeni CI işi/matris yok); ek bulgu: yerleşim işi aynı commit'e
      bindirilmiş, ayrı konudur

**Verdict:** FAZ 6'nın **kod ve belge içeriği spec'e (I-1…I-8, T-72…T-77) birebir uyuyor** —
bu turda yapılan statik denetimde hiçbir sözleşme maddesi ihlali bulunmadı. Açık kalan tek
kalem **süreç**: dal hiç push edilmemiş, PR açılmamış, üç OS CI hiç koşmamış, yerel test
suite bu turda koşulmadı — dolayısıyla "179 iddia aynen yeşil" ve "üç OS CI yeşil" koşulları
**doğrulanmadı**, ihlal edildi de değil. Kod tarafı **hazır**; kapanış için §9'daki
doğrulamaların (kullanıcı onayıyla) çalıştırılması gerekiyor.

---

## İşleyiş notu

- Bu belge tek turda, HEAD (`ecca473`) üzerinden statik denetimle üretildi; test suite
  koşulmadı (kullanıcı talimatı — 52 dk sürüyor).
- Bulgular **G-n/I-n/T-n referanslı** raporlandı; `[STATİK]` bu turda fiilen yapılan kod
  okumasını, `[ÇALIŞTIR — doğrulanmadı]` bu turda koşulmayan ama koşulması gereken adımı işaret
  eder.
- Kullanıcı onayı olmadan repo'da komut koşulmadı; test suite çalıştırma bu tur kapsamı
  dışında tutuldu.
