# FAZ 9 — Bulgular (Dilim 0)

**Kaynak yöntemi:** quipu tarafındaki tüm bulgular **repo içi kod okuması** kaynaklıdır ve
her biri kesin `dosya:satır` referansı taşır. Satır numaraları **HEAD (`ecca473ae32`,
"docs: tasarım kaydını takibe al" commit'i — FAZ 8/9'un tüm çalışma-ağacı değişikliklerinden
**önceki** hâl) içeriğinden alınmıştır** ve bu belgenin yazıldığı anda `git show
HEAD:<dosya>` ile üretilen geçici kopyalar üzerinden **fiilen doğrulanmıştır** (`quipu` HEAD'de
1060 satır, `i18n/en.txt` HEAD'de 98 satır). Bu referans noktası bilinçli bir seçimdir: FAZ 9
V-2…V-5 kimlik değişiklikleri henüz commit edilmemiş çalışma ağacında yaşıyor (bkz. aşağıdaki
"Çalışma ağacı sapması" bölümü) ve satır numaraları o değişikliklerle kaymış durumda; HEAD
sabit bir referans olduğu için burada kullanılmıştır.

avenoxbeyin (`github.com/avenoxai/avenoxbeyin`) tarafındaki iddialar bu turda **doğrulanamadı**:
repo yerelde klonlu değil (`C:\Users\SelmanBuilds` altında `*avenoxbeyin*` adlı hiçbir dizin
yok) ve görev kapsamı ağdan yeniden çekmeyi yasaklıyor. Bu iddiaların tek kaynağı
`docs/FAZ9-SPEC.md` §1'in kendi metni (2026-08-22 tarihli bir inceleme oturumuna
dayandığını iddia ediyor) — `docs/AVENOXBEYIN-KARSILASTIRMA.md`'nin "Yöntem notu" bölümü de
aynı sınırı aynı gerekçeyle not düşüyor. Bu belgede bu tür iddialar
`[doğrulanmadı — kaynak: FAZ9-SPEC §1, 2026-08-22 incelemesi]` etiketiyle işaretlenmiştir.

İddia etiketi: `[kaynak: …]` = repo'da (HEAD'de) doğrulanabilir; `[ölçüm: …]` = bu makinede
koşturulup görülmüş; `[doğrulanmadı]` = bu turda doğrulanamayan, ikincil kaynağı belirtilen
iddia.

**Sözleşme karşılığı:** Bu dosya `FAZ9-SPEC` §1'deki U-1…U-5'i resmileştirir. Sayılar U-1…U-5;
`FAZ7-BULGULAR`'ın L-n'leriyle, `FAZ6-BULGULAR`'ın G-n'leriyle çakışmaz.

---

## U-1 — Kurulum README §"Install": klonla + `PATH`'e koy; mülakat/kişiselleştirme/ajan-bağlama otomasyonu yok

`[kaynak: README.md:19-23 (HEAD), quipu:457 (HEAD, `_q_cmd_init` tanımı), i18n/en.txt:7 (HEAD, `usage_init`)]`

README'nin "Install" bölümü tamamı iki cümledir (`README.md:21-22`, HEAD'de doğrulandı):

> Clone this repository and put the `quipu` script on your `PATH`. Prerequisites:
> POSIX sh plus `sed`, `awk`, `grep`, `tr`, and `git`.

Ne bir mülakat adımı, ne kullanıcı/companion adı sorusu, ne de ajan yüzeyine (Claude Code,
Codex, hook'suz) otomatik bağlama var — kullanıcı README'yi elle okuyup `settings.json`'a
elle hook eklemek zorunda (bkz. README §"Claude Code"). `usage_init` metni de bunu doğruluyor
(`i18n/en.txt:7`, HEAD): `init      create .quipu/ and the AGENTS.md bridge block` — yalnız
teknik bir eylem tarifi, kişiselleştirme sözü yok. `_q_cmd_init` (`quipu:457`, HEAD) HEAD'de
yalnız `--plain`, `--git`, `--lang` bayraklarını tanıyor; `--user`/`--companion` **hiç yok**
(`grep -n -- '--user\|--companion' <(git show HEAD:quipu)` sıfır sonuç döndü).

**Etki:** V-1 (`docs/KURULUM.md`) bu boşluğu bir kod değişikliği değil, bir **belge**
olarak kapatır — mülakat + kurulum + kimlik + ajan bağlama + doğrulama beş fazlı bir ajan
runbook'u. V-2 aynı boşluğun CLI tarafını (`--user`/`--companion` bayrakları) kapatır.

## U-2 — Persona zaten veri: `persona/en.md`/`persona/tr.md`, `init` dil zincirine göre birini kopyalıyor

`[kaynak: quipu:559-581 (HEAD, seed bloğu; `cp` satırı `quipu:567`)]`

`_q_cmd_init` içindeki seed bloğu (`quipu:559`, yorum satırı: `# Seeds: only-if-missing,
never touched again`) `persona/$_q_pers.md` dosyasını, yalnızca hedef **yoksa**,
`<companion-klasörü>/companion.md`'ye kopyalıyor (`quipu:567`, HEAD):

```sh
cp "$_q_HOME/persona/$_q_pers.md" "$_q_v/$_q_cname/companion.md"
```

Dil seçimi `_q_pers=$(_q_lang)` ile yapılıyor, karşılık gelen dosya yoksa `en`'e düşüyor
(`quipu:562-565`). Kullanıcı sonradan `companion.md`'yi düzenlerse, dosya zaten varolduğu
için ikinci `init` ona **dokunmuyor** — yalnız-yoksa garantisi.

**Etki:** Kişiselleştirme için yeni bir dosya sınıfı ya da şablon motoru gerekmez; `persona/*.md`
zaten veri. V-3 bu `cp`'yi bir `printf` ile değiştirip iki `%s` yer tutucusunu (companion adı,
kullanıcı adı) dolduracak — dosyanın **veri olma** niteliği bozulmadan.

## U-3 — Layout zaten veri: `layout/emoji.txt` + `layout/plain.txt`, klasörler ve `AGENTS.md` gövdesi buradan üretiliyor

`[kaynak: quipu:531-544 (HEAD, klasör ağacı döngüsü), quipu:583-606 (HEAD, `AGENTS.md` köprü gövdesi)]`

Klasör ağacı `layout/$_q_layout.txt`'teki `slug<TAB>ad` satırlarından üretiliyor
(`quipu:531`, yorum: `# Folder tree: names come from layout/<layout>.txt`), her satır için
`mkdir -p` + `.gitkeep` (`quipu:540-542`, HEAD'de doğrulandı, satır satır eşleşti). `AGENTS.md`
köprü gövdesi de **aynı dosyadan** üretiliyor (`quipu:583`, yorum: `# AGENTS.md bridge block:
body from i18n + layout file, via stdin`); döngü her klasör için `layout_$_q_slug` i18n
anahtarını basıyor (`quipu:598-600`). HEAD'de `bridge_companion` satırı (`quipu:604`) tek bir
`%s` alıyor — yalnız klasör adını:

```sh
printf "$(_q_msg bridge_companion)\n" "$_q_cname"
```

**Etki:** Yeni klasör ihtiyacı bir kod değişikliği değil, `layout/*.txt`'e satır eklemek olurdu
— ama V-6 bunu kullanıcı klasörleri için **kasıtlı olarak yasaklıyor** (§4, iki dosyanın slug
eşitliği `doctor` tarafından kilitli, her slug iki i18n anahtarı ister). V-4 `bridge_companion`'ı
iki `%s`'e çıkarır (ad + yol), köprü gövdesi companion'ı klasör adıyla değil **adla** anar.

## U-4 — avenoxbeyin'in `SETUP.md`'si kod değil, ajan runbook'u

`[doğrulanmadı — kaynak: FAZ9-SPEC §1 U-4, 2026-08-22 incelemesi]`

FAZ9-SPEC'in iddiasına göre avenoxbeyin'in kurulumu altı fazlı bir ajan runbook'u: makine
adından `JohnOS` türetme, Türkçe mülakat (isim, bio, companion adı, opsiyonel klasörler,
mem0 sorusu), `brew install obsidian`, `template/` kopyalama, `{{OS_NAME}}`/`{{COMPANION}}`
yer tutucu doldurma, `osacompile` + Swift/AppKit ile masaüstü `.app` üretimi, doğrulama +
Türkçe rapor. Bu iddia **avenoxbeyin tarafında doğrulanamadı** — repo yerelde klonlu değil,
ağdan çekilmedi (kapsam dışı). `docs/AVENOXBEYIN-KARSILASTIRMA.md` da aynı iddiayı aynı
etiketle taşıyor (§1 tablo, "Kurulum runbook'u" satırı), yani bu ikinci-el karakter tüm
FAZ 8/9/10 spec zincirinde tutarlı.

**Etki:** Spec'in "alınacak fikir" listesi (runbook + mülakat + doğrulama raporu) ile
"alınmayacak" listesi (`{{...}}` yer tutucu motoru, `brew`, Obsidian kurulumu, macOS
launcher, `python3`, mem0) doğrulanamayan bir kaynaktan süzülmüş olsa da, V-1'in kendisi
**quipu'nun kendi doğrulanabilir primitifleriyle** (i18n, `doctor`, mevcut komutlar) yazılır
— avenoxbeyin doğrulanmasa bile V-1'in içeriği bağımsız olarak doğrulanabilir kalır.

## U-5 — `doctor` zaten kurulum doğrulayıcısı

`[kaynak: quipu:259-263 (HEAD, ajan yüzeyi satırı), quipu:304-312 (HEAD, özet + çıkış kodu)]`

`_q_doctor` (HEAD) sırasıyla araçları, lehçeleri (`stat`/`awk` çeşidi), gönderilen dosyaları,
vault durumunu ve ajan yüzeylerini denetliyor. Ajan yüzeyi satırı Claude Code hook'larının
kurulu olup olmadığını `~/.claude/settings.json` içinde `quipu` dizgesi arayarak buluyor
(`quipu:259-263`, HEAD):

```sh
if [ -e "$HOME/.claude/settings.json" ] && grep -q quipu "$HOME/.claude/settings.json"; then
  _q_line ok 'claude hooks' "$(_q_msg doc_hooks_installed)"
else
  _q_line warn 'claude hooks' "$(_q_msg doc_hooks_missing)"
fi
```

Özet satırı dört sayıyı i18n şablonuna basıyor (`quipu:304`, `_q_fmt=$(_q_msg doc_summary)`)
ve `FAIL > 0` olduğunda çıkış kodu 1, aksi hâlde 0 (`quipu:310-312`, HEAD'de birebir
doğrulandı):

```sh
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
```

**Etki:** Runbook'un Faz 0 (ön koşul) ve Faz 5 (doğrulama) adımları yeni bir doğrulama
mekanizması icat etmez, var olan `doctor`'ı iki kez çağırır. V-5, `doctor`'a kimlik
satırını (`user=`/`companion=` yoksa **warn**) ekler — `doc_layout_missing`'in birebir
deseni; HEAD'de bu satır **yok** (aşağıya bakınız).

---

## Çalışma ağacı sapması

Bu belge **geriye dönük** yazılmıştır: `docs/FAZ9-SPEC.md` §3'ün V-2…V-5 kimlik maddeleri
(`.quipu/config`'e `user=`/`companion=` yazımı ve `init --user`/`--companion` bayrakları,
`persona/*.md`'nin `%s` yer tutucularıyla kişiselleştirilmesi, `bridge_companion`'ın iki
`%s`'e çıkması, `doctor`'a `doc_identity`/`doc_identity_missing` satırı) bu görev
başladığında **zaten kodlanmıştı** — ama HEAD'e (`ecca473`) değil, commit edilmemiş çalışma
ağacına. Bu turda doğrulandı: HEAD'de `--user`/`--companion` bayrağı yok, HEAD `i18n/en.txt`'te
`persona_default_*`/`doc_identity*` anahtarları yok, HEAD `persona/en.md`'de `%s` yer
tutucusu ya da yer tutucu sırasını belgeleyen yorum satırı yok — üçü de yalnız çalışma
ağacında (`quipu`, `i18n/en.txt`, `i18n/tr.txt`, `persona/en.md`, `persona/tr.md` dosyalarının
`git status`taki `M` durumu) mevcut. **V-1 (`docs/KURULUM.md`) bu görevin dışında hiç
yazılmamıştı** — bu görevin ürettiği tek yeni madde budur; V-2…V-5 kod ve testleri (T-110…T-118)
bu görevden önce, başka bir ajan turunda tamamlanmış durumda ve bu belge yalnız onları
`[kaynak: HEAD]` referanslı bulgulara **resmi olarak bağlıyor**, kodlarını değiştirmiyor.

---

## Tasarım etkileri (U → V eşlemesi)

| Bulgu | Sözleşme maddesi | Ne gerektiriyor |
|---|---|---|
| U-1 | V-1 | `docs/KURULUM.md`: mülakat + kurulum + kimlik + ajan bağlama + doğrulama, platforma özgü araç yok |
| U-2 | V-3 | `persona/*.md`'deki `cp`'nin yerini iki `%s` dolduran `printf` alır; dosya veri kalır |
| U-3 | V-4, V-6 | `bridge_companion` iki `%s`'e çıkar (ad + yol); kullanıcı klasörleri `layout/*.txt`'e eklenmez |
| U-4 | V-1 (biçim örneği) | avenoxbeyin doğrulanamasa da runbook'un içeriği quipu'nun kendi primitifleriyle bağımsız doğrulanabilir kalır |
| U-5 | V-5 | `doctor`'a `doc_layout_missing` deseninin kopyası olan bir kimlik satırı (`doc_identity_missing`) |

## Test malzemesi (Dilim 1-4 için)

- **Kimlik (T-110…T-118):** `mkrem`/`mkvault` + `QUIPU_VAULT` ile taze vault, `QUIPU_LANG=en`
  altında i18n metnine bakan iddialar (`i18n <key>` yardımcısı), `comp_name plain` ile
  companion klasör adı. Mevcut `-*)` regresyon deseni (`FAZ7-BULGULAR` L-1/J-3) T-117'de
  aynen tekrarlanır: `--user` argümansız → `err_missing_arg`, `--companion --bogus` →
  `err_unknown_flag` + bayrak adı.
- **Runbook kapıları (T-119/T-120):** statik `grep` iddiaları — `docs/KURULUM.md`'de
  platforma özgü araç dizgesi yok (T-119), beş fazın hepsi `## Faz N` başlığıyla var ve
  çağrılan her `quipu <komut>` `usage_*` anahtar kümesiyle kesişen bir altı-komutluk beyaz
  listede (T-120). `docs/KURULUM.md` bu iki testi karşılayacak şekilde, ayrı bir görevde
  yazılmıştır (bkz. yukarıdaki "Çalışma ağacı sapması").
