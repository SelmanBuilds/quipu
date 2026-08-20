# quipu — FAZ 3 düzeltme talimatı (inceleme sonrası, REVİZE)

> FAZ 3 uygulaması **kabul edildi** (PR #3 merged, `39d79cd`): `FAZ3-SPEC.md` C-1…C-36 +
> `FAZ3-BULGULAR.md` AM-1…AM-4 birebir karşılandı, KONTROL §7'nin 8 kırmızı bayrağı temiz.
> Aşağıdaki düzeltmeler FAZ 4'ten **önce** yapılacak. **Revizyon:** ilk sürümdeki N1 kod
> düzeltmesi bağımsız inceleme sonrası **retrakte edildi** — taşma yok. Kalan iş: N1-test
> sıkılaştırma (gerekçesi değişti), N2 doküman (üç satır), N3 savunmacı guard (iyileştirilmiş test).
> Kapsam **yalnızca** bunlar — başka refaktör yok, davranış N3 dışında değişmez.

---

## N1 — RETRAKT: taşma yok (`quipu:593` dokunulmaz)

### Hüküm

İlk talimattaki "1 bayt taşma" teşhisi **yanlıştı**. Kod, C-16 değişmezini (`toplam çıktı ≤
QUIPU_CTX_MAX`) zaten tam olarak sağlıyor. `quipu:593` **değiştirilmez**.

### Neden yanlıştı

İlk model, `_q_thr` değişkeninin sonunda `\n` taşıdığını varsayıyordu. Oysa `_q_thr` komut
ikamesiyle üretiliyor (`quipu:596`); POSIX komut ikamesi sondaki **tüm** satır sonlarını keser.
Muhasebe (awk gövdesi `quipu:600-610`):

```
acc ≤ budget                                  (her satır n+1 bayt sayılır, \n dahil — quipu:605-606)
awk çıktısı = acc + _q_msize                  (EN KÖTÜ durum: cut; kırpma yoksa yalnızca acc — quipu:609)
_q_thr       = awk çıktısı − 1                (komut ikamesi sondaki \n'i keser)
toplam       = _q_fixed + (_q_thr) + 1        (son metin: act + thr + "\n" + idx — quipu:614-615)
             = _q_fixed + acc + _q_msize
             ≤ _q_fixed + budget + _q_msize
             = _q_max   ✓
```

Ayrıcın sayılmadığı `+1` ile komut ikamesinin kestiği `−1` birbirini tam götürüyor. Sıkı durumda
çıktı tam `QUIPU_CTX_MAX` bayttır, asla `+1` değil. `quipu:593`'ü değiştirmek kullanılabilir
bütçeyi 1 bayt daraltır ve koda yanlış bir modeli sabitler — **uygulanmaz.**

### Uygulanacak tek değişiklik: test sıkılaştırma

`tests/run.sh:521` — gerekçe "yeni bir düzeltmeyi ölçmek" **değil**, zaten geçerli olan değişmezi
ilk kez gerçekten test etmek (`+10` toleransı gerçek sınırı gizliyordu; T-41 şu an 988 bayt üretiyor):

```sh
# ÖNCE
assert_eq "context bound: body within QUIPU_CTX_MAX+10" 'yes' "$([ "$SIZE" -le 1010 ] && printf yes || printf no)"
# SONRA
assert_eq "context bound: body within QUIPU_CTX_MAX" 'yes' "$([ "$SIZE" -le 1000 ] && printf yes || printf no)"
```

Bir platformda 1001 çıkarsa **geri rapor et** — o zaman gerçekten bilinmeyen bir sızıntı var
demektir; sessizce 1001'e gevşetme.

### Kenar durum (bilinen sınır, KAPSAM DIŞI — kayda geçsin)

`QUIPU_CTX_MAX < _q_fixed + _q_msize` (~60 bayt) ise `_q_budget < 0` olur; awk yine de marker'ı
basar (`END { if (cut) print m }`) ve toplam sınırı aşar. C-16'yı ihlal edebilen **tek gerçek yol**
budur. Gerçekçi değildir (sabit bölümler — `ctx_activity` başlığı + `ctx_index` satırı + marker —
zaten ~60 bayt). Guard istenirse **ayrı bir madde** olarak ele alınır; bu pakete girmez.

---

## N2 — test sayısı raporlaması + PR durumu (doküman, üç satır)

### Sorun

`docs/PLAN.md`'de "154/154" ve "PR pending" ifadeleri kaldı. `tests/run.sh:762` özeti
`# pass 154, fail 0, skip 2` basıyor; 2 skip, `command -v shellcheck` kontrolünden
(shellcheck.exe PATH dışı, `.claude/tools/` altında; `run.sh:135`). Yani 156 iddia, 154 geçti.
"154/154" yanlış. Ayrıca PR #3 merged olduğu halde üç yerde "PR'a kaldı / pending" kalmış.

### Uygulama

N1-test (sayı değişmez) + N3-test (1 yeni iddia) sonrası **gerçek sayıyı** `sh tests/run.sh`
çıktısından al (öngörü: `155 geçti + 2 skip`, 157 iddia), sonra üç yeri düzelt:

`docs/PLAN.md:8`:

```md
# ÖNCE
> **Tarih:** 2026-08-20 · **Durum:** FAZ 3 tamam — Claude Code adaptörü (referans uygulama) + `quipu remember`; üç OS CI PR'a kaldı. FAZ 4 sırada.
# SONRA
> **Tarih:** 2026-08-20 · **Durum:** FAZ 3 tamam — Claude Code adaptörü (referans uygulama) + `quipu remember`; üç OS CI yeşil (PR #3, 39d79cd). FAZ 4 sırada.
```

`docs/PLAN.md:534`:

```md
# ÖNCE
testler 117 → 154. Üç OS CI notu PR'a kaldı (**PR pending**).
# SONRA
testler 117 → 155 geçti + 2 skip (157 iddia). Üç OS CI yeşil (PR #3, 39d79cd).
```

`docs/PLAN.md:624-625`:

```md
# ÖNCE
README "Claude Code" bölümü; FAZ3-SPEC sözleşmesi C-1..C-36; yerelde 154/154, shellcheck sessiz;
üç OS CI notu PR'a kaldı (**PR pending**).
# SONRA
README "Claude Code" bölümü; FAZ3-SPEC sözleşmesi C-1..C-36; yerelde 155 geçti + 2 skip
(shellcheck PATH dışı; shellcheck.exe sessiz); üç OS CI yeşil (PR #3, 39d79cd).
```

> **Kural:** `155`/`157` öngörüdür. `sh tests/run.sh` ne basarsa onu yaz — `N/N` biçimini bir daha
> kullanma; daima `geçti + skip` biçimini yaz. Commit mesajı (zaten merged) elle düzeltilmez.

---

## N3 — bozuk log satırlarında boş timestamp'li sindirim (savunmacı)

### Sorun

`lib/digest.awk` digest modunda, dilimdeki satırların **hiçbiri** üç `" | "` ayracı + boş olmayan
PATH içermiyorsa `n==0` olur ve `RANGE` satırı boş `first`/`last` ile basılır (`RANGE\t\t\t0`).
`quipu remember` bunu "Range: → (0 events)" olarak `<sessions>/YYYY-MM-DD.md`'ye yazar,
`Last-Session.md`'ye dokunur ve filigranı ilerletir. Normal akışta erişilemez (capture hep iyi
biçimli üretir); elle düzenlenmiş `activity.log`'da çöp bölüm yazar.

### Uygulama

`quipu:707` (`_q_count=` satırından hemen sonra, `_q_tools=` satırından önce) guard ekle:

```sh
  _q_count=$(printf '%s\n' "$_q_digest" | awk -F"$_q_tab" '$1=="RANGE"{print $4; exit}')
  # Savunmacı (C-1): dilimde geçerli olay yoksa sindirim yazılmaz ve filigran ilerlemez.
  if [ -z "$_q_count" ] || [ "$_q_count" = 0 ]; then
    _q_msg remember_empty
    exit 0
  fi
```

Nokta yan etkisizdir: guard'dan önce hiçbir yazma/`mkdir`/`mktemp` yok; üç yazma adımı
(sessions `:744-745`, `Last-Session.md` `:748-749`, filigran `:751`) ve `trap` (`:724-725`)
hepsi guard'dan sonra. `exit 0` temiz. Filigranın ilerlememesi kasıtlı: geçersiz satırlar asla
"tüketilmez", her koşuda ucuzca yeniden taranır ve sessizce düşürülmez.

### Test (iyileştirilmiş)

`tests/run.sh`'de T-40 bloğunun hemen sonrasına (satır 697 civarı) ekle. `init` **Last-Session.md
oluşturmaz** (yalnızca `remember` oluşturur), bu yüzden `! -f` doğrudur:

```sh
mkrem vr50
printf 'not a valid log line\n' > "$TMP/vr50/.quipu/activity.log"
t; OUT=$(rem vr50); RC=$?
assert_eq "remember: malformed log is a no-op" 'yes' \
  "$([ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF "$REM_EMPTY" && [ ! -f "$TMP/vr50/700-Sessions/$D.md" ] && [ ! -f "$TMP/vr50/Last-Session.md" ] && [ ! -f "$TMP/vr50/.quipu/remembered" ] && printf yes || printf no)"
```

### Not (ölü dal)

`-z "$_q_count"` dalı pratikte ölüdür: digest modunda `RANGE` her koşulda basılır, `$4` daima
dolu. Zararsız savunma, kalsın; bu dal için test yazılması beklenmez ve kimse peşine düşmesin.

---

## Uygulayıcı ajana net liste

1. ~~`quipu:593`~~ — **dokunma** (N1 retrakte).
2. `tests/run.sh:521` — `-le 1010` → `-le 1000`, test adını `QUIPU_CTX_MAX+10` → `QUIPU_CTX_MAX`.
3. `quipu:707` sonrası — N3 guard'ını ekle (yukarıdaki gibi).
4. `tests/run.sh` T-40 sonrası — N3 testini ekle, `Last-Session.md` `! -f` assert'i dahil.
5. `sh tests/run.sh` çalıştır; basılan `pass/fail/skip` sayısını al.
6. `docs/PLAN.md:8, :534, :624-625` — yukarıdaki SONRA blokları, sayıyı 5. adımdan yaz.

## Çıkış koşulu (revize)

1. `sh tests/run.sh` yerelde yeşil (fail 0, skip 2); T-41 sıkı sınırı (`-le 1000`) ve N3 testi geçiyor.
   (Bu, N1'in "bir şeyi düzelttiğinin" kanıtı değil — mevcut davranışın kilitlenmesidir.)
   **Üç OS kanıtı ayrıdır:** `-le 1000`'in Linux ve macOS'ta da geçtiği yalnızca CI koşusuyla
   (PR + üç OS matrisi yeşil) doğrulanır. Yerel yeşil bu koşulu **kapatmaz**; CI yeşil olana dek
   #1 "kısmen" sayılır. Çıktıda CI linki/durumu bulunmalı.
2. `./.claude/tools/shellcheck.exe -s sh quipu tests/run.sh` sessiz.
3. PLAN.md'de `154/154`, `PR pending`, `PR'a kaldı` kalmadı; sayı raporla teyitli.
4. Kapsam dışına çıkılmadı; `quipu:593` değişmedi.
