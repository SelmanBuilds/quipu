# avenoxbeyin karşılaştırması — sentez

> **Bu belge bir sözleşme değil, bir sentez belgesidir.** Uygulama sözleşmesi olan dört
> belge `docs/FAZ8-SPEC.md`, `docs/FAZ9-SPEC.md`, `docs/FAZ10-SPEC.md` ve
> `docs/V1-DUZELTME-SPEC.md`'dir; bu dosya onları tek yerde okunur hale getirir, yeni bir
> karar eklemez. Bir satır değiştiğinde doğru olan sözleşme dosyasıdır, bu belge değil.

## Yöntem notu — ne doğrulandı, ne doğrulanmadı

**avenoxbeyin tarafı:** `github.com/avenoxai/avenoxbeyin` bu turda **yerel olarak klonlu
değil** — `C:\Users\SelmanBuilds` altında (`Projects` dahil, ilk beş dizin seviyesi)
`*avenoxbeyin*` adlı hiçbir dizin bulunamadı (bu oturumda `find` ile tarandı, sıfır sonuç);
dolayısıyla `remote.origin.url` ile doğrulama adımı da uygulanamadı — doğrulanacak bir klon
yok. Ağdan yeniden çekmeye çalışılmadı (görev kapsamı dışı, uydurma yasak). Bu yüzden
avenoxbeyin hakkındaki **her** iddia ikinci-el etiketlidir:
`[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-5, 2026-08-22 incelemesi]` (veya ilgili
diğer spec'in bulgu bölümü). Bu iddiaların birincil kaynağı 2026-08-22'de yapılan tek
seferlik bir inceleme oturumu; repo klonlanıp yeniden okunmadan bunlar kanıtlı sayılamaz —
`docs/FAZ8-BULGULAR.md`'nin S-5 maddesi de aynı sınırı aynı gerekçeyle not düşüyor.

**quipu tarafı:** Aşağıdaki her `[kaynak: quipu:satır]` etiketi bu belgenin yazıldığı anda
`git show HEAD:quipu` ile üretilmiş bir geçici kopya üzerinden **fiilen doğrulandı**
(HEAD = `ecca473`, "docs: tasarım kaydını takibe al" commit'i, dosya 1060 satır). Çalışma
ağacındaki `quipu` bu commit'ten sonra değişmiş durumda (FAZ 8/9 kısmi kod, `git status`ta
`M quipu`) — bu belgedeki satır numaraları o değişikliği **görmez**, yalnız `ecca473`'ü
yansıtır. Bu yüzden aşağıdaki tabloda "durum" hücresi, kodun **commit'lenmiş** olup
olmadığını ayrı bir eksen olarak taşır: bir sözleşme maddesi kodlanmış olabilir ama henüz
`HEAD`'de değildir.

Etiket sözlüğü (`docs/FAZ7-BULGULAR.md:9-10` ile aynı):
`[kaynak: …]` = repo'da doğrulanabilir · `[ölçüm: …]` = bu makinede koşturulup görülmüş ·
`[doğrulanmadı]` = bu turda doğrulanamadı, ikincil kaynağı belirtilir.

---

## 1. Ana tablo — avenoxbeyin avantajı → quipu karşılığı

| avenoxbeyin özelliği | ne sağlıyor | quipu'da karşılığı | hangi sözleşme/faz | durum |
|---|---|---|---|---|
| Oturum sonu yansıma/hafıza yazımı | Modelin oturum sonunda "ne oldu / nereye vardı" yazması için ayrılmış bir alan `[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-5]` | `<!-- quipu:reflect:start/end -->` marker bloğu; `remember` yalnız-yoksa ekler, model doldurur, ikinci `remember` silmez | FAZ8-SPEC Y-1 (§2) | **commit'siz** — kod+testler yazılmış, `docs/PLAN.md:766`'ya göre `FAZ8-BULGULAR.md` da eksikti (bu tur içinde başka bir ajan tarafından dolduruldu), suite yeşil doğrulanmadı |
| Oturum başı bağlam enjeksiyonu | Yeni oturuma önceki oturumun özeti otomatik basılır `[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-5]` | `quipu context --json SessionStart` zaten var ve **commit'li**: `_q_ctx_text` (`quipu:638-705`) activity + index + Threads.md'yi QUIPU_CTX_MAX sınırıyla birleştirip basıyor | FAZ 3-6 (temel), FAZ8-SPEC Y-3/Y-4 üstüne ekliyor | **temel: yapıldı** (HEAD'de çalışıyor) · **yansıma-eksikliği uyarısı (Y-3/Y-4): commit'siz** |
| Prompt sayacı ile hatırlatma | N istemde bir "hafızanı yaz" hatırlatması `[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-3]` | `QUIPU_NUDGE_AFTER` (varsayılan 50) + `.quipu/remembered`/`.quipu/nudged` filigranları, `ctx_precompact` mesajı (`i18n/en.txt:65`) | zaten var, FAZ 5/6 | **yapıldı ve commit'li** — HEAD'de `i18n/en.txt:65` doğrulandı: `ctx_precompact=Context may be compacted: write your memory now — update Threads.md and append today's session summary to the %s folder.` |
| `CLAUDE.md` protokolü | Ajana hafıza disiplinini anlatan sabit metin `[doğrulanmadı — kaynak: docs/FAZ9-SPEC.md §1 U-4]` | `AGENTS.md`/`CLAUDE.md` köprü bloğu, `block.awk` ile idempotent yazılıyor (`quipu:606`, `quipu:610`, HEAD'de doğrulandı); hafıza protokolü paragrafı i18n'den (`bridge_reflect`) eklenecek | FAZ8-SPEC Y-6 | **köprü mekanizması: yapıldı, commit'li** · **hafıza protokolü paragrafı: commit'siz** (çalışma ağacında `bridge_reflect` referansı var ama bu HEAD'de değil) |
| Kurulum runbook'u (`SETUP.md`) | Tek yapıştırmalık mülakat + kurulum + doğrulama akışı `[doğrulanmadı — kaynak: docs/FAZ9-SPEC.md §1 U-4]` | `docs/KURULUM.md` — 5 fazlı ajan runbook'u (mülakat → kurulum → kimlik → ajan bağlama → indeks+doğrulama), platforma özgü araç yok | FAZ9-SPEC V-1 (§2) | **bekliyor** — `docs/PLAN.md:747`'ye göre bu tur başında hiç yazılmamıştı; bu bulgunun **kendisi** bu dosyanın yazıldığı ajan turunda değil, ayrı bir tur için ayrılmış iş |
| Kimlik/persona kişiselleştirme | Kurulumda kullanıcı adı + AI ortağı adı sorulup şablona basılıyor `[doğrulanmadı — kaynak: docs/FAZ9-SPEC.md §1 U-4]` | `persona/en.md`/`persona/tr.md` zaten **veri**; `init --user`/`--companion` iki `%s` yer tutucusunu `printf` ile doldurur, `.quipu/config`'e `user=`/`companion=` yazar (yalnız-yoksa) | FAZ9-SPEC V-2/V-3/V-4 (§3) | **commit'siz** — kod yazılmış (`docs/PLAN.md:767`), HEAD'de `--user`/`--companion` bayrağı **yok** |
| Klasör taksonomisi | Sabit, adlandırılmış klasör hiyerarşisi `[doğrulanmadı — kaynak: docs/PLAN.md:742]` | `layout/emoji.txt` + `layout/plain.txt` (slug\tad), `init` bunlardan on klasör üretiyor; 2026-08-22 yerleşim güncellemesiyle avenoxbeyin taksonomisine yaklaştırıldı (`docs/PLAN.md:742`) | zaten var, FAZ 6 yerleşim dilimi | **yapıldı ve commit'li** |
| Obsidian uyumu | frontmatter (`title/created/modified/type/status/tags`), `[[wikilink]]`, durum emojisi alfabesi, Dashboard hub `[doğrulanmadı — kaynak: docs/FAZ10-SPEC.md §1 W-5]` | `index.tsv` şeması 7 sütuna çıkar (`status`/`type` eklenir), `search --tag/--status`, `lib/index.awk mode=links` + `quipu links`, `layout/status.txt` (durum verisi) | FAZ10-SPEC Z-1…Z-7 | **hiç başlanmadı** — `docs/PLAN.md:768`: "bekliyor — hiç başlanmadı; V1-DUZELTME zorunlu önce" |

## 2. Quipu'nun avenoxbeyin'den üstün olduğu yerler — dört kırık yol

`docs/FAZ8-SPEC.md §1 S-5` avenoxbeyin'in aynı işi (oturum sonu yazım + oturum başı okuma)
yaparken dört yerden kırıldığını iddia ediyor. Bu iddialar avenoxbeyin tarafında
**doğrulanmadı** (repo klonlu değil — yukarıdaki yöntem notu); ama karşı tarafta, yani
quipu'nun **aynı işi nasıl yaptığı**, bu turda HEAD (`ecca473`) üzerinde fiilen doğrulandı.
Tablo, iddia edilen kırığı quipu'nun ölçülmüş karşı-önlemiyle eşleştiriyor:

| avenoxbeyin'in iddia edilen kırığı | quipu'nun ölçülmüş karşı-önlemi |
|---|---|
| `python3 -c json.dumps`'a bağımlı JSON kaçışı; `python3` yoksa hook sessizce hiçbir şey basmıyor `[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-5.1]` | `python3` dizgesi `quipu`'nun HEAD sürümünde **hiç geçmiyor** — `grep -c python3` = 0 (bu turda doğrulandı, `ecca473`). JSON alan çıkarımı `lib/jsonfield.awk` ile saf awk'ta yapılıyor; harici yorumlayıcı yok, dolayısıyla "yoksa sessiz başarısızlık" sınıfı bir hata quipu'da tanımsız |
| `session-end.sh`'te `stat -f %m` doğrudan çağrısı — BSD-only, Git Bash'te kırılıp `MODIFIED=0`'a sabitleniyor `[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-5.2]` | quipu'da doğrudan `stat -f`/`stat -c` çağrısı **yalnız** `mtime()` sarmalayıcısında (`quipu:130`, HEAD'de doğrulandı: `mtime() { stat -c %Y "$1" 2>/dev/null \|\| stat -f %m "$1" 2>/dev/null \|\| echo 0; }`) ve `doctor` tanı çıktısında (`quipu:183-188`) var — ikisi de GNU/BSD'yi sırayla dener, ikisi de düşerse `0`/uyarı döner, hiçbiri sabit yanlış değere düşmez. Toplamda `grep -c 'stat '` 6 satır döndürüyor (130, 183-186, 188), hepsi bu iki noktada — `tests/run.sh` T-108 bu sayıyı 6'ya sabitliyor. Ayrıca FAZ8-SPEC'in tasarım kısıtı (§0, §3 Y-2), yansıma bloğunun doluluk tespitini **hiç `mtime` kullanmadan** yapmayı zorunlu kılıyor — S-5.2'nin sınıfını kaynağında kapatan bir karar |
| Bağlam dizgisinde çift tırnak içinde yorumlanmayan literal `\n` — modele iki karakterlik `\n` çöpü gidiyor `[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-5.3]` | quipu bağlam metnini shell string birleştirmesiyle **gerçek** satır sonlarıyla kurar: `_q_ctx_text` içindeki `_q_add_act()`/`_q_add_idx()` yardımcıları `_q_act="${_q_act}${1}` satırının hemen ardından kaynak dosyada **fiziksel bir satır sonu** bırakıp kapanış tırnağını bir sonraki satıra koyuyor (`quipu:647-649`, `quipu:661-663`, HEAD'de doğrulandı) — yani ara değişkenlerde literal `\n` iki karakteri hiç oluşmuyor, gerçek `0x0A` bayt kullanılıyor. Ayrıca test paketi bunu genel olarak kilitliyor: "no literal backslash in shipped sources" (`tests/run.sh:120-121`, HEAD'de doğrulandı: `awk 'index($0, sprintf("%c", 92)) != 0 {...}'` — çıktı boş olmalı) |
| Marker'sız prosa sözleşmesi — okuyucu `sed -n '/^## Session:/,/^## Previous/p'` aralığına bağlı, yazan taraf serbest metin yazan model, başlık değişirse devamlılık sessizce ölüyor `[doğrulanmadı — kaynak: docs/FAZ8-SPEC.md §1 S-5.4]` | quipu'nun tüm ekleme/köprü noktaları `lib/block.awk`'ın idempotent marker sözleşmesiyle çalışıyor: `<!-- quipu:start -->`/`<!-- quipu:end -->` (varsayılan) veya `-v start=/end=` ile hedeflenmiş marker (`quipu:606,610,772,879`, hepsi HEAD'de doğrulandı) — okuma da yazma da **aynı** literal marker dizgesine bağlı, prozaya değil. Bu sözleşme FAZ 5'ten beri test kilitli: `tests/run.sh:946-953`'te T-68 (`-v` override marker'ı değiştiriyor) ve T-71 (varsayılan marker aynen korunuyor) HEAD'de doğrulandı. FAZ8-SPEC bu deseni yansıma bloğu için de öngörüyor, ama **`block.awk`'ın kendisiyle değil** — çünkü onun "değiştir" semantiği modelin yazdığını silerdi (S-4); bunun yerine ayrı bir "yalnız-yoksa-ekle" tespiti kullanılıyor (Y-1) |

## 3. Kasıtlı olarak alınmayan kalemler ve gerekçeleri

- **mem0 / harici semantik katman** — `docs/FAZ8-SPEC.md §9` ve `docs/FAZ9-SPEC.md §9`
  ikisi de açıkça kapsam dışı bırakıyor. Gerekçe `docs/PLAN.md §1`'deki temel tezi bozmamak:
  "Semantik katman = zaten oradaki modelin kendisi. Vektör veritabanı satın almaya gerek
  yok" (README "Why it's free" bölümünün de birebir dile getirdiği karar, HEAD'de
  doğrulandı). Harici bir semantik servis eklemek bu tezi **iptal eder**, tamamlamaz.
- **`Last-Session.md`'yi üzerine yazmak** — `docs/FAZ8-SPEC.md §9`: "avenoxbeyin öyle
  yapıyor, append-only'yi bozar." quipu'da `Last-Session.md` `block.awk`'ın marker
  bloğuyla güncelleniyor (`quipu:879`, HEAD) — blok dışındaki içerik hep korunuyor; üzerine
  yazma bu garantiyi kaldırır.
- **Modelin yazdığı yansımanın içerik denetimi** — `docs/FAZ8-SPEC.md §9`: "şema yok,
  doğrulayıcı yok; yalnız blok var." quipu formatı (marker konumu) zorlar, **anlamı**
  zorlamaz — modelin ne yazdığına karışmak, avenoxbeyin'in prozaya güvenip sonra
  hiçbir tespit mekanizması kuramamasının simetriği bir hata olurdu.
- **`Threads.md`'yi quipu'nun güncellemesi** — `docs/FAZ8-SPEC.md §9`: dosya modelin
  sorumluluğunda kalır, quipu yalnız hatırlatır (S-2, `Threads.md` tohumlanıyor ama hiçbir
  komut onu güncellemiyor — bu **bilinçli** bir sınır, eksiklik değil).
  Y-6 bunu i18n metniyle telafi eder: bakımı model üstlenir, quipu yazmaz.
- **Prompt sayacı** — `docs/FAZ8-SPEC.md §9`: avenoxbeyin'in "15'te tek atış" mekanizması
  gereksiz, çünkü quipu'nun `QUIPU_NUDGE_AFTER` filigranı (varsayılan 50, HEAD'de zaten
  çalışıyor) **aynı işi** satır sayısıyla yapıyor — ikinci bir sayaç eklemek kopya kod
  olurdu (FAZ7-BULGULAR L-2'nin uyardığı türden bir tekrar).

## 4. Açık kalemler

Yok. Dört spec'in (`FAZ8-SPEC.md`, `FAZ9-SPEC.md`, `FAZ10-SPEC.md`, `V1-DUZELTME-SPEC.md`)
her biri kendi §9'unda kapsam-dışı bıraktığı avenoxbeyin fikrini açıkça adlandırıyor (mem0,
`Last-Session.md` overwrite, macOS launcher/Obsidian kurulumu, `{{...}}` şablon motoru,
prompt sayacı, `Threads.md`'nin quipu tarafından güncellenmesi) — bunların hepsi §3'te
listelendi. Henüz hiçbir sözleşmeye bağlanmamış, kapsam-dışı da sayılmamış bir avenoxbeyin
fikri bulunamadı; `docs/PLAN.md:770-772`'nin kendi özeti de aynı sonuca varıyor ("Alınmayan
kalemler açıkça kapsam dışı").
