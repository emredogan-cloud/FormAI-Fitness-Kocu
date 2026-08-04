# İçerik Operasyonları (Content Ops) — SOP

Bu doküman SixPack AI içerik kataloğunun (tarifler ve egzersizler)
freelance diyetisyen / antrenör tarafından üretilmesini, admin tarafından
incelenmesini ve canlıya alınmasını standardize eder. Phase 50A ile
birlikte tarifler ve egzersizler artık Supabase'de tutulmaktadır;
güncellemeler için yeni bir Flutter sürümü yayınlamak gerekmez.

---

## 1. Görsel Standartları

Tüm görseller `WebP` formatında, sıkıştırılmış (kalite ≥ 80) ve aşağıdaki
sabit boyutlarda üretilir. Standardizasyon `cached_network_image` cache
maliyetini düşürür ve liste/grid hizalamasını bozmaz.

| Tür         | Boyut       | Format | Maks. dosya boyutu | Notlar                                         |
|-------------|-------------|--------|---------------------|------------------------------------------------|
| Tarif       | 800 × 600   | WebP   | ~150 KB             | Tabak üstten çekim, doğal ışık, sade arka plan.|
| Egzersiz    | 400 × 400   | WebP   | ~80 KB              | Kare çerçeve, hareketin tepe noktası.          |
| Egzersiz video thumbnail | 400 × 400 | WebP | ~80 KB | Videodan alınan kare; oranı kare olmalı.       |

**Yükleme yolu:** Supabase Storage → `recipes` veya `exercises` bucket'ı.
Dosya isimleri tarif/egzersiz `slug` değeriyle aynı olmalı:
`izgara_tavuk_kinoa_kasesi.webp`, `crunch_thumb.webp` gibi.

> ⚠️ JPEG / PNG yüklenmesin. Mobil cihazlarda bant genişliği farkı
> kullanıcı başına aylık 30–60 MB'a kadar çıkıyor.

---

## 2. Tarif (Recipe) Zorunlu Alanları

Aşağıdaki alanlar **boş geçilemez**. Eksik alanı olan satır admin review
aşamasında reddedilir ve drafts tablosuna geri gönderilir.

| Alan          | Tip       | Açıklama                                                   |
|---------------|-----------|------------------------------------------------------------|
| `title`       | text      | Türkçe başlık. Maks. 60 karakter, baş harfler büyük.       |
| `meal_type`   | enum text | `breakfast` / `lunch` / `dinner` / `snack` / `main`.        |
| `calories`    | int       | Tek porsiyon kalori (kcal).                                |
| `protein`     | int       | Tek porsiyon protein (gram).                               |
| `carbs`       | int       | Tek porsiyon karbonhidrat (gram).                          |
| `fat`         | int       | Tek porsiyon yağ (gram).                                   |
| `image_url`   | text      | Supabase Storage'daki WebP URL'si (madde 1'e uygun).       |
| `tags`        | text[]    | En az bir etiket: `Yüksek Protein` / `Düşük Kalori` /       |
|               |           | `Hacim` / `Sıkılaşma` / `Vegan`.                            |

Opsiyonel alanlar: `prep_time_minutes`, `instructions`. `instructions`
alanı `MALZEMELER:` ve `HAZIRLANIŞ:` başlıkları ile bölümlenir
(`supabase_seed_recipes.sql`'deki örnek satırları referans al).

### Egzersiz Zorunlu Alanları (referans)

| Alan                          | Tip       | Açıklama                                  |
|-------------------------------|-----------|-------------------------------------------|
| `slug`                        | text      | URL-güvenli benzersiz id (`crunch`).       |
| `name`                        | text      | Türkçe görünen ad.                         |
| `type`                        | enum text | `repBased` / `timeBased`.                  |
| `category`                    | enum text | `core`/`chest`/`legs`/`back`/`arms`/        |
|                               |           | `shoulders`/`fullBody`.                    |
| `difficulty`                  | enum text | `beginner` / `intermediate` / `advanced`.   |
| `target_muscles`              | text[]    | Birincil hedef kas. Tek elemanlı olabilir.  |
| `instructions`, `short_tip`   | text      | Türkçe açıklama ve 4-6 kelimelik ipucu.    |
| `video_url`                   | text      | Dosya adı (`Crunch.mp4`) veya tam URL.     |

---

## 3. İş Akışı: Drafting → Admin Review → Live

Üç durumlu pipeline. Tüm adımlar Supabase üzerinde yürür; ayrı bir CMS
kurulmaz.

### 3.1. Drafting (Diyetisyen)

1. Diyetisyen, paylaşılan **Notion sayfasındaki** "Yeni Tarif Şablonu"nu
   doldurur (alanlar: madde 2'deki zorunlu alanlar + reçete içeriği).
2. Görseli madde 1'deki standartlara göre üretir, WebP'ye çevirir
   (`cwebp -q 82 input.jpg -o output.webp`) ve Notion sayfasına ekler.
3. Tamamlandığında Notion sayfasının durumunu **"Review'e hazır"** olarak
   işaretler ve admine Slack'ten ping atar.

> Diyetisyenin doğrudan veritabanına yazma yetkisi YOKTUR. RLS politikası
> (`supabase_rls_policies.sql`) yalnızca `app_metadata.role = 'admin'`
> claim'i taşıyan kullanıcılara INSERT/UPDATE/DELETE izni verir.

### 3.2. Admin Review (Ürün / Tech Lead)

1. Admin, Notion sayfasını açar; alanları madde 2'deki şablona göre
   doğrular (eksik alan varsa "Geri Gönder" durumuna çeker).
2. Görseli Supabase Storage → ilgili bucket'a yükler.
3. Supabase Studio → SQL Editor'da satırı `INSERT` eder. Idempotency için
   `ON CONFLICT (slug) DO NOTHING` veya `(title) DO NOTHING` kullanılır
   (mevcut seed scriptleri bu deseni kullanıyor).
4. INSERT başarılı olunca Notion sayfasının durumunu **"Live"** yapar.

### 3.3. Live

1. Yeni satır anında tüm istemcilere açılır (RLS public read).
2. Mobil uygulama açıkken aktif kullanıcılar tarafı önbellek nedeniyle
   güncellemeyi sonraki açılışta görebilir; bu kabul edilebilir bir
   gecikmedir.
3. Hatalı yayın tespit edilirse Supabase Studio'dan satır `UPDATE` veya
   `DELETE` ile düzeltilir; ayrı bir rollback aracı şart değildir.

---

## 4. Güncelleme & Silme

* **Güncelleme:** Mevcut `slug`/`title` üzerinde `UPDATE`. `updated_at`
  trigger'ı otomatik tetiklenir.
* **Silme:** Tarihçe gerekmiyorsa `DELETE`. Plan şablonlarında referans
  veren bir egzersiz silinirse, plan kısalır (`workout_repository.dart`
  içinde `whereType<Exercise>()` filtresi olmayan slug'ları sessizce
  düşürür) — uygulama çökmeden çalışmaya devam eder.

---

## 5. KPI Takibi

Aylık olarak admin aşağıdakileri raporlar:

* Yeni eklenen tarif/egzersiz sayısı.
* Reddedilen draft yüzdesi (kalite kontrol göstergesi).
* En çok görüntülenen 10 tarif (Supabase analytics view'u).

Bu metrikler, freelance ekiple yapılan haftalık toplantıların gündemidir
ve içerik üretim hızını / kalitesini ölçer.

---

# BÖLÜM II — Phase 14: İçerik Tazeliği (Content Freshness)

Yukarıdaki bölüm tarif ve egzersiz kataloğunu anlatır. Bu bölüm Phase
14'ün eklediği üç içerik türünü anlatır: **meydan okumalar**, **sürüm
notları** ve **içerik duyuruları**. Üçünün de ortak özelliği şudur:

> **Hiçbiri uygulama sürümü gerektirmez.** Hepsi Supabase satırıdır ve
> metinleri `jsonb` içinde locale'e göre tutulur. ARB'ye yazılan bir
> metin, yayın trenine biner — bu fazın varlık sebebi tam olarak bunu
> engellemektir.

Bunun bir bedeli var ve istemci onu üstlenir: **sunucu istemciden yeni
olabilir.** Tanımadığı bir `kind`, okunabilir metni olmayan bir satır,
başlıksız bir madde — hepsi *sessizce düşürülür*. Ekranda slug görmek,
hiç görmemekten kötüdür.

---

## 6. Kadans (Cadence) — taahhüt edilen ritim

Roadmap'in başarı ölçütü altı ay boyunca sürdürülen bir ritimdir. Ritim
şudur:

| İçerik | Sıklık | Nereye | Sürüm gerekir mi |
|---|---|---|---|
| Tarif partisi | 2 haftada bir | `recipes` + `recipe_ingredients` | Hayır |
| Antrenman planı | Ayda bir | `exercises` + plan şablonu | Hayır |
| Meydan okuma | Ayda bir | `challenges` | Hayır |
| Mevsimsel içerik | 3 ayda bir | `content_drops` (`seasonal`) | Hayır |
| Sürüm notu | Her uygulama sürümünde | `content_releases` | Sürümle birlikte |

**Sürüm notu tek istisnadır** ve sebebi §8'de.

---

## 7. Meydan okuma yayınlama (`challenges`)

Şablon: `supabase/sql/seed_challenge_example.sql`. Yayında olan altı
meydan okuma: `supabase/migrations/021_launch_challenges.sql`.
Dönüşümlü kütüphane (7 günlük başlangıç, 21 günlük alışkanlık, 60 günlük
dönüşüm, bölge ve ekipman odaklı): `025_rotating_challenge_library.sql`.

### 7.1. Motorun ölçebildiği dört şey — ve ölçemedikleri

`challenges.kind` yalnızca şu dördünü kabul eder:

| `kind` | Ne sayar | Birim |
|---|---|---|
| `sessions` | Tamamlanan antrenman oturumu | adet |
| `streak` | Kesintisiz gün serisi | gün |
| `xp` | Kazanılan XP | puan |
| `consistency` | Tutarlılık yüzdesi | % |

Bunun dışındaki her fikir — "haftada 3 kez bacak günü", "5 kg ver",
"her gün 10.000 adım" — **reddedilir.** Sebep `021`'in başlığında uzun
uzun yazılıdır ve önemli olan kısım şudur: motor onu ölçemiyorsa,
meydan okuma ilerlemeyi *gösteremez*, ve ilerlemeyen bir meydan okuma
kullanıcıya yalan söyler. Ölçülemeyen bir hedefi yayınlamak yerine
yayınlamamak doğrudur.

### 7.2. İki tuzak

1. **`en` metni fiilen zorunludur.** Fallback zinciri locale → dil →
   `en` → null'dır. `en` yoksa ve kullanıcının dili de yoksa satır
   düşer, yani kimse görmez.
2. **Erken bitirmek için satır silinmez, `ends_at` geçmişe çekilir.**
   `challenge_participants` cascade siler; satırı silmek insanların o
   meydan okumayı bitirdiği kaydını yok eder.

---

## 8. Sürüm notu yayınlama (`content_releases`)

Uygulamanın güncelleme sonrası gösterdiği "Yenilikler" ekranı.

```sql
insert into public.content_releases (version, build_number, copy) values (
  '1.1.0',
  37,
  '{
     "tr": {"headline": "FormAI biraz daha iyi oldu",
            "items": [{"title": "Meydan okumalar",
                       "body": "Topluluk sekmesinden katıl."}]},
     "en": {"headline": "FormAI just got better",
            "items": [{"title": "Challenges",
                       "body": "Join one from Community."}]}
   }'::jsonb
);
```

### 8.1. `build_number` neden tarih değil

Play, bir sürümü günlere yayarak dağıtır. Yayın gününde **iki popülasyon
aynı anda vardır**: güncellemiş olanlar ve olmayanlar. Tarihe bağlı bir
not, güncellemeyenlere sahip olmadıkları bir uygulamayı anlatır.

İstemci **kendi build'inden küçük veya eşit** olan en yeni notu ister.
Bu sayede kademeli dağıtım *tasarım gereği* doğru çalışır — içerik
ekibinin bir şeyi hatırlamasına bağlı değildir. Notu build çıkmadan önce
yazıp yayınlamak da bu yüzden güvenlidir.

### 8.2. Üç madde kuralı

`ContentRelease.maxItems = 3`. Dördüncü madde **sessizce düşer**. Bu bir
hata değil: kural insanın okuyacağı miktarla ilgilidir, ve içerik ekibi
ekranda üç madde görünce kuralı bir hata mesajından daha hızlı öğrenir.

Madde listesi **bütün olarak** fallback yapar, madde madde değil. Türkçe
başlık altında İngilizce maddeler, yarım kalmış bir çeviri turunun
bıraktığı hâldir ve hata gibi okunur (Phase 7, tarifler için aynı kararı
verdi: bir satır, bir dil).

---

## 9. İçerik duyurusu yayınlama (`content_drops`)

"Yenilikler" listesinde görünen, yeni içeriğin geldiğini haber veren
kart.

```sql
insert into public.content_drops
  (slug, kind, copy, route, published_at, expires_at,
   target_goals, target_levels, target_locales, requires_equipment)
values (
  'agustos-tarifleri', 'recipes',
  '{"tr": {"title": "20 yeni tarif", "body": "Yaz mutfağı."},
    "en": {"title": "20 new recipes", "body": "Summer cooking."}}'::jsonb,
  '/nutrition/discover', now(), null,
  null, null, null, null
);
```

`kind`: `recipes` · `workout_plan` · `challenge` · `seasonal`. Başka bir
değer istemcide düşer.

### 9.1. Hedefleme (targeting)

| Kolon | Boş/null ise | Doluysa |
|---|---|---|
| `target_goals` | herkes | yalnızca o hedefteki kullanıcı |
| `target_levels` | herkes | yalnızca o seviyedeki kullanıcı |
| `target_locales` | herkes | `tr` yazmak `tr-TR`'yi de kapsar; `tr-TR` yazmak `tr`'yi kapsamaz |
| `requires_equipment` | herkes | `true` = ekipmanı olanlar, `false` = olmayanlar |

**Boş dizi de null gibi "herkes" demektir.** Bir form hiçbir şey
seçilmeyince `'{}'` gönderir, ve kimseye ulaşmayan bir duyuru bu tablonun
yapabileceği en kötü hatadır.

Uygulamanın kullanıcı hakkında bilmediği bir alan, **hedeflenmiş** bir
duyuruyu eler. Ekipmanı bilinmeyen birine barbell programı göndermemek,
göndermekten iyidir.

### 9.2. Mevsimsel içerik ve `expires_at`

`expires_at` yalnızca mevsimsel içerikte doldurulur. Kalıcı bir ekleme
(tarif partisi gibi) hiç sona ermez; Ramazan menüsü, yılbaşı meydan
okuması ve yaz programı sona erer. Süresi dolan bir kart listeden
kendiliğinden düşer — silinmesi gerekmez.

---

## 10. Bildirim kampanyaları (`lifecycle_campaigns.dart`)

Kampanyalar **koddadır, içerikte değildir** — çünkü ne zaman
gönderilecekleri bir kuraldır, bir metin değil. İçerik ekibinin
değiştireceği tek şey ARB'deki metinlerdir.

Bilinmesi gereken tek kural: **haftada en fazla 2, ve iki bildirim arası
en az 48 saat.** Bu tavan, kampanyaların kendi tetikleyicilerinden
önce gelir. 14 gün uzaklaşmış bir kullanıcı aynı gün hem win-back hem
seri-riski hem içerik duyurusu için uygundur; üçü de gönderilmez.

Günlük hatırlatıcı bu tavana dahil **değildir**: onun saatini kullanıcı
seçti. Tavan, *uygulamanın* göndermeye karar verdiği bildirimler
içindir.

Metin tonu: *"Seni özledik"*, asla *"3 gündür antrenman yapmadın"*.
İki hafta uzaklaşmış biri bunu zaten biliyor.

---

## 11. Yayın sonrası kontrol

Her yayından sonra, 60 saniye:

```sql
-- Satır gerçekten yazıldı mı?
select slug, kind, published_at from public.content_drops
  order by published_at desc limit 5;

-- Metin her iki dilde de okunabiliyor mu? (null dönerse istemci düşürür)
select slug, copy->'tr'->>'title' as tr, copy->'en'->>'title' as en
  from public.content_drops order by published_at desc limit 5;
```

Uygulamada görünmüyorsa sırasıyla: `en` metni var mı → `kind` tanınan
bir değer mi → `published_at` geçmişte mi → `expires_at` gelecekte mi →
hedefleme kolonları o kullanıcıyı eliyor mu.

İstemci önbelleği en fazla 1 saatlik: `ContentSyncService` bundan eski
bir önbelleği tazeler. Hemen görmek için uygulamayı kapatıp açmak
yeterli değildir — bir saat beklemek ya da uygulama verisini temizlemek
gerekir.
