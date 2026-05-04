# SixPack AI — Master Launch Roadmap

**Versiyon:** 1.0
**Rapor Tarihi:** 2026-05-02
**Kapsam:** `ROADMAP.md` (mühendislik denetimi) + `STORE_LAUNCH_REPORT.md` (pazarlama / mağaza / monetizasyon) dosyalarının birleştirilmiş, **tek kaynak** yayın yol haritası.
**Format:** 8 faz, her görev priority + bağımlılık + zorluk etiketli.

> **Bu dokümanın amacı:** Yayına gitmeden önce **tek tek tamamlanması gereken** her aksiyonu önem sırasına göre kataloglamak. Faz 0 → Faz 7 yukarıdan aşağı sıralı; üst fazdaki bir blocker tamamlanmadan alt fazların hiçbirine başlama.
>
> **Kaynak dokümanlar:** `docs/ROADMAP.md` (542 satır, mühendislik denetimi), `docs/STORE_LAUNCH_REPORT.md` (469 satır, pazarlama). Bu dosya kanonik **eylem planı**dır; kaynakların tek satır özeti hâline gelmiş referans ve detayları için yine kaynak dokümanlara dönülmeli.

---

## Etiket Anahtarı

**Priority:**
- **P0** — Bu olmadan submit reddi veya canlı bug. Yayın için zorunlu.
- **P1** — Bu olmadan ilk hafta retention zarar görür. Launch sprint'inde kapatılmalı.
- **P2** — Launch sonrası 30 gün içinde değerlendirilir.

**Zorluk:**
- **S** (Small) — ≤1 saat veya tek-satır config / SQL.
- **M** (Medium) — Yarım gün, tek widget veya tek özellik.
- **L** (Large) — 1-3 gün, çapraz dosya / yeni sistem.
- **XL** — 3+ gün, yeni feature veya iç mimari değişikliği.

**Owner:**
- **Dev** — kod çalışması.
- **PM** — mağaza / dashboard / hosting / SQL apply gibi panel işi.
- **Designer** — görsel üretimi.

**ID şeması:** `P{faz}.{görev}` — örn. `P1.4` = Faz 1, görev 4.

---

## Yayın Tetikleyici Kontrolü (özet)

Aşağıdakilerin **tümü** ✅ olmadan TestFlight / Internal Testing'e bile gönderme:

| ID | Konu | Durum |
|---|---|---|
| P0.* | Tüm Faz 0 görevleri | Faz 84-87 commit'leriyle giderildi; PM tarafı `bash scripts/diagnose_videos.sh` doğrulamasını yapsın. |
| P1.1 | Production `.env` doldurma | ⛔ Bekliyor |
| P1.2 | `formai.app/privacy` + `formai.app/terms` canlı | ⛔ Bekliyor |
| P1.3 | Play Console Data Safety formu | ⛔ Bekliyor |
| P1.4 | RevenueCat prod ürün + entitlement | ⛔ Bekliyor |
| P1.5 | Supabase prod RPC + tablo apply | ⛔ Bekliyor |
| P1.7 | Sentry/PostHog smoke test | ⛔ Bekliyor (P1.1 sonrası) |
| P2.* | Mağaza görselleri (6 screenshot + feature graphic) | ⛔ Bekliyor |

`GO` koşulu: ⛔ → ✅. P3+ yayın sonrası iyileştirme.

---

## PHASE 0 — Kritik Bug Fix & Stabilite

**Amaç:** Yayına çıkmadan önce hiçbir crash / sessiz UI bozulması / kullanıcının görebileceği "yarım iş" kalmasın.

### P0.1 · Hero görsel hizalama (Faz 87)
- **Aksiyon:** `_HeroHeader` ve `_PlanHeroHeader` widget'larındaki `Positioned(right:-10, width:220)` tasarım deseni `Positioned.fill` + güçlendirilmiş gradient'a çevrildi.
- **Durum:** ✅ **Kod tarafında tamamlandı** (commit `4567cb… (Faz 87)`).
- **Doğrulama (PM):** Cihazda 3 yoldan hero'yu aç:
  - Dashboard "Günlük Meydan Okuma" kartı → plan detail.
  - Antrenman tab'ı → herhangi bir Ekipmanlı kart → plan detail.
  - Bölgeler chip'i → herhangi bir regional plan → plan detail.
  Üçünde de görsel **tam genişlik**, sağa kayma yok, başlık okunaklı.
- **Priority:** P0 · **Zorluk:** S (doğrulama) · **Owner:** PM · **Bağımlılık:** Yok

### P0.2 · Egzersiz video oynatma denetimi
- **Aksiyon:** 51 egzersiz slug'ının video URL'lerini denetle. `scripts/diagnose_videos.sh` komutunu çalıştır:
  ```bash
  bash scripts/diagnose_videos.sh
  ```
  Çıktı `docs/VIDEO_DIAGNOSTIC_REPORT.md` olarak yazılır.
- **Beklenen sonuç:** Tüm 51 slug için HTTP 200, codec H264. 404'ler genellikle Faz 85'te eklenen 10 slug için (videolar henüz yüklenmedi).
- **Aksiyonlar:**
  - 404 dönen slug'lar → Supabase Storage'a `<PascalCase(slug)>.mp4` adıyla yükle.
  - 403 dönen slug'lar → Storage bucket'ı public read olarak ayarla.
  - HEVC dönen slug'lar → `ffmpeg -i input.mp4 -c:v libx264 -preset veryfast -crf 23 output.mp4` ile re-encode et.
- **Priority:** P0 · **Zorluk:** M (her video için ~5 dk) · **Owner:** PM · **Bağımlılık:** Yok

### P0.3 · Onboarding görsellerinin release APK'sında render testi (ROADMAP §2.1)
- **Aksiyon:** Asset isimlerinde Türkçe karakter + boşluk içeren 27 webp dosyası var. Bazı CI ortamlarında UTF-8 normalization sorunu yaşanabilir. Bir release APK build'i alıp 9 onboarding sayfasını sırayla aç; her sayfa için **gerçek fotoğraf** mı yoksa **fallback gradient** mı göründüğünü kontrol et.
- **Eğer fallback'e düşen var:** dosyayı ASCII isimle yeniden adlandır (örn. `welcome_bg.webp`), `Image.asset` çağrısını da güncelle.
- **Priority:** P0 · **Zorluk:** S (test) - M (rename gerekirse) · **Owner:** PM (test) + Dev (rename) · **Bağımlılık:** Yok

### P0.4 · UI regresyon checklist'i (ROADMAP §4.1)
- **Aksiyon:** Cihazda manuel ~45 dk test:
  - Recipe grid scroll: bottom overflow yok.
  - Onboarding 6/7/8: photo card'lar taşmıyor.
  - Paywall light/dark geçiş: ghost text yok.
  - Plan detail 30 günlük grid: invisible day cards yok (Faz 53D).
  - Light mode tüm ekranlar: ghost text'ten arınmış (Faz 53B-I).
- **Priority:** P0 · **Zorluk:** S · **Owner:** PM · **Bağımlılık:** P0.1 (cihaz testi sırasında birlikte yapılır)

### P0.5 · Cold start ölçümü (ROADMAP §2.5)
- **Aksiyon:** Orta-segment Android cihaz (Galaxy A52 / Redmi Note 11). Force stop → stopwatch → ikona bas → ilk frame. 3 ölçüm ortalaması.
- **Hedef:** < 2.5s (kabul edilebilir < 3.5s).
- **Hedef üstündeyse:** Sentry Performance ile span analizi; Faz 48 cold-start optimizasyonlarına bir tur daha gözden geç.
- **Priority:** P0 · **Zorluk:** S · **Owner:** PM · **Bağımlılık:** Yok

---

## PHASE 1 — Hard Launch Blockers (ZORUNLU)

**Amaç:** Olmadan App Store / Play Store submit'i reddedilen veya yayın sonrası 1-yıldız spam patlamasına neden olan sistem konfigürasyonları.

### P1.1 · Production `.env` doldurma (ROADMAP §1.1)
- **Aksiyon:** `.env` dosyasına aşağıdaki 5 anahtarı ekle:
  ```env
  SENTRY_DSN=                          # Sentry projesi → DSN
  POSTHOG_API_KEY=                     # PostHog projesi → Project API Key
  POSTHOG_HOST=https://app.posthog.com # EU instance ise eu.posthog.com
  REVENUECAT_ANDROID_KEY=              # RevenueCat → Settings → API Keys → Android (public)
  REVENUECAT_IOS_KEY=                  # iOS yayını başladığında — boş bıraksa fallback paywall ayakta
  ```
- **Not:** `.env.example` dosyasında `REVENUECAT_APPLE_KEY` / `REVENUECAT_GOOGLE_KEY` adları yanlış (kod gerçekte `REVENUECAT_IOS_KEY` / `REVENUECAT_ANDROID_KEY` arıyor). `.env.example` senkronizasyonu P7.8 maddesinde.
- **Priority:** P0 · **Zorluk:** S · **Owner:** PM · **Bağımlılık:** P1.4 (RevenueCat anahtarlarını oluşturmadan dolduramazsın)

### P1.2 · Yasal sayfaların canlı yayını (ROADMAP §1.2)
- **Aksiyon:** `https://formai.app/terms` ve `https://formai.app/privacy` sayfalarını yayına al. Statik HTML / Notion publish / GitHub Pages / Carrd — fark etmez. Şartlar: HTTPS, `<meta name="viewport">`, içerik dolu (boş sayfa Apple Guideline 5.1.1(i) reddi).
- **Doğrulama:** Tarayıcıda iki URL'yi aç → 200 OK → içerik var.
- **Priority:** P0 · **Zorluk:** M · **Owner:** PM · **Bağımlılık:** Yok

### P1.3 · Play Console Data Safety formu + ATT testi (ROADMAP §1.3)
- **Aksiyon (Play Console):**
  - **App content → Data safety:** Toplanan veriler `Email address` (auth), `Health & fitness` (kilo/boy/hedef), `Photos and videos` (kamera — on-device). "Shared with third parties? **No**", "Encrypted in transit? **Yes**", "Users can request deletion? **Yes** (in-app)".
  - **App content → Permissions declaration:** Kamerayı açıkla — "Antrenman sırasında pose detection için. Görüntü cihazdan ayrılmıyor."
  - **App content → Privacy policy:** P1.2'de yayına alınan `https://formai.app/privacy` URL'sini gir.
- **iOS ATT testi:** TestFlight'ta cihazda **Settings → Privacy & Security → Tracking** listesinde uygulama görünmemeli. `NSPrivacyTracking = false` ayarı `ios/Runner/PrivacyInfo.xcprivacy` içinde — bu prompt çıkmasını engelliyor.
- **Priority:** P0 · **Zorluk:** M · **Owner:** PM · **Bağımlılık:** P1.2

### P1.4 · RevenueCat production ürün + entitlement (ROADMAP §1.4)
- **Aksiyon (Google Play Console):**
  - Monetize → Subscriptions → 3 ürün yarat ve ACTIVE state'e geçir:
    | SKU | Süre | Fiyat (TR) | Trial |
    |---|---|---|---|
    | `formai_pro_monthly` | 1 ay | ₺149 | Yok |
    | `formai_pro_quarterly` | 3 ay | ₺299 | Yok |
    | `formai_pro_yearly` | 1 yıl | ₺799 | 7 gün |
- **Aksiyon (RevenueCat dashboard):**
  - Project Settings → Apps → Android app → bundle ID = `com.emredogan.formai` (üretim `applicationId`'si — `android/app/build.gradle.kts:50`).
  - Entitlements → **`FormAI Pro`** (boşluk dâhil, byte-byte aynı; kod `lib/features/monetization/providers/monetization_provider.dart:16`'ten okuyor).
  - Products → 3 ürünü Google Play'den import et.
  - 3 ürünü `FormAI Pro` entitlement'ına bağla.
  - Offerings → `default` offering altında 3 paketi (`monthly`, `quarterly`, `annual`) sırala.
- **Doğrulama (Internal Testing track'inde):**
  - [ ] `formai_pro_monthly` purchase → paywall kapanıyor → `isProProvider == true`
  - [ ] Restore Purchases → eski abonelik geri yükleniyor
  - [ ] Sandbox tester ile cancel + refund senaryosu
- **Priority:** P0 · **Zorluk:** L · **Owner:** PM · **Bağımlılık:** Yok (paralel olarak P1.2, P1.3 ile yürütülebilir)

### P1.5 · Supabase production SQL apply (ROADMAP §1.5)
- **Aksiyon:** Aşağıdaki SQL parçalarını **sırayla** Supabase SQL Editor üzerinden çalıştır:
  - **P1.5.1** — `supabase/sql/exercises_migration.sql` apply (Faz 50A egzersiz katalogu).
  - **P1.5.2** — `supabase/sql/seed_categories.sql` apply.
  - **P1.5.3** — `supabase/sql/seed_recipes.sql` apply.
  - **P1.5.4** — `supabase/sql/patch_first_5_recipes.sql` + `patch_missing_tags.sql` apply.
  - **P1.5.5** — `supabase/sql/phase83_budget_meals.sql` + `phase83_budget_meals_batch2.sql` apply.
  - **P1.5.6** — `supabase/sql/phase84_full_meal_expansion.sql` apply.
  - **P1.5.7** — `supabase/sql/phase85_equipment_exercises.sql` apply (10 ekipmanlı egzersiz).
  - **P1.5.8** — `supabase/sql/rls_policies.sql` apply.
  - **P1.5.9** — `delete_user` RPC (KVKK / hesap silme — ROADMAP §1.5.1 SQL bloğunu kopyala).
  - **P1.5.10** — `referrals` tablosu + `redeem_referral` RPC (ROADMAP §1.5.2 SQL).
  - **P1.5.11** — `feedback` tablosu + RLS (ROADMAP §1.5.3 SQL).
- **Smoke test:**
  ```sql
  select relname, relrowsecurity
  from pg_class
  where relname in ('recipes', 'exercises', 'user_progress', 'feedback', 'referrals');
  ```
  Hepsi `relrowsecurity = true` dönmeli.
- **RLS denemesi:** İki farklı kullanıcı yarat, A user_progress'ten B'yi okuyamadığını doğrula.
- **Priority:** P0 · **Zorluk:** L · **Owner:** PM · **Bağımlılık:** Yok

### P1.6 · RevenueCat sandbox butonu prod build'de gizli mi? (ROADMAP §1.6)
- **Aksiyon:** ✅ **Doğrulandı**. `lib/features/monetization/presentation/paywall_screen.dart:90` `if (kDebugMode) ...[` guard'ı mevcut.
- **Priority:** P0 · **Zorluk:** S (durum) · **Owner:** Dev · **Bağımlılık:** Yok

### P1.7 · Sentry + PostHog DSN smoke test (ROADMAP §1.7)
- **Aksiyon:**
  - Sentry: bir test cihazında `throw Exception('sentry test')` tetikle → Sentry dashboard'da event gör.
  - PostHog: onboarding tamamla → PostHog dashboard'da `onboarding_step_completed` event'leri gör.
- **Priority:** P0 · **Zorluk:** S · **Owner:** PM · **Bağımlılık:** P1.1

### P1.8 · CI yeşil, lokal test paketi temiz (ROADMAP §2.4)
- **Aksiyon:** Submit'ten önce lokalde `flutter pub get && flutter analyze && flutter test` çalıştır → tüm testler yeşil.
- **Mevcut test dosyaları:** 10 unit/widget test + 1 integration test (`integration_test/app_test.dart`). Workout generator tarafı 15/15 (Faz 86 sonrası).
- **Priority:** P0 · **Zorluk:** S · **Owner:** Dev · **Bağımlılık:** Yok

---

## PHASE 2 — Mağaza Hazırlığı

**Amaç:** Play Console / App Store Connect listing'i, screenshot setup, feature graphic, store metadata.

### P2.1 · Mağaza ekran görüntüleri (6 adet) (LAUNCH_REPORT §5.1)
- **Aksiyon:** Aşağıdaki 6 screenshot setini hazırla. Format: 1080×1920, PNG, Pixel 8 Pro mockup.
  | # | Tür | Mesaj |
  |---|---|---|
  | 1 | Hero / value prop | "30 günde sıkı karın — kişisel AI antrenörün cebinde" |
  | 2 | AI form check | "Kamerada hatalı formu yakalar" |
  | 3 | Plan üretimi | "Hedefine göre 30 gün, 30 farklı seans" |
  | 4 | Beslenme | "Tarif + makro hesabı tek uygulamada" |
  | 5 | Ekipmanlı | "Her bölge için özel plan: Göğüs, Sırt, Bacak..." |
  | 6 | Sosyal kanıt | "★ 4.7 — 'İlk haftada fark ettim'" |
- **Üretim:** Midjourney v6 → arka plan; Figma/Photoshop → mockup + copy overlay. Promptlar `STORE_LAUNCH_REPORT.md §5.3`'te.
- **Priority:** P0 · **Zorluk:** L (designer) · **Owner:** Designer + PM · **Bağımlılık:** Yok

### P2.2 · Feature Graphic (1024×500) (LAUNCH_REPORT §5.4)
- **Aksiyon:** Play Store listing'in üst banner'ı. Slogan: **"30 GÜNDE FARK YARAT — KİŞİSEL AI ANTRENÖRÜN"**, sub: **"Kamerada form düzeltme · Türkçe · Beslenme entegre"**. Midjourney prompt → `STORE_LAUNCH_REPORT.md §5.3` Before/After bloğu.
- **Priority:** P0 · **Zorluk:** M · **Owner:** Designer · **Bağımlılık:** Yok

### P2.3 · Store listing copy (LAUNCH_REPORT §1.2)
- **Aksiyon:** Play Console'a aşağıdakileri gir:
  - **Kısa açıklama (80 char):** "30 günde sıkı karın — kişisel AI antrenörün cebinde"
  - **Uzun açıklama (4000 char):** Türkçe + İngilizce. Vurgu noktaları: AI form check, Türkçe içerik, beslenme entegrasyonu, 30-day struktur. ROADMAP'in pozisyonlama mesajı: "Türkiye'de Türkçe + AI form check + entegre beslenme üçlüsünü sunan tek app" — bunu öne çıkar.
  - **Kategori:** Health & Fitness
  - **Hedef kitle:** 13+
  - **Reklam içeriyor mu?** Hayır
- **Priority:** P0 · **Zorluk:** M · **Owner:** PM · **Bağımlılık:** Yok

### P2.4 · App icon + monochrome variant
- **Aksiyon:** Mevcut launcher icon (`pubspec.yaml:147` `flutter_launcher_icons: android: "launcher_icon"`). Apple Store için **dynamic island monochrome variant** (1024×1024 PNG, alpha+mask) gerekir; eksikse Apple submit reddedilir.
- **Priority:** P1 (iOS submit'e kadar) · **Zorluk:** S · **Owner:** Designer · **Bağımlılık:** Yok

### P2.5 · Demo hesap (reviewer için)
- **Aksiyon:** Apple/Google reviewer Premium akışına girmeyi denemez ama girilebilir bir demo hesabı hazır olmalı:
  - Play Console → App content → App access → "Add credentials" — `reviewer@formai.app` / şifre + "Premium entitlement aktif" notu.
- **Priority:** P0 · **Zorluk:** S · **Owner:** PM · **Bağımlılık:** P1.4 (entitlement)

### P2.6 · Paywall copy App Store guideline 3.1.2 uyumu (ROADMAP §2.7)
- **Aksiyon:** Türkçe paywall metninin Apple "auto-renewing subscription" şablonuyla **% match** olduğunu doğrula. Fiyat StoreKit'ten `Package.storeProduct.priceString` ile geliyor — Apple'ın istediği formatla otomatik gelir.
- **Priority:** P1 · **Zorluk:** S · **Owner:** PM · **Bağımlılık:** P1.4

---

## PHASE 3 — Monetizasyon Optimizasyonu

**Amaç:** Yayın sonrası ilk 90 günde paywall conversion rate'ini iyileştir, A/B test altyapısı kur, fiyatlandırmayı kalibre et.

### P3.1 · 7 günlük free trial yapılandırması (LAUNCH_REPORT §6.2)
- **Aksiyon:** Yıllık paket için **7 gün ücretsiz trial** Google Play Console'da SKU yarattığında ekle. Trial bitiminin 24 saat öncesinde push notif tetikle (`notification_service.dart` içinde `trial_ending_warning` channel ekle, RevenueCat webhook subscription'a bind).
- **Priority:** P1 · **Zorluk:** M · **Owner:** PM (config) + Dev (push) · **Bağımlılık:** P1.4

### P3.2 · Default plan seçim A/B testi (LAUNCH_REPORT §6.3)
- **Aksiyon:** Mevcut paywall hangi paketi öne çıkarıyor? `lib/features/monetization/presentation/paywall_screen.dart` kontrol et. RevenueCat Experiments üzerinden **monthly vs yearly** default vurgusu için A/B test ayarla. Hipotez: monthly default → trial uptake +%20.
- **Bağımlılık:** RevenueCat Experiments paid tier (MTR > $10K) — ilk 6 ay statik, sonraki sprint.
- **Priority:** P2 · **Zorluk:** M · **Owner:** PM · **Bağımlılık:** P1.4 + 6 ay yayın geçmişi

### P3.3 · Free day count A/B (7 vs 14)
- **Aksiyon:** `AppConstants.freeDayLimit = 7` mevcut. PostHog'da `paywall_shown` event'ine variant tag ekleyerek 7 vs 14 günlük free split deneyi yap. Hipotez: 14 günde habit formation → conversion x1.3.
- **Priority:** P2 · **Zorluk:** M · **Owner:** Dev + PM · **Bağımlılık:** P1.7

### P3.4 · Weekly SKU eklenmesi (opsiyonel, post-launch)
- **Aksiyon:** Türkiye düşük gelir grubunda haftalık satın alma yaygın. `formai_pro_weekly` SKU + ₺79 (LAUNCH_REPORT §6.2 önerisi). Önemli: Apple Guideline §3.1.2 weekly subscription için ek değer ifade etmesini istiyor — copy bunu netleştirmeli ("haftalık deneme planı, dilediğin zaman iptal").
- **Priority:** P2 · **Zorluk:** M · **Owner:** PM · **Bağımlılık:** İlk 90 gün yayın metrik analizi

### P3.5 · Trial bitiş hatırlatma push notification
- **Aksiyon:** RevenueCat webhook → Supabase Edge Function → FCM push. Trial bitimi - 24h.
- **Priority:** P1 · **Zorluk:** M · **Owner:** Dev + PM · **Bağımlılık:** P1.4

---

## PHASE 4 — Çekirdek UX Polish

**Amaç:** İlk açılış deneyiminde "aha moment" yarat, drop-off oranlarını minimize et, perception value'yu yükselt.

### P4.1 · Onboarding "plan hazırlanıyor" mikroanimasyonu (LAUNCH_REPORT §3.3)
- **Aksiyon:** Onboarding'in son adımında 1.5-2 sn animasyon overlay. Metin: "Hedefin: Sıkılaşmak. Seviyeniz: Orta. Programın hazırlanıyor..." Generator zaten log'lar veriyor — sadece UI overlay ekleyeceksin.
- **Priority:** P1 · **Zorluk:** M · **Owner:** Dev · **Bağımlılık:** Yok

### P4.2 · İlk seans "aha moment" celebration overlay (LAUNCH_REPORT §3.1)
- **Aksiyon:** İlk gün tamamlandıktan sonra:
  - Streak +1 emoji burst animasyonu.
  - "1. günü tamamladın — yarın 2. gün için seni bekliyoruz" overlay.
  - "Hatırlatıcı kuruldu" toast (push notif opt-in promptu).
- **Mevcut altyapı:** `SessionCompleteOverlay` var. Streak burst + push opt-in eklenecek.
- **Hipotez:** D1→D2 dropoff'u %50 azaltır.
- **Priority:** P1 · **Zorluk:** L · **Owner:** Dev · **Bağımlılık:** Yok

### P4.3 · Dashboard "Bugün ne yiyeceğim?" beslenme kartı (LAUNCH_REPORT §3.4)
- **Aksiyon:** Dashboard'a (Antrenman tab'ının altına veya yan tab'a) 2-3 öğün rotasyonlu beslenme kartı. `lib/features/nutrition/providers/daily_menu_provider.dart` zaten günlük öneri çıkarıyor; sadece dashboard'a expose et.
- **Priority:** P1 · **Zorluk:** M · **Owner:** Dev · **Bağımlılık:** Yok

### P4.4 · Boş state geliştirmeleri (LAUNCH_REPORT §1.3)
- **Aksiyon:**
  - **Favorites:** Hiç tarif favorilemediği bir kullanıcı favorites_screen'i açtığında "İlk favori tarifini ekle, alışveriş listesi oluşturalım" CTA'sı.
  - **Plan:** Boş plan durumu için Faz 47B'nin `_ComingSoonNote` zaten var — ama "yakında" subtitle'ı plan_detail'de gerçek anlamda placeholder değil (ROADMAP §2.3 kabul edildi).
- **Priority:** P1 · **Zorluk:** M · **Owner:** Dev · **Bağımlılık:** Yok

### P4.5 · Ek "yakında" / placeholder temizlik (ROADMAP §2.3)
- **Aksiyon:** ROADMAP §2.3'te kalan 2 metin kabul edildi (gerçek anlamda placeholder değil). Yine de submit öncesi `grep -rn "yakında\|coming soon\|placeholder" lib/` taraması yap; yeni eklenmiş bir tane varsa kapat.
- **Priority:** P1 · **Zorluk:** S · **Owner:** Dev · **Bağımlılık:** Yok

---

## PHASE 5 — Retention Sistemi

**Amaç:** Habit loop tasarımıyla D7 ve D30 retention'ı sektör ortalamasının üzerine çıkar.

### P5.1 · Streak görsel iyileştirme (LAUNCH_REPORT §3.2)
- **Aksiyon:** Header'da güncel streak (3🔥) + en uzun streak (12) + bugün hedefi. Streak hesaplama mevcut (`_streakOf` antrenman_tab.dart:200), sadece görsel emphasis düşük. Hero card'a + günlük tile'a streak rozeti ekle.
- **Priority:** P1 · **Zorluk:** M · **Owner:** Dev · **Bağımlılık:** Yok

### P5.2 · Push notification matrisi (LAUNCH_REPORT §8.3)
- **Aksiyon:** 6 notification türünü `notification_service.dart`'a ekle:
  | Tür | Tetikleyici | İçerik | Öncelik |
  |---|---|---|---|
  | Hatırlatıcı | Her gün 18:00 | "Bugün 12. gün — 18 dakikada bitir" | P0 |
  | Streak risk | 4h kalmış, hala işlem yok | "Streak'in tehlikede — son 4 saat" | P0 |
  | Trial bitiş | Trial - 24h | "Yarın trial bitiyor" | P1 (P3.5) |
  | Comeback | 3 gün dropoff | "Seni özledik — bugün 15 dk" | P1 |
  | Yeni içerik | Haftalık | "Bu hafta 3 yeni Ekipmanlı plan" | P2 |
  | Sosyal kanıt | Aylık | "Bu hafta 1.247 kişi seninle aynı programı tamamladı" | P2 |
- **Sıklık tavanı:** Haftada en fazla 5.
- **Priority:** P1 · **Zorluk:** L · **Owner:** Dev · **Bağımlılık:** P1.7

### P5.3 · Habit micro-design — grace period (LAUNCH_REPORT §8.4)
- **Aksiyon:** Streak grace period: kullanıcı bir günü kaçırırsa **haftada 1 kez free pass**. `markDayCompleted` mantığına ekle: `if missed_yesterday and grace_used_this_week == false → skip rest day insert`.
- **Priority:** P2 · **Zorluk:** M · **Owner:** Dev · **Bağımlılık:** P5.1

### P5.4 · Milestone unlock — paylaşılabilir story
- **Aksiyon:** 7 günlük streak'te badge animasyonu + paylaşılabilir story görseli. Faz 54 referral altyapısı yarım kalan iş — bu görev tamamlanması bunu unlock'lar.
- **Priority:** P2 · **Zorluk:** L · **Owner:** Dev + Designer · **Bağımlılık:** P5.1, P7.1

### P5.5 · Analytics event taksonomisi (LAUNCH_REPORT §8.1)
- **Aksiyon:** `lib/core/services/analytics_service.dart` içine 12 event'i tanımla (PostHog kebab-case):
  ```
  onboarding_started, onboarding_step_completed, onboarding_completed,
  plan_generated, day_started, exercise_completed, day_completed,
  streak_milestone_reached, paywall_shown, paywall_dismissed,
  trial_started, purchase_succeeded
  ```
- **Conversion funnel:** PostHog'da kur — `onboarding_started → onboarding_completed → day_started → day_completed (D1) → day_completed (D7) → trial_started → purchase_succeeded`.
- **Priority:** P1 · **Zorluk:** L · **Owner:** Dev · **Bağımlılık:** P1.7

---

## PHASE 6 — Rakip Eşitleme Özellikleri

**Amaç:** Freeletics / Nike Training Club / Fitify rekabetinde sektör baseline'ına eriş.

### P6.1 · AI antrenör persona/karakter (LAUNCH_REPORT §4.1)
- **Aksiyon:** Antrenör maskotu — önerilen Türkçe persona: **"Aysu"** veya **"Demir"**. Mevcut `_challengeTitleFor` zaten dinamik başlıklar üretiyor; karakter ismini dashboard'da, paywall copy'sinde, push notification'larda kullan. Görsel için tek illustration yeterli (Midjourney prompt: "stylized Turkish fitness coach character, athletic but approachable, neon purple highlights, transparent background").
- **Hipotez:** Duygusal bağ → retention +%15.
- **Priority:** P2 · **Zorluk:** M · **Owner:** Dev + Designer · **Bağımlılık:** Yok

### P6.2 · 30 günlük takvim + ısı haritası dashboard'a (LAUNCH_REPORT §4.2)
- **Aksiyon:** Mevcut `_StickyRemainingHeader` "X gün kaldı" yerine 30 günlük takvim grid + tamamlama ısı haritası. Nike Training Club'ın benzer feature'ı yüksek görsel etki yaratıyor.
- **Priority:** P2 · **Zorluk:** L · **Owner:** Dev · **Bağımlılık:** Yok

### P6.3 · Before/after photo upload (LAUNCH_REPORT §4.3)
- **Aksiyon:** ImagePicker zaten projede (`image_picker: ^1.2.x`). Profil ekranına "Before / After foto yükle" CTA'sı; Supabase Storage'a upload (private bucket); kullanıcının kendi görselleri progress ekranında yan yana render.
- **Privacy:** Bu KVKK kapsamında **photos** kategorisi — Data Safety formuna ekle.
- **Priority:** P2 · **Zorluk:** L · **Owner:** Dev · **Bağımlılık:** Yok (P1.3 doldurulduktan sonra Data Safety güncelle)

### P6.4 · "10 dakika için..." kısa antrenman temaları
- **Aksiyon:** Mevcut `_equipmentTemplates` (Faz 85) bunun bir formu. Daha agresif: duration 10 dk olan tematik plan'lar (10 dk Karın HIIT, 10 dk Sabah Kardiyosu, vb.). Yeni `_quickWorkoutTemplates` static list'i + dashboard'a 4. strip.
- **Priority:** P2 · **Zorluk:** M · **Owner:** Dev · **Bağımlılık:** Yok

### P6.5 · Onboarding sıkıştırma — Fitify benchmark
- **Aksiyon:** Bizim wizard 9 adım. Fitify 3-4 adımda paywall'a çekiyor. Kritik adımlar (gender, goal, level) öne taşı; opsiyonel adımları (age, body metrics) "Daha sonra detaylandır" haline getir. Trial uptake'e doğrudan etki.
- **Priority:** P2 · **Zorluk:** L (UX redesign) · **Owner:** Dev + Designer · **Bağımlılık:** Yok (P1.7 sonrası analytics ile karşılaştırılır)

---

## PHASE 7 — Yayın Sonrası Büyüme

**Amaç:** İlk 90 gün metrik analizi, A/B test framework, içerik genişletme, eski tech-debt temizliği.

### P7.1 · Referral ödüllendirme tarafının automation'ı (ROADMAP §3.1)
- **Aksiyon:** ROADMAP §1.5.2'deki `referrals` tablosu kayıt tutuyor; ödül grant (her iki tarafa 1 ay Pro boost) henüz manual. RevenueCat REST API + Supabase Edge Function ile otomatize et.
- **Tetikleyici:** Kullanım %5'i geçtiğinde otomatize et.
- **Priority:** P2 · **Zorluk:** L · **Owner:** Dev · **Bağımlılık:** P1.5

### P7.2 · `user_metrics` tablosu Supabase'e taşı (ROADMAP §3.2)
- **Aksiyon:** `supabase_rls_policies.sql:217-284` arasında yorumlu hazır. Multi-device sync istendiği gün apply edilir.
- **Priority:** P2 · **Zorluk:** M · **Owner:** Dev + PM · **Bağımlılık:** Çoklu cihaz desteği talebi

### P7.3 · Apple Watch complication & Live Activity polish (ROADMAP §3.3)
- **Aksiyon:** Faz 55 iOS Live Activities entegrasyonunu içerdi. Apple Watch complication ileri faz.
- **Priority:** P2 · **Zorluk:** L · **Owner:** Dev · **Bağımlılık:** iOS yayınının başlaması

### P7.4 · ASO + içerik pazarlaması (ROADMAP §3.4)
- **Aksiyon:**
  - App Store / Play Console A/B test (3 başlık × 5 screenshot varyantı).
  - TikTok / YouTube Shorts içerik üretimi.
  - Zendesk / Helpscout entegrasyonu (şu an mailto fallback `support@formai.app`).
- **Priority:** P2 · **Zorluk:** XL · **Owner:** PM + Marketing · **Bağımlılık:** İlk 30 gün yayın

### P7.5 · Onboarding metric/imperial toggle (ROADMAP §3.5)
- **Aksiyon:** Türkiye için kg/cm yeterli; global launch öncesi gerekli. 2 saatlik iş.
- **Priority:** P2 · **Zorluk:** S · **Owner:** Dev · **Bağımlılık:** Global launch kararı

### P7.6 · 25 tarif `ingredients[]` backfill (ROADMAP §3.6)
- **Aksiyon:** Eski 25 tarifte `ingredients` kolonu NULL. Admin panelden tek tek doldur ya da SQL backfill.
- **Priority:** P2 · **Zorluk:** M · **Owner:** PM · **Bağımlılık:** Yok

### P7.7 · `README.md` doldurulması (ROADMAP §3.7)
- **Aksiyon:** Repo kökündeki `README.md` 1 satır. 30 satırlık yeni README: kurulum, env şablonu, branch policy, yerel çalıştırma.
- **Priority:** P2 · **Zorluk:** S · **Owner:** Dev · **Bağımlılık:** Yok

### P7.8 · `.env.example` senkronizasyonu (ROADMAP §3.8)
- **Aksiyon:** `.env.example` içinde `REVENUECAT_APPLE_KEY` → `REVENUECAT_IOS_KEY`, `REVENUECAT_GOOGLE_KEY` → `REVENUECAT_ANDROID_KEY`. SENTRY_DSN, POSTHOG_API_KEY, POSTHOG_HOST de eklenmeli.
- **Hipotez:** Yeni katılan dev'in onboarding hatasını engeller.
- **Priority:** P1 · **Zorluk:** S · **Owner:** Dev · **Bağımlılık:** Yok

### P7.9 · `recipes` tablosundaki yinelenen satırlar (ROADMAP §3.9)
- **Aksiyon:** Faz 72 sync script'i 107 satır buldu, ~82 benzersiz başlık. Dedupe SQL pass'i:
  ```sql
  DELETE FROM public.recipes r1 USING public.recipes r2
  WHERE r1.ctid < r2.ctid AND r1.title = r2.title;
  ALTER TABLE public.recipes ADD CONSTRAINT recipes_title_unique UNIQUE (title);
  ```
- **Priority:** P2 · **Zorluk:** M · **Owner:** PM · **Bağımlılık:** Yok

### P7.10 · `delete_user`/`redeem_referral`/`feedback` SQL'lerini repo'ya commit'le (ROADMAP §6.2)
- **Aksiyon:** P1.5.9-11'deki SQL bloklarını `supabase/sql/migration_*.sql` olarak commit'le. Versiyon kontrolü dışı state taşımayı bitir.
- **Priority:** P1 · **Zorluk:** S · **Owner:** Dev · **Bağımlılık:** P1.5

### P7.11 · Sosyal kanıt counter — "X kişi şu an antrenman yapıyor" (LAUNCH_REPORT §8.4)
- **Aksiyon:** PostHog session count'undan beslenen canlı sayaç. Marketing açıdan güçlü; landing'a ve dashboard header'ına eklenebilir.
- **Priority:** P2 · **Zorluk:** M · **Owner:** Dev · **Bağımlılık:** P5.5

### P7.12 · İçerik genişletme — 25 yeni tarif (ROADMAP §2.6)
- **Aksiyon:** Mevcut 25 → 50 tarif. Freelance diyetisyen ile çalış. Her kategori (5) için 10 tarif → "ilk gün boş hissi" ortadan kalkar.
- **Priority:** P2 · **Zorluk:** XL (içerik üretimi) · **Owner:** PM + içerik · **Bağımlılık:** Yok

### P7.13 · Yeni egzersizler (ekipman katmanı genişletme) (`WORKOUT_DATA_REPORT.md` §5)
- **Aksiyon:** Phase 85'te 17→27 ekipmanlı egzersize çıktık. 10 ekipmanlı egzersiz daha (face_pull, preacher_curl, goblet_squat, vb.) → her kart 4-6 movement'a çıkar.
- **Priority:** P2 · **Zorluk:** L · **Owner:** Dev + content · **Bağımlılık:** Yok

---

## Kapanış Notları

### Yayın gününün son saatinde

1. **Pre-launch checklist** (`STORE_LAUNCH_REPORT.md §2`) baştan sona yap.
2. **`scripts/diagnose_videos.sh`** son kez çalıştır → tüm slug'lar 200.
3. **`flutter analyze && flutter test`** lokal yeşil.
4. **Internal Testing track**a `flutter build appbundle --release` ile yükle.
5. **3-5 gün soak.**
6. **Closed Testing → Production track.**

### Tahmini süre

| Faz | Süre tahmini | Owner |
|---|---|---|
| Faz 0 (kritik bug fix) | 0.5 gün | PM (test) |
| Faz 1 (hard blocker) | 1.5-2 gün | PM ağırlıklı |
| Faz 2 (mağaza hazırlığı) | 2-3 gün | Designer + PM |
| Faz 3-7 | Yayın sonrası 90 gün | Dev + PM |

**Türkiye soft-launch hazır:** ~3-4 iş günü içinde tüm Faz 0-2 tamamlanırsa.

### Bu dosyanın güncelliği

Bu **kanonik** master roadmap. ROADMAP.md ve STORE_LAUNCH_REPORT.md kaynaklar olarak korunur (geçmiş tarihçe için), ancak yayın hazırlığı sırasında **yalnızca bu dosyaya bakılır**. Bir görev tamamlandığında ilgili `### P{X}.{Y}` başlığının hemen altına `**Durum:** ✅ Tamamlandı (commit: <sha>, tarih: <yyyy-mm-dd>)` satırı düşür — başlığı silme, tarihçe önemli.

### Atılan / değişen şeyler

- **STORE_LAUNCH_REPORT.md §6.2'deki weekly/monthly/yearly fiyatlandırma (₺79/₺199/₺1499)** ile **ROADMAP §1.4'teki monthly/quarterly/yearly (₺149/₺299/₺799)** önerileri çelişiyordu. Master roadmap **ROADMAP.md fiyatlarını kabul ediyor** (P1.4); STORE_LAUNCH_REPORT'un weekly varyantı **P3.4** olarak post-launch experimentation'a indirildi.
- **ROADMAP §2.4** (CI durumu) ve **STORE_LAUNCH_REPORT'un §2 Pre-launch Checklist'i** kısmen örtüşüyor; her ikisinin de unique kalemleri P0.4-P0.5 ve P1.8'de birleştirildi.
- **STORE_LAUNCH_REPORT §5.2** layout standartları (Pixel 8 Pro mockup, gradient banner, vb.) P2.1 görevinin "üretim" notu olarak kayboldu — yapılırken `STORE_LAUNCH_REPORT §5.2`'ye bak.
