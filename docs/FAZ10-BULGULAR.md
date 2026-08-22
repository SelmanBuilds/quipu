# FAZ 10 — Bulgular (Dilim 0)

**Kaynak yöntemi:** Bulgular **repo içi kod okuması + bu makinede canlı komut koşumu**
kaynaklıdır; her biri kesin `dosya:satır` referansı taşır. İddia etiketi `[kaynak: …]` =
repo'da doğrulanabilir; `[ölçüm: …]` = bu oturumda geçici vault'ta fiilen koşulup gözlenen
davranış; `[doğrulanmadı]` = repoda ya da bu makinede doğrulanamayan, yalnız kaynak belgeye
dayanan iddia.

**Satır referansı:** Tüm `quipu:satır` ve `lib/*.awk:satır` referansları **HEAD** (`ecca473`,
"docs: tasarım kaydını takibe al") sürümünden alınmış ve `git show HEAD:quipu` /
`git show HEAD:lib/index.awk` / `git show HEAD:lib/search.awk` ile tek tek satır satır
doğrulanmıştır. Çalışma ağacındaki `quipu` (1240 satır, HEAD'de 1060) commit edilmemiş
FAZ 8 (yansıma bloğu) + FAZ 9 (kimlik/persona) eklemelerini taşıyor — `git diff HEAD -- quipu`
bunun yalnız `_q_reflect_filled` fonksiyonu, `doctor`un kimlik satırı, `init --user/--companion`
ve `remember`/`context` yansıma mantığı olduğunu gösteriyor; **`index`, `search`, katlama
profili zinciri (`_q_prof=…`) ve `.quipu/config` `layout=`/`lang=` yazımı bu diff'in dışında,
HEAD ile birebir aynı**. `lib/index.awk` ve `lib/search.awk` çalışma ağacında hiç
değişmemiş (`git diff HEAD -- lib/index.awk lib/search.awk` boş çıktı). Bu nedenle bu belgedeki
canlı ölçümler çalışma ağacındaki `quipu` ile alınmış olsa da, FAZ 10'un ilgilendiği tüm
davranış (indeks şeması, katlama, arama bayrakları) için HEAD ile eşdeğerdir; bu eşdeğerlik
yukarıdaki diff kontrolüyle doğrulanmıştır, varsayılmamıştır.

**Sözleşme karşılığı:** Bu dosya `FAZ10-SPEC` §1'deki W-1…W-5'i resmileştirir. Sayılar
W-1…W-5; `FAZ6-BULGULAR`'ın G-n'leri, `FAZ7-BULGULAR`'ın L-n'leri, `V1-DUZELTME-SPEC`'in
P-n'leriyle çakışmaz.

---

## W-1 — `mode=meta` frontmatter'ı kısmen okuyor: `status`/`type` hiç çıkarılmıyor

`[kaynak: lib/index.awk:59, lib/index.awk:63-64, lib/index.awk:68-72, lib/index.awk:137]`

`mode=meta` bloğu `FNR == 1 && $0 == "---"` ile açılıyor (`lib/index.awk:59`):

```awk
mode == "meta" && FNR == 1 && $0 == "---" { fm = 1; next }

mode == "meta" && fm == 1 {
  if ($0 == "---" || $0 == "...") { fm = 2; next }
  if (substr($0, 1, 6) == "title:") { if (title == "") title = trim_(substr($0, 7)) }
  if (substr($0, 1, 5) == "tags:")  { collect_tags(substr($0, 6)) }
  next
}
```

Bu blok yalnız `title:` (`:63`) ve `tags:` (`:64`) alanlarını tanıyor; başka hiçbir
`substr($0, 1, N) == "xxx:"` dalı yok. Blok kapanınca (`fm == 2`) gövde taraması sürüyor
(`:68-72`) — yalnız `# ` başlığı ve satır içi `#etiket`ler toplanıyor. Sonda tek çıktı
`print title, tags` (`:137`). **`status:`, `type:`, `created:`, `modified:` alanları,
frontmatter'da yazılsalar bile hiçbir değişkene atanmıyor, çıktıya hiç girmiyor.**

**[ölçüm: bu makine]** Geçici vault'a şu frontmatter'lı not yazıldı:

```yaml
---
title: Test Note
tags: [alpha, beta]
status: active
type: task
---
```

`quipu index` sonrası `index.tsv` satırında `status` ve `type` değerlerinin izi **hiçbir
sütunda** yok — 5. sütun (katlanmış alan) bile `status: active type: task` metnini kelime
düzeyinde taşısa da (gövde metni olarak katlandığı için), yapısal olarak "bu notun durumu
active'tir" bilgisini kodlayan ayrı bir alan **mevcut değil**.

**Etki:** Z-1 iki `substr` dalı daha ekler (`substr($0,1,7)=="status:"`,
`substr($0,1,5)=="type:"`), regex kullanmadan (yasak desen, PLAN §4.11).

## W-2 — `index.tsv` 5 sütun; katlanmış alan 2000 karakterle sınırlı

`[kaynak: lib/index.awk:26, lib/index.awk:138, quipu:963, quipu:965-966]`

Katlanmış alan üretimi `mode=flat` ile bir tavan alıyor:

```awk
BEGIN { … if (max + 0 == 0) max = 2000 … }          # lib/index.awk:26
END { … if (mode == "flat") { sub(/^[ ]+/, "", buf); print substr(buf, 1, max) } }  # :138
```

`quipu` tarafında satır beş alanla birleştiriliyor (`quipu:963`, `:965-966`):

```sh
_q_meta=$(cd "$_q_v" && awk -v mode=meta -f "$_q_HOME/lib/index.awk" "$_q_p")
_q_flat=$(cd "$_q_v" && sed -f "$_q_HOME/fold/$_q_prof.sed" "$_q_p" | tr 'A-Z' 'a-z' | awk -v mode=flat -v max=2000 -f "$_q_HOME/lib/index.awk")
printf '%s\t%s\t%s\t%s\n' "$_q_p" "$_q_meta" "$_q_mt" "$_q_flat"
```

`_q_meta` iki alan taşıyor (`title tags`, `awk` `print title, tags` çıktısı OFS ile ayrılmış
tek dizge), yani toplam sütun sayısı: yol(1) + başlık(1) + etiketler(1, `_q_meta`'nın ikinci
parçası) + mtime(1) + katlanmış(1) = **5**.

**[ölçüm: bu makine]** İzole geçici vault'ta `quipu init` + bir not + `quipu index` sonrası
`.quipu/index.tsv`:

```
note1.md	Test Note	alpha,beta,gamma	1787391279	--- title: test note tags: [alpha, beta] status: active type: task ---  # test note  some content …
```

`awk -F'\t' '{print NF}' .quipu/index.tsv` → her satır için **5**. Sütun sırası: `yol · başlık
· etiketler · mtime · katlanmış`. `search.awk`'ın kendi baş yorumu da bunu ilan ediyor
(`lib/search.awk:3-6`): *"5 TAB-separated fields: yol başlık etiketler mtime katlanmış-alan…
column 5 is the folded, single-space-squeezed search field."*

**Etki:** Z-2 bu satırı 7 sütuna çıkarır (`durum`, `tip` sona eklenir); `search.awk`'ın `$5`
okuması (bkz. W-3) bozulmaz çünkü katlanmış alan pozisyonunu korur.

## W-3 — Etiket **boost**'u var, etikete göre filtreleme yok; `search` yalnız üç bayrak tanıyor

`[kaynak: lib/search.awk:119, lib/search.awk:123, quipu:993-995]`

`search.awk` skorlama geçişinde katlanmış terim etiketle **tam eşleşirse** ağırlığı `×1.5`
yapıyor — hem birincil eşleşme yolunda hem geri düşüş (fallback/substring) yolunda:

```awk
if (index(tags[d], term) > 0) contrib *= 1.5                       # :119 (fallback)
for (j = 1; j <= ntag; j++) {
  if (ta[j] == term) { contrib *= 1.5; break }                     # :123 (normal yol)
}
```

Ama bu **sıralamayı etkileyen bir ağırlık**, doküman elemek için kullanılmıyor — etiketi
uymayan doküman yine de emit edilebilir, yalnız daha düşük skorla. `quipu` tarafında
`_q_cmd_search`'ün argüman döngüsü **yalnız üç bayrak** tanıyor (`quipu:993-995`):

```sh
--limit) [ "$#" -ge 2 ] || _q_die err_missing_arg 2; _q_limit=$2; shift 2 ;;
--paths) _q_paths=1; shift ;;
--brief) _q_brief=1; shift ;;
-*) _q_die err_unknown_flag 2 "$1" ;;
```

`--tag` ya da `--status` bugün `-*)` dalına düşer → `err_unknown_flag` ile exit 2 (FAZ 7
J-3/J-4'ün kazanımı: en azından sessizce sorgu kelimesi olmuyor, gürültülü hata veriyor).

**Etki:** Z-3/Z-4 `--tag`/`--status` dallarını `--brief`'in hemen altına, `-*)` yakalayıcısından
**önce** ekler; `search.awk`'a `-v tagf=` / `-v statf=` geçilir, eşleşmeyen doküman **hiç emit
edilmez** (mevcut boost'tan farklı olarak eleme, ağırlıklandırma değil).

## W-4 — `[[wikilink]]` hiçbir yerde ayrıştırılmıyor

`[kaynak: quipu:3]` `[ölçüm: bu makine — grep]`

Repo genelinde `[[` dizgisinin geçtiği **tek yer** `quipu`'nun kendi baş yorumundaki bashism
uyarısıdır ve Obsidian wikilink'iyle **ilgisi yok**:

```
3:# Single-file POSIX sh (PLAN FAZ 1). No bashisms: no [[ ]], no local,
```

**[ölçüm]** `git show HEAD:quipu | grep -n '\[\['` → yalnız bu satır. `grep -rn '\[\[' lib/`
→ **boş çıktı**. Yani `.quipu/links.tsv` yok, `quipu links` komutu yok, bağlantı grafiği yok,
kırık bağlantı tespiti yok — bulgu SPEC'in iddiasıyla birebir örtüşüyor.

**Etki:** Z-5 `lib/index.awk`'a `mode=links` ekler (yalnız `index()`/`substr()`, regex yok —
`:` ayraç aramaları için model, mevcut `substr($0,1,N)` desenlerinin aynısı); `quipu links <yol>`
yeni komut, `.quipu/links.tsv` yeni çıktı dosyası.

## W-5 — avenoxbeyin sözleşmesi yalnız prozada var; doğrulayıcı/ayrıştırıcı yok

`[doğrulanmadı — kaynak: FAZ10-SPEC §1, avenoxbeyin repo yerelde klonlu değil]`

Bu makinede `github.com/avenoxai/avenoxbeyin` klonu bulunamadı (`find … -iname
'*avenoxbeyin*'` boş sonuç döndü); repoya ağdan da erişilmedi. Bu nedenle W-5'in kendisi —
`template/CLAUDE.md` §Conventions'ın frontmatter (`title, created, modified, type, status,
tags`), `[[wikilinks]]`, durum alfabesi `🟢/🟡/🔴/⚪`, `🎯 100-Command-Center/Dashboard.md`
hub'ı ilan ettiği iddiası — **FAZ10-SPEC'in kendi metnine dayanır, bu oturumda ikinci bir
kaynaktan doğrulanamamıştır**. quipu tarafındaki karşılığı doğrulanabilir: `layout/emoji.txt`
zaten `🎯 100-Command-Center` slug'ını taşıyor (`[ölçüm: bu makine]`
`git show HEAD:layout/emoji.txt` satır 3: `command	🎯 100-Command-Center`) — yani hub yolu
quipu'da da var, ama durum emojisi kodda hiçbir yerde gömülü değil (aşağıya bkz.) ve
`[[wikilink]]`/frontmatter doğrulaması W-1/W-4'te gösterildiği gibi yok.

**Etki:** Z-6/Z-7 durum alfabesini `layout/status.txt` veri dosyasına taşır; W-5'in prozadan
"sorgulanabilir" hale getirilmesi budur.

---

## V1-DUZELTME bağımlılığı — somut kanıt

FAZ10-SPEC'in başlığı bu bağımlılığı tek cümleyle ilan ediyor (`docs/FAZ10-SPEC.md:6-7`):

> Ön koşul: FAZ 7 tamam. **V1-DUZELTME önce girmeli** (indeks şeması bu fazda değişiyor;
> katlama profili sabitlenmemişse `--full` yeniden indeksleme sessizce profil değiştirir).

Bu iddiayı somutlaştırmak için `V1-DUZELTME-SPEC`'in P-3 bulgusu bu oturumda **canlı olarak
yeniden üretildi**.

**[ölçüm: bu makine]** İzole vault, `quipu init --lang tr` (config: yalnız `layout=emoji`,
`lang=tr` — **`fold=` satırı yok**, P-1'in doğrulanmış hâli). `birinci.md` yazılıp
`quipu index` koşuldu (ambient `_q_lang=tr` → profil `tr`):

```
# birinci  ikinci monitorde taskin cop igdir olcum.
```

Aynı vault'a `ikinci.md` eklenip `QUIPU_LANG=en quipu index` koşuldu (ambient `_q_lang=en` →
profil `default`, çünkü config'te `fold=` sabit değil):

```
# ikinci  Üçüncü monitörde ölçek testi iğdır.
```

`index` özeti `reused 4, stale 1` dedi — **hiçbir uyarı basılmadı**; iki satır artık **farklı
katlama profilleriyle** aynı `index.tsv`'de yan yana duruyor. Sonuç: `QUIPU_LANG=en search
igdir` yalnız `birinci.md`'yi buluyor, `QUIPU_LANG=en search iğdır` yalnız `ikinci.md`'yi
buluyor — **aynı konuyu (Iğdır'da monitör/ölçek) anlatan iki not, hiçbir ortak sorgu terimiyle
birlikte bulunamıyor.**

**Çakışan şema alanı — neden FAZ 10'dan önce:** FAZ10 Z-2, `index.tsv`'nin sütun sayısı
beklenenden azsa (5 < 7) **"tüm satırlar bayat sayılır"** diyor — yani şema geçişi, kullanıcı
`--full` istemeden, örtük bir tam yeniden-indeksleme tetikliyor. Bu örtük tam-yeniden-indeksleme
tam olarak P-2/P-3'ün gösterdiği kırılgan yüzeydir: `_q_prof` her `index` çağrısında ortam
(`QUIPU_LANG`/`LC_ALL`/`LANG`) üzerinden yeniden türetiliyor (`quipu:914-924`), çünkü
`fold=` config'e hiç yazılmıyor (P-1, `quipu:503` yalnız `layout=`, `quipu:509/511` yalnız
`lang=` yazıyor). V1-DUZELTME'nin R-1'i olmadan FAZ10'un şema-geçişi tetiklediği bu
tam-yeniden-indeksleme, geçişi başlatan oturumun ambient dilini **sessizce** tüm vault'a
katlama profili olarak damgalar — geçiş öncesi karışık durumdaki notların katlama tutarsızlığı
düzelmez, yalnız yeni bir tek-profil anlık görüntüsüyle üstü örtülür; sonraki bir oturumda farklı
`QUIPU_LANG` ile eklenen tek bir not aynı karışıklığı hemen yeniden başlatır (P-3/P-4 aynen
sürer). R-1 (init'te `fold=` bir kez yazılır) + R-4 (`_q_fold_prof` tek kaynak) bu zemini
FAZ10'un şema geçişinden **önce** sabitliyor; aksi hâlde FAZ10'un "index kendisi fark eder"
otomasyonu (Z-2) sorunu gizleyen ikinci bir katman olur.

---

## Tasarım etkileri (W → Z eşlemesi)

| Bulgu | Sözleşme maddesi | Ne gerektiriyor |
|---|---|---|
| W-1 | Z-1 | `mode=meta`'ya iki `substr` dalı (`status:`, `type:`), regex yok |
| W-2 | Z-2 | `index.tsv` 7 sütun, katlanmış alan 5. sütunda sabit kalır, yeni alanlar sona |
| W-3 | Z-3, Z-4 | `--tag`/`--status` filtreleri, boost'tan bağımsız eleme yolu; `-*)` yakalayıcısından önce eklenir |
| W-4 | Z-5 | `mode=links` (`index()`/`substr()`), `.quipu/links.tsv`, `quipu links <yol>` |
| W-5 | Z-6, Z-7 | `layout/status.txt` veri dosyası, i18n `links_out/links_in/doc_index_schema/doc_links_broken/usage_links` |
| — (V1 bağımlılığı) | R-1…R-4 (V1-DUZELTME) | FAZ10 Z-2'nin örtük tam-yeniden-indeksleme tetiği, sabit `fold=` olmadan P-2/P-3'ü gizler; **V1-DUZELTME önce** |

## Test malzemesi (Dilim 1-4 için)

- **Şema (T-130…T-133):** `index.tsv` sütun sayısı bu belgede **ölçülerek** 5 olarak
  doğrulandı (`awk -F'\t' '{print NF}'`); T-131'in "her satır 7 sütun" iddiası bu ölçümün
  güncellenmiş hâlidir. T-132'nin "eski 5 sütunlu `index.tsv` → tüm satırlar bayat" davranışı
  Z-2'nin metninden kod okumasıyla çıkarılmıştır (henüz uygulanmadığı için canlı ölçülemedi).
- **Daraltma (T-134…T-138):** `--tag`/`--status` bugün `err_unknown_flag` ile exit 2 veriyor
  (`quipu:996`, `[ölçüm: bu makine]` `quipu search --tag x` → exit 2, mesaj
  `unknown flag: --tag`) — bu, Z-3/Z-4 uygulanmadan önceki taban davranıştır; T-134/T-135 bunun
  yerini alacak.
- **Wikilink (T-139…T-141):** `[[hedef]]`/`[[hedef|ad]]`/`[[hedef#bölüm]]` çıkarımı henüz kod
  düzeyinde yok; test malzemesi olarak `mode=meta`'nın `substr`-tabanlı ayıklama deseni
  (`lib/index.awk:63-64`) doğrudan model alınabilir — `|` ve `#` için `index()` ile ilk
  geçtikleri konumdan `substr` kesimi aynı yasak-desen kısıtına (regex yok) tabidir.
- **Veri (T-142):** statik ASCII kontrolü için taban ölçüldü — `git show HEAD:quipu` ve
  `lib/*.awk` içinde `🟢`/`🟡`/`🔴`/`⚪` **hiç geçmiyor** (`[ölçüm: bu makine]` grep boş
  döndü); yani T-142'nin "kodda emoji yok" iddiası **bugün bile doğru** — Z-6/Z-7'nin işi
  emoji'yi koda sokmamak değil, `layout/status.txt`'ten okunan bir veri kaynağı **eklemek**.

---

## Dürüstlük notu

**FAZ 10 bu oturum itibarıyla hiç uygulanmamıştır** — `lib/index.awk`, `lib/search.awk`,
`quipu`'nun `search`/`index`/`doctor` yolları, `layout/`, `i18n/` dosyalarında Z-1…Z-7'ye
karşılık gelen tek satır kod yoktur; T-130…T-142 testlerinden hiçbiri `tests/run.sh`'e
eklenmemiştir. Bu belge, uygulama **öncesi** bir ön-ölçümdür: W-1…W-5'in doğruluğu bu oturumda
kod okuması ve izole geçici vault'larda canlı komut koşumuyla doğrulanmış, ama FAZ 10'un
kendi çıkışı (Dilim 1-4) henüz yazılmamıştır.

**V1-DUZELTME uygulanmadan FAZ 10'a girilmemelidir.** Yukarıdaki "somut kanıt" bölümü bunu
tek bir ölçümle gösteriyor: bugünkü `.quipu/config`'te `fold=` hiç yazılmıyor (P-1), katlama
profili her `index`/`search` çağrısında ortamdan yeniden türetiliyor (P-2), ve bu iki koşul
birlikte aynı vault içinde **sessizce iki farklı katlama profiliyle** karışmış bir indeks
üretebiliyor (P-3, bu oturumda yeniden üretildi). FAZ10'un Z-2 maddesi ("şema farklıysa tüm
satırlar bayat sayılır") bu karışıklığı düzeltecek bir mekanizma değildir — tam tersine,
kullanıcıdan habersiz bir tam-yeniden-indeksleme tetikleyerek mevcut karışıklığı yeni bir
sessiz anlık görüntüyle üstü örtebilir. Bu nedenle sıra: **V1-DUZELTME (R-1…R-6) → FAZ 10
(Z-1…Z-7)**, tersi değil.
