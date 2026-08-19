# FAZ 0 — Doğrulama Sonuçları

**Ölçüm tarihi:** 2026-08-19 · **Ortam:** Windows 11 Pro 26200, Git Bash,
Claude Code 2.1.235, GNU sed 4.9, GNU awk 5.4.0, git 2.55.0.windows.4

Durum kodları: ✅ doğrulandı · ❌ çürütüldü · ⏳ oturum yeniden başlatması gerekiyor

---

## Ö-1 ✅ Ortam envanteri (plan §4.10 doğrulandı)

| Araç | Durum |
|---|---|
| sh, bash, sed, awk, grep, tr, git, perl, stat, cygpath | ✅ var |
| `jq` | ❌ yok |
| `python3` | ⚠️ sadece WindowsApps stub'ı — **güvenilmez** |
| `node` v24, `rg` | var, ama opsiyonel sayılmalı |
| `shellcheck`, `checkbashisms` | ❌ yok → FAZ 6 CI'da kurulacak |

Plan §4.10 birebir doğru. Sıfır-bağımlılık hedefi bu makinede gerçekten gerekli:
`python3`'e dayanan bir tasarım (avenoxbeyin'in 1. hatası) burada **sessizce ölürdü**.

---

## Ö-2 ✅ Windows'ta `.sh` doğrudan çalıştırılamaz (plan §4.7 doğrulandı)

Claude Code hook'ları Node `child_process.spawn` ile başlatır. Birebir taklit edildi:

| Çağrı biçimi | Sonuç |
|---|---|
| `spawn("<...>/probe.sh", [...])` | ❌ **`EFTYPE` fırlatıyor**, süreç hiç başlamıyor |
| `spawn("bash", ["<...>/probe.sh", ...])` | ✅ exit=0, stdin tam geldi |
| `spawn("sh", ["<...>/probe.sh", ...])` | ✅ exit=0, stdin tam geldi |

**Sonuç:** hook `command` alanı **asla** doğrudan `.sh` olamaz. `command: "bash"` +
`args: ["<mutlak yol>", "<etiket>"]` deseni zorunlu. Sessiz başarısızlık değil, sert
hata — yani yanlış yapılandırma fark edilir (iyi haber).

Yeniden üretme: `.claude/faz0/` içindeki probe + spawn testi.

---

## Ö-3 ❌ Plan §4.8'deki awk JSON snippet'i olduğu gibi KULLANILAMAZ

Plandaki regex tabanlı `field()` fonksiyonu bir `.awk` dosyasına yazıldığında
patladı:

```
awk: fatal: invalid regexp: unbalanced [: /"hook_event_name"[[:space:]]*:[[:space:]]*"(\.|[^"\])*"/
```

**Kök neden:** ters-slash'lar her alıntılama katmanında (heredoc, kabuk, dosya yazımı)
yarıya iniyor. Kaynakta `\\` yazılan dizi dosyaya `\` olarak düştü, awk string
katmanı da bir kat daha yedi → regex bozuldu. Bu, quipu'nun **her katmanda** karşılaşacağı
bir tuzak; snippet "bir kere çalıştı" diye güvenilemez.

**Bu, §4.1'in (sed çok baytlı sınıf hatası) kardeşi: kaçış temelli kod kırılgan.**

### Düzeltme — kaçışa tamamen bağışık parser

Regex kullanmayan, elle tarayan bir sürüm yazıldı. Ters-slash **hiç literal olarak
yazılmıyor**, `sprintf("%c", 92)` ile üretiliyor → hiçbir alıntılama katmanı bozamaz.

Dosya: `.claude/faz0/jsonfield.awk`

Doğrulanmış çıktı (gerçekçi, doğru kaçışlı payload ile):

```
girdi : {"tool_name":"Edit","tool_input":{"file_path":"C:\Users\x\not.md"}}
çıktı : tool=[Edit] path=[C:\Users\x\not.md]
```

Ayrıca doğrulandı: `\"` → `"`, `\n` → gerçek satır sonu, `\t`, `\r`, UTF-8 (`ö`) korunuyor.
Bulunmayan alan boş dize döndürüyor (çökmüyor) — Katman 0 için doğru davranış.

**KURAL (§4.1'in genellemesi): kaçış dizilerine dayanan kod yazma. Ters-slash ve
çok baytlı karakterleri kod noktasından üret.**

Yan not: `awk -f prog.awk '{...}' dosya` çalışmaz — `-f` ile satır içi program
karıştırılamaz, satır içi metin dosya adı sanılır. Hep `-f` + `-f` kullan.

---

## Ö-4 ⏳ Hook config'i çalışan oturuma sıcak yüklenmiyor

`.claude/settings.json` proje içine yazıldı, ardından `PostToolUse` matcher'ına uyan
bir araç çağrıldı → **hiçbir capture düşmedi.**

Bu bir hata değil, kasıtlı güvenlik davranışı: hook yapılandırması oturum başında
okunuyor; aksi halde bir repo'yu açmak mid-session kod çalıştırabilirdi.

**Etkisi:** FAZ 0'ın kalan üç maddesi (`PostToolUse` şeması, `SessionStart` düz stdout,
`PreCompact` tetiklenmesi) **canlı ölçüm için oturum yeniden başlatması gerektiriyor.**
Bu, kullanıcı eylemi gerektiren gerçek bir engel.

Kurulum hazır ve bekliyor: `.claude/settings.json` + `.claude/faz0/probe.sh`
5 olayı da kaydediyor, ham stdin'i baytı baytına `capture-<olay>.jsonl` dosyalarına döküyor.

---

## Bekleyen maddeler

- [ ] `PostToolUse` stdin şeması — alanlar gerçekten `tool_name` / `tool_input.file_path` mi
- [ ] `SessionStart` düz stdout enjeksiyonu (§4.5) kurulu sürümde çalışıyor mu
- [ ] `PreCompact` tetikleniyor mu, stdout'u bağlama giriyor mu

---

## Ö-5 ⚠️ Canlı kanıt: `SessionStart` çıktısı bağlama GİRİYOR — ama iki farklı etiketle

Bu oturumun başında, bu makinede kurulu **iki ayrı** `SessionStart` hook'unun çıktısı
ana döngünün bağlamına düştü. İkisi farklı biçimde etiketlendi:

```
SessionStart:startup hook success: <ham terminal escape baytları>
```
```
SessionStart hook additional context: # claude-mem status ...
```

**Kesin olan:** bir hook'un ürettiği metin gerçekten bağlama ulaşıyor — §4.5'in
enjeksiyon yarısı canlı olarak doğrulandı, hiçbir şey kurmadan.

**Belirsiz olan:** ikinci hook düz stdout mu kullandı, yoksa JSON `additionalContext`
alanı mı? İki farklı etiket, iki farklı mekanizma olduğunu düşündürüyor. Eğer
"additional context" etiketi yalnızca JSON'la elde ediliyorsa, planın "JSON'a hiç
gerek yok" tezi (§4.5) — ki sıfır-bağımlılık sözünün dayanağı bu — **kısmen** yanlış olur.

Fark önemli: düz stdout `echo` ile yeter; JSON gerekiyorsa kaçış yapmak gerekir ve
Ö-3'te görüldüğü gibi kaçış bu projedeki en kırılgan şey. Yine de Ö-3'teki
`sprintf("%c",92)` tekniğiyle jq/python olmadan JSON üretmek mümkün — yani en kötü
durumda bile sıfır-bağımlılık korunur, sadece kod biraz büyür.

**Karar: FAZ 1'e geçmeden bu ayrım netleşmeli.** Probe her iki olayda da düz stdout
ile `QUIPU_FAZ0_MARKER` yazıyor; yeniden başlatmada bu satırın bağlamda görünüp
görünmediği soruyu kesin olarak yanıtlar.

---

## Ö-6 ✅✅ `PostToolUse` şeması DOĞRULANDI — planın 1 numaralı riski kapandı

Yeniden başlatmaya gerek kalmadı: Claude Code kendi transcript kayıtlarında
**gerçek bir hook payload'ı** saklıyor.

**Kaynak (gerçek yakalanmış payload, simülasyon değil):**
`~/.claude/projects/C--Users-SelmanBuilds-Desktop-GoodbyeDPI-Plus/b5792953-.../tool-results/hook-535a1bb5-...-stdout.txt`

Kendi `jsonfield.awk` parser'ımız bu gerçek payload'a uygulandı:

```
hook_event_name = [PostToolUse]
tool_name       = [Read]
file_path       = [C:\Users\SelmanBuilds\.claude\jobs\df68423a\tmp\taskbar_overflow.png]
cwd             = [C:\Users\SelmanBuilds\Desktop\GoodbyeDPI-Plus]
session_id      = [b5792953-f324-4dd1-9acb-d7e5f3d1a6c0]
transcript_path = [C:\Users\SelmanBuilds\.claude\projects\...jsonl]
permission_mode = [auto]
agent_type      = [general-purpose]
--- camelCase kontrolü ---
toolName=[] toolInput=[] hookEventName=[]        ← hepsi boş, doğru
```

**Sonuç: alan adları tam olarak `tool_name` ve `tool_input.file_path`. Hepsi
snake_case. camelCase varyant YOK.** Plan §6 FAZ 0'ın tek doğrulanmamış varsayımı
buydu — Katman 0 tasarımı olduğu gibi geçerli, git-diff fallback'ine inmeye gerek yok.

Bağımsız ikinci kaynak (kod, üretimde çalışan): claude-mem 13.15.2 adaptörü ham
stdin'den şunları okuyor — `session_id`, `cwd`, `prompt`, `tool_name`, `tool_input`,
`tool_response`, `transcript_path`, `agent_id`, `agent_type`; ayrıca
`permission_mode`, `model`, `turn_id`, `stop_hook_active`, `last_assistant_message`,
ve `SessionStart` için `source` (`startup|resume|clear`).

### Katman 0 için ek uyarı: payload ÇOK büyük olabilir

Ölçülen bu payload **458 KB** — çünkü `tool_response` bir görüntünün base64'ünü
taşıyordu. `quipu capture` asla tüm stdin'i belleğe alıp işlememelidir; ihtiyaç
duyduğu alanlar (`tool_name`, `tool_input.file_path`) baştadır, `tool_response`
sondadır. Kural: **ilk eşleşmede dur, `tool_response`'a hiç dokunma.**
(`activity.log` şişmesi riski planda §7'de zaten var; bu onun ikizi.)

---

## Ö-7 ✅ `conhost.exe --headless` hook deseni payload'ı BOZUYOR — kullanılmayacak

Yukarıdaki 458 KB'lık dosya 3446 satır çıktı. Nedeni JSON değil: akışa
**3456 ANSI escape baytı** ve **3446 adet imleç konumlandırma dizisi**
(`ESC[29;120H`) karışmış. Kaynak, bu makinenin global `settings.json`'ındaki
`conhost.exe --headless cmd.exe /d /c ...` sarmalayıcısı.

Ve sadece gürültü değil — **veri bozuluyor.** Escape'ler temizlendikten sonra:

```
"tool_use_id":"toolu__015hFqYvgmSCUQuGojU1L5QR"
              └─ çift alt çizgi; gerçek değer toolu_015hFq...
```

Satır kaydırma sınırında karakter tekrarlanıyor. 3446 kaydırmanın her birinde.

**KURAL: quipu hook'ları asla conhost/cmd sarmalayıcısı üzerinden çalıştırılmaz.**
Doğru desen, üretimde kanıtlanmış olan (claude-mem 13.15.2 `hooks/hooks.json`):

```json
{ "type": "command", "shell": "bash", "command": "<sh komutu>",
  "timeout": 120, "async": true }
```

`shell: "bash"` gerçek ve desteklenen bir alan (plan §4.7 doğru). Ağır iş için
`async: true`. Alternatif olarak Ö-2'deki `command: "bash"` + `args: [<yol>]` deseni.

> Yan not: claude-mem'in kendi kodunda ANSI escape'leri çıktıdan silen bir regex var
> — aynı sorunu onlar da yaşamış.

---

## Ö-5 (kapandı) ✅ Bağlam enjeksiyonu: JSON yolu kesin, düz stdout yolu farklı etiketleniyor

claude-mem düz stdout kullanmıyor; **JSON** döndürüyor:

```js
{ continue: true, suppressOutput: true,
  hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: <metin> } }
```

Oturum başındaki iki farklı etiketin açıklaması bu:
- `hook additional context:` → JSON `hookSpecificOutput.additionalContext` yolu (temiz, amaçlanan yol)
- `hook success: <ham baytlar>` → düz stdout; bağlama ulaşıyor, ama "hook başarılı" raporu olarak

**Etkisi planın §4.5 tezine:** "JSON'a hiç gerek yok" iddiası fazla iyimser.
Düz stdout gerçekten bağlama ulaşıyor, ama temiz enjeksiyon için küçük bir JSON
zarfı gerekiyor. **Sıfır bağımlılık yine de korunuyor** — Ö-3'teki
`sprintf("%c",92)` tekniğiyle jq/python olmadan JSON *yazmak* da mümkün.

→ **FAZ 1'e bir iş kalemi eklendi: `jsonfield.awk`'ın ikizi olan bir JSON
   *yazıcı* (`jsonemit.awk`) da gerekiyor** — `"`, `\`, satır sonu ve kontrol
   karakterlerini kaçıran. Okuyucu kadar kritik.

---

# FAZ 0 KARARI

| # | Madde | Sonuç |
|---|---|---|
| 1 | `PostToolUse` şeması `tool_name` / `tool_input.file_path` mi | ✅ **DOĞRULANDI** (gerçek payload) |
| 2 | `SessionStart` çıktısı bağlama giriyor mu | ✅ evet — JSON yolu kesin, düz stdout farklı etiketle |
| 3 | `PreCompact` tetikleniyor mu | ⏳ yeniden başlatma gerekiyor (FAZ 3'ü etkiler, FAZ 1'i değil) |
| 4 | Windows'ta `.sh` çalıştırma | ✅ **DOĞRULANDI** — doğrudan `.sh` = EFTYPE; `bash <yol>` veya `shell:"bash"` şart |

**Plan §9 adım 3 uyarınca: şema onaylandı → FAZ 1'e geçilebilir.**
Katman 0'ı git-diff fallback'ine indirgemeye gerek yok.

### FAZ 0'ın plana getirdiği değişiklikler

1. §4.8'deki awk snippet'i **silinmeli**, yerine `jsonfield.awk` (Ö-3).
2. §4.5'in "JSON gerekmiyor" tezi **yumuşatılmalı**; `jsonemit.awk` FAZ 1 kapsamına eklendi (Ö-5).
3. Yeni kural, §4.1'in genellemesi: **kaçış dizilerine dayanan kod yazma; ters-slash'ı
   kod noktasından üret** (Ö-3).
4. Yeni kural: **conhost/cmd sarmalayıcısı yasak**, `shell:"bash"` kullan (Ö-7).
5. `quipu capture` büyük payload'a karşı korunmalı: ilk eşleşmede dur, `tool_response` okuma (Ö-6).
