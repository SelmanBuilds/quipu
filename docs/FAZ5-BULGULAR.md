# FAZ 5 — Bulgular (Dilim 0)

**Kaynak yöntemi:** Bu faz için **canlı ölçüm YOK** — hook'suz ajanların gerçek davranışı
bu makinede ölçülmedi (hook'suz ajan = tanım gereği ölçülecek hook yok; Codex de kurulu
değil). Tüm bulgular **repo içi kod okuması + PLAN.md** kaynaklıdır; her biri kesin
`dosya:satır` referansı taşır. İddia etiketi: `[kaynak: …]` = repo'da doğrulanabilir;
`[doğrulanmadı]` = dış ajan davranışı, ileride canlı doğrulanacak.

**Sözleşme karşılığı:** Bu dosya `FAZ5-SPEC` §1'deki F-1…F-5'i resmileştirir. Sayılar
F-1…F-5; `FAZ4-SPEC`'in A-n'leriyle, `FAZ3-BULGULAR`'ın Ö-n/E-n'leriyle çakışmaz.

---

## F-1 — AGENTS.md köprüsü statiktir ("nasıl kullanılır"; "son oturum" değil)

`[kaynak: quipu:507-530, i18n/en.txt:74-77]`

`quipu init`, AGENTS.md'ye **tek bir statik blok** yazar. Gövde: `bridge_run`
("Run: quipu context"), `bridge_layout` + layout klasör listesi, `bridge_companion`
(companion yolu), `bridge_append` (append-only notu). Bu içerik kurulumdan sonra bir daha
güncellenmez — "son oturum + aktif konular" (PLAN §2'nin evrensel köprüsü) **hiçbir yerde
üretilmiyor**.

**Etki:** Hook'suz ajan AGENTS.md'yi okur ama hafıza *bağlamını* değil, yalnız "quipu nasıl
çalıştırılır" rehberini görür. → `context --bridge` (H-10) bu boşluğu kapatır.

## F-2 — `lib/block.awk` tek işaretçi çiftini hardcode eder

`[kaynak: lib/block.awk:13-14]`

`start`/`end` değişkenleri sabit: `<!-- quipu:start -->` / `<!-- quipu:end -->`. Span
değiştirme / ekleme / kullanıcı-içeriği-koruma mantığı işaretçiden **bağımsız**; yalnız
işaretçi sabit. İkinci (dinamik) blok için bu sabiti parametreleştirmek yeterli.

**Etki:** `-v start=… -v end=…` ile genelleştirmek geriye uyumlu olur (H-12); init /
Last-Session.md / CLAUDE.md çağrıları varsayılan işaretçiyle aynen çalışır.

## F-3 — `context` bağlamı yalnız hook zarfıyla dışarı çıkar; hook'suz ajanda yol yok

`[kaynak: quipu:562-684]`

Bağlam metni üç bölümden oluşur: activity (log tail + digest tablosu, `quipu:581-593`),
index istatistiği (`:595-606`), Threads.md (`QUIPU_CTX_MAX` ile satır-sınırında kırpılmış,
`:608-633`). Çıkış iki yol: bare (metni stdout'a, `:682`) ve `--json EVENT` (hook zarfı,
`:676-680`). İkisi de "bir oturum hook'u bu komutu çağırır" varsayımına dayanır; SessionStart
hook'u olmayan ajanda bu metne ulaşan **yol yok**.

**Etki:** `--bridge` üçüncü bir çıkış hedefi ekler — aynı metin, AGENTS.md'ye (H-10);
bağlam üretimi `context` ile `bridge` arasında **kopyalanmaz** (H-14 tek kaynak).

## F-4 — `capture` hook payload'ına bağımlıdır; hook'suz ajanda hiçbir şey yakalamaz

`[kaynak: quipu:331-385]`

stdin modu JSON payload bekler (`jsonfield.awk` + `capture.awk`, `:357`); flag modu
`--event/--tool/--path` elle verilir (`:344-346`). İkisi de "bir hook (veya insan) olayı
verir" varsayımına dayanır. Git-diff yalnız içerik **değişimini** görür (M/A/D);
PostToolUse matcher'ının yakaladığı `Read` olaylarını çıkaramaz `[doğrulanmadı — hook'suz
ajanın fiili edit yüzeyi ajana göre değişir]`.

**Etki:** `capture --git` değişenleri ≈ düzenlemeler olarak kaydeder; READ yok (H-9
dürüst sınır).

## F-5 — `remember --git` "git yok / repo değil → sessiz exit 0" desenini zaten kurdu

`[kaynak: quipu:781-789]`

`if command -v git … && git rev-parse --git-dir` → değilse iç içe `if`'ler sessizce atlanır,
akış `remember_ok`'a düşer ve komut **örtük 0** ile biter. Açık bir `exit 0` **yok** —
desen "guard + sessiz exit 0" değil, **"koşullu atlama + örtük başarı"**dır. Git
bulunamadığında / vault repo olmadığında hata değil, no-op.

**Etki:** `capture --git` bu desenden yalnız **ön koşulu** (`command -v git` + `rev-parse
--git-dir`) devralır (H-2/H-8); `remember`'ın `git add -A && ! git diff --cached --quiet`
boru hattını **devralmaz**. Yeni bir hata yüzeyi açılmaz.

---

## Tasarım etkileri (F → H eşlemesi)

| Bulgu | Sözleşme maddesi | Ne gerektiriyor |
|---|---|---|
| F-1 | H-10, H-11 | AGENTS.md'ye dinamik bağlam bloğu; statik blok init'in malı kalır |
| F-2 | H-12 | block.awk işaretçi çifti `-v` ile parametreleşir (geriye uyumlu) |
| F-3 | H-10, H-14 | `--bridge` = context metninin AGENTS.md hedefi; üretim tek kaynak |
| F-4 | H-3, H-9 | git-diff + `ls-files --others`; READ yakalanmaz (dürüst sınır) |
| F-5 | H-2, H-8 | `git rev-parse` guard'ı; sessiz exit 0 |

## Test malzemesi (Dilim 1 için)

`capture --git` testleri geçici git repo'larında (`tests/run.sh` içinde `TMP=${TMPDIR:-/tmp}/quipu-tests-$$`
+ `git init -q "$TMP/…"` + `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env kimliği deseni, T-40 ile aynı) kurulur.
Gerçek kullanıcı yolu / session_id yok — vault yolları `$TMP/…` altında maskeleli.
Fixture dosyası gerekmez (git durumu test içinde kurulur); yalnızca H-4 filtresinin
`.md`-olmayan ve köprü dosyalarını dışladığı davranış için sabit `$TMP` senaryosu yeterli.
