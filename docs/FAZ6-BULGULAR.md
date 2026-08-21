# FAZ 6 — Bulgular (Dilim 0)

**Kaynak yöntemi:** Bu fazın bulguları **repo içi kod okuması + bu makinede canlı komut
koşumu** kaynaklıdır; her biri kesin `dosya:satır` referansı taşır. İddia etiketi
`[kaynak: …]` = repo'da doğrulanabilir; `[ölçüm]` = geçici vault'ta fiilen koşulup
gözlenen davranış. Bu faz yeni çekirdek kod üretmediği için "davranış boşluğu" değil
**kanıt boşluğu** aranmıştır: hangi davranış doğru çalışıyor ama hiçbir testin altında
değil.

**Zaman referansı:** Bulgular FAZ 6 senaryoları yazılmadan **önceki** tabanı betimler
(179 iddia = 177 geçti + 2 skip; `tests/run.sh` o an 955 satır). Satır referansları bu
tabanın senaryo eklemeleriyle kaymayan bölgelerine (`tests/run.sh` ≤ 940) verilmiştir.

**Sözleşme karşılığı:** Bu dosya `FAZ6-SPEC` §1'deki G-1…G-5'i resmileştirir. Sayılar
G-1…G-5; `FAZ5-BULGULAR`'ın F-n'leri, `FAZ4-SPEC`'in A-n'leri, `FAZ3-BULGULAR`'ın
Ö-n/E-n'leriyle çakışmaz.

---

## G-1 — CI zaten üç OS'ta tek iş + tek kapı; eklenecek olan job değil, senaryo

`[kaynak: .github/workflows/ci.yml:3-9, .github/workflows/ci.yml:22-23, tests/run.sh:135-149]`

`ci.yml` altında **tek bir job** var (`test`, satır 4) ve matrisi zaten üç platformu
kapsıyor: `os: [ubuntu-latest, macos-latest, windows-latest]` (satır 8), `runs-on:
${{ matrix.os }}` (satır 9). Bu job'ın tek doğrulama adımı `Run tests` → `sh tests/run.sh`
(satır 22-23); shellcheck bile ayrı bir job değil, önce kurulur (satır 15-21) sonra
`tests/run.sh` içinden iddia olarak koşulur (`tests/run.sh:135-149`). Yani platform
kapsaması ile senaryo kapsaması **aynı tek kapıdan** geçiyor: `tests/run.sh`'e eklenen her
iddia üç OS'ta bedelsiz koşar.

**Sonuç:** FAZ 6 yeni job, yeni matris veya yeni koşucu eklemez — kapsam genişletmenin tek
doğru yeri `tests/run.sh`'in kendisidir (I-1); `ci.yml` bu fazda değişmez.

## G-2 — Zincirin halkaları ayrı bölümlerde testleniyor, zincir olarak hiç koşulmuyor

`[kaynak: tests/run.sh:246, tests/run.sh:410, tests/run.sh:489, tests/run.sh:412-433, tests/run.sh:491-506]`

Üç halka üç ayrı bölümde duruyor: `# ---- init + context ----` (satır 246),
`# ---- index ----` (satır 410), `# ---- search ----` (satır 489). Bölümler birbirinin
çıktısını **girdi olarak almıyor**: `mk_index_vault` vault'u elle kuruyor (`mkdir` +
heredoc'lar, satır 412-433) ve `mk_search_vault` de aynı şekilde (satır 491-503) —
ikisi de `quipu init` çağırmaz. Search bölümü zincirin yalnız bir eklemini kurar
(`quipu index`, satır 506), `capture` ise index/search yollarının hiçbirinde yer almaz;
simetrik olarak init bölümü de kendi vault'unda `index`/`search` koşmaz (satır 248-281).

**Sonuç:** `init → capture → index → search` tek vault'ta uçtan uca hiç koşulmadı; halkalar
tek tek yeşil olduğu hâlde zincir kanıtsız — I-2 (tek testte tek vault, adım sırası birebir)
ve I-3 (aynı zincirin Türkçe/katlamalı formu) tam olarak bu boşluğu kapatır.

## G-3 — `index` özet satırının şekli yalnız ilk koşu için kilitli; artımlı koşularda sadece sayılar

`[kaynak: quipu:971-974, tests/run.sh:476-481, tests/run.sh:435-437, tests/run.sh:445-455]`

Özet satırı i18n şablonundan dört sayıyla üretilir: `_q_fmt=$(_q_msg idx_summary)`
(`quipu:971`), ardından `printf "$_q_fmt" "$N" "$R" "$S" "$D"` (`quipu:973`) ve ayrı bir
`printf '\n'` (`quipu:974`). **Tam satır şekli tek bir yerde** kilitli: `idxlang` testi
`QUIPU_LANG=en` altında `i18n/en.txt`'ten `idx_summary` şablonunu okuyup `3 0 3 0` ile
doldurur ve çıktıyla karşılaştırır (`tests/run.sh:476-481`) — yani yalnız **ilk koşu**
(reuse 0, stale N, drop 0). Artımlı koşular ise `idx_nums` üzerinden ölçülür; bu yardımcı
rakam olmayan her baytı boşluğa çevirir (`tests/run.sh:435-437`), dolayısıyla iddialar
`'3 0 3 0'` (445), `'3 2 1 0'` (450), `'2 2 0 1'` (455), `'3 0 3 0'` (463) ve `'0 0 0 0'`
(487) — **etiket, sıra ve dizgi şekli değil, yalnız sayı dizisi**.

**Sonuç:** reuse/stale/drop *davranışı* sayı düzeyinde kanıtlı ama artımlı koşuların *satır
şekli* kilitli değil; T-74/T-75 ikinci koşu ile tek-dosya-değişimi senaryolarının tam
satırını `QUIPU_LANG=en` altında sabitler (I-4).

## G-4 — Capture flag-modu stdin fixture'ı olmadan satır üretir → senaryolar hermetic olabilir

`[kaynak: quipu:374-376, quipu:386-391, quipu:435-437]` `[ölçüm]`

`capture`'ın argüman döngüsünde `--event`, `--tool` ve `--path` dalları `_q_flag=1` kurar ve
her biri zorunlu argümanını `[ "$#" -ge 2 ] || _q_die err_missing_arg 2` ile denetler
(`quipu:374-376`); üçünün de dolu olması ayrıca, herhangi bir alt kabuk `_q_p`'yi yeniden
kullanmadan önce kontrol edilir (`quipu:386-391`). Flag modu doğruysa akış stdin'i okuyan
`jsonfield.awk`/`capture.awk` boru hattına **hiç girmez**: `_q_flag -eq 1` dalı doğrudan
`_q_norm_path` + `_q_append_line` çağırır (`quipu:435-437`). Canlı ölçüm bunu doğruladı:
kapalı stdin (`</dev/null`) ile `capture --event PostToolUse --tool Write --path note.md`
exit 0 verip `activity.log`'a tam bir satır yazdı — `2026-08-21T11:37 | PostToolUse |
Write | note.md`, dosyada tek satır `[ölçüm]`.

**Sonuç:** zincir senaryolarında hook payload'ı taklit eden JSON fixture'a gerek yok;
senaryolar tamamen kendi kurduğu vault içinde, dış dosyaya bağımlı olmadan koşabilir —
bu yüzden "senaryoda fixture JSON'a bağımlılık" SPEC §6'da yasak desen sayılmıştır.

## G-5 — Git'li e2e zinciri hiç kurulmamış: `commit → yeniden capture --git → satır yok` kanıtsız

`[kaynak: tests/run.sh:807, tests/run.sh:814-818, tests/run.sh:820-902, tests/run.sh:873-879, tests/run.sh:712-718]`

`# ---- FAZ 5: capture --git (T-57..T-64, T-69, T-70) … ----` bölümündeki (satır 807) her
test kendi taze vault'unu `mk_git_vault` ile kurar (satır 814-818) ve **tek bir**
`capture --git` koşar — T-57 (826), T-58, T-59 (844), T-60 (853), T-61 (863), T-62 (871),
T-63 (879), T-64 (887), T-69 (895), T-70 (901). Aynı vault'ta ikinci bir çağrı yok; en
yakın komşu T-63 "temiz ağaç → sessiz exit 0" (satır 873-879), ama oradaki vault'ta daha
önce hiç `capture --git` koşmamıştır — yani "diff'i commit tüketti, o yüzden ikinci koşu
sessiz" iddiasını taşımaz. Tek "iki kez koş" deseni ayrı bir bölümdeki `remember --git`
testinde var (satır 712-718: birinci koşu commit atar — satır 715, ikinci koşu boş olduğu
için atlar — satır 716, `git log` sayısı 1'de kalır) ve bu test `capture`/`activity.log`
ile hiç ilişkilendirilmez.

**Sonuç:** H-9'un dürüst davranışı — `capture --git` satır yazar → `git commit` diff'i
tüketir → yeniden `capture --git` **yeni satır eklemez** — zincir içinde hiç
doğrulanmamıştır; I-5/T-76 bunu activity.log satır sayımının eşit kalmasıyla kanıtlar.

---

## Tasarım etkileri (G → I eşlemesi)

| Bulgu | Sözleşme maddesi | Ne gerektiriyor |
|---|---|---|
| G-1 | I-1 | Yeni job/matris/koşucu yok; senaryolar `tests/run.sh` içine, `ci.yml` değişmez |
| G-2 | I-2, I-3 | Tek vault + tek testte `init → capture → index → search`; Türkçe katlamalı formu |
| G-3 | I-4 | Artımlı index özetlerinin tam satırı `QUIPU_LANG=en` ile kilitlenir (sayı + şekil) |
| G-4 | I-2 | Senaryolar flag-modu capture kullanır; JSON fixture bağımlılığı yok (hermetic) |
| G-5 | I-5, I-6 | Git zinciri: capture → commit → yeniden capture (yeni satır yok) + zincir vault'unda doctor |

## Test malzemesi (Dilim 1/2 için)

Zincir senaryoları mevcut çatıyı aynen kullanır: `mkvault`/`mk_git_vault` + `git_commit`
(`tests/run.sh:181, 809-818`), satır sayımı `awk 'END{print NR}'`, log kuyruğu `log_line`
(`tests/run.sh:182`), özet sayıları `idx_nums` (`tests/run.sh:435-437`), i18n değeri `i18n`
(`tests/run.sh:635`). Yeni yardımcı gerekmez; fixture dosyası gerekmez (G-4). i18n metnine
bakan iddialarda `QUIPU_LANG=en`, Türkçe katlama isteyen zincirde config'e `fold=tr`
sabitlemesi zorunludur — katlama profili zinciri config `fold=` → `lang=tr` → `default`
sırasıyla çözüldüğü için `QUIPU_LANG=en` altında profil aksi hâlde `default`'a düşer.
