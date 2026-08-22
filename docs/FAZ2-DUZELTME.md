# quipu — FAZ 2 düzeltme talimatı (inceleme sonrası)

> FAZ 2 uygulaması **kabul edildi**: 115/115 test yeşil, shellcheck temiz, `docs/FAZ2-SPEC.md`
> B-1…B-33 karşılanmış. Aşağıdaki düzeltmeler commit/CI öncesi yapılacak: **D1** (davranış
> gerilemesi), **D2** (test kırılganlığı), **D3** (housekeeping), **D4** (bulgunu PLAN'a yaz).
> Kapsam **yalnızca** bunlar. Başka refaktör yok, spec yeniden yorumlanmayacak.
>
> Raporundaki iki tespit bağımsız olarak doğrulandı ve **doğru**: (a) `_q_msg`'in global `_q_v`'yi
> ezmesi — vault OneDrive uyarısı gerçekten ölü koddu, koyduğun `_q_v=$(_q_vault)` guard'ı yerinde
> ve D1'den sonra da kalmalı; (b) GNU grep 3.0'ın 4 baytlık emoji kalıplarını eşleştirmemesi —
> bkz. D4. İkisi de iyi yakalanmış.

---

## D1 — doctor: OneDrive kurulum-yolu uyarısı geri gelmeli (gerileme)

### Sorun

`quipu:245-256`. Uyarı bloğunun **tamamı** `[ "$_q_lay" = emoji ]` kapısının arkasında.
`_q_lay` ancak vault varsa **ve** `.quipu/config` içinde `layout=` satırı varsa doluyor.
Sonuç: vault yokken `_q_lay` boş kalıyor ve kurulum yolu kontrolü hiç çalışmıyor.

FAZ 1'de bu uyarı koşulsuzdu. Aynı dizinde iki sürüm karşılaştırıldı:

```
YENİ (HEAD+worktree):  summary: 22 ok, 1 warn, 0 fail        ← OneDrive uyarısı YOK
ESKİ (HEAD):           warn  path  path contains OneDrive (emoji folder risk, PLAN 4.9)
                       summary: 17 ok, 2 warn, 0 fail
```

Kaybedilen senaryo, PLAN'ın tavsiye ettiği ilk adımın ta kendisi: kullanıcı quipu'yu
OneDrive'lı bir yola kuruyor → **önce `doctor`** çalıştırıyor (henüz vault yok) → uyarı almıyor
→ `init` varsayılan emoji ile riskli klasörleri kuruyor. Uyarının en değerli olduğu an bu an.

**Not:** Bu bir spec kusuru, senin hatan değil. Raporunda B-23'ü "OneDrive kurulum+vault yolu,
yalnızca `layout=emoji`'de" diye özetlemişsin — yani bilinçli bir okuma, ve lafza uygun. `FAZ2-SPEC.md` B-23'ün lafzı ("kurulum yolu *veya* vault yolu
OneDrive içeriyorsa uyar; emoji risk mesajı yalnızca `layout=emoji` ise verilir") iki türlü
okunabiliyordu. Aşağıdaki davranış bağlayıcı yeni tanımdır.

### İstenen davranış

| Durum | `_q_HOME` OneDrive içeriyor | vault yolu OneDrive içeriyor |
|---|---|---|
| `layout=emoji` | uyar (`doc_onedrive`) | uyar (`doc_onedrive_vault`) |
| `layout` çözülmedi (vault yok / config'te `layout=` yok) | **uyar** (`doc_onedrive`) | uyarma (vault yok) |
| `layout=plain` | uyarma | uyarma |

Gerekçe: yerleşim çözülmemişse bir sonraki `init` **varsayılan olarak emoji** kuracak,
yani risk fiilen mevcut. `plain` ise risk gerçekten yok (PLAN §4.9 emoji klasör adları hakkında).

### Uygulama

`quipu:245-256` şu blokla değiştirilir:

```sh
  _q_msg doc_sec_warn
  _q_lay=${_q_lay:-}
  _q_v=$(_q_vault)
  # PLAN 4.9: the emoji-folder risk applies when the active layout is emoji, and
  # also when no layout is resolved yet - the next `init` defaults to emoji.
  if [ "$_q_lay" != plain ]; then
    case "$_q_HOME" in
      *OneDrive*) _q_line warn path "$(_q_msg doc_onedrive)" ;;
    esac
  fi
  if [ "$_q_lay" = emoji ]; then
    case "$_q_v" in
      *OneDrive*) _q_line warn vault "$(_q_msg doc_onedrive_vault)" ;;
    esac
  fi
```

Bu blok inceleme sırasında geçici bir kopyada uygulanıp ölçüldü; `sh -n` temiz ve üç senaryo
istenen sonucu veriyor (OneDrive geçen uyarı satırı sayısı): vault yok → **1**, `plain` vault → **0**,
`emoji` vault → **2**. Yamayı olduğu gibi uygula.

- `_q_v=$(_q_vault)` satırı **kalmalı**. `_q_msg doc_sec_warn` doğrudan (komut ikamesi olmadan)
  çağrıldığı için `_q_msg` içindeki `_q_v=` ataması üstteki vault değerini eziyor; bu satır onu
  geri okuyor. Silme.
- Yeni i18n anahtarı gerekmiyor; `doc_onedrive` ve `doc_onedrive_vault` zaten var.

### Testler

`tests/run.sh` FAZ 2 bölümüne eklenecek. Kurulum yolunu taklit etmek için `QUIPU_HOME` yerine
gerçek bir kopya kullan — `_q_HOME` kontrolü yol dizgesine bakıyor:

```sh
# doctor: the OneDrive install-path warning must not depend on a vault existing.
ODH="$TMP/OneDrive-home"
mkdir -p "$ODH"
cp "$ROOT/quipu" "$ODH/"
cp -r "$ROOT/lib" "$ROOT/i18n" "$ROOT/fold" "$ROOT/layout" "$ROOT/persona" "$ODH/"
mkdir -p "$TMP/odwork"
t; OUT=$( (cd "$TMP/odwork" && sh "$ODH/quipu" doctor) 2>&1 )
assert_eq "doctor: OneDrive install path warns with no vault" 'yes' \
  "$(printf '%s\n' "$OUT" | grep -q OneDrive && printf yes || printf no)"
t; OUT=$( (cd "$TMP/vfreshp" && sh "$ODH/quipu" doctor) 2>&1 )
assert_eq "doctor: plain layout suppresses the OneDrive warning" 'no' \
  "$(printf '%s\n' "$OUT" | grep -q OneDrive && printf yes || printf no)"
```

İkinci iddia `$TMP/vfreshp` (`--plain` ile kurulmuş vault) üzerinde koşuyor; o vault
FAZ 2 bölümünde zaten var, yeniden kurma. Bu iki iddia dosyanın sonuna değil,
**mevcut `doctor: layout line shows plain` satırından sonra** eklenir (`vfreshp` orada kurulu).

**`grep` kullanımı burada bilinçli:** aradığın dizge `OneDrive`, saf ASCII. Senin bulduğun
4-baytlık kalıp sorunu (aşağıda D4) yalnızca çok baytlı dizgeleri ilgilendiriyor; ASCII grep
bu makinede doğrulandı, çalışıyor. Klasör adı gibi emoji içeren dizgelerde `awk index()`
kuralın geçerliliğini koruyor.

---

## D2 — testler: locale'e bağımlı iki iddia

### Sorun

`tests/run.sh:374-375`:

```sh
t; assert_eq "doctor: layout line shows emoji" 'yes' "$(awk -F"$TAB" '$2=="layout" && $3=="emoji" {print "yes"; exit}' "$TMP/vfresh.out")"
t; assert_eq "doctor: layout line shows plain" 'yes' "$(awk -F"$TAB" '$2=="layout" && $3=="plain" {print "yes"; exit}' "$TMP/vfreshp.out")"
```

İkinci sütun `_q_line`'a `$(_q_msg doc_layout)` olarak veriliyor, yani **i18n'li**: Türkçe'de
`yerleşim`. `vfresh`/`vfreshp` vault'larında `lang=` yok, dolayısıyla dil `LC_ALL`/`LANG`'dan
geliyor. `LANG=tr_TR.UTF-8` olan bir geliştirici makinesinde veya öyle yapılandırılmış bir
runner'da bu iki test, kodda hiçbir sorun yokken kırmızıya döner.

Aynı dosya 8 satır aşağıda doğrusunu yapıyor (`threads_seed_title`/`threads_seed_note`'u
i18n'den okuyup arıyor) — tutarsızlık da bu.

### Uygulama

`doctor` çağrılarını dilden yalıtmak en ucuzu. `tests/run.sh:368` ve `:371`'deki iki çağrıya
`QUIPU_LANG=en` eklenir, iddialar aynen kalır:

```sh
t; (cd "$TMP/vfresh" && QUIPU_LANG=en "$ROOT/quipu" doctor) >"$TMP/vfresh.out" 2>&1; RC=$?
assert_eq "doctor: fresh emoji vault exits 0" '0' "$RC"

mkvault vfreshp
QUIPU_VAULT="$TMP/vfreshp" sh "$ROOT/quipu" init --plain >/dev/null 2>&1
t; (cd "$TMP/vfreshp" && QUIPU_LANG=en "$ROOT/quipu" doctor) >"$TMP/vfreshp.out" 2>&1; RC=$?
assert_eq "doctor: fresh --plain vault exits 0" '0' "$RC"
```

`_q_lang()` zincirinde `QUIPU_LANG` en yüksek öncelikte (`quipu:48`), config'i de LANG'ı da
ezer — yalıtım tam olur.

**Alternatif kabul edilmez:** `$2` yerine `$3`'e bakıp `$2`'yi hiç kontrol etmemek. Satırın
doğru satır olduğunu doğrulamak testin işi.

---

## D3 — housekeeping (kod değişikliği yok)

1. `layout/`, `persona/` ve `docs/FAZ2-SPEC.md` hâlâ **untracked**. Üçü de commit'e girecek.
   `docs/PLAN.md` §3'e eklenen taksonomi satırı `docs/FAZ2-SPEC.md`'ye atıf yapıyor; dosya
   commit edilmezse referans boşa düşer.
2. `tests/run.sh:277` — `RC=$?` alınıp hiç kullanılmıyor:
   ```sh
   t; (cd "$TMP/vexcl" && "$ROOT/quipu" index) >/dev/null 2>&1; RC=$?
   assert_eq "index: CLAUDE.md excluded, not.md indexed" '1' "$(...)"
   ```
   Ya `RC` iddia edilsin (`index` çıkışı 0 olmalı, ayrı bir `t;` ile), ya da `; RC=$?` silinsin.
   Satır şu hâliyle eksik bir assert gibi okunuyor.

---

## D4 — `grep` bulgusunu PLAN §4'e yaz (yeni iş)

Raporunda geçen şu bulgu **kaybedilmemeli**: Windows'ta GNU grep 3.0, `LANG=en_US.UTF-8`
altında 4 baytlık emoji kalıplarını eşleştirmiyor. İnceleme sırasında bağımsız olarak
yeniden ürettim, doğrulandı:

```
grep (GNU grep) 3.0   ·   LANG=en_US.UTF-8
hedef: [🔮 850-Companion]
grep -q   → eşleşmiyor
grep -qF  → eşleşmiyor      (-F de kurtarmıyor)
awk index() → eşleşiyor
grep 'OneDrive' (ASCII) → eşleşiyor
```

Bu, PLAN §4'ün ("Doğrulanmış bulgular — KRİTİK, yeniden keşfetmeyin") tam olarak topladığı
cinsten, ölçülmüş bir platform olgusu ve §4.1-4.3'ün (`sed` karakter sınıfları, BSD `tr`)
doğal kardeşi. Yazılmazsa FAZ 3'te yeniden keşfedilecek.

**Yapılacak:** `docs/PLAN.md` §4'e yeni bir alt bölüm eklenir — `### 4.17 grep çok baytlı
kalıpları eşleştirmeyebilir` (numarayı dosyadaki son alt bölüme göre ver). İçerik: yukarıdaki
tablo, yeniden üretme komutu, ve kural:

> **KURAL:** Çok baytlı bir dizgeyi metinde ararken `grep` kullanma; `awk index()` kullan.
> ASCII dizgeler için `grep` güvenlidir.

§7 risk tablosuna da bir satır: mevcut "Katlama kayıplı" / "macOS/BSD" satırlarının yanına
`grep çok baytlı kalıp` → ✅ KAPANDI (FAZ 2: testlerde `awk index()`'e geçildi).

---

## Çıkış koşulu

1. `sh tests/run.sh` yeşil — mevcut 115 + D1'den 2 yeni iddia = 117
2. `shellcheck -s sh quipu tests/run.sh` temiz.
   **"shellcheck yerelde kurulu değil" artık geçerli bir risk değil:** depoda
   `.claude/tools/shellcheck.exe` (sürüm 0.10.0) duruyor. `.claude/` gitignore'da olduğu için
   gözden kaçmış olabilir. İnceleme sırasında bu ikiliyle koşturuldu ve **temiz** çıktı —
   yani yeni `disable` yorumların şu an sorun çıkarmıyor. Bundan sonra CI'yı beklemeden
   yerelde kapı olarak kullan:
   ```sh
   ./.claude/tools/shellcheck.exe -s sh quipu tests/run.sh
   ```
   Test paketindeki 2 SKIP de bu yüzden: harness `PATH`'te arıyor, depodaki ikiliyi görmüyor.
   İstersen `tests/run.sh`'ın shellcheck aramasına `.claude/tools/shellcheck.exe` fallback'i
   eklenebilir — opsiyonel, bu düzeltmenin zorunlu parçası değil.
3. Şu üç senaryo elle doğrulanmış olmalı:
   - OneDrive'lı kurulum yolu + vault yok → `doctor` OneDrive uyarısı **veriyor**
   - OneDrive'lı yol + `layout=plain` vault → uyarı **yok**
   - OneDrive'lı yol + `layout=emoji` vault → **iki** uyarı (`path` ve `vault`)
4. `git status` temiz: `layout/`, `persona/`, `docs/FAZ2-SPEC.md` izleniyor
5. Dal + PR açılır (FAZ 1 Adım 3 deseni), üç OS CI yeşil olmadan merge yok

## Değiştirilmeyecekler

- Taksonomi klasör adları, slug'lar, emoji seçimi (K-1/K-2 onaylandı, `layout/*.txt` dondu)
- `_q_mdlist` sözleşmesi ve üç çağrı yeri
- `companion.md` / `Threads.md` yalnızca-yoksa davranışı (B-9)
- `err_layout_conflict` / `err_layout_unknown` akışı — elle doğrulandı, doğru çalışıyor
- README'deki `26 ok` ve `indekslendi 3` sayıları — gerçek çıktıyla birebir eşleşiyor.
  D1'den sonra bu sayılar **değişmez** (test makinesinde OneDrive yolu yok); yine de
  `quipu doctor` çıktısını bir kez daha karşılaştır, tahmin etme.
