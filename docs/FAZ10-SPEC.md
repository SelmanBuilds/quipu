# quipu — FAZ 10 SPEC: Obsidian sözleşmeleri (frontmatter, etiket/durum filtresi, wikilink grafiği)

> **Bu belge bir uygulama sözleşmesidir, öneri değil.** Kod ajanı bunu birebir uygular.
> Kaynak: 2026-08-22 avenoxbeyin (github.com/avenoxai/avenoxbeyin) incelemesi —
> `template/CLAUDE.md` §Conventions — + `lib/index.awk`/`lib/search.awk`'ın mevcut yetenekleri.
> Ön koşul: FAZ 7 tamam. **V1-DUZELTME önce girmeli** (indeks şeması bu fazda değişiyor;
> katlama profili sabitlenmemişse `--full` yeniden indeksleme sessizce profil değiştirir).
> Numara önekleri: **W-n** (bulgu), **Z-n** (sözleşme), **T-130…T-142** (test). Çakışma yok.
>
> **Bu fazın işi:** avenoxbeyin not sözleşmesini prozayla ilan ediyor (her notta frontmatter,
> `[[wikilink]]`, durum alfabesi 🟢🟡🔴⚪, Dashboard hub) ama hiçbiri makine tarafından
> okunmuyor. quipu frontmatter'ın yarısını zaten okuyor. Bu faz sözleşmeyi **sorgulanabilir**
> hale getirir.

## Ön bilgi (yeni oturum için)

- Repo: tek dosya POSIX `sh` CLI (`quipu`) + `lib/*.awk` + veri dizinleri. Derinlik: `docs/PLAN.md`.
- **Yasak desenler:** `declare -A` · `${var,,}` · `[[ ]]` · `=~` · `local` · kaçış dizisine
  dayanan KOD (§4.11) · ham kullanıcı verisini `awk -v` ile geçirmek (§4.16) · çok baytlı `sed`
  sınıfı (§4.1) · **çok baytlı `grep` kalıbı** (§4.17) · `python3`.
  **awk tarafında regex yasağı:** `lib/*.awk` yalnız `split()`/`index()`/`substr()` kullanır —
  `lib/search.awk`'ın baş yorumundaki sözleşme (PLAN §4.11) bunu kilitliyor.
- Testler: `sh tests/run.sh`. Yardımcılar: `t`, `assert_eq`, `mkvault`, `mk_index_vault`,
  `mk_search_vault`, `idx_nums`, `i18n key`, `TMP`, `ROOT`, `LIB`, `TAB`.
- Suite yerelde ~52 dk (5000 dokümanlık ölçek testi T-85…T-87 — **bu fazda şema değişince
  o testler de gözden geçirilir**). `/tmp` kullanmayın. `docs/` `.gitignore`'da.

## 0. Bu fazın tek cümlelik ölçütü

> **`search` etikete ve duruma göre daraltabiliyor, `quipu links` bir notun gelen/giden
> `[[bağlantı]]`larını basabiliyor, ve durum alfabesi kodda değil veride yaşıyor.**

## 1. Bulgular (W-1…W-5)

`docs/FAZ10-BULGULAR.md`'de resmileşir, her biri `[kaynak: <dosya>:<satır>]` etiketli.

- **W-1** `lib/index.awk` `mode=meta` frontmatter'ı **kısmen** okuyor: `FNR == 1 && $0 == "---"`
  ile bloğu açıyor (`lib/index.awk:59`), `title:` (`:63`) ve `tags:` (`:64`) alanlarını
  çıkarıyor, blok kapanınca gövdeden `# ` başlığını ve etiketleri toplamayı sürdürüyor
  (`:68-72`), sonda `print title, tags` (`:137`). **`type`, `status`, `created`, `modified`
  okunmuyor.**
- **W-2** `index.tsv` **5 sütun**: yol, başlık, etiketler, mtime, katlanmış alan. Katlanmış alan
  2000 **karakter**le sınırlı (`substr(buf, 1, max)`, `lib/index.awk:138`; `max` varsayılanı
  `:26`). `search.awk` girdi sözleşmesini baş yorumunda ilan ediyor.
- **W-3** `search.awk` etiket **boost**'u var — katlanmış terim etiketle tam eşleşirse `×1.5`
  (`lib/search.awk:123`, geri düşüş yolunda `:119`) — ama **etikete göre filtreleme yok**.
  `search` seçenekleri yalnız `--limit`, `--paths`, `--brief` (`quipu:993-995`).
- **W-4** `[[wikilink]]` hiçbir yerde ayrıştırılmıyor: `lib/` ve `quipu` içinde `[[` yalnız
  `quipu:3`'teki "no `[[ ]]`" yorumunda geçiyor. Bağlantı grafiği yok, kırık bağlantı tespiti yok.
- **W-5** avenoxbeyin sözleşmeyi **yalnız prozada** ilan ediyor (`template/CLAUDE.md`
  §Conventions): her notta `title, created, modified, type, status, tags` frontmatter'ı,
  `[[wikilinks]]`, durum alfabesi `🟢 active · 🟡 in progress · 🔴 blocked · ⚪ paused`,
  hub olarak `🎯 100-Command-Center/Dashboard.md`. Doğrulayıcı, ayrıştırıcı, test yok —
  yani sözleşme ilk uyumsuz notta sessizce kopuyor.

## 2. İndeks şeması genişler (Z-1…Z-2)

- **Z-1** `mode=meta` iki alan daha okur: `status:` ve `type:`. Ayıklama `substr($0, 1, 7)` /
  `substr($0, 1, 5)` deseniyle (W-1'in mevcut biçimi), **regex yok**. Değer yoksa boş dize.
- **Z-2** `index.tsv` **7 sütuna** çıkar: `yol · başlık · etiketler · mtime · katlanmış · durum · tip`.
  Katlanmış alan 5. sütunda **kalır** — `search.awk` onu `$5` olarak okuyor
  (`lib/search.awk:60`), yeni alanlar **sona** eklenir ki mevcut okuma bozulmasın.
  - `index` şema değişikliğini kendisi fark eder: mevcut `index.tsv` satırlarının sütun sayısı
    beklenenden azsa **tüm satırlar bayat sayılır** (artımlı `reuse` yolu devre dışı) ve
    özet bunu olağan `bayat N` sayısıyla raporlar. Kullanıcıdan `--full` istenmez.
  - `doctor`: `index.tsv` var ama sütun sayısı beklenenden farklıysa **warn**
    (`doc_index_schema`), `doc_index_stale` deseninin kopyası (`quipu:241`/`:245`).

## 3. Daraltma seçenekleri (Z-3…Z-4)

- **Z-3** `search --tag <etiket>`: `search.awk`'a `-v tagf=<katlanmış etiket>` geçilir; etiket
  sütunu (`$3`) `split(…, ",")` ile parçalanıp **tam eşleşme** aranır (mevcut boost kodunun
  aynı deseni, `lib/search.awk:104` + `:123`). Eşleşmeyen doküman **hiç emit edilmez**.
  - **Dürüst sınır (belgelenir):** etiket sütunu **ham** yazılıyor, sorgu ise katlanıyor →
    `#İstanbul` etiketi `--tag istanbul` ile bulunmaz. Bu, FAZ 1'den beri bilinen
    "başlık/etiket boost'u yalnız ASCII'de ateşler" sınırının aynısı (PLAN §7). Bu fazda
    **çözülmez**, README'ye yazılır.
- **Z-4** `search --status <durum>`: yeni 6. sütunda tam eşleşme, `-v statf=` ile.
  `--tag` ve `--status` **birlikte** kullanılabilir (AND). İkisi de `--paths`/`--brief` ile
  serbestçe birleşir; `--brief` + `--paths` çakışması (FAZ 7 J-6) aynen durur.
  Bilinmeyen bayrak yolu (`-*) _q_die err_unknown_flag 2 "$1"`) korunur.

## 4. Wikilink grafiği (Z-5)

- **Z-5** `lib/index.awk`'a `mode=links`: bir dosyanın gövdesindeki `[[hedef]]` çıkarımı
  **yalnız `index()`/`substr()`** ile yapılır (regex yok, §4.17). `|` takma ad ve `#` çapa
  ayrılır: `[[hedef|görünen]]` → `hedef`, `[[hedef#bölüm]]` → `hedef`.
  - Çıktı `.quipu/links.tsv`: `kaynak<TAB>hedef` (her bağlantı bir satır, yinelenenler
    tekilleştirilmez — sayım anlam taşır).
  - `index` bu dosyayı `index.tsv` ile aynı koşuda üretir (ikinci bir tarama YOK: aynı
    dosya okuması içinde). Bayat/yeniden mantığı `index.tsv` ile birlikte yürür.
  - Yeni komut `quipu links <yol>`: giden bağlantılar (kaynak = yol) ve gelen bağlantılar
    (hedef = yol) iki bölüm hâlinde basılır; i18n başlıkları `links_out`, `links_in`.
    Vault yoksa `err_no_vault`, `links.tsv` yoksa `err_no_index` (mevcut anahtarlar).
  - `doctor`: `links.tsv`'de hedefi vault'ta bulunmayan bağlantı varsa **warn**
    (`doc_links_broken`) + sayı.

## 5. Durum alfabesi veri olur (Z-6…Z-7)

- **Z-6** `layout/status.txt` — `slug<TAB>işaret` (ör. `active<TAB>🟢`). `layout/*.txt`
  ikilisiyle aynı biçim ve aynı okuma deseni (`awk -F"$TAB"`). **Kodda gömülü emoji yok.**
  `doctor`'un gönderilen dosya listesine (`quipu:201`) eklenir.
- **Z-7** i18n: `links_out`, `links_in`, `doc_index_schema`, `doc_links_broken`,
  `usage_links` (+ `usage_search` satırına `--tag`/`--status` notu). tr + en, küme eşitliği
  zorunlu. `usage()` çağrı listesine `usage_links` eklenir (`quipu:120-127`).

## 6. Testler (T-130…T-142)

**Şema:**
- **T-130** `mode=meta` frontmatter'dan `status`/`type` okuyor; alan yoksa boş dize.
- **T-131** `index.tsv` her satır **7 sütun** (mevcut "every row has 5 columns" testinin
  güncellenmiş hâli).
- **T-132** 5 sütunlu eski `index.tsv` bırakılmış vault → `index` tüm satırları bayat sayıyor,
  özet `bayat N` gösteriyor, sonuç 7 sütun.
- **T-133** `doctor`: 5 sütunlu `index.tsv` → warn (`doc_index_schema`), exit 0.

**Daraltma:**
- **T-134** `--tag alpha` → yalnız o etiketi taşıyan doküman döner; etiketsiz doküman düşer.
- **T-135** `--status active` → yalnız o durum; `--tag` ile birlikte AND davranıyor.
- **T-136** `--tag` + `--brief` → 5. sütun künye hâlâ ≤ 120 bayt, satırlar filtreli.
- **T-137** `--tag` argümansız → exit 2 + `err_missing_arg`; `--tagg` → exit 2 +
  `err_unknown_flag` (FAZ 7 regresyonu).
- **T-138** Dürüst sınır kanıtı: `#İstanbul` etiketli doküman `--tag istanbul` ile
  **bulunmuyor** — bu bir hata değil, belgelenmiş sınırdır (test bunu kilitler ki sessizce
  değişmesin).

**Wikilink:**
- **T-139** `[[hedef]]`, `[[hedef|ad]]`, `[[hedef#bölüm]]` üçü de `hedef` olarak çıkıyor;
  `links.tsv` satır sayısı beklenen.
- **T-140** `quipu links <yol>` gelen ve giden bağlantıları doğru bölümlerde basıyor
  (`QUIPU_LANG=en` ile başlık metinleri kilitli).
- **T-141** Kırık bağlantı → `doctor` warn (`doc_links_broken`), exit 0.

**Veri:**
- **T-142** `layout/status.txt` okunuyor, `quipu` ve `lib/*.awk` içinde durum emojisi
  **literal olarak geçmiyor** (statik ASCII kontrolü: kodda `🟢`/`🟡`/`🔴`/`⚪` yok).

## 7. Dilimler

| Dilim | İçerik | Çıkış koşulu |
|---|---|---|
| **0** | `docs/FAZ10-BULGULAR.md` — W-1…W-5 `[kaynak]` etiketli | her W-n kaynaklı |
| **1** | Z-1/Z-2 (şema 7 sütun) + T-130…T-133 | 4 test, eski şema kendini yeniliyor |
| **2** | Z-3/Z-4 (`--tag`/`--status`) + T-134…T-138 | 5 test, dürüst sınır kilitli |
| **3** | Z-5 (`links.tsv`, `quipu links`) + T-139…T-141 | 3 test, regex yok |
| **4** | Z-6/Z-7 (durum verisi, i18n, usage) + T-142 + belgeler | kodda emoji yok |

## 8. Yasak desenler (devralınan + yeni)

Ön bilgideki liste · **wikilink çıkarımında regex** (Z-5: `index`/`substr`) · **durum emojisini
koda gömmek** (Z-6) · **katlanmış alanı 5. sütundan oynatmak** (Z-2: yeni alanlar sona) ·
**kullanıcıdan `--full` istemek** (Z-2: şema farkını `index` kendisi yönetir) ·
**etiket filtresini katlanmış karşılaştırmayla "düzeltmeye" çalışmak** (Z-3: sınır belgelenir,
bu fazda çözülmez) · `index.tsv` için ikinci bir dosya taraması (Z-5: aynı koşuda).

## 9. Çıkış koşulu

1. Dilim 0: `FAZ10-BULGULAR.md` W-1…W-5'i cevaplıyor.
2. **Regresyon kapısı:** mevcut iddialar yeşil; şema değişimi nedeniyle güncellenen testler
   (5 → 7 sütun) ve **ölçek testleri T-85…T-87** gözden geçirilmiş, `--brief` çıktısı hâlâ
   5 alanlı (künye 5. sütunda kalıyor).
3. `sh tests/run.sh` yeşil, `shellcheck -s sh quipu tests/run.sh` sessiz.
4. Üç OS CI yeşil olmadan merge yok.

## 10. Kapsam dışı

- **Obsidian eklentisi / canlı senkron / grafik görselleştirme** — quipu bir CLI'dır.
- **YAML'ın tamamı için ayrıştırıcı** — yalnız `title`, `tags`, `status`, `type`; iç içe yapı,
  liste sözdizimi, çok satırlı değer yok.
- **`created`/`modified` alanları** — `mtime` zaten var, ikinci bir doğruluk kaynağı üretmeyiz.
- **Etiket katlama sorununun çözümü** — `index.tsv`'ye katlanmış etiket sütunu eklemek ayrı bir
  şema değişikliğidir; v2 adayı.
- **`search.awk`'ın akış tabanlı sürümü** — bellek tavanı, v2 adayı (PLAN §7).
