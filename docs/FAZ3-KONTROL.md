# quipu — FAZ 3 çıktı kontrol listesi

> **ÇALIŞAN FAZ 3 AJANINA NOT (2026-08-20):**
> 1. Bu dosya senin uygulamanın **gözden geçirme protokolüdür, spec değişikliği DEĞİLDİR**.
>    Bağlayıcı sözleşme değişmedi: `FAZ3-SPEC.md` + `FAZ3-BULGULAR.md` (AM-1…AM-4).
>    Yeni gereksinim yok; bu listeyi "karşılamak" için ek iş üretme.
> 2. **GÜNCELLEME:** Claude Code artık test için kullanılabilir — kullanıcı Claude Code'a
>    DeepSeek modelini bağladı. C-33 canlı katmanı serbest.
>    Hook/enjeksiyon davranışı istemci tarafıdır, modelden bağımsızdır — sonuçlar geçerli
>    kalır. Yine de C-33 kaydına hangi modelle koşulduğunu yaz (BULGULAR'da model belirtme deseni var).

> **Bu dosya ne?** FAZ 3'ü uygulayan kod ajanının çıktısını incelemek için
> gözden geçirme protokolü. Çıktı (PR/diff + test raporu + ajan raporu)
> geldiğinde bu liste sırasıyla işlenir; bulgular C-n referansıyla raporlanır.
> Kaynaklar: `docs/FAZ3-SPEC.md` (C-1…C-36, T-30…T-49), `docs/FAZ3-BULGULAR.md`
> (Ö-1…Ö-5, E-1…E-4, AM-1…AM-4, dal kararı), `docs/FAZ2-DUZELTME.md` (D1-D4 dersleri).
>
> **Tarih:** 2026-08-20 · **Durum:** hazır — ajan çıktısı bekleniyor.
>
> Her madde `[STATİK]` (kod/dosya okuma) veya `[ÇALIŞTIR]` (repo'da komut — yalnızca
> kullanıcı onayıyla) işaretlidir. C-33 canlı katmanı yalnızca kullanıcı koşabilir.

---

## 0. Girdi kontrolü

- Ajanın değiştirdiği dosya listesi + diff (veya dal/PR adresi)
- `sh tests/run.sh` çıktısı (üç OS CI + yerel)
- `shellcheck -s sh quipu tests/run.sh` çıktısı
- Ajanın kendi kapanış raporu (hangi dilimler, hangi C-n'ler karşılandı iddiası)

## 1. Kapsam doğrulama

| Kontrol | Ne aranır |
|---|---|
| Dilim E-0 | `docs/FAZ3-BULGULAR.md` var, Ö-1…Ö-5 + E-1…E-4 cevaplı, fixture'lar `tests/fixtures/` içinde maskeleli |
| Dilim E-1 | `lib/digest.awk` var; `quipu` içindeki gömülü `cnt[path]++` toplayıcısı `context`'ten **kaldırılmış**, tek kaynak digest.awk |
| Dilim E-2 | `quipu remember` + filigran + i18n anahtarları |
| Dilim E-3 | `context` kırpma (C-16/17) + nudge (C-19/20) — PreCompact kolu (C-18) **yok** |
| Dilim E-4 | `adapters/claude-code.json`, doctor hook kontrolü, `QUIPU_HOOK` |
| Dilim E-5 | README, PLAN §6/§7/§9 |
| Kapsam dışı ihlali | `quipu install` yok; `capture --git` yok; settings.json programatik düzenleme yok (C-26) |

## 2. Sözleşme denetimi (C-n → kanıt)

**`remember` (C-7…C-15):**

- **C-7** [STATİK] `.quipu/remembered` filigranı **satır metni**; `remember` o satırın log'daki **son** geçişini bulup sonrasını alır (aynı satır iki kez geçiyorsa sonuncusu şart); bulamazsa tüm log işlenir. Bayt ofseti kullanımı = kırmızı bayrak.
- **C-8** [STATİK] `<sessions>/YYYY-MM-DD.md` append-only: var olan içerik hiç okunmuyor, `>>` ile `## HH:MM` bölümü ekleniyor. `cat dosya` + yeniden yazma deseni = ihlal.
- **C-9** [STATİK] `Last-Session.md` güncellemesi `lib/block.awk` üzerinden; kullanıcı metni blok dışında korunuyor; ikinci koşu blok çoğaltmıyor.
- **C-9b** [STATİK] Last-Session gövdesi **işaretçi**: `tarih · N events · sessions/yol` — sindirim kopyası değil.
- **C-10/C-11** [STATİK+ÇALIŞTIR] Bayraksız `remember` asla commit atmaz; `--git`: git yok/vault repo değil/değişiklik yok → sessiz atla, çıkış 0.
- **C-12** [ÇALIŞTIR] `--dry-run` stdout'a basar; hiçbir dosya yazılmaz; filigran değişmez (T-36'nın iddia ettiği tam set).
- **C-13** [STATİK] Başlıklar i18n'den (`digest_range`, `digest_tools`, `digest_files`); sayılar/yollar veri.
- **C-14** [STATİK] `context` ve `remember` aynı toplayıcıyı (digest.awk) kullanıyor — kopya toplama mantığı ikinci yerde = ihlal.
- **C-14b** [STATİK] `usage_remember` satırı + dispatch'te `remember)` dalı var; sıra `context`'ten sonra.
- **C-15** [ÇALIŞTIR] Dosya listesi varsayılan 10, `--limit` ile değişiyor.

**`context` (C-16…C-20):**

- **C-16** [STATİK+ÇALIŞTIR] `QUIPU_CTX_MAX` (varsayılan 4096) aşımında **yalnız** Threads bölümü **sonundan** kırpılır; activity + indeks bölümleri korunur; `ctx_truncated` satırı eklenir.
- **C-17** [STATİK] Kırpma **satır sınırında**; çok baytlı karakter ortadan kesilmez. Uygulama bayt-ofsetli `cut`/`head -c` kullanıyorsa ihlal.
- **C-18** [STATİK] `context --json PreCompact` kod yolu **olmamalı** (dal kararı: ulaşmıyor).
- **C-19/C-20** [STATİK, yüksek risk — bkz. §7] `--json UserPromptSubmit`'te: filigrandan sonraki satır sayısı > `QUIPU_NUDGE_AFTER` (50) → `ctx_precompact` talimatı; sonrasında `.quipu/nudged` yazılır ve eşik yeniden aşılana dek susulur.

**Adaptör (C-21…C-25):**

- **C-21/C-22** [STATİK] `adapters/claude-code.json` içinde `conhost`/`cmd.exe` yok; `command` alanı doğrudan `.sh` yolu değil; `shell: "bash"`.
- **C-23** [STATİK] Adaptörde `cygpath` gömülü değil.
- **C-24** [STATİK] `async: true` **yalnız** `PostToolUse`'da; `matcher` birebir `Edit|Write|NotebookEdit|Read`; SessionStart/UserPromptSubmit senkron, SessionEnd senkron.
- **C-25** [STATİK+ÇALIŞTIR] Hook'lar her koşulda 0 ile çıkar: `QUIPU_HOOK=1` setliyken hata çıkışları 0'a çevrilir; bayraksız elle çalıştırmada anlamlı kod kalır; `|| true` kullanılmamış.

**Doctor/C-28:** `~/.claude/settings.json` içinde `quipu` alt-dizgesi geçiyorsa `ok claude hooks: kurulu`, geçmiyorsa `warn … kurulu değil`. JSON ayrıştırma yok (C-31 ruhu); dosya yoksa çökme yok.

**i18n/C-29:** Yeni anahtarlar iki dosyada da: `usage_remember`, `remember_ok`, `remember_empty`, `remember_git`, `digest_range`, `digest_tools`, `digest_files`, `ctx_truncated`, `ctx_precompact`, `doc_hooks_installed`, `doc_hooks_missing`. Tek satır `key=value`; printf formatlı değerlerde kaçak `%` yok; anahtar kümeleri özdeş.

## 3. Ölçüm değişiklikleri (AM-1…AM-4) — spec'ten sapmaların ana kaynağı

| # | Kontrol |
|---|---|
| AM-1 | SessionStart zinciri: `QUIPU_HOOK=1 quipu remember && QUIPU_HOOK=1 quipu context --json SessionStart`; SessionEnd: `QUIPU_HOOK=1 quipu remember`. **PreCompact bloğu adaptörde YOK** (Ö-2). |
| AM-2 | Her komut `QUIPU_HOOK=1 quipu …` biçiminde (E-3: hook `env` anahtarı yok). `"env": {...}` kalıntısı adaptörde geçmemeli. |
| AM-3 | `UserPromptSubmit` hook'u var: `QUIPU_HOOK=1 quipu context --json UserPromptSubmit`. |
| AM-4 | README Windows notu: Git `bin` PATH (E-2 "Executable not found in $PATH: bash") + §4.15 yeniden başlatma uyarısı. |
| Ö-5 etkisi | `quipu capture` **tüm yollarda** stdout'a sıfır bayt yazar (async çıktı "system-reminder" olarak modele girer). |

## 4. Test incelemesi (T-30…T-49)

Her test için iki soru: (a) var mı, (b) iddia doğru şeyi mi sınıyor — yanlış negatif üretemeyecek kadar güçlü mü:

- **T-30** boş log: çıkış 0 + hiçbir dosya yazılmadı. **T-31** sindirim `<sessions>/YYYY-MM-DD.md`'de, dosya dolu. **T-32** ikinci koşu ikinci `## HH:MM` bölümü, ilk bölüm bayt-bayt aynı. **T-33** filigran sonrası yeni satır yokken `remember_empty`.
- **T-34** log rotasyonu: filigran satırı log'da yok → çökmüyor, tümünü işliyor. Testin rotasyonu **gerçekten simüle ettiğini** kontrol et (filigranı .1'e taşımak yetmez; yeni log'da filigranın olmaması gerek).
- **T-35** Last-Session bloğu tek + kullanıcı metni korunmuş. **T-36** `--dry-run` üçlüsü: stdout'ta sindirim, yazılan dosya yok (sessions dahil), filigran değişmemiş.
- **T-37** araç ve dosya sayaçları elle kurulmuş log'la birebir (digest.awk doğruluğunun asıl kanıtı — özellikle aynı dosyaya birden çok dokunuşta `cnt[path]++`).
- **T-38** `--limit` sınırı. **T-39/T-40** `--git` matrisi; T-40 `git -c user.email=… -c user.name=…` kullanıyor (C-32) — CI'da global kimlik yok.
- **T-41/T-42/T-43** kırpma üçlüsü: T-41 sınır altında kalma; **T-42 satır sınırı + geçerli UTF-8 — testin sınırın tam üstüne çok baytlı karakter koyduğunu doğrula**, aksi halde ortadan kesme yakalanmaz; UTF-8 geçerlilik kontrolü `grep` değil awk ile olmalı (B-30). **T-43** `ctx_truncated` satırı var.
- **T-44** kırpılmış bağlamla `--json` çıktısı round-trip sürücüsüyle geçerli JSON.
- **T-45** dal doğru koşulda talimatı basıyor, yanlış koşulda **basMıyor** — iki yönlü iddia şart. Özellikle: eşik altında talimat YOK; eşik aşıldıktan sonra bir kez VAR; ikinci prompt'ta (nudged sonrası) YOK; eşik tekrar aşılınca tekrar VAR.
- **T-46/T-47** adaptör dizge kontrolü: yasak dizgeler yok (T-46); her `command` `^QUIPU_HOOK=1 quipu ` ile başlıyor, `shell` = bash (T-47, AM-2 güncellemesiyle).
- **T-48** `QUIPU_HOOK=1` iken vault'suz `remember` **ve** `capture` çıkış 0; bayraksız 1.
- **T-49** doctor: `quipu` geçen sahte settings → `kurulu`; geçmeyen → `kurulu değil`.

**Kırılganlık dersleri (FAZ 2 D2/D3 aynen geçerli):**

- Yeni iddialar i18n metnine bakıyorsa `QUIPU_LANG=en` izolasyonu var mı (locale bağımlı kırmızıya dönme riski).
- Çok baytlı dizge aramaları `awk index()`; ASCII için grep serbest.
- `RC=$?` alınıp kullanılmayan satır, başıboş `t;` yok.
- Test sayısı raporlanmış olmalı: **117 + ~20 yeni**. Mevcut testlerden silinmiş/zayıflatılmış olan var mı — diff'te tek tek bak.

## 5. Regresyon kapısı (E-1)

- Mevcut 117 iddia aynen yeşil (dilim E-1 davranış değiştirmemeli — `context` çıktısı refaktör öncesiyle özdeş kalmalı; testlerden hiçbiri "yeni formata uyarlandı" bahanesiyle değişmemeli).
- `capture`, `index`, `search`, `init`, `doctor` davranışlarında diff kaynaklı değişiklik yok.

## 6. Yasak desen taraması (§9)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) · ham kullanıcı verisi `awk -v` (§4.16) · çok baytlı `sed` karakter sınıfı · çok baytlı `grep` kalıbı · tırnaksız yol değişkeni · `conhost`/`cmd` · hook'ta doğrudan `.sh` · settings.json programatik düzenleme.

## 7. Kırmızı bayraklar — en olası hata noktaları (öncelikli statik inceleme)

1. **Nudge baz hattı (C-19/C-20):** Satır sayısı hangi filigrandan sayılıyor? Doğru: `.quipu/nudged` varsa oradan, yoksa `.quipu/remembered`'dan. Her iki durumda da baz **yalnızca enjeksiyon anında** ilerler. Baz hep `remembered` kalırsa talimat **her prompt'ta** tekrar eder (C-20 ihlali).
2. **C-7 filigran:** Tekrarlayan satırlarda **son** geçiş kullanılmalı. `awk` ilk eşleşmede kırılıyorsa olay kaybı var.
3. **Kırpma bütçesi:** `QUIPU_CTX_MAX` nereye uygulanıyor — çıplak `context` çıktısına mı, JSON zarfının içindeki metne mi? İki yolda da tutarlı olmalı (T-41 ve T-44 birlikte sınar).
4. **QUIPU_HOOK kapsamı:** Sadece `_q_die` değil — `set -eu` altında beklenmedik çıkış yolları da 0'a düşmeli mi? T-48'in senaryoları (vault'suz remember + capture) en azından örtülü olmalı; hook gerçekte düşen başka yol varsa C-25 ihlali.
5. **`_q_msg` → `_q_v` ezmesi (D1 dersi):** Yeni kodda **komut ikamesi olmadan** çağrılan `_q_msg` (doğrudan satırda) kendinden sonra `_q_v` kullanan bir yolu eziyorsa = Faz 2'deki OneDrive gerilemesinin aynısı.
6. **Capture sessizliği:** `capture`'ın hiçbir yolunda stdout çıktısı yok (Ö-5).
7. **Fixture maskelemesi:** `tests/fixtures/*.json` içinde gerçek kullanıcı yolu (`C:\Users\…`), gerçek session id, ham transcript kalıntısı olmamalı; maske `alice/demo` + sabit id.
8. **Untracked dosyalar (D3 dersi):** `adapters/`, `lib/digest.awk`, `docs/FAZ3-BULGULAR.md` ve yeni fixture'lar commit'e girmiş olmalı; `.gitignore` bunları yutmamalı.

## 8. Belge tamamlığı

- **C-34:** README'ye "Claude Code" bölümü (yapıştırılacak snippet, PATH notu, Windows notu, **yeniden başlatma uyarısı**) + komut listesinde `quipu remember`.
- **C-35:** `docs/PLAN.md` — §4.18 mevcut mu ve BULGULAR ile birebir mi (6 madde); §6 FAZ 3 ✅; §7 risk tablosuna `PreCompact enjeksiyonu` satırı (dürüst: "ulaşmıyor, UserPromptSubmit'e düşüldü"); §9 durum + sıradaki FAZ 4.
- **C-36:** `docs/FAZ3-BULGULAR.md` var, FAZ0-BULGULAR deseninde, dal kararı gerekçeli.
- **C-33 (canlı katman):** BULGULAR'daki "Kalan canlı katman" bölümü doldurulmuş olmalı — bu adım **kullanıcı** gerçek oturumda koşar (yeniden başlatılmış Claude Code): SessionStart enjeksiyonu görünüyor mu, PostToolUse `activity.log`'a satır düşürüyor mu, SessionEnd/sonrası `<sessions>/` dosyası oluştu mu. **CI yeşili bunun yerine geçmez** — dolu değilse çıktı kabul edilmez.

## 9. Koşulacak doğrulamalar (çıktı geldiğinde, kullanıcı onayıyla)

1. `sh tests/run.sh` — yerel tam paket; sayı ve SKIP'ler raporla karşılaştırılır.
2. `./.claude/tools/shellcheck.exe -s sh quipu tests/run.sh` — sıfır bulgu (Faz 2 kapısı).
3. Elle senaryolar: nudge eşik geçişi (eşik altı/üstü/susma/tekrar), filigranlı + tekrarlayan satırlı log, çok baytlı sınır kırpması, `--dry-run` saflığı, `QUIPU_HOOK=1` vs bayraksız çıkış kodları.
4. Üç OS CI durumu (PR üzerinde).

## 10. Kabul koşulları — tek bakışta

- [ ] E-0…E-5 dilimleri eksiksiz; dal kararı "ulaşmıyor" gerekçeli
- [ ] T-30…T-49 var ve güçlü; 117 + ~20 iddia; üç OS yeşil; shellcheck sessiz
- [ ] AM-1…AM-4 birebir; PreCompact adaptörde ve kodda yok
- [ ] §9 yasak desenlerin hiçbiri yok
- [ ] §7 kırmızı bayrakların 8'i temiz
- [ ] C-34/C-35/C-36 belgeler tam; fixture'lar maskeli; her şey izleniyor
- [ ] C-33 canlı katman kullanıcı tarafından koşulup belgelenmiş

---

## İşleyiş notu

- Çıktı geldiğinde bu dosya sırayla işlenir; bulgular **C-n/AM-n/T-n referanslı** raporlanır.
- İnceleme ilerledikçe dosya yerinde güncellenir (işaretleme/notlar), yeniden oluşturulmaz.
- Kullanıcı onayı olmadan repo'da komut koşulmaz; C-33 yalnızca kullanıcı tarafından yürütülür.
