# quipu — FAZ 2 SPEC: Vault taksonomisi + kimlik

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: `docs/PLAN.md` §6 FAZ 2, §2 (dört katman), §3 (verilmiş kararlar), §4.9, §4.11.
> Ön koşul: FAZ 1 tamam (altı komutlu CLI, üç OS CI yeşil, PR #1 merge).

## 0. Karar noktaları (uygulamadan önce onaylanmalı)

Bu iki maddeyi PLAN belirlemiyor; spec bir varsayım seçti. Yanlışsa **önce burayı düzelt**,
sonra uygula — sonradan değiştirmek kullanıcı vault'unda klasör taşıma demektir.

| # | Varsayım | Gerekçe |
|---|---|---|
| K-1 | Varsayılan yerleşim **emoji**, `--plain` ASCII'ye düşürür | PLAN §6: "emoji opsiyonel — `--plain` bayrağı olsun" → bayrağın adı emoji'nin varsayılan olduğunu ima ediyor |
| K-2 | Beş klasör: `100-Inbox`, `300-Projects`, `500-Knowledge`, `700-Sessions`, `850-Companion` | `500-Knowledge` ve `850-Companion` PLAN'da kanıtlı (§2 satır 79, §4.9). Diğer üçü dört katman veri akışından türetildi. |

---

## 1. Kapsam

### Kapsam içi
1. Yerleşim (layout) verisi + `quipu init` ile klasör iskeleti üretimi (`--plain` gerçek hâle gelir)
2. `AGENTS.md` köprü bloğunun genişletilmesi + yeni `CLAUDE.md` ince işaretçi
3. Companion persona **veri olarak**: `persona/{en,tr}.md` → vault'ta `<companion>/companion.md`
4. `Threads.md` tohumlanması (`quipu context` zaten okuyor, `quipu:425`)
5. İndeksten dışlama listesinin tek kaynağa indirgenmesi (şu an üç yerde kopyalanmış)
6. `doctor`: yeni gönderilen dosyalar, yerleşim satırı, vault yolu için OneDrive kontrolü
7. i18n: yeni anahtarlar `tr` + `en`
8. Testler + README + PLAN güncellemesi

### Kapsam dışı (gerekçesiyle)
- `Last-Session.md` **üretilmez** — sahibi FAZ 3 `SessionEnd`'dir (PLAN §2 KATMAN 1). FAZ 2
  sadece yerini (`700-Sessions/`) açar. Boş dosya bırakmak `context` çıktısını kirletir.
- `quipu remember` — PLAN §6'da açıkça FAZ 3'e ertelenmiş.
- Hook kurulumu / adaptörler — FAZ 3.

---

## 2. Yeni gönderilen dosyalar (shipped data)

Kural (PLAN §3 "Depolama: düz Markdown", §1 "dil paketleri: kod değil, veri"):
**taksonomi ve persona kodun içine gömülmez.** `fold/` ve `i18n/` ile aynı desen.

```
quipu/
├── layout/emoji.txt          # YENİ
├── layout/plain.txt          # YENİ
├── persona/en.md             # YENİ
└── persona/tr.md             # YENİ
```

### 2.1 `layout/*.txt` — biçim sözleşmesi

İki sütun, **TAB ayraçlı**: `slug<TAB>görünen ad`. `#` ile başlayan ve boş satırlar yok sayılır.

`layout/plain.txt`:

```
inbox	100-Inbox
projects	300-Projects
knowledge	500-Knowledge
sessions	700-Sessions
companion	850-Companion
```

`layout/emoji.txt`:

```
inbox	📥 100-Inbox
projects	🚧 300-Projects
knowledge	📚 500-Knowledge
sessions	📆 700-Sessions
companion	🔮 850-Companion
```

**BAĞLAYICI kurallar:**

- **B-1** Slug kümesi iki dosyada **birebir aynı ve aynı sırada** olmalı. Kod slug ile konuşur,
  görünen adla asla. FAZ 3 `SessionEnd`, `sessions` slug'ıyla klasörü bulacak.
- **B-2** Emoji seçimi: **tek kod noktası**, varyasyon seçici (U+FE0F) **yok**, ZWJ dizisi **yok**.
  Seçilenler: U+1F4E5, U+1F6A7, U+1F4DA, U+1F4C6, U+1F52E. Varyasyon seçicili bir emoji
  (`🗓️` gibi) klasör adında platformlar arası normalizasyon farkı üretir — kullanma.
- **B-3** Görünen adlar **boşluk içerir**. Her `mkdir`, her `find` sonucu, her değişken kullanımı
  çift tırnaklı olmalı; `while IFS= read -r` ile okunmalı (IFS boş = baştaki/sondaki boşluk
  korunur). `$(...)` çıktısını tırnaksız kullanmak yasak.
- **B-4** `.gitattributes`'a `layout/*.txt` için ek gerekmez (`*.txt text eol=lf` zaten var).

### 2.2 `persona/*.md` — companion tohumu

Kısa (≤20 satır), frontmatter'lı, kullanıcının düzenlemesi beklenen bir dosya.
`lib/index.awk` meta modu `title:` ve `tags:` okur (`lib/index.awk:60-64`) — frontmatter bu yüzden şart.

`persona/en.md` iskeleti:

```markdown
---
title: Companion
tags: [quipu, companion, persona]
---

# Companion

This file is data, not code. Edit it freely — quipu never overwrites it.

## Role
<how the agent should act in this vault>

## Tone
<voice, verbosity, language>

## Boundaries
<what it must not do without asking>
```

`persona/tr.md` aynı yapı, Türkçe gövde. `title: Companion` **aynı kalır** (indeks başlığı stabil olsun).

- **B-5** `.gitattributes`'a **`persona/*.md text eol=lf` satırı eklenir**. Bu dosyalar vault'a
  aynen kopyalanıyor; CRLF bulaşırsa CR baytları indekse ve `context` çıktısına sızar.
- **B-6** PLAN §4.11 gereği bu dosyalarda **literal ters-slash yok**. Test 29 tarzı kaynak
  hijyen testi `persona/` ve `layout/` dizinlerini de kapsayacak (T-21).

---

## 3. Vault yapısı (init sonrası)

```
<vault>/
├── .quipu/
│   ├── config              # lang=, fold=, layout=          ← layout YENİ
│   ├── index.tsv
│   └── activity.log
├── AGENTS.md               # evrensel köprü (blok genişledi)
├── CLAUDE.md               # YENİ — ince işaretçi, blok işaretli
├── Threads.md              # YENİ — tohumlanır, asla üzerine yazılmaz
├── 📥 100-Inbox/.gitkeep
├── 🚧 300-Projects/.gitkeep
├── 📚 500-Knowledge/.gitkeep
├── 📆 700-Sessions/.gitkeep
└── 🔮 850-Companion/
    ├── .gitkeep
    └── companion.md        # YENİ — persona/<lang>.md'den tohumlanır
```

**Neden `.gitkeep`, neden `.md` değil:** git boş dizin izlemez. Tohum dosyası `.md` olsaydı
indekse girip her aramada gürültü yapardı. `.gitkeep`, `find -name '*.md'` filtresine takılmaz.
Klasörlerin ne işe yaradığı `AGENTS.md` köprü bloğunda anlatılır — o dosya zaten indeks dışı.

---

## 4. Davranış sözleşmeleri

### 4.1 `quipu init` — yerleşim seçimi ve kalıcılığı

```
quipu init [--plain] [--lang L] [--git]
```

| Durum | Davranış |
|---|---|
| İlk `init`, bayraksız | `layout=emoji` config'e yazılır, emoji ağacı kurulur |
| İlk `init --plain` | `layout=plain` config'e yazılır, ASCII ağacı kurulur |
| Sonraki `init`, bayraksız | config'teki `layout=` okunur ve **ona uyulur** |
| Sonraki `init --plain`, config `layout=emoji` | **hata, çıkış 2**, `err_layout_conflict`, hiçbir şey değişmez |
| config'te `layout=` yok (FAZ 1'den kalma vault) | `--plain` varsa plain, yoksa emoji; değer config'e yazılır |
| config'te tanınmayan `layout=` değeri | **hata, çıkış 2**, `err_layout_unknown` |

- **B-7** Çakışan bayrak **sessizce ikinci bir ağaç kurmaz**. FAZ 2'nin en kolay düşülen tuzağı
  budur: iki paralel taksonomi = bölünmüş hafıza.
- **B-8** `--plain` artık no-op değil. `quipu:304`'teki `--plain) shift ;;   # accepted; no-op until FAZ 2`
  satırı gerçek davranışla değiştirilir.

### 4.2 Üzerine yazma yasağı (PLAN §3: append-only)

- **B-9** `companion.md` ve `Threads.md` **yalnızca yoksa** oluşturulur. Var olan dosyaya
  **hiçbir koşulda** dokunulmaz — ne truncate, ne append, ne yeniden tohumlama. Bunlar
  kullanıcı/ajan hafızasıdır.
- **B-10** `mkdir -p` kullanılır (var olan klasör hata değil). `.gitkeep` yoksa oluşturulur,
  varsa dokunulmaz.
- **B-11** `AGENTS.md` ve `CLAUDE.md` **yalnızca işaretli blok** içinden değiştirilir;
  `lib/block.awk` zaten idempotent ve kullanıcı metnini koruyor. Yeni kod yazma, onu kullan.

### 4.3 `AGENTS.md` köprü bloğu — yeni gövde

Şu anki gövde iki satır (`quipu:350`): `## quipu` + `Run: quipu context`.
Yeni gövde i18n'den üretilir ve **gerçek klasör adlarını** içerir:

```
## quipu
<bridge_run>
<bridge_layout>
  - 📥 100-Inbox — <layout_inbox>
  - 🚧 300-Projects — <layout_projects>
  - 📚 500-Knowledge — <layout_knowledge>
  - 📆 700-Sessions — <layout_sessions>
  - 🔮 850-Companion — <layout_companion>
<bridge_companion>
<bridge_append>
```

- **B-12** Klasör satırları `layout/<layout>.txt`'ten okunur, elle yazılmaz. `--plain` vault'ta
  ASCII adlar görünür.
- **B-13** Blok gövdesi `lib/block.awk`'a **stdin'den** verilir (mevcut çağrı deseni, `quipu:350`).
  Veriyi `awk -v` ile geçirmek yasak (PLAN §4.16).

### 4.4 `CLAUDE.md` — ince işaretçi

- **B-14** İçerik: `AGENTS.md`'ye yönlendiren tek blok. Taksonomi/persona **tekrarlanmaz**
  (çift kaynak = kayma). `lib/block.awk` ile aynı işaretçi çifti kullanılır.
- **B-15** Var olan `CLAUDE.md` korunur, blok eklenir/güncellenir, çoğaltılmaz.

### 4.5 İndeks dışlama listesi — tek kaynak

`AGENTS.md` filtresi şu an **üç yerde** kopyalanmış: `quipu:174` (doctor bayatlık),
`quipu:486` (all-list), `quipu:491` (changed-list). FAZ 2 `CLAUDE.md`'yi de ekliyor →
üç yerde de değişmesi gerekirdi. Bu kopya kaldırılır.

- **B-16** Tek yardımcı fonksiyon eklenir; üç çağrı yeri onu kullanır:

```sh
_q_mdlist() {
  # Vault-relative .md paths, excluding agent-bridge files. Caller must cd to
  # the vault first. $1 (optional): only files newer than this path.
  if [ -n "${1:-}" ]; then
    find . \( -name .git -o -name .quipu -o -name node_modules \) -prune -o \
      -type f -name '*.md' -newer "$1" -print
  else
    find . \( -name .git -o -name .quipu -o -name node_modules \) -prune -o \
      -type f -name '*.md' -print
  fi | sed 's|^\./||' | awk '$0 != "AGENTS.md" && $0 != "CLAUDE.md"'
}
```

- **B-17** `companion.md` ve `Threads.md` **indekslenir** — bunlar hafıza içeriğidir. Yalnızca
  `AGENTS.md`/`CLAUDE.md` (ajan talimatı) dışlanır.
- **B-18** `init` indeksi kendisi üretmez. Sonuç: init'ten hemen sonra `doctor` bayat indeks
  **uyarısı** verir — bu doğru ve dürüst davranıştır (uyarı çıkış kodunu değiştirmez, `doctor`
  yine 0 döner). `init` çıktısına `init_next` ipucu satırı eklenir: "şimdi çalıştır: quipu index".

### 4.6 `doctor` eklemeleri

- **B-19** "kurulum dosyaları" döngüsüne (`quipu:157`) dört dosya eklenir:
  `layout/emoji.txt`, `layout/plain.txt`, `persona/en.md`, `persona/tr.md`.
- **B-20** Slug tutarlılığı kontrolü: iki layout dosyasının slug sütunları aynı değilse `fail`
  (`doc_layout_mismatch`). B-1'i çalışma zamanında zorlar.
- **B-21** vault bölümüne yerleşim satırı: `ok layout emoji|plain`. Config'te `layout=` yoksa
  `warn` + `doc_layout_missing` (FAZ 1'den kalma vault → `quipu init` gerek).
- **B-22** Companion kontrolü: `<companion>/companion.md` yoksa `warn doc_companion_missing`.
- **B-23** OneDrive kontrolü düzeltilir. Şu an yalnız `_q_HOME`'a (kurulum dizini) bakıyor
  (`quipu:208-210`) — oysa §4.9 riski **vault yolu** hakkında. Yeni davranış: kurulum yolu
  *veya* vault yolu `OneDrive` içeriyorsa uyar; emoji risk mesajı **yalnızca `layout=emoji`**
  ise verilir, `--plain` vault'ta bu uyarı anlamsızdır.

### 4.7 `context` — değişiklik yok

`Threads.md` okuması zaten var (`quipu:425-428`). FAZ 2 sadece dosyayı **tohumluyor**.
Tohum tek satırlık bir başlık + tek açıklama satırı olmalı; daha uzunu her `context` çıktısını şişirir.

---

## 5. i18n anahtarları (hem `tr.txt` hem `en.txt`)

```
# init
init_next
init_layout            # %s = emoji|plain
init_companion
err_layout_conflict
err_layout_unknown
# bridge (AGENTS.md blok gövdesi)
bridge_run
bridge_layout
bridge_companion
bridge_append
bridge_claude          # CLAUDE.md gövdesi (tek satır, AGENTS.md'ye yönlendirir)
# layout klasör açıklamaları
layout_inbox
layout_projects
layout_knowledge
layout_sessions
layout_companion
# doctor
doc_layout
doc_layout_missing
doc_layout_mismatch
doc_companion_missing
doc_onedrive_vault
# threads tohumu
threads_seed_title
threads_seed_note
```

- **B-24** i18n biçimi `key=value`, **tek satır** (awk `$1==k` ile okunuyor, `quipu:75`).
  Çok satırlı değer yasak — her satır ayrı anahtar.
- **B-25** `%s`/`%d` taşıyan değerler `printf` formatı olarak kullanılıyor (`quipu:356` deseni);
  gövdede kaçak `%` bırakma.
- **B-26** Bir anahtar iki dosyadan birinde eksikse `_q_msg` sessizce anahtarın kendisini basar —
  bu gözden kaçar. T-20 iki dosyanın anahtar kümesini karşılaştırır.

---

## 6. Dilimler (uygulama sırası)

Her dilim kendi testleriyle yeşil bırakılmalı; dilim sonunda `sh tests/run.sh` **ve**
`shellcheck -s sh quipu` temiz.

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **D-1** | `layout/*.txt`, `persona/*.md`, `.gitattributes` satırı, doctor kurulum-dosyası kontrolleri (B-19, B-20) | doctor yeni dosyaları görüyor; kaynak hijyen testi geçiyor |
| **D-2** | `_q_mdlist` refaktörü (B-16, B-17) ve üç çağrı yerinin dönüştürülmesi | mevcut 83 iddia aynen geçiyor; `CLAUDE.md` dışlaması test edilmiş |
| **D-3** | `init`: yerleşim çözümü + config `layout=` + klasör ağacı + `.gitkeep` (B-7…B-11) | T-1…T-5 |
| **D-4** | `companion.md` + `Threads.md` tohumu (B-9) | T-6…T-8, T-12, T-13 |
| **D-5** | `AGENTS.md` gövdesi + `CLAUDE.md` (B-12…B-15) | T-9…T-11 |
| **D-6** | `doctor` yerleşim/companion/OneDrive satırları (B-21…B-23) | T-18, T-19 |
| **D-7** | README + `docs/PLAN.md` güncellemesi | §8 |

**Neden bu sıra:** D-1 saf veri (kod riski yok). D-2 mevcut davranışı **korumak zorunda olan**
saf refaktör — yeni içerik eklenmeden önce yapılırsa bir regresyonun kaynağı belirsiz kalmaz.
D-3'ten sonrası yeni davranış.

---

## 7. Testler (`tests/run.sh`, mevcut `t; assert_eq` üslubu)

Yeni bölüm başlığı: `# ---- FAZ 2: layout + identity ----`, mevcut `# ---- init + context ----`
bölümünden sonra.

| # | Test |
|---|---|
| T-1 | `init` (bayraksız) beş emoji klasörünü oluşturur, her birinde `.gitkeep` var |
| T-2 | `init --plain` ASCII adlar üretir; klasör adlarında 0x80+ bayt **yok** |
| T-3 | config `layout=emoji` / `layout=plain` kaydeder |
| T-4 | İkinci `init --plain` (config emoji) → çıkış 2; klasör sayısı değişmez |
| T-5 | İkinci `init` (bayraksız) idempotent: klasör ve `.gitkeep` sayısı aynı |
| T-6 | `<companion>/companion.md` oluşur ve boş değil |
| T-7 | Kullanıcı `companion.md`'yi düzenler → ikinci `init` içeriği **aynen korur** |
| T-8 | `init --lang tr` → `companion.md` Türkçe tohumdan gelir (tr'ye özgü dizge aranır) |
| T-9 | `CLAUDE.md` oluşur, `quipu:start` içerir, `AGENTS.md` dizgesine işaret eder |
| T-10 | Var olan `CLAUDE.md` kullanıcı metni korunur; ikinci `init` bloğu çoğaltmaz (`grep -c` = 1) |
| T-11 | `AGENTS.md` bloğu beş klasör adının hepsini içerir |
| T-12 | `Threads.md` oluşur; `quipu context` çıktısı `ctx_threads` bölümünü ve tohum satırını içerir |
| T-13 | Kullanıcı `Threads.md`'ye satır ekler → ikinci `init` korur |
| T-14 | `index` sonrası `index.tsv`'de `CLAUDE.md` satırı **yok** |
| T-15 | `index` sonrası `index.tsv`'de `companion.md` satırı **var**, yolu emoji klasörünü içeriyor |
| T-16 | `search` companion.md içindeki bir terimi bulur; `--paths` emoji klasörlü yolu doğru basar |
| T-17 | `capture --path "<emoji klasör>/not.md"` → `activity.log` satırı bozulmadan yazılır, `context` onu basar |
| T-18 | Taze emoji vault'ta **ve** `--plain` vault'ta `doctor` çıkış 0 |
| T-19 | `doctor` çıktısı `layout` satırı içerir ve doğru değeri gösterir |
| T-20 | `i18n/tr.txt` ve `i18n/en.txt` **aynı anahtar kümesine** sahip (B-26) |
| T-21 | Kaynak hijyeni (mevcut test 29): `layout/*.txt` ve `persona/*.md` literal ters-slash içermiyor |
| T-22 | İki layout dosyasının slug sütunları birebir aynı (B-1) |

**BAĞLAYICI test kuralları:**

- **B-27** T-15/T-16/T-17 FAZ 2'nin **asıl taşınabilirlik sınavıdır**: emoji + boşluklu yol
  `find → sed → awk → TSV → sort → head` zincirinden sağ çıkıyor mu. macOS (BSD) ve Windows
  runner'da ayrı ayrı yeşil olmadan dilim kapanmaz.
- **B-28** Testler `QUIPU_VAULT="$TMP/..."` deseniyle yazılır (mevcut `mkvault` üslubu);
  gerçek kullanıcı vault'una dokunulmaz.
- **B-29** Emoji dizgeleri teste **elle yazılmaz**; `layout/emoji.txt`'ten okunur. Aksi hâlde
  test dosyasının kodlaması ikinci bir hata kaynağı olur.
- **B-30** T-2'nin "0x80+ bayt yok" kontrolü **`awk` `sprintf("%c",N)` ile yazılmaz.** Bu spec'i
  yazarken ölçüldü: UTF-8 locale'inde gawk `sprintf("%c",240)` **U+00F0 karakterini** üretir
  (`c3 b0`, iki bayt), 0xF0 baytını değil — bayt karşılaştırması sessizce başarısız olur ve test
  yanlış "geçti" verir. PLAN §4.11'in `sprintf("%c",N)` kuralı **kontrol baytları (9, 10, 13, 92)**
  içindir; 0x80+ için geçerli değildir. Doğru araç: `LC_ALL=C tr -d '[:print:]'` ya da
  `od -An -tx1` üzerinden bayt sayımı.

---

## 8. Belge güncellemeleri

- **B-31** `README.md` "Commands" bölümüne `--plain` ve yerleşim bir cümleyle eklenir;
  "Status" bölümü FAZ 2 tamam olarak güncellenir.
- **B-32** `README.md` uçtan uca örneğindeki **`özet: 20 ok, 0 uyarı, 0 hata` satırı artık yanlış
  olacak** — doctor'a 4 kurulum dosyası + 1 yerleşim satırı eklendi. Ajan bu sayıyı **gerçek
  çıktıdan** almalı, tahmin etmemeli.
- **B-33** `docs/PLAN.md`: §6 FAZ 2 maddesi ✅ işaretlenir, §9 "Durum ve sonraki adım" güncellenir
  (sıradaki: FAZ 3 — Claude Code adaptörü), taksonomi kararı §3 tablosuna bir satır eklenir.

---

## 9. Yasak desenler (PLAN §6 Adım 3'ten devralınan, FAZ 2'de de geçerli)

`declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · `conhost`/`cmd` sarmalayıcısı ·
kaçış dizisine dayanan kod (§4.11) · ham kullanıcı verisini `awk -v` ile geçirmek (§4.16) ·
çok baytlı karakterde `sed` karakter sınıfı (§4.1) · tırnaksız yol değişkeni (B-3)

---

## 10. Çıkış koşulu

1. `sh tests/run.sh` üç OS'ta yeşil (mevcut 83 + yeni ~22 iddia)
2. `shellcheck -s sh quipu tests/run.sh` temiz (yeni bir `disable` yorumu ekleniyorsa gerekçesi satır içinde)
3. `quipu init` → `quipu index` → `quipu search` zinciri **hem** emoji **hem** `--plain` vault'ta çalışıyor
4. İkinci `init` hiçbir kullanıcı dosyasını değiştirmiyor (T-5, T-7, T-10, T-13)
5. README ve PLAN güncel
