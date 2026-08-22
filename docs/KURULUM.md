# Quipu Kurulum Runbook'u

> Bu belge bir **ajan runbook'udur**: bir kod ajanı bunu baştan sona okuyup uygulayarak,
> boş bir dizinde çalışan, kişiselleştirilmiş ve kendi ajan yüzeyine bağlanmış bir vault
> kurar. Altı fazın hepsi platformdan bağımsız POSIX araçlarıyla (`sh`, `sed`, `awk`,
> `grep`, `tr`, `git`) çalışır; macOS'a özgü bir araç, bir paket yöneticisi ya da bir
> betik dili gerekmez.

## Faz 0 — Ön koşul

Kuruluma başlamadan önce ortamı doğrulayın:

```
quipu doctor
```

Çıktıda bir `fail` satırı varsa (örn. `sh`/`sed`/`awk`/`grep`/`tr`/`git` bulunamadı),
önce onu giderin — Quipu'nun tek gereksinimi POSIX sh ve bu beş araçtır, başka hiçbir
platforma özgü kurulum adımı yoktur. `fail` yoksa devam edin; henüz vault kurulmadığı
için görülecek `warn` satırları (örn. vault alanının boş olması) bu aşamada beklenendir
ve zararsızdır.

## Faz 1 — Mülakat

Kullanıcıyla, kendi dilinde ve konuşma diliyle, beş soru sorun:

1. Kullanıcının adı ne?
2. AI ortağına (companion) hangi adı vermek ister?
3. Hangi dilde çalışacak — Türkçe (`tr`) mi İngilizce (`en`) mi?
4. Klasör adları emoji'li mi (varsayılan) yoksa sade ASCII mi (`--plain`) olsun?
5. Vault hangi dizinde kurulacak (yeni ya da mevcut boş bir klasör)?

Bu fazda dış bir servis sorusu **yoktur** (ör. mem0 gibi harici bir semantik hafıza
servisi) — Quipu'nun hafıza katmanı zaten döngüdeki ajanın kendisidir, ek bir servise
ihtiyaç duymaz.

## Faz 2 — Kurulum

Faz 1'in cevaplarıyla vault'u kurun:

```
quipu init --lang <tr|en> [--plain] [--user <ad>] [--companion <ad>]
```

Örnek:

```
quipu init --lang tr --user Ada --companion Kuz
```

Bu tek çağrı şunları yapar: `.quipu/config` ile `.quipu/index.tsv` ve `activity.log`
dosyalarını, on klasörlü vault ağacını, `AGENTS.md`/`CLAUDE.md` köprü bloklarını ve
companion klasöründe kişiselleştirilmiş bir `companion.md` tohumunu oluşturur. Çağrı
**idempotent**tir: aynı vault'ta tekrar çalıştırmak mevcut değerleri asla ezmez — yalnız
eksik olanı tamamlar.

## Faz 3 — Kimlik

Kimliğin gerçekten yerleştiğini elle doğrulayın:

- `.quipu/config` içinde `user=<ad>` ve `companion=<ad>` satırları var mı?
  (`grep user= .quipu/config`, `grep companion= .quipu/config`)
- Companion klasöründeki `companion.md` içinde her iki ad da geçiyor mu; ham `%s` yer
  tutucusu **kalmamış** mı? (Kalmışsa Faz 2 hatalı çalışmış demektir.)

Ad verilmeden kurulum yapıldıysa bu iki alan i18n'den gelen nötr karşılıklarla dolar
(İngilizcede `Companion`/`User`, Türkçede eşdeğerleri); bu bir hata değildir, yalnızca
kimliksiz bir kuruluma işaret eder. İstenirse `--user`/`--companion` ile ikinci bir
`quipu init` çağrısı yapılıp eksik alan tamamlanabilir — mevcut değerler asla üzerine
yazılmaz, yalnızca boş olan satır eklenir.

## Faz 4 — Ajan bağlama

Kullanıcının ajanına göre dallanın:

- **Claude Code:** README'nin "Claude Code" bölümündeki `hooks` bloğunu
  `~/.claude/settings.json` içine birleştirin (dördü: oturum başlangıcında bağlam
  enjeksiyonu, her istek öncesi bağlam hatırlatması, araç kullanımı sonrası günlükleme,
  oturum sonunda özet yazımı). **Ayarları düzenledikten sonra Claude Code'u yeniden
  başlatın** — hook yapılandırması çalışan bir oturuma yeniden yüklenmez.
- **Codex:** `adapters/codex/hooks.json` dosyasını `~/.codex/hooks.json` (genel) ya da
  `.codex/hooks.json` (proje bazlı) konumuna kopyalayın. **Kurulumdan sonra Codex'i
  yeniden başlatın** — hook yapılandırması yalnız oturum kurulumunda okunur.
- **Hook yüzeyi olmayan ajanlar:** yerel bir hook kuramıyorsanız README'nin "Hook-less
  agents" bölümündeki elle döngüyü izleyin. En az iki adım hep elle çalıştırılır:
  oturum sonunda

  ```
  quipu remember
  ```

  ile mekanik özeti güncel oturum dosyasına yazdırın, oturum başında da

  ```
  quipu context --bridge
  ```

  ile güncel bağlamı `AGENTS.md`'nin kendi bloğuna yazdırıp ajana orada okutun.

## Faz 5 — İlk indeks ve doğrulama

1. İlk indeksi kurun:

   ```
   quipu index
   ```

   Soğuk (ilk) çalıştırma büyük vault'larda uzun sürebilir — ölçülmüş örnek: 5000
   notluk bir vault'ta Windows msys'te 2150-2367 saniye (bkz. README "Large vaults").
   Yeni kurulan, birkaç notluk bir vault'ta bu birkaç saniye sürer.

2. Bir arama deneyin:

   ```
   quipu search <bir kelime>
   ```

3. Bağlamı görüntüleyin:

   ```
   quipu context
   ```

4. Kurulumu tekrar doğrulayın:

   ```
   quipu doctor
   ```

   Özet satırı `özet: N ok, N uyarı, N hata` biçimindedir; hata sayısı 0 olduğunda
   çıkış kodu 0'dır.

5. Kullanıcının dilinde kısa bir rapor verin: ne kuruldu (vault yolu, dil, yerleşim,
   kimlik), ilk indeksin ne kadar sürdüğü, ve son olarak "sihri göster" adımını birlikte
   yapın — kullanıcıdan bir şey söylemesini isteyin, oturumu kapatıp yeniden açın, önceki
   oturumun bağlamının yeni oturumda göründüğünü birlikte gözlemleyin.

## Ek klasörler

Kullanıcı ek klasörler isterse (ör. bir hedefler klasörü ya da özel bir arşiv), bunları
**layout dosyalarına eklemeyin** — `layout/emoji.txt` ve `layout/plain.txt` Quipu'nun
kendi malıdır ve `quipu doctor` bu iki dosyanın slug kümesinin birebir eşit kalmasını
zorunlu kılar; her yeni slug ayrıca iki dilde yeni bir i18n anahtarı gerektirir. Bunun
yerine kullanıcıya klasörü doğrudan vault içinde elle açmasını söyleyin:
`quipu index` zaten vault'taki **tüm** `.md` dosyalarını tarar, yani ek bir klasör hiçbir
kod ya da yapılandırma değişikliği gerektirmez.
