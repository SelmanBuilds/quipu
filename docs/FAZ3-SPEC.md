# quipu — FAZ 3 SPEC: Claude Code adaptörü (referans uygulama)

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: `docs/PLAN.md` §2 (dört katman), §4.5-4.7, §4.12-4.17, §5, §6 FAZ 3.
> Ön koşul: FAZ 2 tamam (PR #2 merged, 117/117, üç OS yeşil).
> Sözleşme numaraları **C-n** (FAZ 2'nin B-n'leriyle çakışmasın).

## 0. Bu fazın tek cümlelik ölçütü

> **Adaptör bir yapılandırma dosyasından ibaret olmalı.** Yeni kod gerekiyorsa çekirdek CLI
> yanlış tasarlanmış demektir (PLAN §6 FAZ 4). FAZ 3'te çekirdeğe komut eklemek serbesttir —
> ama o komutlar **ajandan bağımsız** olmalı; içinde "Claude Code" geçen tek şey
> `adapters/claude-code.json` olacak.

---

## 1. Mimari karar: SessionEnd'de model yoktur

FAZ 3'ün en kolay yanlış tasarlanan yeri burası. PLAN §2 KATMAN 1 "SessionEnd → activity.log'u
oku, Last-Session.md + Threads.md güncelle" diyor ve PLAN §1 tezi "semantik katman zaten
oradaki model" diyor. **İkisi SessionEnd'de aynı anda doğru olamaz:** oturum biterken model
döngüde değildir, bir hook ona soru soramaz.

Bağlayıcı ayrım:

| An | Model döngüde mi | quipu ne yapar |
|---|---|---|
| `SessionStart` | evet (birazdan) | **bağlam enjekte eder** — `context --json` |
| `PreCompact` / oturum ortası | **evet** | **talimat enjekte eder**: "hafızayı şimdi yaz" |
| `SessionEnd` | **hayır** | **mekanik özet yazar** — AI yok, `activity.log`'dan olgu türetir |

- **C-1** `quipu remember` **asla** özet uydurmaz, yorumlamaz, "anlam" çıkarmaz. Yaptığı iş
  `activity.log` satırlarını toplayıp sayısal/olgusal bir sindirim (digest) üretmektir.
  Anlamlı özeti model yazar — ve bunu ancak **döngüdeyken** yazabilir (PreCompact talimatı).
- **C-2** İki mekanizma birbirinin yedeği değil, tamamlayıcısıdır. Model hiç özet yazmasa bile
  mekanik sindirim durur; model yazdıysa `Threads.md`/`700-Sessions/` zaten zenginleşmiştir.

---

## 2. Dilim 0 — ÖLÇÜM (bloklayıcı, kod yazmadan önce)

PLAN §9: FAZ 0'ın dört maddesinden **`PreCompact` doğrulanamadı**, FAZ 3'e ertelendi.
Ölçülmeden üstüne tasarım yapılmayacak.

### Ölçülecekler

| # | Soru | Neden kritik |
|---|---|---|
| Ö-1 | `PreCompact` hook'u gerçekten tetikleniyor mu? Payload şeması ne? | §4.6 olay listesinde var ama canlı görülmedi |
| Ö-2 | `PreCompact` çıktısındaki `hookSpecificOutput.additionalContext` modele **ulaşıyor mu**? | §4.5 yalnız `SessionStart`, `UserPromptSubmit`, `UserPromptExpansion` için stdout enjeksiyonu doğruluyor. **`PreCompact` o listede YOK.** |
| Ö-3 | `SessionEnd` payload'ı: `reason` alanı var mı, değerleri ne? | Temiz çıkış / crash ayrımı yapılacaksa gerek |
| Ö-4 | `SessionStart` payload'ındaki `source` (`startup\|resume\|clear`) gerçekte hangi değerleri veriyor? | `resume`'da bağlam enjeksiyonu gereksiz olabilir |
| Ö-5 | `async: true` olan bir hook'un çıktısı bağlama giriyor mu? | `PostToolUse` async çalışacak; giriyorsa gürültü olur |

### Yöntem

- **C-3** Ölçüm, FAZ 0'ın yöntemiyle yapılır: hook `command`'ı payload'ı bir dosyaya
  yazar (`.claude/faz3/<event>.json`), sonra oturum yeniden başlatılır (§4.15: yapılandırma
  **sıcak yüklenmez**, mid-session yazmak hiçbir şey tetiklemez).
- **C-4** Yakalanan payload'lar `tests/fixtures/`'a **temizlenerek** alınır: kullanıcı yolları,
  `session_id`, `transcript_path` maskelenir, büyük gövdeler kısaltılır (PLAN §6 Adım 1'deki
  fixture kuralının aynısı).
- **C-5** Bulgular `docs/FAZ3-BULGULAR.md`'ye yazılır ve PLAN §4'e yeni alt bölüm olarak
  özetlenir (§4.17'den sonraki numara). Ö-2'nin cevabı ne çıkarsa çıksın yazılır — "ulaşmıyor"
  da değerli bir bulgudur.

### Ö-2'nin iki dalı — tasarım buna göre çatallanır

| Ö-2 sonucu | `PreCompact` tasarımı |
|---|---|
| **Ulaşıyor** | `PreCompact` hook'u `quipu context --json PreCompact` çağırır; çıktı "hafızayı şimdi yaz" talimatını içerir (§4.2) |
| **Ulaşmıyor** | `PreCompact` düşer; talimat **`UserPromptSubmit`** üzerinden, **bayatlık eşiğiyle** enjekte edilir (§4.3) |

- **C-6** Her iki dal da spec'te tanımlı; ajan **ölçüm sonucuna göre birini uygular**, ikisini
  birden değil. Hangi dalın uygulandığı `docs/FAZ3-BULGULAR.md`'de gerekçesiyle yazılır.

---

## 3. Çekirdek CLI eklemeleri

### 3.1 `quipu remember` — mekanik sindirim yazıcısı

```
quipu remember [--git] [--dry-run]
```

Davranış:

1. Vault yoksa → `err_no_vault`, çıkış 1.
2. `activity.log`'u oku. `.quipu/remembered` varsa, **içindeki satırın son geçtiği yerden
   sonrasını** al; yoksa tüm dosyayı al.
3. İşlenecek satır yoksa → `remember_empty` mesajı, çıkış **0**, hiçbir dosya yazılmaz.
4. Sindirimi üret (§3.2) ve `<sessions>/YYYY-MM-DD.md` dosyasına **ekle** (append).
   `<sessions>` = `layout/<layout>.txt` içindeki `sessions` slug'ının görünen adı.
5. `Last-Session.md`'yi (vault kökü) `lib/block.awk` işaretli bloğuyla güncelle.
6. `.quipu/remembered` dosyasına işlenen **son satırı aynen** yaz.
7. `--git` verildiyse ve vault bir git deposuysa: `git add -A` + `git commit`.

**Bağlayıcı sözleşmeler:**

- **C-7** **Filigran (watermark) satır metnidir, ofset değildir.** `.quipu/remembered` işlenen
  son log satırının **tam metnini** tutar. `remember` o satırın log'daki **son** geçtiği yeri
  bulur ve sonrasını alır; bulamazsa (log döndü, §FAZ1 rotasyonu) **tümünü** alır.
  Bayt ofseti kullanmak yasak: `activity.log` 256 KB'ta `.1`'e dönüyor, ofset anlamsızlaşır.
- **C-8** `<sessions>/YYYY-MM-DD.md` **append-only**. Var olan içerik asla okunup yeniden
  yazılmaz; dosyanın sonuna `## HH:MM` başlıklı yeni bir bölüm eklenir. Aynı gün içinde
  birden çok `remember` = aynı dosyada birden çok bölüm.
- **C-9** `Last-Session.md` quipu'nundur ama **kullanıcı metnine dokunulmaz**: `lib/block.awk`
  ile `<!-- quipu:start -->…<!-- quipu:end -->` arası değiştirilir (FAZ 2 B-11'in aynısı).
  Yeni kod yazma, `block.awk`'ı kullan.
- **C-9b** `Last-Session.md` sindirimin **kopyası değil, işaretçisidir**: tarih, olay sayısı ve
  asıl dosyaya bağlantı (`<sessions>/YYYY-MM-DD.md`). Gerekçe: her iki dosya da `.md` ve
  `_q_mdlist` onları dışlamıyor — aynı içeriği iki yere yazmak indekste **çift kayıt** ve
  aramada çift isabet demektir. `AGENTS.md`/`CLAUDE.md` gibi dışlamak da yanlış olur; bunlar
  hafıza içeriği (FAZ 2 B-17).
- **C-10** `--git` **opt-in**. Bayraksız `remember` **asla** commit atmaz. Kullanıcının deposuna
  habersiz commit atmak sürpriz yan etkidir. Adaptör yapılandırması da bayraksız gönderir;
  `--git` dokümanda "istersen ekle" olarak anlatılır.
- **C-11** `--git` verildiğinde: vault git deposu değilse **sessizce atla** (çıkış 0);
  commit edilecek değişiklik yoksa **sessizce atla** (`git commit` boş commit'te hata verir,
  bu hata hook'u düşürmemeli); `git` yoksa atla.
- **C-12** `--dry-run` sindirimi stdout'a basar, hiçbir dosya yazmaz, filigranı güncellemez.
  Testlerin ve kullanıcının davranışı görmesinin ucuz yolu.

### 3.2 Sindirim biçimi (mekanik, AI yok)

`--dry-run` çıktısı ve dosyaya eklenen bölüm aynı gövdedir:

```markdown
## 14:32

- Aralık: 2026-08-20T11:05 → 2026-08-20T14:31 (87 olay)
- Araçlar: Edit 41, Read 33, Write 13
- Dokunulan dosyalar (en çok 10):
  - 12  500-Knowledge/not.md
  -  7  300-Projects/quipu/PLAN.md
  ...
```

- **C-13** Başlıklar i18n'den gelir (`digest_range`, `digest_tools`, `digest_files`).
  Sayılar ve yollar veridir.
- **C-14** Toplama `quipu context`'in hâlihazırda yaptığı işin aynısıdır — `quipu:555-565`
  civarındaki gömülü awk programı (`cnt[path]++`, `lasttool[path]`). **Kopyalama yapma:**
  ortak toplayıcı `lib/digest.awk`'a çıkarılır, `context` de onu kullanır. FAZ 2'nin
  `_q_mdlist` refaktörüyle aynı gerekçe.
- **C-14b** `usage()` ve dispatch `case` bloğu güncellenir: `usage_remember` satırı ve
  `remember) shift; _q_cmd_remember "$@" ;;` dalı. Komut sırası PLAN §6'daki mantığı korur —
  `remember`, `context`'ten sonra (ikisi de vault varsayar).
- **C-15** Dosya listesi varsayılan 10 satırla sınırlı (`--limit` ile değişir). Sınırsız liste
  `700-Sessions/` dosyalarını şişirir ve indekse gürültü olarak girer.

### 3.3 `quipu context` — sınırlandırma ve talimat

- **C-16** **Çıktı sınırlandırılır.** `context` her `SessionStart`'ta bağlama giriyor;
  `Threads.md` sınırsız büyüyebilir. Yeni sınır: toplam çıktı `QUIPU_CTX_MAX` baytını
  (varsayılan **4096**) aşarsa, **`Threads.md` bölümünün sonundan** kırpılır ve kırpıldığını
  belirten bir satır eklenir (`ctx_truncated`). Etkinlik ve indeks bölümleri korunur —
  onlar zaten sınırlı.
- **C-17** Kırpma **bayt sınırında değil, satır sınırında** yapılır. Çok baytlı bir karakteri
  ortasından kesmek UTF-8'i bozar ve JSON zarfına geçersiz bayt sokar.
- **C-18** (yalnız Ö-2 "ulaşıyor" dalında) `context --json PreCompact` çıktısına
  `ctx_precompact` talimat satırı eklenir. Talimat **veridir**, i18n'dedir, koda gömülmez.
  Metin, modelden `Threads.md`'yi ve `<sessions>/` dosyasını güncellemesini ister.

### 3.4 Bayatlık eşiği (yalnız Ö-2 "ulaşmıyor" dalında)

- **C-19** `quipu context --json UserPromptSubmit` çağrıldığında: `.quipu/remembered`
  filigranından bu yana biriken satır sayısı `QUIPU_NUDGE_AFTER` (varsayılan **50**) eşiğini
  aşmışsa, çıktıya `ctx_precompact` talimatı eklenir; aşmamışsa **hiçbir şey eklenmez.**
- **C-20** Talimat her istemde tekrarlanmaz: enjekte edildiğinde `.quipu/nudged` dosyasına
  o anki filigran yazılır; eşik yeniden aşılana kadar susulur. Her promptta "hafızanı yaz"
  demek, talimatı gürültüye çevirir ve model onu yok saymayı öğrenir.

---

## 4. Adaptör: `adapters/claude-code.json`

**Kod değil, veri.** `layout/` ve `persona/` ile aynı desen.

### 4.1 İçerik

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "shell": "bash",
                     "command": "quipu context --json SessionStart",
                     "timeout": 10 } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|NotebookEdit|Read",
        "hooks": [ { "type": "command", "shell": "bash",
                     "command": "quipu capture",
                     "timeout": 10, "async": true } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "shell": "bash",
                     "command": "quipu remember",
                     "timeout": 30 } ] }
    ]
  }
}
```

`PreCompact` bloğu Ö-2'nin sonucuna göre eklenir veya eklenmez.

### 4.2 Bağlayıcı kurallar

- **C-21** **`conhost.exe` / `cmd.exe` sarmalayıcısı YASAK** (§4.13). Bu yasak teorik değil:
  inceleme sırasında bu makinedeki `~/.claude/settings.json`'ın başka bir araç tarafından
  kurulmuş `SessionStart` hook'unun tam olarak o deseni kullandığı ve çıktısının
  `ESC[?9001h ESC[?1004h ESC[?25l ESC[2J ESC[H` gibi ANSI baytlarıyla dolduğu **canlı görüldü**.
  §4.13'ün ölçtüğü 3456 escape baytı ve `toolu__015hFq…` çift-alt-çizgi bozulması aynı desenin
  sonucudur. quipu'nun kendi yapılandırması bu desene **asla** girmeyecek.
- **C-22** `command` alanı doğrudan bir `.sh` yolu **olamaz** (§4.14: `spawn` → `EFTYPE`,
  süreç hiç başlamaz). `shell: "bash"` + komut dizgesi kullanılır. `quipu` uzantısız ve
  `PATH`'te olduğu için komut satırı sade kalır.
- **C-23** `quipu` `PATH`'te değilse mutlak yol yazılır; Windows'ta yol dönüşümü için §4.7
  `cygpath` deseni dokümanda gösterilir. Yapılandırmaya `cygpath` **gömülmez** — kullanıcı
  kendi yolunu yazar.
- **C-24** `PostToolUse` **`async: true`** (§4.7/§4.13: ağır iş asenkron). Diğerleri senkron;
  `SessionStart` bağlamı zamanında girmeli, `SessionEnd` yazma işini bitirmeli.
- **C-25** **Her hook her koşulda 0 ile çıkar.** Vault yok, git yok, log boş, disk dolu —
  hiçbiri kullanıcının oturumunu bozmaz. `quipu remember` ve `quipu capture` hata durumunda
  stderr'e yazıp 0 döner; yalnızca **elle** çağrıldığında anlamlı çıkış kodu verir.
  Bunu sağlamak için adaptör komutları `|| true` ile sarılmaz — **komutların kendisi**
  hook bağlamında sessiz-başarılı olur. Ayrım: `QUIPU_HOOK=1` ortam değişkeni set edilirse
  hata çıkışları 0'a çevrilir; adaptör yapılandırması bunu set eder.

> **C-25 notu:** `|| true` yerine açık bir ortam bayrağı seçilmesinin nedeni, elle
> çalıştırmada hataların görünür kalması. `quipu remember` bozuk bir vault'ta sessizce
> 0 dönerse kullanıcı sorunu hiç öğrenemez.

### 4.3 Kurulum — installer YOK

- **C-26** FAZ 3 **`quipu install` komutu getirmez.** `~/.claude/settings.json` kullanıcının
  dosyasıdır, içinde başka araçların hook'ları vardır (bu makinede olduğu gibi) ve jq'suz
  güvenli JSON birleştirme gerçek bir risktir. Yapılan iş: parçacığı **göstermek**.
- **C-27** `README.md`'ye "Claude Code" bölümü eklenir: yapıştırılacak parçacık, `PATH` notu,
  Windows yol notu ve **§4.15 uyarısı**: *yapılandırma çalışan oturuma yüklenmez, Claude Code
  yeniden başlatılmalı.* Bu uyarı olmadan kullanıcı "çalışmıyor" diye geri dönecektir.
- **C-28** `quipu doctor` "ajan yüzeyleri" bölümü genişletilir: `~/.claude/settings.json`
  mevcutsa içinde `quipu` geçen bir hook komutu **var mı** diye bakılır ve
  `ok claude hooks: kurulu` / `warn claude hooks: kurulu değil` satırı basılır.
  JSON ayrıştırma **gerekmez**; `quipu` dizgesini aramak yeterli ve kırılgan değildir.

---

## 5. i18n anahtarları (hem `tr.txt` hem `en.txt`)

```
# remember
usage_remember
remember_ok             # %s = yazılan dosya
remember_empty
remember_git
digest_range            # %s = ilk ts, %s = son ts, %d = olay sayısı
digest_tools
digest_files
# context
ctx_truncated
ctx_precompact
# doctor
doc_hooks_installed
doc_hooks_missing
```

- **C-29** FAZ 2 B-24/B-25/B-26 aynen geçerli: tek satır `key=value`, `printf` formatı olan
  değerlerde kaçak `%` yok, iki dosyanın anahtar kümesi özdeş (test T-20 bunu zaten zorluyor).

---

## 6. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **E-0** | Ölçüm (§2): PreCompact/SessionEnd/SessionStart payload'ları, Ö-2 cevabı, `docs/FAZ3-BULGULAR.md`, PLAN §4'e yeni alt bölüm, fixture'lar | Ö-1…Ö-5 cevaplı; hangi dalın uygulanacağı yazılı |
| **E-1** | `lib/digest.awk` ortak toplayıcı + `context`'in ona taşınması (davranış **değişmez**) | mevcut 117 iddia aynen yeşil |
| **E-2** | `quipu remember` (§3.1-3.2), filigran, i18n, usage satırı | T-30…T-40 |
| **E-3** | `context` sınırlandırma (C-16/C-17) + seçilen dalın talimat mekanizması (C-18 **veya** C-19/C-20) | T-41…T-45 |
| **E-4** | `adapters/claude-code.json`, `doctor` hook kontrolü, `QUIPU_HOOK` sessiz-başarı | T-46…T-49 |
| **E-5** | README "Claude Code" bölümü, PLAN §6 FAZ 3 ✅, §9 güncellemesi | §8 |

**Neden E-1 önce:** FAZ 2'nin `_q_mdlist` dersi. Ortak toplayıcı, yeni davranış eklenmeden
**önce** çıkarılırsa bir regresyonun kaynağı belirsiz kalmaz.

---

## 7. Testler

Hook'lar CI'da tetiklenemez (Claude Code yok). Bu yüzden test stratejisi **iki katmanlı**:

### 7.1 CLI katmanı (otomatik, `tests/run.sh`)

| # | Test |
|---|---|
| T-30 | `remember` boş log'da çıkış 0, hiçbir dosya yazmıyor |
| T-31 | `remember` sindirimi `<sessions>/YYYY-MM-DD.md`'ye yazıyor, dosya var ve boş değil |
| T-32 | İkinci `remember` **aynı dosyaya ikinci bölüm** ekliyor, ilk bölüm aynen duruyor (C-8) |
| T-33 | Filigran çalışıyor: ilk `remember` sonrası yeni satır yokken ikinci `remember` boş çıkıyor |
| T-34 | Log rotasyonu sonrası (filigran satırı bulunamıyor) `remember` çökmüyor, tümünü işliyor (C-7) |
| T-35 | `Last-Session.md` bloğu tek, kullanıcı metni korunuyor, ikinci çalıştırma çoğaltmıyor (C-9) |
| T-36 | `--dry-run` stdout'a basıyor, **hiçbir dosya yazmıyor**, filigran değişmiyor (C-12) |
| T-37 | Sindirimdeki araç sayaçları ve dosya sayaçları elle kurulmuş log'la birebir eşleşiyor |
| T-38 | Dosya listesi `--limit` ile sınırlanıyor (C-15) |
| T-39 | `--git`: git olmayan vault'ta sessizce atlıyor, çıkış 0 (C-11) |
| T-40 | `--git`: git vault'ta commit atıyor; değişiklik yokken ikinci çağrı yine çıkış 0 |
| T-41 | `context` çıktısı `QUIPU_CTX_MAX` sınırını aşmıyor; aşan `Threads.md` kırpılıyor |
| T-42 | Kırpma satır sınırında: çıktı geçerli UTF-8, çok baytlı karakter ortadan kesilmemiş (C-17) |
| T-43 | Kırpılmış çıktıda `ctx_truncated` satırı var |
| T-44 | `context --json` kırpılmış bağlamla da geçerli JSON üretiyor (mevcut round-trip sürücüsüyle) |
| T-45 | Seçilen dala göre: talimat doğru koşulda çıkıyor, yanlış koşulda **çıkmıyor** (C-18 veya C-19/C-20) |
| T-46 | `adapters/claude-code.json` içinde `conhost` / `cmd.exe` / `.sh` geçmiyor (C-21/C-22) |
| T-47 | `adapters/claude-code.json` içindeki her `command` `quipu ` ile başlıyor, `shell` alanı `bash` |
| T-48 | `QUIPU_HOOK=1` iken vault'suz `remember` ve `capture` çıkış **0**; bayraksız çıkış **1** (C-25) |
| T-49 | `doctor` hook kontrolü: `quipu` geçen sahte bir settings.json'da `kurulu`, geçmeyende `kurulu değil` |

**Bağlayıcı test kuralları:**

- **C-30** FAZ 2 B-27/B-28/B-29/B-30 aynen geçerli. Özellikle **B-30**: çok baytlı dizge
  aranırken `grep` değil `awk index()` (PLAN §4.17). T-42 bunu doğrudan ilgilendiriyor.
- **C-31** `adapters/claude-code.json` testleri JSON ayrıştırmaz — dizge kontrolü yapar.
  Depoda JSON okuyucu yok ve bu iş için gerekmiyor.
- **C-32** T-40'ta `git commit` çağrılıyor: test `git -c user.email=… -c user.name=…` ile
  koşmalı, CI runner'larında global git kimliği yok.

### 7.2 Canlı katman (elle, bir kez, belgelenir)

- **C-33** Gerçek bir Claude Code oturumunda, **yeniden başlatılmış** olarak (§4.15):
  `SessionStart` bağlam enjeksiyonu görünüyor mu, `PostToolUse` `activity.log`'a satır
  düşürüyor mu, `SessionEnd` sonrası `<sessions>/` dosyası oluşmuş mu. Sonuç
  `docs/FAZ3-BULGULAR.md`'ye yazılır. **CI'nın yeşil olması bu adımın yerine geçmez.**

---

## 8. Belge güncellemeleri

- **C-34** `README.md`: "Claude Code" kurulum bölümü (C-27), komut listesine `quipu remember`.
- **C-35** `docs/PLAN.md`: §4'e ölçüm bulguları (yeni alt bölüm), §6 FAZ 3 ✅, §7 risk
  tablosunda `PostToolUse şeması` satırının yanına `PreCompact enjeksiyonu` → sonucu ne
  olduysa (KAPANDI / kapanmadıysa dürüstçe "ulaşmıyor, UserPromptSubmit'e düşüldü"),
  §9 durum + sıradaki (FAZ 4: Codex → OpenCode → Cursor/Windsurf).
- **C-36** `docs/FAZ3-BULGULAR.md` yeni dosya (FAZ0-BULGULAR.md deseninde).

---

## 9. Yasak desenler (devralınan + yeni)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine dayanan kod (§4.11) ·
ham kullanıcı verisini `awk -v` ile geçirmek (§4.16) · çok baytlı `sed` karakter sınıfı (§4.1) ·
çok baytlı `grep` kalıbı (§4.17) · tırnaksız yol değişkeni (FAZ 2 B-3) ·
**`conhost`/`cmd` sarmalayıcısı (§4.13)** · **hook `command`'ında doğrudan `.sh` (§4.14)** ·
**`~/.claude/settings.json`'ı programatik olarak düzenlemek (C-26)**

---

## 10. Çıkış koşulu

1. E-0 ölçümü yapılmış, `docs/FAZ3-BULGULAR.md` yazılmış, seçilen dal gerekçeli
2. `sh tests/run.sh` üç OS'ta yeşil (117 + yeni ~20 iddia)
3. `./.claude/tools/shellcheck.exe -s sh quipu tests/run.sh` temiz
4. Canlı katman (C-33) bir kez elle koşulmuş ve belgelenmiş
5. `adapters/claude-code.json` yasak desenlerden arınmış (T-46/T-47)
6. Dal + PR, üç OS CI yeşil olmadan merge yok

## 11. Kapsam dışı

- `quipu install` / settings.json birleştirme (C-26)
- Codex, OpenCode, Cursor, Windsurf adaptörleri → FAZ 4
- Hook'suz git-diff yakalama (`capture --git`) → FAZ 5
- MCP sunucusu → PLAN §3'te v1 dışı
