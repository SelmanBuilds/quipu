# quipu — FAZ 4 çıktı kontrol listesi

> **Bu dosya ne?** FAZ 4'ü uygulayan kod ajanının çıktısını incelemek için gözden geçirme
> protokolü. Çıktı (PR/diff + test raporu + ajan raporu) geldiğinde bu liste sırasıyla işlenir;
> bulgular K-n/T-n/A-n referansıyla raporlanır.
> Kaynaklar: `docs/FAZ4-SPEC.md` (K-1…K-25, T-50…T-56, A-1…A-6), `docs/FAZ3-DUZELTME.md` (N1-N3),
> `docs/FAZ3-KONTROL.md` (protokol deseni), `docs/PLAN.md` §4.8/§4.11/§4.16/§4.17 (yasak desen dersleri).
>
> **ÇALIŞAN FAZ 4 AJANINA NOT:** Bu dosya gözden geçirme protokolüdür, **spec değişikliği DEĞİLDİR**.
> Bağlayıcı sözleşme değişmedi: `FAZ4-SPEC.md`. Yeni gereksinim yok; bu listeyi "karşılamak" için ek iş üretme.
>
> **Tarih:** 2026-08-20 · **Durum:** hazır — ajan çıktısı bekleniyor.
>
> Her madde `[STATİK]` (kod/dosya okuma) veya `[ÇALIŞTIR]` (repo'da komut — yalnızca kullanıcı
> onayıyla) işaretlidir. Canlı Codex doğrulaması `[doğrulanmadı]` — Codex bu makinede kurulu değil,
> kurulana dek açık kalır.

---

## 0. Girdi kontrolü

- Ajanın değiştirdiği dosya listesi + diff (veya dal/PR adresi)
- `sh tests/run.sh` çıktısı (yerel + üç OS CI)
- `shellcheck -s sh quipu tests/run.sh` çıktısı
- Ajanın kendi kapanış raporu (hangi dilimler, hangi K-n'ler karşılandı iddiası)

## 1. Kapsam doğrulama

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| 0 | `docs/FAZ4-BULGULAR.md` — A-1…A-6'yı `[kaynak]`/`[doğrulanmadı]` etiketleriyle resmileştir | "ölçüldü" iddiası YOK; her bulgu kaynaklı |
| 1 | `lib/capture.awk` + `quipu capture` shell döngüsü (§2) + fixture'lar + testler | 157 iddia regresyonsuz + T-50…T-53 |
| 2 | `adapters/codex/hooks.json` (§3) + statik testler | T-54…T-56 |
| 3 | README "Codex" bölümü, PLAN §6/§7/§9 | §10 kapsam dışı dürüstçe belgelenmiş |

**Kapsam dışı ihlali kontrolü:** `quipu install` yok; `capture --git` yok (FAZ 5); `~/.codex/hooks.json`
programatik düzenleme yok (K-17, C-26 ruhu); `mcp__*`, `Bash` yol çıkarımı, silme/rename yakalama yok (K-7, K-4).

## 2. Kaynak bulgular (Dilim 0 — A-1…A-6)

`FAZ4-BULGULAR.md` şu altı maddeyi birebir ve etiketli cevaplamalı (hepsi `[kaynak]`; fiilen
kanıtlanamayanlar ek `[doğrulanmadı]`):

- **A-1** `hooks.json` şeması — kök `{description, hooks}`, camelCase alanlar, PascalCase event,
  `shell` yok, `matcher` grupta, `SessionEnd` 1s/3s tavan + zorla senkron, `additionalContextLimit` 2500.
- **A-2** araç adları — `apply_patch` (düzenleme), `Bash` (shell, canonical); `Read`/`Edit`/`Write`/
  `NotebookEdit` payload'a serileşmez; `Edit|Write` yalnız matcher alias'ı.
- **A-3** `PostToolUse` payload'ı — top-level snake_case, `additionalProperties:false`, **`tool_input.file_path`
  YOK**, `apply_patch → tool_input={command:<patch metni>}`.
- **A-4** `additionalContext` enjeksiyonu — zarf `hookSpecificOutput.additionalContext`; `SessionStart`/
  `SubagentStart`/`UserPromptSubmit` JSON+plain; `PreToolUse`/`PostToolUse` yalnız JSON; `SessionEnd` çıktı şeması yok.
- **A-5** Windows — `commandWindows` (primary) yalnız Windows'ta; `cmd.exe /C`; `QUIPU_HOOK=1 …` POSIX
  env-öneki cmd'de geçersiz (`[doğrulanmadı]`).
- **A-6** feature bayrağı — kanonik `hooks` (`CodexHooks`, `Stable`, `default_enabled:true`), `[features]
  hooks=false` kapatır; watcher yok → yeniden başlatma gerekir.

## 3. Sözleşme denetimi (K-n → kanıt)

**Capture genelleştirmesi (K-1…K-10, K-20, K-22):**

- **K-1** [STATİK] Şema dağıtımı **payload şekline** dayanır: `file_path` varsa onu kullan (Claude şeması
  birebir korunur); yoksa `apply_patch` diff'i aranır. `tool_name`'e dayalı dallanma `file_path` kontrolünden
  önce geliyorsa = ihlal.
- **K-2** [STATİK] `apply_patch` dalında "Codex" string'i geçmez; kriter `tool_input.command`'da unified diff
  + `+++ b/` başlığı.
- **K-3** [STATİK] `+++ b/` (6 bayt) `substr` ile; **regex yok** (PLAN §4.8/§4.11). Yalnız `+++ b/` (hedef)
  yakalanır; `--- a/` (kaynak) yakalanmaz.
- **K-4** [STATİK] `/dev/null` atlanır (silme); rename eski adı korunmaz (dürüst sınır).
- **K-5** [STATİK] Her yol TAB/CR/LF'den temizlenir; boş yol atlanır.
- **K-6** [STATİK] `hook_event_name<TAB>apply_patch<TAB><yol>` satırı; çok dosya → çok satır; TOOL ham `apply_patch`.
- **K-7** [STATİK] `Bash`/`Read`/`mcp__*` yakalanmaz (dürüst sınır, README'de).
- **K-8** [STATİK+ÇALIŞTIR] `_q_out` satırlara bölünür; **rotasyon döngüden ÖNCE bir kez**; her satırda cygpath
  normalizasyonu + vault-relative şerit + temizlik + ekleme. Rotasyon döngü içindeyse = ihlal.
- **K-9** [ÇALIŞTIR] `capture` **tüm yollarda stdout'a 0 bayt** yazar (Ö-5; async çıktı "system-reminder" olur).
- **K-10** [STATİK] Bayrak modu (`--event --tool --path`) değişmez; genelleştirme yalnız stdin modunda.
- **K-20** [STATİK] Diff ayrıştırması `substr`/`index`, regex yok; testler bayt-bayt karşılaştırır.
- **K-22** [STATİK] Çok baytlı `awk index()`, ASCII `grep` serbest; yeni iddia i18n'ye bakmaz (K-19).

**Adaptör (K-11…K-18):**

- **K-11** [STATİK] Dört olay FAZ 3 Claude zincirinin aynısı; **`PreCompact` bloğu YOK**.
- **K-12** [STATİK] `SessionEnd.timeout == 3` (tavan 3s). FAZ 3'ün 30'u kopyalanmamalı.
- **K-13** [STATİK] `PostToolUse.matcher == "apply_patch"` (Claude'un `Edit|Write|NotebookEdit|Read`'i kopyalanmaz).
- **K-14** [STATİK] `"shell"` alanı YOK (Codex'te yok).
- **K-15** [STATİK] `|| true` yok; Unix `QUIPU_HOOK=1`, Windows `commandWindows` `set` öneki. `set VAR=1&&` —
  `&&` değerden boşluksuz biter (cmd `set` boşluk tuzağı).
- **K-16** [STATİK] `conhost`/`cmd.exe` sarmalayıcısı, doğrudan `.sh`, `"env"` anahtarı YOK.
- **K-17** [STATİK/DOKÜMAN] installer yok; hooks.json global `~/.codex/` veya proje `.codex/`; `config.toml`'a
  bayrak gerekmez (varsayılan açık) — README "hooks varsayılan açıktır, kapatma istersen `false`" der.
- **K-18** [DOKÜMAN] README'de yeniden başlatma uyarısı (A-6: watcher yok).

**i18n:** **K-19** [STATİK] Yeni anahtar yok; `i18n/{tr,en}.txt` dokunulmaz.

**Doküman (K-23…K-25):**

- **K-23** README "Codex": kopyalama yeri, `hooks` varsayılan-açık notu, `commandWindows` notu, yeniden
  başlatma, dürüst sınırlar (yalnız `apply_patch`; `Bash`/`Read`/silme yakalanmaz).
- **K-24** PLAN §6 FAZ 4 ✅ (revize: çok-şemalı capture + Codex; Cursor/Windsurf/OpenCode ertelendiği açık),
  §7 risk tablosuna "Codex hook şeması" satırı (`[doğrulanmadı]`, canlı ölçüm açık), §9 durum + sıradaki FAZ 5.
- **K-25** `docs/FAZ4-BULGULAR.md` yeni dosya (FAZ3-BULGULAR deseninde).

## 4. Test incelemesi (T-50…T-56)

Her test için iki soru: (a) var mı, (b) iddia doğru şeyi mi sınıyor — yanlış negatif üretemeyecek kadar güçlü mü:

- **T-50** tek dosyalı `apply_patch` → `activity.log`'da `PostToolUse | apply_patch | <+++ b/ yolu>` tek satır.
- **T-51** çok dosyalı `apply_patch` → dosya başına bir satır, **sayı birebir**.
- **T-52** `/dev/null` (`+++ /dev/null`) → o dosya için satır YOK.
- **T-53** mevcut Claude Code fixture'ı → davranış **değişmedi** (regresyon). K-1'in canlı kanıtı — eski
  çıktı bayt-bayt aynı olmalı.
- **T-54** dört event anahtarı var; `PreCompact` anahtarı YOK (K-11).
- **T-55** `"shell"`, `"env"`, `conhost`, `cmd.exe`, `.sh` komutu yok (K-14/K-16).
- **T-56** `command` `QUIPU_HOOK=1 quipu ` ile başlıyor; `commandWindows` var; `async` yalnız `PostToolUse`'da
  (**tam bir kez**); `PostToolUse.matcher == "apply_patch"`.

**Fixture notu (K-21):** `codex-apply-patch.json`, `codex-apply-patch-multi.json`, `codex-apply-patch-delete.json`
temizlenmiş olmalı — gerçek kullanıcı yolu / session_id / transcript yok, path `alice/demo` maskeli.

**Kırılganlık dersleri (FAZ 2 D2/D3 aynen geçerli):**

- Yeni iddialar i18n metnine bakıyorsa `QUIPU_LANG=en` izolasyonu var mı (locale bağımlı kırmızıya dönme riski).
- Çok baytlı dizge aramaları `awk index()`; ASCII için grep serbest.
- `RC=$?` alınıp kullanılmayan satır, başıboş `t;` yok.
- Test sayısı raporlanmış olmalı: **157 + 7 yeni = 164 iddia** (2 skip dahil). Mevcut testlerden silinmiş/
  zayıflatılmış olan var mı — diff'te tek tek bak.

## 5. Regresyon kapısı (K-1)

- **Mevcut 157 iddia (155 geçti + 2 skip) aynen yeşil** — `capture`'ın Claude Code şeması değişmedi (K-1).
- `capture --event --tool --path` (K-10) ve `index`/`search`/`init`/`doctor`/`remember` davranışlarında diff
  kaynaklı değişiklik yok.

## 6. Yasak desen taraması (§9)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) · ham kullanıcı
verisi `awk -v` (§4.16) · çok baytlı `sed` karakter sınıfı (§4.1) · çok baytlı `grep` kalıbı (§4.17) · tırnaksız
yol değişkeni · `conhost`/`cmd` (§4.13) · hook `command`'ında doğrudan `.sh` (§4.14) · `~/.codex/hooks.json`
programatik düzenleme · **`apply_patch` diff ayrıştırmasında regex (§2.2)**.

## 7. Kırmızı bayraklar — en olası hata noktaları (öncelikli statik inceleme)

1. **K-1 dağıtım sırası:** `tool_name`'e dayalı dallanma `file_path` kontrolünden önce gelirse Claude şeması
   kırılır. Regresyon T-53 ile kilitli olmalı.
2. **K-3 `+++ b/` ayrıştırma:** regex kullanımı (§2.2 yasağı) veya `+++ b/`'yi patch gövdesinde (başlık dışında)
   yakalamak. `+++ a/` (kaynak) yanlışlıkla yakalanmamalı.
3. **K-8 rotasyon:** döngü içinde rotasyon = çok satırlı çıktıda log `.1`'e gider / veri kaybı.
4. **K-9 sessizlik:** çok satırlı dalda stdout'a tek bayt sızması = async çıktı modele "system-reminder" olarak girer.
5. **K-12/K-13/K-14 Claude kopyası:** implementer FAZ 3 adaptörünü kopyalayıp `timeout 30`, `Edit|Write|NotebookEdit|Read`,
   `"shell":"bash"` bırakırsa üçü de ihlal.
6. **A-5/K-15 `commandWindows`:** `set QUIPU_HOOK=1&&` — `&&` öncesi boşluk = cmd `set` tuzağı (değere boşluk girer).
   `[doğrulanmadı]` olduğu için özellikle gözden geçir.
7. **K-21 fixture temizliği:** gerçek Codex payload'ı temizlenmeden commit (gerçek yol/session_id/transcript kalıntısı).
8. **Regresyon sayısı:** "156" bayat değeri kapıya yazmak. Gerçek sayıyı `sh tests/run.sh`'ten al (157).
9. **K-19 i18n:** gereksiz yeni anahtar eklemek — `i18n/{tr,en}.txt` diff'te değişmemeli.
10. **K-2 ajan-agnostiklik:** `apply_patch` dalına "Codex" literal'ı sızmışsa Cursor/Windsurf'ün ilerideki şeması
    bu dala giremez.

## 8. Belge tamamlığı

- **K-23:** README "Codex" bölümü (kopyalama yeri, varsayılan-açık notu, `commandWindows` notu, yeniden başlatma
  uyarısı, dürüst sınırlar) + komut listesinde değişiklik yok (`capture` davranışı kapsamında).
- **K-24:** `docs/PLAN.md` — §6 FAZ 4 ✅ + ertelenen ajanlar açıkça yazılı; §7 risk tablosuna "Codex hook şeması"
  satırı (`[doğrulanmadı]`); §9 durum + sıradaki FAZ 5.
- **K-25:** `docs/FAZ4-BULGULAR.md` var, FAZ3-BULGULAR deseninde, `[kaynak]`/`[doğrulanmadı]` etiketli.

## 9. Koşulacak doğrulamalar (çıktı geldiğinde, kullanıcı onayıyla)

1. `sh tests/run.sh` — yerel tam paket; sayı ve SKIP'ler raporla karşılaştırılır.
2. `./.claude/tools/shellcheck.exe -s sh quipu tests/run.sh` — sıfır bulgu.
3. Elle: tek/çok dosyalı `apply_patch` payload'ı pipe'la `capture`'a → `activity.log` satırları birebir;
   Claude fixture → çıktı değişmedi; `capture --event --tool --path` bayrak modu hâlâ çalışıyor.
4. Üç OS CI (PR üzerinde) — yeni testlerin Linux/macOS'ta da geçtiği kanıtı.

## 10. Kabul koşulları — tek bakışta

- [ ] Dilim 0–3 eksiksiz; `FAZ4-BULGULAR.md` A-1…A-6'yı etiketli cevaplıyor
- [ ] T-50…T-56 var ve güçlü; 157 + 7 iddia; üç OS yeşil; shellcheck sessiz
- [ ] K-1…K-25 birebir; `PreCompact`/`shell`/`env`/`conhost` adaptörde yok
- [ ] Regresyon kapısı: 157 iddia aynen yeşil (spec'teki "156" düzeltilmiş)
- [ ] §9 yasak desenlerin hiçbiri yok
- [ ] §7 kırmızı bayrakların 10'u temiz
- [ ] K-23/K-24/K-25 belgeler tam; fixture'lar maskeli; her şey izleniyor
- [ ] "Canlı Codex doğrulaması" `[doğrulanmadı]` olarak dürüstçe açık (K-24 risk satırı)

---

## İşleyiş notu

- Çıktı geldiğinde bu dosya sırayla işlenir; bulgular **K-n/T-n/A-n referanslı** raporlanır.
- İnceleme ilerledikçe dosya yerinde güncellenir (işaretleme/notlar), yeniden oluşturulmaz.
- Kullanıcı onayı olmadan repo'da komut koşulmaz.
