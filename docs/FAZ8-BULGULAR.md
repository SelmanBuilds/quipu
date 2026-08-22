# FAZ 8 — Bulgular (Dilim 0)

**Kaynak yöntemi:** Bulgular **repo içi kod okuması + bu makinede canlı komut koşumu**
kaynaklıdır; her biri kesin `dosya:satır` referansı taşır. Satır numaraları commit
`ecca473` (FAZ 7 + yerleşim, **FAZ 8 uygulanmadan önceki** çalışma ağacı) içeriğinden
alınmıştır — `git show ecca473:quipu` ile doğrulandı, çalışma ağacındaki `quipu`'dan değil
(orada FAZ 8 zaten uygulanmış durumda, satır numaraları kaymış). İddia etiketi:
`[kaynak: …]` = repo'da doğrulanabilir; `[ölçüm: bu makine]` = commit `ecca473`'ün geçici
bir kopyası (`git archive ecca473`) üzerinde bu oturumda fiilen koşulup gözlenen davranış;
`[doğrulanmadı]` = bu makinede doğrulanamadı, kaynağı ayrıca belirtilir.

**Sözleşme karşılığı:** Bu dosya `FAZ8-SPEC` §1'deki S-1…S-5'i resmileştirir. Sayılar S-1…
S-5; `FAZ7-BULGULAR`'ın L-n'leriyle, `FAZ6-BULGULAR`'ın G-n'leriyle çakışmaz.

---

## S-1 — `remember` yalnız mekanik yazıyor; not içeriği hiçbir yere sızmıyor

`[kaynak: quipu:875, quipu:879, i18n/en.txt:71-73]` `[ölçüm: bu makine]`

Oturum dosyasına yazılan gövde `lib/digest.awk`'ın ürettiği `RANGE`/`TOOL`/`FILE` olgu
satırlarından ve üç i18n başlığından (`digest_range`, `digest_tools`, `digest_files`,
`i18n/en.txt:71-73`) kurulur; ekleme `cat "$_q_body" >> "$_q_v/$_q_rel"` ile **append**'tir
(`quipu:875`). `Last-Session.md` bu dosyanın yoluna işaret eden tek satırlık bir
işaretçidir, `lib/block.awk`'ın varsayılan `<!-- quipu:start -->`/`<!-- quipu:end -->`
markerleriyle yazılır (`quipu:879`).

**Ölçülmüş örnek:** `ecca473`'ün geçici bir kopyasında (`git archive ecca473`) taze bir
vault kurulup `capture --event PostToolUse --tool Read --path gizli.md` ve
`--tool Write --path gizli.md` koşuldu, `gizli.md` dosyasına `gizli sirdir
supersecrettoken123` yazıldı, ardından `QUIPU_LANG=en remember` çalıştırıldı. Oturum
dosyasının tam içeriği:

```
## 12:30
Range: 2026-08-22T12:30 → 2026-08-22T12:30 (2 events)
Tools: Read 1, Write 1
Touched files (top 10):
  -  2  gizli.md
```

`Last-Session.md`:

```
<!-- quipu:start -->
2026-08-22 · 2 events · 📆 700-Sessions/2026-08-22.md
<!-- quipu:end -->
```

Vault'un tamamında `grep -rn "gizli sirdir\|supersecrettoken123"` yalnız `gizli.md`'nin
kendisinde eşleşti — dosya adı ve olay sayısı dışında not **içeriği** hiçbir çıktıya
sızmadı.

**Etki:** Y-1'in "yansıma bloğu" tam olarak bu boşluğu — modelin ürettiği *anlamın*
mekanik defterin hiçbir yerine yazılmaması — hedef alır. T-96 (ilk `remember`'da blok var,
başlıklar i18n'den) bu bulgunun doğrudan devamıdır; regresyon kapısı (SPEC §8.2) bu ölçülen
mekanik çıktının **değişmediğini** ister.

## S-2 — `Threads.md` tohumlanıyor ve okunuyor ama hiçbir şey güncellemiyor

`[kaynak: quipu:573-574, quipu:638, quipu:672-685, i18n/en.txt:94-95]`

`Threads.md`'ye dokunan iki yer var: `init` dosya yoksa `threads_seed_title` +
`threads_seed_note` başlıklarıyla oluşturuyor (`quipu:573-574`, anahtarlar
`i18n/en.txt:94-95`); `_q_ctx_text` (`quipu:638`) bağlam metnini kurarken dosyayı
`cat`'liyor (`quipu:672-685`, `685`: `cat "$_q_v/Threads.md"`). Repo genelinde (`quipu` +
`lib/*.awk`) bu ikisi dışında `Threads.md` dizgesi geçmiyor — **hiçbir komut dosyayı
güncellemiyor**, yalnız okuyor. Dosya modelin serbest metin yazdığı, quipu'nun asla
dokunmadığı bakımsız bir defter.

**Etki:** SPEC §9 kapsam dışı listesi bunu açıkça bırakıyor ("`Threads.md`'yi quipu'nun
güncellemesi — modelin işi kalır"); Y-6'nın `AGENTS.md` protokol paragrafı modele bu
sorumluluğu **açıkça** hatırlatır (T-107), ama dosyanın kendisi bu fazda da bakımsız kalır.

## S-3 — Hatırlatma mekaniği zaten var; eksik olan "yazdı mı?" tespiti

`[kaynak: quipu:736-763, i18n/en.txt:65]`

`remember`/`context` zincirinde nudge mantığı tam kurulu: `QUIPU_NUDGE_AFTER` (varsayılan
50, `quipu:736`), toplam log satırı ile iki filigran arasındaki fark (`quipu:737-746`:
`.quipu/remembered` ve `.quipu/nudged`), eşik aşıldığında `ctx_precompact` mesajının basılıp
`.quipu/nudged`'in güncellenmesi (`quipu:747-763`) — hepsi yalnız `--json UserPromptSubmit`
olayında (`quipu:735`). Mesajın FAZ 8 öncesi metni: *"update Threads.md and append today's
session summary to the %s folder"* (`i18n/en.txt:65`). Bu mekanik **ne zaman** hatırlatacağını
biliyor (satır eşiği); ama modelin hatırlatılan şeyi **fiilen yaptığını** hiçbir şekilde
denetlemiyor — "hatırlat" var, "doğrula" yok.

**Etki:** Y-3 (yakalayıcı) ve Y-2 (doluluk tespiti) tam bu boşluğu kapatıyor: hatırlatma
mekaniğine dokunulmadan (watermark ikilisi, eşik, olay tetiği aynen kalır), üstüne "önceki
oturum bloğu boş kaldıysa" tespiti eklenir. Y-4 `ctx_precompact` metnini yansıma bloğuna
işaret edecek şekilde günceller (T-106) — SPEC §8.2 regresyon kapısı nudge eşiğinin ve
filigran mekaniğinin **davranışça** değişmediğini şart koşar, yalnız mesaj metni değişir.

## S-4 — `lib/block.awk` idempotent marker primitifi zaten var ve hedef marker değiştirilebilir

`[kaynak: lib/block.awk:12-16, quipu:772, quipu:879, quipu:606]`

`lib/block.awk` stdin'den okuduğu gövdeyi `start`/`end` markerleri arasına idempotent
şekilde yazıyor; marker yoksa dosya sonuna ekliyor, varsa aralığı değiştiriyor, marker
dışındaki her satırı aynen koruyor (`lib/block.awk:12-16`, doğrulandı: `BEGIN { if
(start == "") start = "<!-- quipu:start -->" ... }`). Üç kullanım yeri farklı marker
seçimiyle aynı primitifi paylaşıyor:

- `context --bridge`, özel marker çiftiyle (`-v start='<!-- quipu:context:start -->' -v
  end='<!-- quipu:context:end -->'`, `quipu:772`),
- `remember`'ın `Last-Session.md`'si, varsayılan markerle (`-v` yok, `quipu:879` —
  yukarıdaki ölçümde doğrulandı: çıktıda `<!-- quipu:start -->`/`<!-- quipu:end -->`),
- `init`'in `AGENTS.md` köprü gövdesi, yine varsayılan markerle (`quipu:606`).

**Etki:** Y-1'in yansıma bloğu bu primitifi **kullanamıyor** (S-4'ün kendisi bunu
işaretliyor): `block.awk`'ın semantiği *değiştir*, yansıma bloğunun ihtiyacı ise
*yalnız-yoksa-ekle* (aynı gün ikinci `remember` modelin yazdığını silmemeli). Bu yüzden
Y-1 kendi tespitini (`quipu:reflect:start` marker'ının varlığı) kurup `block.awk`'ı
bilinçli olarak devre dışı bırakıyor; T-97 tam bunu kilitliyor (yazılan satır korunuyor,
marker sayısı 1'de kalıyor).

## S-5 — avenoxbeyin'in dört kırık yolu `[doğrulanmadı — kaynak: FAZ8-SPEC §1 S-5, 2026-08-22 incelemesi]`

Bu bulgu FAZ8-SPEC'in kendisinde iddia ediliyor (`github.com/avenoxai/avenoxbeyin`,
`template/.claude/hooks/session-start.sh`, `prompt-counter.sh`, `session-end.sh`,
`template/CLAUDE.md`), ama repo bu makinede **yerel olarak klonlu değil** —
`C:\Users\SelmanBuilds\Projects` altında ve ev dizininin ilk beş seviyesinde
`*avenoxbeyin*` adlı hiçbir dizin bulunamadı (`find` taraması bu oturumda koşuldu, sıfır
sonuç). Repoyu ağdan çekmek bu görevin kapsamı dışında bırakıldı. Dolayısıyla aşağıdaki
dört iddia **bu oturumda doğrulanmadı**, yalnız SPEC'in kendi metninden aktarılıyor:

1. JSON kaçışının `python3 -c json.dumps`'a yaptırılması, `python3` yoksa hook'un sessizce
   hiçbir şey basmaması (exit 0).
2. `session-end.sh`'te `stat -f %m` kullanımının BSD-only olması, Git Bash'te kırılıp
   `MODIFIED=0`'a sabitlenmesi.
3. Bağlam dizgisinde çift tırnak içinde yorumlanmayan literal `\n` bulunması.
4. Okuyucunun `sed -n '/^## Session:/,/^## Previous/p'` aralığına, yazan tarafın ise
   serbest metin yazan modele bağlı olması — marker'sız prosa sözleşmesi.

**Bu belgenin bir eksiği olarak açıkça not düşülüyor:** bu dört madde, repo klonlanıp
fiilen incelendiğinde `[kaynak: <dosya>:<satır>]` etiketiyle yeniden doğrulanmalı; o ana
kadar S-5 **kanıtsız bir tasarım gerekçesi** olarak kalıyor.

**Etki:** S-5'in doğruluğundan bağımsız olarak, quipu tarafında **doğrulanabilir** bir
karşı-örnek var: `python3` çalışma ağacında hiç geçmiyor (`grep -c python3 quipu` → `0`,
commit `ecca473`), doğrudan `stat` çağrısı yalnız `mtime()` sarmalayıcısında ve `doctor`
tanı çıktısında geçiyor (`quipu:130`, `quipu:183-188`; toplam altı `stat ` eşleşmesi,
`ecca473` içinde ölçüldü) ve `lib/*.awk` + `quipu` içinde literal ters bölü yok (mevcut
hijyen testi bunu zaten kilitliyor). Bu fazın tasarım kısıtı — **yazar/okuyucu sözleşmesi
prozayla değil marker'la zorlanır** — S-5'in iddia ettiği dördüncü kırığa (marker'sız
prosa) karşı Y-1'in `<!-- quipu:reflect:start/end -->` marker çiftiyle doğrudan cevap
veriyor; T-108 `python3` yokluğunu ve `stat` sayımının sabit kaldığını statik olarak
kilitler.

---

## Tasarım etkileri (S → Y eşlemesi)

| Bulgu | Sözleşme maddesi | Ne gerektiriyor |
|---|---|---|
| S-1 | Y-1 | Mekanik çıktı değişmeden, yoksa eklenen bir yansıma bloğu; not içeriği hâlâ hiçbir yere sızmaz |
| S-2 | Y-6 (dolaylı) | `Threads.md` bu fazda da güncellenmiyor; Y-6 modele sorumluluğu i18n metniyle hatırlatır |
| S-3 | Y-2, Y-3, Y-4 | Mevcut nudge eşiği/filigranları aynen kalır; üstüne doluluk tespiti + tek atış yakalayıcı + güncel istem metni eklenir |
| S-4 | Y-1 | `block.awk`'ın *değiştir* semantiği yansıma bloğu için kullanılamaz; ayrı, yalnız-yoksa-ekle tespiti gerekir |
| S-5 | Y-1, Y-5, Y-6 | Tasarım kısıtı: sözleşme marker'la zorlanır, prozayla değil; `python3`/`stat`/`\n` kırıklarının hiçbiri quipu'da tekrarlanmaz |

## Test malzemesi (T-96…T-108 için)

- **Blok yaşam döngüsü (T-96…T-100):** S-1'in ölçülen vault kurma deseni yeniden kullanılır
  (`mkvault` + `capture --event … --tool … --path …` flag modu, FAZ 6/G-4'ün hermetic
  yaklaşımıyla aynı) — fixture JSON gerekmez. Doluluk tespiti (T-99/T-100) marker aralığını
  `awk` ile okur, `_q_reflect_filled` tek yerde yaşar (Y-2); ikinci `remember` testinde
  (T-97) marker sayımı `grep -c` ile doğrulanmalı (S-4'ün "değiştirme değil ekleme"
  ayrımının kanıtı).
- **Yakalayıcı (T-101…T-104):** `.quipu/needs_reflection` dosyasının varlığı/yokluğu ve
  tek atışlığı (T-103) mevcut `.quipu/remembered`/`.quipu/nudged` filigran desenine paralel
  kurulur (S-3, `quipu:739`); `mtime` hiçbir iddiada kullanılmaz — bu, S-5.2'nin BSD/GNU
  `stat` kırığından kaçınmanın doğrudan kanıtıdır.
- **İstem ve metin kilitleri (T-105…T-107):** `QUIPU_LANG=en` altında `ctx_reflect_ask` ve
  güncel `ctx_precompact` metinleri `i18n/en.txt`'ten okunup karşılaştırılır (FAZ7/DZ-4
  desenindeki gibi). T-107 `AGENTS.md` köprü gövdesinde ham `reflect_`/`ctx_reflect`
  anahtarının **görünmediğini** doğrular — i18n çözümlemesinin gerçekten çalıştığının
  kanıtı.
- **Statik dürüstlük kapıları (T-108):** `grep -c python3 quipu` → `0` sabiti; `stat `
  eşleşme sayısı bu belgede ölçülen değere (altı) kilitlenir; mevcut literal-ters-bölü
  hijyen testi (PLAN 4.11) yansıma metinleriyle bozulmamalı.

---

## Kapanış notu — yazım sırası

Bu belge Dilim 0'ın çıkış koşulu olarak tanımlanmış olsa da (SPEC §6), fiilen **geriye
dönük** yazıldı: FAZ 8'in kodu ve testleri (Y-1…Y-6, T-96…T-108) bu belge yazılmadan önce
çalışma ağacında zaten uygulanmıştı — henüz commit edilmemiş hâlde (`git status --short`
çıktısında `quipu`, `i18n/en.txt`, `i18n/tr.txt` değişiklik olarak görünüyor). Yukarıdaki
S-1…S-5 bulguları bu sıralamadan etkilenmemesi için özenle commit `ecca473`'ün (FAZ 8
uygulanmadan önceki durum) içeriğinden doğrulandı, çalışma ağacından değil — ama sıralamanın
kendisi SPEC'in öngördüğü "önce bulgu, sonra kod" akışını tersine çevirdi. Bu tutarsızlık
burada açıkça kayda geçirilmiştir.
