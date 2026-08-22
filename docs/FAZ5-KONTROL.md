# quipu — FAZ 5 çıktı kontrol listesi

> **Bu dosya ne?** FAZ 5'i uygulayan kod ajanının çıktısını incelemek için gözden geçirme
> protokolü. Çıktı (PR/diff + test raporu + ajan raporu) geldiğinde bu liste sırasıyla işlenir;
> bulgular F-n/H-n/T-n/DZ-n referansıyla raporlanır.
> Kaynaklar: `docs/FAZ5-SPEC.md` (H-1…H-20, T-57…T-68), `docs/FAZ5-DUZELTME.md` (DZ-1…DZ-12,
> T-69…T-71), `docs/FAZ5-BULGULAR.md` (F-1…F-5), `docs/PLAN.md` §4 (yasak desen dersleri),
> `docs/FAZ4-KONTROL.md` (protokol deseni).
>
> **ÇALIŞAN FAZ 5 AJANINA NOT:** Bu dosya gözden geçirme protokolüdür, **spec değişikliği
> DEĞİLDİR**. Bağlayıcı sözleşme: `FAZ5-SPEC.md` + `FAZ5-DUZELTME.md`. Yeni gereksinim yok; bu
> listeyi "karşılamak" için ek iş üretme.
>
> **Tarih:** 2026-08-21 · **Durum:** **TAMAM** — FAZ 4 merged (PR #5, `eb045dc`) + FAZ 5 merged
> (PR #6, `c4b200c`). Yerel doğrulama: `# pass 177, fail 0, skip 2`, shellcheck sessiz,
> üç OS CI yeşil; `capture --git` / `context --bridge` canlı smoke testlerden geçti.
>
> Her madde `[STATİK]` (kod/dosya okuma) veya `[ÇALIŞTIR]` (repo'da komut — yalnızca kullanıcı
> onayıyla) işaretlidir. Hook'suz ajan davranışı `[doğrulanmadı]` — bu makinede canlı ölçüm yok.

---

## 0. Girdi kontrolü

- Ajanın değiştirdiği dosya listesi + diff (veya dal/PR adresi)
- `sh tests/run.sh` çıktısı (yerel + üç OS CI) — **özet satırı birebir** (`# pass N, fail 0, skip S`)
- `shellcheck -s sh quipu tests/run.sh` çıktısı
- Ajanın kendi kapanış raporu (hangi dilimler, hangi H-n/DZ-n karşılandı iddiası)

## 0.1 Ön kapı — FAZ 4 (DZ-1) `[STATİK]`

**Bu kapı açılmadan aşağıdaki hiçbir madde işlenmez.** Üçü birden doğrulanır:

- [x] `main`'de FAZ 4 merge commit'i var (`eb045dc`)
- [x] `adapters/codex/hooks.json` mevcut
- [x] `lib/capture.awk` `apply_patch` dalını içeriyor
- [x] K-8'in çok-satırlı loop'u **çağrılabilir fonksiyon** olarak çıkarılmış — `_q_norm_path` /
      `_q_rotate_log` / `_q_append_line` (`quipu:309,330,343`); `capture --git` bunları çağırıyor,
      kopyalamıyor (`quipu:380-408`)

**Kapı kapalıyken gelen çıktı reddedilir**, çünkü H-5/H-6 karşılanamaz ve implementer ya olmayan
yardımcıyı çağırmış ya da §8'de yasak ikinci kopyayı yazmıştır.

## 1. Kapsam doğrulama

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| 0 | `docs/FAZ5-BULGULAR.md` — F-1…F-5, `[kaynak]`/`[doğrulanmadı]` etiketli | "ölçüldü" iddiası YOK; **DZ-11 satır düzeltmeleri işlenmiş** |
| 1 | `capture --git` (§2) + `_q_md_filter` (DZ-3) + `block.awk` genelleştirmesi (H-12/DZ-5) + testler | taban iddia regresyonsuz + T-57…T-64, T-69, T-70, T-71 |
| 2 | `context --bridge` (§3) + `_q_ctx_text` (DZ-7) + testler | T-65…T-68 |
| 3 | README "hook'suz ajanlar" (DZ-10a), PLAN §2/§6/§7/§9 (DZ-10b) | §10 dürüstçe belgelenmiş |

**Kapsam dışı ihlali kontrolü:** `quipu install` yok; git-diff'ten araç-tür çıkarımı
(added/modified/deleted granularlığı) yok; durumlu capture / çoğaltma filigranı yok; yeni ajan
adaptörü yok; MCP yok. Bilinmeyen bayrağın `err_missing_arg` kullanması **düzeltilmemiş olmalı**
(DZ-4 kapsam dışı bıraktı — "iyileştirme" diye düzeltilmişse kapsam sızmasıdır).

## 2. Kaynak bulgular (Dilim 0 — F-1…F-5)

`FAZ5-BULGULAR.md` şu beşi etiketli cevaplamalı **ve** DZ-11'in düzeltmelerini taşımalı:

- **F-1** AGENTS.md köprüsü `init` ile statik kurulur (`quipu:485-508`, `i18n/en.txt:74-77`).
- **F-2** `lib/block.awk` işaretçi çiftini hardcode eder (**`:13-14`**, `:12` değil).
- **F-3** `context` bağlamı yalnız hook zarfıyla çıkar (`quipu:540-662`; activity **`:559-571`**).
- **F-4** `capture` hook payload'ına bağımlıdır (`quipu:290-363`).
- **F-5** `remember --git` deseni (**`quipu:753-761`**, `:759-767` değil) — lafız "koşullu atlama
  + örtük başarı", "guard + exit 0" değil.

`[STATİK]` Her `dosya:satır` referansı **tek tek açılıp** doğrulanır. FAZ 4 çekirdeği değiştirdiği
için Dilim 0 sonrası referanslar yeniden kaymış olabilir; kaymış referans = bulgu.

## 3. Sözleşme denetimi (H-n → kanıt)

### capture --git (H-1…H-9, DZ-2, DZ-3, DZ-4)

- **H-1** [STATİK] `--git` bağımsız mod; `--event/--tool/--path` ile birleşince hata. `_q_flag=1`
  kullanılmamalı — kullanıldıysa `quipu:310-313` üç değeri birden zorunlu kılar ve `--git` tek
  başına ölür. Hata anahtarı **`err_conflict`**, exit **2** (DZ-4).
- **H-2** [STATİK] `git rev-parse --git-dir` alt-kabukta, `>/dev/null 2>&1` ile; başarısızsa
  sessiz exit 0. `cd "$_q_v"` alt-kabuk dışına **çıkmamış** olmalı.
- **H-3 + DZ-2** [STATİK+ÇALIŞTIR] `git rev-parse --verify --quiet HEAD` guard'ı **var mı**?
  Yoksa unborn HEAD'de `set -eu` (`quipu:10`) betiği 128 ile öldürür ve H-7/H-8 birlikte kırılır.
  T-69 bunun canlı kanıtıdır.
- **H-4 + DZ-3** [STATİK] `_q_md_filter` çıkarılmış mı; `_q_mdlist` **de** onu çağrıyor mu (tek
  kaynak)? İkinci bir dışlama mantığı yazıldıysa ihlal. Önek testleri `index($0, "…") == 1` ile —
  `.quipu/`, `.git/`, `node_modules/`; `.md` sonek testi `substr` ile; **regex yok**.
- **H-5** [STATİK] Satır biçimi `gitdiff | git | <vault-relative yol>`; çok dosya → çok satır;
  FAZ 4'ün loop'u **çağrılıyor**, kopyalanmıyor.
- **H-6** [STATİK] cygpath normalizasyonu + vault-relative şerit + temizlik + rotasyon tek
  kaynaktan. **Rotasyon döngüden ÖNCE bir kez** (K-8) — döngü içindeyse çok satırlı çıktıda log
  `.1`'e kayar, veri kaybı.
- **H-7** [ÇALIŞTIR] `capture --git` **tüm yollarda stdout'a 0 bayt**. Sızma adayları: `git
  rev-parse` stderr, `git diff` unborn HEAD `fatal:`, `cd` çıktısı. Hepsi susturulmuş olmalı.
- **H-8** [ÇALIŞTIR] Temiz ağaç → exit 0, satır yok.
- **H-9** [DOKÜMAN] Dürüst sınırlar README'de: READ yakalanmaz; silme yakalanır; commit'siz iki
  koşu çoğaltır.

### context --bridge (H-10…H-17, DZ-5, DZ-6, DZ-7)

- **H-10** [STATİK] `--bridge` bare-flag olarak `context` döngüsüne eklenmiş (`init`'in
  `--plain`/`--git` kalıbı, `quipu:375-376`); stdout'a **yalnız onay**.
- **H-11** [STATİK] İşaretçiler `<!-- quipu:context:start/end -->`; statik `quipu:start` bloğuna
  dokunulmamış. block.awk tam-satır eşitliği kullandığı için (`lib/block.awk:34,38`) iki blok yan
  yana güvenli — **ama** DZ-5 uygulanmadıysa `-v` ezilir ve statik blok hedeflenir.
- **H-12 + DZ-5** [STATİK] `BEGIN`'de `if (start == "") …` koşullu varsayılan var mı? Koşulsuz
  atama kalmışsa `-v` işlevsizdir = ihlal. Emsal: `lib/index.awk:26`.
- **H-13 + DZ-6** [STATİK] Blok yoksa dosya sonuna eklenir, varsa yerinde değişir; kullanıcı
  içeriği ikisinde de korunur.
- **H-14 + DZ-7** [STATİK] `_q_ctx_text` **global ayarlayıcı** (`_q_text` kurar, stdout'a yazmaz).
  `$(...)` ile yakalanmışsa **son satır sonu sökülür** = ihlal. Nudge (`quipu:620-652`) helper'ın
  **dışında**; `--bridge` çıktısında nudge metni görünüyorsa ihlal. Bağlam üretiminin ikinci
  kopyası yok.
- **H-15 + DZ-4** [STATİK] `--bridge` + `--json` → `err_conflict`, exit 2.
- **H-16** [STATİK] Vault yoksa `err_no_vault` (`quipu:552-555` guard'ının altına düşüyor mu).
- **H-17** [STATİK] CLAUDE.md diff'te **değişmemiş**.

### i18n (H-18, DZ-4)

- **H-18** [STATİK] **İki** yeni anahtar: `bridge_updated` + `err_conflict`; tr + en, aynı
  `key=value` biçimi, `# bridge` bölümünde `bridge_claude`'dan sonra (`i18n/{tr,en}.txt:74-78`).
  Başka i18n değişikliği yok. `bridge_updated` değerinde `%s` varsa `printf` deseni doğru mu.

### Doküman (H-19, H-20, DZ-10)

- **H-19** [DOKÜMAN] README "hook'suz ajanlar" bölümü `## Claude Code` ile `## Status` arasında;
  `README.md:29` ("one line") ve `:32` (`--bridge` yok) düzeltilmiş; `:121-122` Status tazelenmiş;
  dürüst sınırlar `## Honest limits` ile **çift yazılmamış**, bağlanmış.
- **H-20** [DOKÜMAN] PLAN §6 FAZ 5 ✅; §7 risk tablosuna (`PLAN.md:560-561`, iki kolon
  `| Risk | Not |`) git-diff satırı; §9 durum + sıradaki FAZ 6; **§2'ye köprü sapması cümlesi**
  (dinamik bağlam ayrı blokta — DZ-10b).
- **DZ-10c** [DOKÜMAN] §10'da `install` gerekçesi **C-26**; `(PLAN §3)` atfı yalnız MCP'de.

## 4. Test incelemesi (T-57…T-71)

Her test için iki soru: (a) var mı, (b) doğru şeyi mi sınıyor — yanlış negatif üretemeyecek kadar
güçlü mü.

**capture --git:**

- **T-57** 1 değişmiş `.md` → tek `gitdiff | git | <yol>` satırı
- **T-58** çok dosyalı diff → dosya başına bir satır, **sayı birebir** (deyim: `awk 'END{print NR}'`
  veya `grep -c`, `tests/run.sh:204,223,239,333,422,489`)
- **T-59** untracked yeni `.md` → yakalanır
- **T-60** `.md` olmayan değişim → satır YOK
- **T-61** `AGENTS.md`/`CLAUDE.md`/`.quipu/` → satır YOK
- **T-62 + DZ-8b** yalnız **"repo değil"** → exit 0, satır yok, stdout boş. "git yok" dalı
  PATH manipülasyonuyla test edilmeye çalışılmışsa (flaky) = ihlal; `[doğrulanmadı]` kalmalı
- **T-63** temiz ağaç → exit 0, satır yok
- **T-64** silinen `.md` → kaydedilir
- **T-69 (DZ-2)** commit'siz repo + untracked `.md` → exit 0, stdout boş, satır **var**
- **T-70 (DZ-3)** `.quipu/` altındaki `.md` → satır YOK (bugünkü kriterin kapsamadığı vaka)

**context --bridge:**

- **T-65** `quipu:context:start/end` bloğu + içinde bağlam; blok dışı kullanıcı içeriği birebir
  korunmuş (deyim: `grep -q '^satır$'`, `tests/run.sh:238,332`)
- **T-66** ikinci koşu çoğaltmaz (`grep -c 'quipu:context:start'` = 1)
- **T-67** stdout'ta yalnız onay — **`QUIPU_LANG=en` izolasyonu ZORUNLU** (aşağı bak)
- **T-68** block.awk genelleştirmesi geriye uyumlu; kilitleyen mevcut testler
  `tests/run.sh:238,240,259,260,326,332,333,656-657`
- **T-71 (DZ-5)** `-v` verilmeden varsayılan işaretçilerin **tam metni** korunur (T-68'in
  kapatmadığı literal kilidi)

**Test kurulumu (DZ-8a):** `mktemp -d` / `git -c user.email` **beklenmez** — gerçek kalıp
`TMP=${TMPDIR:-/tmp}/quipu-tests-$$` (`:21-22`) + `git init -q "$TMP/…"` (`:693`) +
`GIT_AUTHOR_*`/`GIT_COMMITTER_*` env kimliği (`:694-695`). T-69 hariç tüm git testleri kurulumda
**commit** atmalı.

**Kırılganlık dersleri:**

- **T-67 tek i18n'ye bakan iddiadır** → `QUIPU_LANG=en` + `i18n bridge_updated` yardımcısı
  (`tests/run.sh:614`) ile yazılmalı; yoksa locale'e bağlı flaky.
- Çok baytlı `awk index()`; ASCII `grep` serbest.
- `RC=$?` alınıp kullanılmayan satır yok; **yeni başıboş `t;` eklenmemiş** (mevcut ikisi `:227`,
  `:241` — DZ-12, bu fazın kapsamı değil, **artmamış** olmalı).
- Yeni fixture yok (git durumu test içinde kurulur); varsa maskeli (gerçek yol/session_id yok).

## 5. Regresyon kapısı

- **Taban sayı FAZ 4 merge sonrası YENİDEN ÖLÇÜLÜR.** Bugünkü (FAZ 4 öncesi) ölçüm:
  `# pass 154, fail 0, skip 2` = **156 iddia** (2026-08-20, bu makine). FAZ 4'ün kendi testleri
  eklendikten sonraki sayı, FAZ 5 kapısının tabanıdır.
- Sayı **`pass + skip`** üzerinden okunur, test numaralayıcısı (`NUM`) üzerinden **değil** —
  `NUM` iki başıboş `t;` yüzünden 2 fazla sayar (DZ-9/DZ-12).
- `FAZ4-KONTROL.md:124`'teki "157"/"164" değerleri **yanlıştır**, kapıya yazılmaz.
- Değişmemiş olması gerekenler: `capture` stdin/flag modu, `context` bare/`--json`, `init`,
  `index`, `search`, `remember`, `doctor`. Mevcut testlerden **silinmiş/zayıflatılmış** olan var mı
  — diff'te tek tek bak (özellikle `_q_mdlist` DZ-3 ile sadeleşirken).

## 6. Yasak desen taraması (§8)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) · ham
kullanıcı verisi `awk -v` (§4.16) · çok baytlı `sed` sınıfı (§4.1) · çok baytlı `grep` kalıbı
(§4.17) · tırnaksız yol değişkeni · `conhost`/`cmd` (§4.13) · hook `command`'ında doğrudan `.sh`
(§4.14) · **git çıktısını `-v` ile geçirmek** · **block.awk'ta yeni işaretçiyi hardcode eden ikinci
kopya** · **bağlam üretiminin ikinci kopyası** · **`.md` filtresinin ikinci kopyası** (DZ-3).

Git çıktısı işleme deseni: `while IFS= read -r` (emsal `quipu:442,457,814`) veya `printf '%s' … |
awk -f …` (emsal `quipu:658,702`). Sabit literal `-v` (işaretçiler) serbesttir — `PLAN.md:335`.

## 7. Kırmızı bayraklar — en olası hata noktaları

Bu liste tahmin değil; uygulama öncesi denetimde **fiilen tespit edilen** kırılma noktalarıdır.

1. **Unborn HEAD abort** (DZ-2): guard'sız `git diff --name-only HEAD` → exit 128 → `set -eu` →
   betik ölür, stderr sızar. H-7/H-8 birlikte gider. **T-69 ile kilitli olmalı.**
2. **`_q_flag=1` tuzağı** (H-1): `--git` bu bayrağı kullanırsa `quipu:310-313` üç argümanı birden
   zorunlu kılar; `capture --git` tek başına ölür.
3. **`.quipu/` filtresini `_q_mdlist`'e güvenerek atlamak** (DZ-3): awk süzgeci yalnız tam
   eşleşmeyle `AGENTS.md`/`CLAUDE.md` atıyor; `.quipu/foo.md` **geçer**. Önek testi ayrı yazılmalı.
4. **block.awk `-v` ezilmesi** (DZ-5): `BEGIN` koşulsuz atarsa `--bridge` sessizce **statik bloğu**
   hedefler — H-11'in tam tersi, üstelik testler `quipu:start` alt-dizisini grep'lediği için
   yanlış-yeşil verebilir.
5. **`$(_q_ctx_text)` ile son satır sonu kaybı** (DZ-7): AGENTS.md'de bozuk/gömülü blok.
6. **Nudge sızması** (DZ-7): `quipu:620-652` helper'a alınırsa `--bridge` çıktısına
   UserPromptSubmit nudge'ı girer.
7. **Rotasyon döngü içinde** (H-6/K-8): çok satırlı çıktıda log `.1`'e kayar, veri kaybı.
8. **stdout sessizliği** (H-7): çok satırlı dalda tek bayt sızması async hook'ta modele
   "system-reminder" olarak girer.
9. **Bayat sayı** (DZ-9): kapıya 156/157/164'ten birini ezbere yazmak. FAZ 4 sonrası **yeniden
   ölçülür**.
10. **`err_missing_arg` ile yetinmek** (DZ-4): çakışmada "zorunlu argüman eksik" basmak — yanlış
    tanı. `err_conflict` yoksa ihlal.
11. **F-n satır referanslarını güncellememek** (DZ-11): Dilim 0 düzeltilmeden Dilim 1'e geçilirse
    BULGULAR "kesin referans" iddiasını kaybeder.
12. **PLAN §2 sapmasını yazmamak** (DZ-10b): diyagram dinamik bağlamı hâlâ `quipu:start` içinde
    gösteriyorsa belge kod ile çelişir.

## 8. Belge tamamlığı

- [ ] README: "hook'suz ajanlar" bölümü + `:29`/`:32`/`:121-122` düzeltmeleri + dürüst sınır bağı
- [ ] PLAN: §2 sapma cümlesi, §6 FAZ 5 ✅, §7 risk satırı, §9 durum + sıradaki FAZ 6
- [ ] `FAZ5-BULGULAR.md`: DZ-11 referans düzeltmeleri + F-5 lafız düzeltmesi
- [ ] `install` gerekçesi C-26 (DZ-10c)

## 9. Koşulacak doğrulamalar (çıktı geldiğinde, kullanıcı onayıyla)

1. `sh tests/run.sh` — özet satırı raporla karşılaştırılır (`pass + skip`).
2. `./.claude/tools/shellcheck.exe -s sh quipu tests/run.sh` — sıfır bulgu.
3. Elle: geçici repo'da `capture --git` (temiz ağaç / tek dosya / çok dosya / silme / unborn HEAD)
   → `activity.log` satırları birebir + **stdout boş**.
4. Elle: `context --bridge` iki kez → AGENTS.md'de tek blok, kullanıcı içeriği korunmuş, statik
   `quipu:start` bloğu **değişmemiş**, stdout'ta yalnız onay.
5. Elle: `capture` stdin/flag modu ve `context` bare/`--json` regresyonsuz.
6. Üç OS CI (PR üzerinde).

## 10. Kabul koşulları — tek bakışta

- [x] **0.1 ön kapısı açık** (FAZ 4 merged + K-8 loop'u fonksiyon)
- [x] Dilim 0–3 eksiksiz; F-1…F-5 etiketli + DZ-11 düzeltmeli
- [x] T-57…T-71 var ve güçlü; taban sayı FAZ 4 sonrası ölçülmüş; üç OS yeşil; shellcheck sessiz
- [x] H-1…H-20 birebir; DZ-1…DZ-11 işlenmiş
- [x] Regresyon kapısı: taban iddia aynen yeşil, hiçbir test zayıflatılmamış
- [x] §6 yasak desenlerin hiçbiri yok; `.md` filtresi/bağlam üretimi/işaretçi tek kaynak
- [x] §7'nin 12 kırmızı bayrağı temiz
- [x] Belgeler tam; hook'suz ajan davranışı `[doğrulanmadı]` olarak dürüstçe açık

---

## İşleyiş notu

- Çıktı geldiğinde bu dosya sırayla işlenir; bulgular **F-n/H-n/T-n/DZ-n referanslı** raporlanır.
- İnceleme ilerledikçe dosya yerinde güncellenir (işaretleme/notlar), yeniden oluşturulmaz.
- Kullanıcı onayı olmadan repo'da komut koşulmaz.
