# FAZ 7 — Bulgular (Dilim 0)

**Kaynak yöntemi:** Tüm bulgular **repo içi kod okuması** kaynaklıdır; her biri kesin
`dosya:satır` referansı taşır. Satır numaraları **FAZ 7 başlangıç durumundan** (FAZ 6 sonu
çalışma kopyası, `quipu` = 1029 satır, `lib/search.awk` = 114 satır) alınmıştır — yani
J-1…J-6 uygulanmadan önceki hâl. Bulgular kusurun *bulunduğu* hâli anlattığı için referans
noktası budur; J-2/J-5 düzenlemeleri satırları aşağı kaydırır, bu yüzden her bulgu altında
**bağlayıcı satır metni birebir alıntılanmıştır** (kayma sonrası da `grep` ile bulunur).
İddia etiketi: `[kaynak: …]` = repo'da doğrulanabilir; `[ölçüm: …]` = bu makinede koşturulup
görülmüş; `[doğrulanmadı]` = platform davranışı, üç OS CI'da görülecek.

**Sözleşme karşılığı:** Bu dosya `FAZ7-SPEC` §1'deki L-1…L-5'i resmileştirir. Sayılar
L-1…L-5; `FAZ5-BULGULAR`'ın F-n'leriyle, `FAZ3-BULGULAR`'ın Ö-n/E-n'leriyle çakışmaz.

---

## L-1 (DZ-4) — Bilinmeyen bayrak "argüman eksik" diye tanılanıyor; search'te ise sessizce sorgu kelimesi oluyor

`[kaynak: quipu:365, quipu:455, quipu:696, quipu:777, quipu:971-978, i18n/en.txt:11]`

Dört argüman döngüsünün `*)` dalı, tanınmayan **her** sözcüğü — bayrak olsun olmasın —
`err_missing_arg` ile öldürüyor:

| Komut | Satır | Metin |
|---|---|---|
| `capture` | `quipu:365` | `      *) _q_die err_missing_arg 2 ;;` |
| `init` | `quipu:455` | `      *) _q_die err_missing_arg 2 ;;` |
| `context` | `quipu:696` | `      *) _q_die err_missing_arg 2 ;;` |
| `remember` | `quipu:777` | `      *) _q_die err_missing_arg 2 ;;` |

Basılan mesaj `err_missing_arg=missing required argument` (`i18n/en.txt:11`). Yani
`quipu capture --bogus` çağrısında kullanıcıya/ajana söylenen şey **"eksik argüman"**;
gerçek sorun ise **bayrağın tanınmaması**. Yanlış tanı: "argüman eksik" ≠ "bilinmeyen
bayrak" — ajan mevcut bayrağa değer eklemeye çalışır, oysa bayrak hiç yoktur.

`search` döngüsünde durum bir adım daha kötü: `*)` dalı hata değil, **sorguya ekleme**
yapıyor (`quipu:971-978`):

```sh
      *)
        if [ -n "$_q_query" ]; then
          _q_query="$_q_query $1"
        else
          _q_query=$1
        fi
        shift
        ;;
```

`--limit` (`quipu:969`) ve `--paths` (`quipu:970`) dışındaki her `-…` dizgisi **sessizce
arama terimi** olur: `quipu search --bogus` hata vermez, "--bogus" kelimesini arar ve
(katlama sonrası eşleşme bulunmayacağı için) boş/alakasız sonuç döner. Sessiz yanlış
davranış, gürültülü hatadan daha pahalıdır.

**Etki:** J-3 dört döngüye `-*)` dalı ekler, J-4 search döngüsüne ekler; `*)` dalları
yerinde kalır (pozisyonel argüman davranışı kapsam dışı). T-80 search'teki davranış
değişikliğini, T-81 `err_missing_arg` regresyonunu kilitler.

## L-2 — `_q_die` yalnız `key [code]` alır; mesaja argüman geçirecek mekanizma yok

`[kaynak: quipu:84-90, quipu:66-82]`

`_q_die` gövdesi tamamı beş satırdır ve `$1` dışında hiçbir argümanı mesaja taşımaz;
`$2` yalnız çıkış koduna gider, `$3` ve sonrası **kullanılmaz**:

```sh
_q_die() {
  _q_msg "$1" >&2
  if [ "${QUIPU_HOOK:-0}" = 1 ]; then
    exit 0
  fi
  exit "${2:-1}"
}
```

Dolayısıyla L-1'in istediği "hangi bayrak?" bilgisini basmanın **hiçbir yolu yok** — bugün
`_q_die err_unknown_flag 2 "$1"` yazılsa `"$1"` sessizce yutulur.

Diğer taraf iyi haber: `_q_msg` (`quipu:66-82`) sözlükten okuduğu değeri **ham dizge**
olarak döndürür; `printf '%s\n' "$_q_v"` (`quipu:78`) ile basar, yani içinde `%s` bulunan
bir değeri **format olarak yorumlamaz, aynen verir**:

```sh
  _q_v=$(awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,"");print;exit}' "$_q_f" 2>/dev/null || true)
```

**Etki:** J-2 için gereken tek şey `_q_die`'ın kalan argümanları `printf "$fmt" "$@"` ile
tüketmesi; `_q_msg` zaten format dizgesi döndürdüğü için i18n katmanına dokunmak
gerekmez. Mevcut `key [code]` çağrılarının hepsi (`$# = 0` kalan arg) eski dalda kalır →
geriye uyumluluk kod düzeyinde garantidir, T-81 kapıyı kilitler.

## L-3 — `search --brief` YOK: katlanmış alan bellekte var, çıktıda yok

`[kaynak: lib/search.awk:42, lib/search.awk:111, lib/search.awk:10, quipu:969-970, quipu:943]`

İndeks satırının 5. sütunu katlanmış arama alanıdır (`quipu:943`,
`printf '%s\t%s\t%s\t%s\n' "$_q_p" "$_q_meta" "$_q_mt" "$_q_flat"` — `_q_meta` başlık+etiket
olmak üzere iki alan taşıdığı için toplam beş sütun; `lib/search.awk:6`: *"column 5 is the
folded, single-space-squeezed search field"*).

`search.awk` bu sütunu **okuyup belleğe alıyor** (`lib/search.awk:42`):

```awk
  folded[n] = $5
```

ve skorlamada dört yerde kullanıyor (`:53`, `:55`, `:75`, `:84`, `:91`) — ama **emit
satırına koymuyor** (`lib/search.awk:111`):

```awk
      printf "%.3f%c%s%c%s%c%s%c", score, 9, path[d], 9, title[d], 9, tags[d], 10
```

Çıktı sözleşmesi dört sütun: `skor<TAB>yol<TAB>başlık<TAB>etiketler`
(`lib/search.awk:10`). `quipu` tarafında da künye anahtarı yok: `_q_cmd_search` yalnız
`--limit` ve `--paths` tanıyor (`quipu:969-970`), `--brief` diye bir dal **mevcut değil**
(L-1'in sonucu olarak yazılsa da sessizce sorgu kelimesi olurdu).

**Etki:** Ajan `--limit 50` ile 50 aday alınca elinde yalnız yol + başlık + etiket olur;
50 dosyayı **okumadan** anlamla seçmesi imkânsızdır — PLAN §7'nin "iki aşamalı daralt-sonra-oku"
deseninin ikinci adımı ürüne hiç girmemiş. J-5 tam olarak bu boşluğu kapatır: veri zaten
bellekte, maliyet yalnız bir `substr` + bir sütun.

## L-4 — Ölçek iddiası hiç ölçülmemiş

`[kaynak: docs/PLAN.md:578, tests/run.sh:101, tests/run.sh:200, tests/run.sh:94]`

PLAN §7 risk tablosu şunu iddia ediyor (`docs/PLAN.md:578`):

> | İndeks bağlam sınırı | Semantik katman indeksi ajanın okumasına dayanır. **Birkaç bin
> nota kadar rahat**; ötesinde iki aşamalı daralt-sonra-oku gerekir. |

Bu cümlenin arkasında **hiçbir ölçüm yok**. Test paketinde büyük *vault* senaryosu
bulunmuyor; süre sınırı iddia eden yalnızca iki satır var ve ikisi de **tek büyük JSON
payload**'ını (448 KB, `tests/run.sh:94` `for(i=0;i<7000;i++)` üreteci) ölçüyor, doküman
sayısını değil:

- `tests/run.sh:101` — `t; assert_eq "448 KB payload: bounded time" 'yes' "$([ $((END - START)) -lt 30 ] && printf yes || printf no)"`
- `tests/run.sh:200` — `t; assert_eq "capture: 448 KB payload bounded time" 'yes' "$([ $((END - START)) -lt 30 ] && printf yes || printf no)"`

Yani ölçülen şey `capture`'ın **girdi sınırı** (PLAN 4.12/4.8), `index`/`search`'ün
**doküman sayısı** ölçeği değil. FAZ 7 öncesi paketin tamamında dört haneli doküman üreten
bir döngü yok; en büyük yapay veri 200 karakterlik bir yol (`tests/run.sh:219`) ve yukarıdaki
payload'lardır.

**Etki:** J-7 sentetik 5000 dosyalık vault (üreteç, fixture değil) ile T-85/T-86/T-87
iddiaya kanıt bağlar; ölçüm deseni mevcut `date +%s` + `[ $((END - START)) -lt N ]`
kalıbından devralınır (`tests/run.sh:97-101`). Ölçüm sonrası PLAN §7 satırı "birkaç bin"
tahmininden ölçülmüş sayıya döner (J-9).

## L-5 — Katlanmış alan tr/latin profillerinde ASCII'ye iner; `fold=default`'ta İNMEZ

`[kaynak: quipu:942, quipu:1003, fold/tr.sed:9-110, fold/default.sed:1-8, quipu:189]`

Katlama boru hattı iki yerde, aynı sırada kurulu (PLAN 4.3: **önce `sed -f fold/…`, sonra
`tr`**):

- indeks üretimi — `quipu:942`:
  `_q_flat=$(cd "$_q_v" && sed -f "$_q_HOME/fold/$_q_prof.sed" "$_q_p" | tr 'A-Z' 'a-z' | awk -v mode=flat -v max=2000 -f "$_q_HOME/lib/index.awk")`
- sorgu katlama — `quipu:1003`:
  `_q_terms=$(printf '%s\n' "$_q_query" | sed -f "$_q_HOME/fold/$_q_prof.sed" | tr 'A-Z' 'a-z')`

`fold/tr.sed` latin tabanı (`:9-100`: `À→a` … `œ→oe`) + Türkçe blokla (`:102-110`:
`I→ı→i`, `İ→i`, `Ğ/ğ→g`, `Ş/ş→s`) **listelenmiş** çok baytlı kod noktalarını ASCII'ye
indirir; ardından `tr 'A-Z' 'a-z'` ASCII büyük harfleri düşürür. Bu profilde tipik Türkçe
metin için 5. sütun saf ASCII'dir → bayt sınırında kesim çok baytlı diziyi ortadan kesemez.

### Sınırlama 1 (bağlayıcı): `fold=default` hiçbir şey katlamaz

`fold/default.sed` bir tane `s///` komutu içermez; kendi başlığı bunu yazıyor
(`fold/default.sed:2-6`): *"ASCII-only: folds nothing itself… Multibyte characters pass
through unchanged — no lossy folding without an explicit profile."*

Profil seçim zinciri `fold=` → `_q_lang`=tr ise `tr` → aksi hâlde **`default`**
(indeks: `quipu:891-901`; search: `quipu:986-996`). Yani **`lang=en` bir vault varsayılan
olarak `default` profilinde çalışır** ve 5. sütun ham çok baytlı metni aynen taşır
(emoji, kıvrık tırnak, CJK, Kiril, hatta katlanmamış Türkçe). Üçüncü profil `latin.sed`
(99 satır, tr.sed'in latin tabanının aynısı) da yalnız listelediği kod noktalarını indirir;
üç profilin tamamı `quipu:189`'daki doctor listesinde sayılıdır.

**[ölçüm: bu makine]** `QUIPU_LANG=en` + `fold=` satırı olmayan config (yalnız
`layout=emoji`) ile kurulan geçici vault'a `acik kapi Iğdır çöp ölçüm emoji 🔮 test`
satırlı bir not yazıldı; `quipu index` sonrası `index.tsv` 5. sütunu
`# baslik → acik kapi iğdır çöp ölçüm emoji 🔮 test` döndü — `ğ`, `ç`, `ö` ve emoji
**aynen** korundu, yalnız ASCII `I` harfi `tr 'A-Z' 'a-z'` adımıyla küçüldü.

**Sonuç: SPEC §1'in "katlanmış alan saf ASCII → bayt kesimi güvenli" gerekçesi yalnız
tr/latin profilleri ve o profillerin listelediği kod noktaları için geçerlidir.** J-5'in
gerçek güvenlik dayanağı ASCII varsayımı değil, **kelime sınırında kesim** olmalıdır:
boşluk (0x20) hiçbir UTF-8 çok baytlı dizisinin içinde geçmez (devam baytları ≥ 0x80), bu
yüzden "son boşluğa kadar geri sar" kuralı profil ne olursa olsun bayt-güvenlidir. Artık
risk tek bir kenar durumdadır: **ilk 120 baytta hiç boşluk yoksa** geri sarılacak sınır
bulunmaz ve sabit kesim `default` profilinde çok baytlı bir karakteri ortadan ikiye
bölebilir. (Bu, `--brief` uygulamasının fallback dalıdır; T-82/T-83 ASCII içerikle koştuğu
için bu dalı görmez.)

### Sınırlama 2: `awk` `length`/`substr` birimi platforma göre bayt ya da karakter

`[ölçüm: bu makine, GNU Awk 5.4.0 — awk 'BEGIN{print length("ığ")}' → 2]`

gawk çok baytlı yerelde `length`/`substr`'i **karakter** birimiyle çalıştırır: iki Türkçe
harf UTF-8'de 4 bayttır ama `length` 2 döndürür. Yani `snip=120` gawk'ta "120 karakter"
(çok baytlı içerikte 480 bayta kadar), mawk/busybox awk'ta "120 bayt" anlamına gelir
`[doğrulanmadı — mawk/BSD awk üç OS CI'da görülecek]`. `--brief` künyesini **bayt** üst
sınırıyla iddia eden bir test, `fold=default` + çok baytlı içerik bileşiminde gawk'ta
kırılabilir; ASCII'ye inen tr profilinde karakter = bayt olduğu için iddia sağlamdır.
Pratik sonuç: künye şekli testleri katlama profilini `fold=tr` ile **sabitlemeli** (ya da
sınırı "≤ 120 karakter" diye okumalı). Bu koşul FAZ 7 test paketinde **sağlanmış
durumdadır**: `mk_search_vault` config'i `fold=tr` + `lang=en` pinliyor
(`[kaynak: tests/run.sh:493-496]`) ve `--brief` iddialarının eşleştiği dokümanlar baştan
ASCII — **[ölçüm: Dilim 2]** eşleşen üç dokümanın 5. sütununda `bytes=194`,
`awkchars=194`, `high_bytes=0`; karşıt kurulumda (`fold=default` + `ığüşöç` içeren
doküman) `high_bytes=12`, yani Sınırlama 1/2 birlikte doğrulandı.

---

## Tasarım etkileri (L → J eşlemesi)

| Bulgu | Sözleşme maddesi | Ne gerektiriyor |
|---|---|---|
| L-1 | J-1, J-3, J-4 | `err_unknown_flag` anahtarı + dört döngüye ve search'e `-*)` dalı; `*)` dalları yerinde |
| L-2 | J-2 | `_q_die key [code [arg…]]`; `_q_msg` format döndürdüğü için i18n dokunulmaz, eski çağrılar aynen |
| L-3 | J-5, J-6 | 5. sütun künye (`folded[d]`'den `substr`); `--brief` ⊕ `--paths` |
| L-4 | J-7, J-9 | 5000 dosyalık sentetik vault + süre sınırları; PLAN §7 satırı ölçüme bağlanır |
| L-5 | J-5, J-8 | Kesim kelime sınırında (marker yok); ASCII varsayımı **profil koşullu** → dürüst tavan notu |

## Test malzemesi (Dilim 1-3 için)

- **DZ-4 (T-78…T-81):** i18n metnine bakan her iddiada `QUIPU_LANG=en` (L-1'in mesajı
  dile bağlı). T-81'in beklediği metin `i18n/en.txt:11` = `missing required argument`.
- **`--brief` (T-82…T-84):** L-5 Sınırlama 2 gereği vault config'i `fold=tr` ile
  sabitlenmiştir (`tests/run.sh:493-496`); künye ASCII olur ve "≤ 120 bayt" iddiası
  platformdan bağımsız tutar. Eşleşen dokümana ASCII-dışı katlanmış metin **eklenmemeli**
  — eklenirse iddia gerçek bayt sayımına çevrilmelidir.
  Künyenin son karakterinin boşluk olmadığı (T-83) L-5'in kelime-sınırı kuralının kanıtıdır.
- **Ölçek (T-85…T-87):** üreteç döngüsü (fixture YASAK, `tests/run.sh:94` desenindeki gibi
  tek `awk BEGIN` döngüsü), süre ölçümü `date +%s` + `[ $((END - START)) -lt N ]`
  (`tests/run.sh:97-101`), satır sayımı `awk 'END{print NR}'`.
