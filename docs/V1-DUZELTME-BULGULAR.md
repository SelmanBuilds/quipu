# V1-DÜZELTME — Bulgular (Dilim 0)

**Kaynak yöntemi:** Bulgular **repo içi kod okuması + bu makinede canlı komut koşumu**
kaynaklıdır; her biri kesin `dosya:satır` referansı taşır. Satır numaraları commit
`dea829c` (FAZ 6 + FAZ 7 + yerleşim, **V1-DÜZELTME uygulanmadan önceki** çalışma ağacı,
1060 satır) içeriğinden alınmıştır — `git show dea829c:quipu` ile bu oturumda tek tek
doğrulandı, çalışma ağacındaki `quipu`'dan değil (orada V1-DÜZELTME'nin kodu `a1f58fb`
ile zaten girmiş durumda, satır numaraları kaymış). İddia etiketi: `[kaynak: …]` =
repo'da doğrulanabilir; `[ölçüm: bu makine]` = commit `dea829c`'nin geçici bir kopyası
(`git archive dea829c`) üzerinde bu oturumda fiilen koşulup gözlenen davranış;
`[doğrulanmadı]` = bu makinede doğrulanamadı, kaynağı ayrıca belirtilir.

**Sözleşme karşılığı:** Bu dosya `V1-DUZELTME-SPEC` §1'deki P-1…P-6'yı resmileştirir.
Sayılar P-1…P-6; `FAZ8-BULGULAR`'ın S-n'leriyle, `FAZ7-BULGULAR`'ın L-n'leriyle çakışmaz.

**Satır numarası doğrulama özeti:** SPEC'in verdiği sekiz referansın (`quipu:503`,
`quipu:509`, `quipu:511`, `quipu:914-924`, `quipu:1016-1024`, `quipu:45-64`, `quipu:241`,
`quipu:245`) tamamı `git show dea829c:quipu` çıktısında **birebir** doğrulandı — hiçbiri
kaymamış. Ayrıca R-3/R-4'ün referans aldığı `quipu:229` (`doc_layout_missing` deseni) ve
`quipu:310-312` (doctor'ın `FAIL > 0` → exit 1 mantığı) de aynı şekilde doğrulandı.

---

## P-1 — `init` config'e `fold=` hiç yazmıyor

`[kaynak: dea829c:quipu:503, dea829c:quipu:507-514]`

`init` config dosyasına yalnız iki alan yazıyor: `layout=` (satır 503, `printf
'layout=%s\n' "$_q_layout" >> "$_q_v/.quipu/config"`) ve `lang=` (507-514 bloğu — var olan
`lang=` satırı `sed` ile güncelleniyor (509), yoksa `printf` ile ekleniyor (511)). Bu iki
bloğun hemen ardından (515. satırdan itibaren) `init` fonksiyonu doğrudan `identity`
alanlarına geçiyor — **aradan `fold=` yazan hiçbir kod parçası geçmiyor.** Doğrulama:
`git show dea829c:quipu | grep -n '^fold='` sıfır sonuç döndürüyor; aynı komut çalışma
ağacında (`a1f58fb` sonrası) bir sonuç döndürüyor (`quipu:606`).

**Etki:** Katlama profili hiçbir zaman vault'a **yazılmıyor**; her komut onu kendi
başına, o anki ortamdan yeniden türetmek zorunda kalıyor. P-2/P-3'ün ön koşulu bu.

## P-2 — Katlama profili zinciri iki yerde bit-birebir kopyalanmış

`[kaynak: dea829c:quipu:914-924 (index), dea829c:quipu:1016-1026 (search), dea829c:quipu:45-64 (_q_lang)]`

`index` (914-924) ve `search` (1016-1026 — SPEC'in verdiği `1016-1024` küçük bir farkla
doğru: zincirin kendisi 1016-1024'te, ama blok üstündeki açıklayıcı yorum 1014-1015'te
zaten söz konusu profil türetimini anlatıyor) **aynı beş satırlık mantığı** taşıyor:

```sh
_q_prof=
if [ -f "$_q_v/.quipu/config" ]; then
  _q_prof=$(awk -F= -v k=fold '$1==k{sub(/^[^=]*=/,"");print;exit}' "$_q_v/.quipu/config" 2>/dev/null || true)
fi
if [ -z "$_q_prof" ]; then
  if [ "$(_q_lang)" = tr ]; then
    _q_prof='tr'
  else
    _q_prof=default
  fi
fi
```

`_q_lang` zinciri (45-64): `QUIPU_LANG` ortam değişkeni → vault config'teki `lang=` →
`LC_ALL`/`LANG`'ın ilk nokta/alt çizgiden önceki kısmı → `en`. Her iki komut da bu zinciri
**ayrı ayrı** çağırıyor; kopyanın kendisi tek başına bir hata değil (ikisi de aynı mantığı
uyguluyor), ama P-1 ile birleşince P-3'teki bozulmayı **etkinleştiren** yapı bu ikili kopya.

**Etki:** Tek bir yerde düzeltilmesi gereken mantık iki yerde bakım gerektiriyor; R-4'ün
`_q_fold_prof` yardımcısı bu kopyayı ortadan kaldırıyor.

## P-3 — Karışık indeks: aynı vault'ta iki not farklı profille katlanabiliyor

`[kaynak: dea829c:quipu:503-514 (P-1), dea829c:quipu:914-924, dea829c:quipu:1016-1026]` `[ölçüm: bu makine]`

**Ölçüm (bu oturumda, `dea829c`'nin `git archive` ile alınan geçici bir kopyasında
yeniden üretildi):**

1. `QUIPU_VAULT=./vp3 sh quipu init --lang tr` → config: `layout=emoji`, `lang=tr` (fold
   satırı yok — P-1).
2. `vp3/dpi.md` yazıldı: `# dpi\n\nİkinci monitörde taşbar taşması.`
3. `QUIPU_VAULT=./vp3 sh quipu index` (QUIPU_LANG **ayarlanmadı** — zincir config'teki
   `lang=tr`'ye düşüyor, dolayısıyla `_q_prof=tr`). Sonuç, `index.tsv`'nin `dpi.md`
   satırı, 5. sütun:
   ```
   # dpi  ikinci monitorde tasbar tasmasi.
   ```
   (tr profiliyle tam ASCII'ye katlanmış — ı, ş, ö kayboldu.)
4. `vp3/dpi2.md` eklendi: `# dpi2\n\nÜçüncü monitörde ölçek sorunu.`
5. `QUIPU_VAULT=./vp3 QUIPU_LANG=en sh quipu index` — bu kez `_q_lang` zinciri `QUIPU_LANG`
   ortam değişkenini config'in önüne koyuyor, `_q_prof=default`'a düşüyor. `dpi.md` satırı
   **mtime değişmediği için yeniden kullanılıyor** (eski, tr-katlanmış hâliyle kalıyor),
   ama yeni `dpi2.md` **default** profille işleniyor:
   ```
   dpi2.md	dpi2		<mtime>	# dpi2  Üçüncü monitörde ölçek sorunu.
   ```
   (Türkçe aksanlar aynen duruyor — default profil hiçbir şeyi katlamıyor, yalnızca ASCII
   `tr 'A-Z' 'a-z'` adımı çalışıyor ve zaten küçük harfli metne dokunmuyor.) `index`'in
   özet satırı: `# indexed 5 (reused 4, stale 1, dropped 0)` — **hiçbir uyarı yok.**
6. `QUIPU_VAULT=./vp3 QUIPU_LANG=en sh quipu search monitor`:
   ```
   1.491	dpi.md	dpi
   ```
   Yalnız `dpi.md` dönüyor (BM25'in alt-dizge yedek yolu `monitorde` içinde `monitor`u
   buluyor). `dpi2.md` **hiçbir sorguyla bulunamıyor** — folded alanında hâlâ
   `monitörde` (ö harfi ile) duruyor, `monitor` sorgusunun ASCII biçimiyle eşleşmiyor.

**Etki:** Aynı vault, aynı komut sırası — iki not sessizce **farklı katlama profilleriyle**
indekslenip biri aranabilir kalırken diğeri kayboluyor, kullanıcıya hiçbir sinyal
verilmeden. R-1 (profili `init`'te bir kez pinlemek) + R-4 (`_q_fold_prof` tek kaynağı)
birlikte bu kökeni kapatıyor: T-91 aynı senaryoyu düzeltilmiş kodda tekrarlayıp her iki
notun da aynı profille katlandığını ve ikisinin de bulunduğunu kilitliyor.

## P-4 — Aynı bozulma `--lang` verilmeden, yalnız locale üzerinden de tetikleniyor

`[kaynak: dea829c:quipu:45-64, dea829c:quipu:914-924]`

`init --lang` verilmeden kurulan bir vault'ta config'e `lang=` satırı hiç yazılmıyor
(507. satırdaki blok yalnız `-n "$_q_lang"` — yani flag verilmişse — çalışıyor). Böyle bir
vault'ta her `index`/`search` çağrısı `_q_lang()`'ı `LC_ALL`/`LANG`'a düşürüyor
(56-58. satırlar). Terminalin locale'i oturumlar arası değişirse (ör. bir shell `tr_TR`,
bir başkası `C`/`en_US`), P-3'teki aynı karışık-indeks kalıbı **hiç `--lang tr`
kullanılmadan** da ortaya çıkabiliyor — profil kaynağı config değil, o anki ortam.

**Etki:** P-3'ün kapsamı yalnız `--lang tr` kullanıcılarıyla sınırlı değil; R-1'in
`init`'te profili pinlemesi bu yolu da kapatıyor çünkü pinlenen `fold=` değeri artık
sonraki her çağrıda `_q_lang()`'dan önce okunuyor (R-4).

## P-5 — Hiçbir adaptör `quipu index` koşmuyor; `doctor` görüyor ama düzeltmiyor

`[kaynak: dea829c:adapters/claude-code.json, dea829c:adapters/codex/hooks.json, dea829c:quipu:241, dea829c:quipu:245]`

`adapters/claude-code.json`'daki `SessionEnd` hook'u yalnız `QUIPU_HOOK=1 quipu remember`
çalıştırıyor; `adapters/codex/hooks.json`'daki `SessionEnd` de aynı şekilde yalnız
`remember` (hem `command` hem `commandWindows` alanlarında). Repo genelinde hiçbir adaptör
JSON'ı `quipu index` dizgesini içermiyor. `doctor` bayatlığı fark ediyor —
`index.tsv` yoksa (241) veya `_q_mdlist` fark tespit ederse (243-245) `doc_index_stale`
uyarısı basıyor — ama bu yalnızca **teşhis**; hiçbir mekanizma `index`'i otomatik koşmuyor.

**Etki:** Bir ajan oturumu not üretip bitirdiğinde indeks kendiliğinden **hiç
güncellenmiyor**; bir sonraki oturum `search` çalıştırdığında yeni notları bulamıyor,
`doctor` koşulmadıkça bunun farkına bile varmıyor. R-5, `SessionEnd`'e `remember`'dan sonra
`index`'i ekliyor (her iki adaptörde, Windows `commandWindows` dahil).

## P-6 — Bu koku testlerde elle yamayla maskeliydi

`[kaynak: tests/run.sh (dal faz6-faz7, `dea829c` öncesi hâli — bkz. commit `dea829c`'nin
kendi diff'i), doğrulama: bu oturumda `grep -n "fold=tr" tests/run.sh`]`

FAZ 6 zincir testleri (T-72, T-73, T-76 — `dea829c` ile eklendi) Türkçe katlama isteyen her
vault'ta `init --lang tr`'den hemen sonra elle `printf 'fold=tr\n' >> .quipu/config`
yapıyordu. Bu satırlar P-1'in **doğrudan telafisiydi**: `init` `fold=` yazmadığı için,
testler onu kendileri yazıp P-2/P-3'ün ortaya çıkmasını engelliyordu — yani P-1 kusuru
canlı kullanımda mevcuttu ama test paketi bunu hiç sınamıyordu.

**Ek bulgu (bu temizlik sırasında ortaya çıktı):** Bu üç testin `init --lang tr` çağrısı
`QUIPU_LANG=en` ile sarmalanmıştı (mesaj çıktısını ASCII-kararlı tutmak için — o satırların
çıktısı zaten `/dev/null`'a yönlendirildiği için gereksizdi). R-1 sonrası bu sarmalama tek
başına yeni bir sorun yaratıyor: `_q_lang()` zinciri `QUIPU_LANG` ortam değişkenini config'in
önüne koyduğu için, `QUIPU_LANG=en ... init --lang tr` çalıştırıldığında `init`'in kendi
`fold=` türetmesi de `QUIPU_LANG=en`'i görüyor ve `fold=default` pinliyor — `--lang tr`
bayrağı `lang=tr`'yi config'e yazmış olsa bile. Doğrulandı: `QUIPU_VAULT=... QUIPU_LANG=en
sh quipu init --lang tr` → `fold=default`; aynı komut `QUIPU_LANG` olmadan → `fold=tr`.
Temizlik bu nedenle iki adımlı oldu: elle `fold=tr` yaması kaldırıldı **ve** yalnız `init`
çağrısından `QUIPU_LANG=en` çıkarıldı (sonraki `capture`/`index`/`search` çağrılarında
kalması zararsız — R-4 sayesinde onlar artık config'teki pinlenmiş `fold=`'u okuyor,
`_q_lang()`'a hiç düşmüyor).

**Etki:** P-6'nın kanıtı, temizlik sonrası T-72/T-73/T-76'nın **değişmeden** geçmesi;
kanıt bu belgeyle aynı commit'te değil, testler + P-6 temizliği commit'inde sunulur.

---

## Tasarım etkileri (P → R eşlemesi)

| Bulgu | Sözleşme maddesi | Ne gerektiriyor |
|---|---|---|
| P-1 | R-1 | `init` profili bir kez türetip `fold=` olarak config'e yazar (yalnız satır yoksa) |
| P-2 | R-4 | `index`/`search`'teki kopya zincir tek yardımcıya (`_q_fold_prof`) çıkarılır |
| P-3 | R-1 + R-2 + R-4 | Profil pinlendiği için artık ortam değişkenine göre çağrıdan çağrıya değişmez |
| P-4 | R-1 | Locale'e bağımlılık `init` anında dondurulan değerle ortadan kalkar |
| P-5 | R-5 | Adaptörlerin `SessionEnd`'i `remember`'dan sonra `index`'i de koşar |
| P-6 | R-1 (dolaylı) | Elle yama artık gereksiz; kaldırılması R-1'in gerçekten çalıştığının kanıtı |

## Test malzemesi (T-88…T-95 için)

- **Pinleme (T-88…T-90):** `init --lang tr`/`init` (LC_ALL=C) çağrıları **QUIPU_LANG
  ortam değişkeni olmadan** koşulur (P-6'nın ek bulgusu) — aksi hâlde ortam değişkeni
  `--lang` bayrağını gölgeliyor. T-90 elle yazılmış `fold=latin`'in hem bilinen hem
  bilinmeyen bir profil için `init` tarafından asla ezilmediğini doğrular.
- **P-3 regresyonu (T-91):** Bu belgedeki ölçümün birebir aynısı, düzeltilmiş kodda
  tekrarlanır — iki notun da 5. sütununda Türkçe harf kalmadığı ve `search monitor`'un
  ikisini de döndürdüğü doğrulanır.
- **`doctor` (T-92):** `doc_fold_missing` (warn, exit 0) ve `doc_fold_unknown` (fail,
  exit 1) `doc_layout_missing`'in birebir deseniyle sınanır; `doc_summary`'nin son alanı
  (`idx_nums`/`doctor: chain vault summary` desenindeki gibi) dil bağımsız okunur.
  `fold=` var + bilinen: `T-93` içinde dolaylı olarak zaten `ok` yoluyla sınanıyor.
- **Tek kaynak (T-93):** `fold=latin` altında `index` ve `search`'ün **aynı** profili
  kullandığının kanıtı, latin'e özgü bir katlamanın (`Straße` → `strasse`) hem
  `index.tsv` 5. sütununda hem arama isabetinde görünmesi.
- **Adaptör verisi (T-94):** T-54…T-56 statik-veri deseninin devamı — her iki adaptörün
  `SessionEnd` bloğunda `index` çağrısının (codex için `commandWindows` dahil) var
  olduğu doğrulanır.
- **Hook sessizliği (T-95):** FAZ 5/H-7 deseninin `index`'e uygulanmış hâli —
  `QUIPU_HOOK=1 quipu index` stdout/stderr boş, exit 0, `index.tsv` yine de güncel.

---

## Kapanış notu — yazım sırası ve dürüstlük

Bu belge Dilim 0'ın çıkış koşulu olarak tanımlanmış olsa da (SPEC §7), fiilen **geriye
dönük** yazıldı: R-1…R-6'nın kodu commit `a1f58fb` ("v1-duzeltme (kısmi): katlama profili
sabitlendi, indeks kendini yeniler") ile bu belge yazılmadan önce zaten girmişti. P-1…P-6
bulguları bu sıralamadan etkilenmemesi için özenle commit `dea829c`'nin (V1-DÜZELTME
uygulanmadan önceki durum) içeriğinden doğrulandı, çalışma ağacından değil — ama
sıralamanın kendisi SPEC'in öngördüğü "önce bulgu, sonra kod" akışını tersine çevirdi. Bu
tutarsızlık burada açıkça kayda geçirilmiştir. P-6'nın ek bulgusu (QUIPU_LANG'ın `init`
çağrısını gölgelemesi) bu belgeyle **aynı oturumda**, testleri yazarken ortaya çıktı — kod
girdikten sonra bulunan, kodun kendisinde henüz düzeltilmemiş bir ince nokta (bkz. P-6);
düzeltme yalnız test çağrılarında yapıldı, `quipu` kaynağında değil.
