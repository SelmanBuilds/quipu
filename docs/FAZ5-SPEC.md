# quipu — FAZ 5 SPEC: hook'suz fallback (git-diff capture + AGENTS.md köprü enjeksiyonu)

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: `docs/PLAN.md` §2 (evrensel köprü), §5 (ajan yüzeyleri), §6 FAZ 5, §9 (durum).
> Ön koşul: FAZ 3 tamam (PR #3 merged) + **FAZ 4 tamam** (capture çok-şemalı + çok-satırlı
> loop). Bulgular: `docs/FAZ5-BULGULAR.md` (F-1…F-5).
> Numara önekleri: **F-n** (bulgu), **H-n** (sözleşme), **T-n** (test). A/B/C/D/K/AM/Ö/E ile çakışmaz.
>
> **Bu faz çekirdeği bilinçli değiştirir** (FAZ 4'teki gibi): `capture`'a `--git` modu,
> `context`'e `--bridge` hedefi, `lib/block.awk`'a işaretçi parametresi. Hook'lu ajanlar
> (FAZ 3 Claude, FAZ 4 Codex) regresyonsuz kalır — regresyon kapısı §9.2.

## 0. Bu fazın tek cümlelik ölçütü

> **Hook desteklemeyen ajanlar için iki düşüş yolu: (1) `quipu capture --git` çalışma
> ağacını son commit'e karşı çıkarır; (2) `quipu context --bridge` son-oturum bağlamını
> AGENTS.md'nin etiketli bloğuna yazar.**

FAZ 3/4'ün "adaptör config-only" ilkesi hook'lu ajanlar içindi. Hook'u olmayan (veya hook
kurulamayan) ajanlarda hem yakalama hem bağlam enjeksiyonu tamamen düşer. Bu faz, o boşluğu
**çekirdekte** kapatır — config dosyasıyla değil.

## 1. Bulgular (F-1…F-5)

`docs/FAZ5-BULGULAR.md`'de resmileşti; özet:

- **F-1** AGENTS.md köprüsü `init` ile **statik** kurulur (`quipu:485-508`) — "son oturum" değil.
- **F-2** `lib/block.awk` tek işaretçi çiftini hardcode eder (`lib/block.awk:12-13`).
- **F-3** `context` bağlamı yalnız hook zarfıyla dışarı çıkar (`quipu:540-662`); hook'suz yol yok.
- **F-4** `capture` hook payload'ına bağımlıdır (`quipu:290-363`); git-diff READ çıkaramaz.
- **F-5** `remember --git` "git yok / repo değil → sessiz exit 0" desenini kurdu (`quipu:759-767`).

## 2. `quipu capture --git` (H-1…H-9)

- **H-1** `--git` **bağımsız bir mod**; `--event`/`--tool`/`--path` ile birleşince hata
  (`err_missing_arg`), sessizce yok sayma değil.
- **H-2** Vault'a `cd`; `git rev-parse --git-dir` başarısızsa **sessiz exit 0** (git yok veya
  repo değil — F-5 deseni).
- **H-3** Değişenler iki kaynaktan, yeni-satır ayrımlı (vault zaten yeni-satır varsayıyor):
  `git diff --name-only HEAD` (tracked M/D) + `git ls-files --others --exclude-standard`
  (untracked A, `.gitignore`'a saygılı).
- **H-4** Filtre: yalnız `*.md`; `.quipu/`, `AGENTS.md`, `CLAUDE.md` hariç — `_q_mdlist`
  dışlamasıyla **aynı kriter** (`quipu:120-130`), ikinci bir dışlama mantığı yazılmaz.
- **H-5** Her dosya → `gitdiff | git | <vault-relative yol>` satırı. Çok satır üretilir;
  FAZ 4'ün çok-satırlı loop'u **paylaşılır** (K-8) — `capture --git` yeni bir append döngüsü
  yazmaz, aynı yardımcıyı çağırır.
- **H-6** Yol normalizasyonu (cygpath + vault-relative şerit + TAB/CR/LF temizliği) ve rotasyon
  (`QUIPU_LOG_MAX`, tek `.1`) mevcut capture ile **tek kaynaktan** paylaşılır (kopyalanmaz).
- **H-7** stdout'a **0 bayt** — capture sessizlik sözleşmesi değişmez (K-9/Ö-5).
- **H-8** Değişiklik yoksa da sessiz exit 0 (boş diff = başarı).
- **H-9** Dürüst sınırlar (README'de): READ yakalanmaz; silme yakalanır (index `drop` ile düşer);
  commit'siz iki koşu aynı dosyaları çoğaltır (git-diff durumsuzdur — kullanıcı `capture --git`'i
  `remember --git`'ten önce koşar).

## 3. `quipu context --bridge` (H-10…H-17)

- **H-10** `context --bridge` bağlam metnini üretir (bare `context` ile **aynı** metin, F-3) ve
  AGENTS.md'ye yazar; stdout'a metni değil, kısa onay basar.
- **H-11** İkinci işaretçi çifti: `<!-- quipu:context:start -->` / `<!-- quipu:context:end -->`.
  Statik blok (`quipu:start`) init'in malıdır, **dokunulmaz**.
- **H-12** `lib/block.awk` genelleştirilir: `-v start=… -v end=…` (varsayılan mevcut değerler).
  Geriye uyumlu — init/Last-Session/CLAUDE.md çağrıları aynı çalışır.
- **H-13** Idempotent; kullanıcı içeriği blok dışında korunur (block.awk garantisi, F-2).
- **H-14** Tek kaynak: bağlam üretimi `context` ile `bridge` arasında **kopyalanmaz** (C-14
  dersi); ortak yardımcı `_q_ctx_text` iki komutun da çağırdığı tek yer olur.
- **H-15** Onay yeni i18n anahtarıyla (`bridge_updated`); `--bridge` ile `--json` karşılıklı dışlar.
- **H-16** `context --bridge` vault'suz ise `err_no_vault` (diğer context yolları gibi).
- **H-17** CLAUDE.md'ye **dokunulmaz** (statik ince işaretçi, init'in işi).

## 4. i18n (H-18)

- **H-18** Tek yeni anahtar `bridge_updated` (tr + en, aynı `key=value` satır biçimi). `capture --git`
  sessiz olduğu için anahtar **gerektirmez**. `i18n/{tr,en}.txt`'te başka değişiklik yok.

## 5. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/FAZ5-BULGULAR.md` — F-1…F-5'i `[kaynak]`/`[doğrulanmadı]` etiketleriyle resmileştir | F-n kaynaklı, "ölçüldü" iddiası yok |
| **1** | `quipu capture --git` (§2) + `lib/block.awk` genelleştirmesi (H-12) + testler | mevcut N iddia regresyonsuz + T-57…T-64 |
| **2** | `quipu context --bridge` (§3) + testler | T-65…T-68 |
| **3** | README "hook'suz ajanlar" bölümü, PLAN §6/§7/§9 | §10 dürüstçe belgelenmiş |

**Neden Dilim 1 önce:** `--git` capture FAZ 4'ün çok-satırlı loop'una (H-5/H-6) bağlı; block.awk
genelleştirmesi de `--bridge`'in (Dilim 2) ön koşulu. Önce çekirdek yetenekler, sonra tüketen arayüz.

## 6. Testler (T-57…)

**capture --git (geçici git repo'lu, otomatik):**

- **T-57** Git repo, 1 değişmiş `.md` → `activity.log`'da `gitdiff | git | <yol>` tek satır.
- **T-58** Çok dosyalı diff → dosya başına bir satır, sayı birebir.
- **T-59** Untracked yeni `.md` → yakalanır (`ls-files --others`).
- **T-60** `.md` olmayan dosya değişimi → satır YOK (H-4 filtresi).
- **T-61** `AGENTS.md` / `CLAUDE.md` / `.quipu/` değişimi → satır YOK (H-4).
- **T-62** Git yok / repo değil → exit 0, satır yok, stdout boş.
- **T-63** Temiz ağaç → exit 0, satır yok.
- **T-64** Silinen `.md` → kaydedilir (H-9 dürüst sınır; index `drop`'a bırakılır).

**context --bridge (otomatik):**

- **T-65** AGENTS.md'de `quipu:context:start`/`end` bloğu var, içinde bağlam metni; blok dışı kullanıcı
  içeriği birebir korunmuş.
- **T-66** İkinci koşu bloğu çoğaltmaz (idempotent).
- **T-67** `--bridge` stdout'ta yalnız onay (`bridge_updated`), ham bağlam değil.
- **T-68** block.awk genelleştirmesi geriye uyumlu: `init`/`Last-Session.md`/`CLAUDE.md` blokları
  değişmedi (regresyon — mevcut testler kilitler).

**Kırılganlık dersleri (FAZ 2/3/4 aynen):** yeni iddia i18n'ye bakıyorsa `QUIPU_LANG=en` izolasyonu;
çok baytlı `awk index()`, ASCII `grep` serbest; `RC=$?` alınıp kullanılmayan satır / başıboş `t;` yok;
test sayısı raporlanmış; yeni fixture'lar maskeli (gerçek yol/session_id yok).

## 7. Belge güncellemeleri

- **H-19** README: "hook'suz ajanlar" bölümü — `capture --git` + `context --bridge` kullanımı,
  dürüst sınırlar (F-4/H-9: READ yakalanmaz, çoğaltma riski), AGENTS.md'nin nasıl okunduğu.
- **H-20** `docs/PLAN.md`: §6 FAZ 5 ✅, §7 risk tablosuna `git-diff capture` satırı (dürüst:
  durumsuz, READ yok), §9 durum + sıradaki (FAZ 6 genişletilmiş CI).

## 8. Yasak desenler (devralınan + yeni)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) · ham
kullanıcı verisi `awk -v` (§4.16) · çok baytlı `sed` sınıfı (§4.1) · çok baytlı `grep` kalıbı
(§4.17) · tırnaksız yol değişkeni · `conhost`/`cmd` (§4.13) · hook `command`'ında doğrudan `.sh`
(§4.14) · **git çıktısını `-v` ile geçirmek** (F-5/§4.16) · **block.awk'ta yeni işaretçiyi hardcode
eden ikinci kopya** (H-12) · **bağlam üretiminin ikinci kopyası** (H-14).

## 9. Çıkış koşulu

1. Dilim 0: `FAZ5-BULGULAR.md` F-1…F-5'i cevaplıyor.
2. **Regresyon kapısı:** mevcut N iddia (FAZ 4 çıktısı) aynen yeşil; `capture` stdin/flag modu,
   `context` (bare/--json), `init`, `index`, `search`, `remember` davranışı değişmedi.
3. `sh tests/run.sh` üç OS'ta yeşil (yerel tek OS + üç OS CI).
4. `shellcheck -s sh quipu tests/run.sh` sessiz.
5. `capture --git` ve `context --bridge` yasak desenlerden arınmış (T-57…T-68).
6. Dal + PR, üç OS CI yeşil olmadan merge yok.

## 10. Kapsam dışı

- **Git-diff'ten araç-tür çıkarımı** (added/modified/deleted granularlığı) — tek `git` aracıyla
  yetinilir; ileride istenirse ayrı katman.
- **Durumlu capture** (commit'siz koşuda çoğaltma önleyici filigran) — H-9'da dürüstçe belgelenir,
  uygulanmaz.
- **README/plan dışı yeni ajan adaptörleri** — bu fazın değil.
- **MCP sunucusu** — v1 dışı (PLAN §3).
- **`quipu install`** — installer yok (C-26 dersi: config-only; programatik düzenleme yok).
