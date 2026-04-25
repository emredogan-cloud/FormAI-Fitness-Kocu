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
