# SixPack AI — Uygulama Yol Haritası (Faz 40+)

**Kaynak:** `PROJECT_DOCUMENTATION.md` (Faz 39 post-mortem).
**Durum:** Faz 39 raporundaki her madde aşağıdaki 17 fazdan birine atandı.
**Prensip:** Her faz tek bir prompt içinde tamamlanabilecek kadar atomik; büyük operasyonel iş kalemleri (ör. admin panel, CDN geçişi) ayrı kendi fazlarına yerleştirildi.

Her faz aşağıdaki şablonu takip eder:
**Hedef** → tek cümle · **Görevler** → tam teknik liste · **Öncelik** → 🔴 store blokörü · 🟡 launch öncesi · 🟢 post-launch.

---

## Faz 40 · App Store Blokörleri ve Temizlik 🔴

**Hedef:** Mağaza reddine sebep olabilecek dummy butonlar, test tuşları ve APK'daki ölü paketler/klasörleri temizleyerek üretime hazır bir taban elde etmek.

**Görevler:**
- `cached_network_image` paketini ekle; `Image.network` kullanan tüm bileşenleri (tarif kartları, Bölgeler hero'ları, `_Thumb`, plan detail hero) `CachedNetworkImage` ile değiştir. Cache stratejisi için memCache 100, diskCache default.
- Faz 39 Bölüm 11'de listelenen 11 "yakında" SnackBar/placeholder kaynağının tümünü tespit edildiği yerden gizle veya render'a girmesini engelle:
  - `nutrition_tab.dart` "Tümünü Gör" butonu
  - `gelisim_tab.dart` "Takvimi Gör →", "Önerilere Git →", "Tümünü Gör →" (rozetler) üç bağlantı
  - `workout_camera_screen.dart` "Önceki egzersize geçiş"
  - `category_recipes_screen.dart` boş kategori metni
  - `plan_detail_screen.dart` "yakında" plan placeholder'ı
  - `antrenman_tab.dart` "Bu bölge için plan yakında eklenecek" kartı
  - `profile_tab.dart` "Değiştir" menü öğeleri
  - `account_settings_screen.dart` placeholder aksiyonları
- `pubspec.yaml`'dan `fl_chart` dependency'sini kaldır ve `flutter clean` + `flutter pub get`.
- `pubspec.yaml`'dan kullanım dışı asset klasörlerini çıkar (`docs/Core (Karın & Stabilite)/`, `docs/Göğüs (Chest)/`, `docs/Sırt (Back)/`, `docs/Bacak (Legs)/`, `docs/Kol (Arms)/`, `docs/Omuz (Shoulders)/`, `docs/Kardiyo & Full Body/`) ve klasörleri sil.
- `Beslenme-Photos/` untracked dizinini ya `.gitignore`'a ekle ya da formal olarak projeye bağla.
- `paywall_screen.dart`'taki RevenueCat Sandbox butonunu `if (kDebugMode)` guard'ı arkasına al — prod build'de görünmesin.
- Sandbox flag (`_kDevProOverrideKey`) hâlâ okunabilir kalsın, sadece butonun kendisi gizlensin.
- `flutter analyze` + `flutter test` temiz geçmeli.

---

## Faz 41 · Gizlilik, Hukuk ve Mağaza Uyumluluğu 🔴

**Hedef:** App Store Guideline 5.1.1(i) ve Play Data Safety gerekliliklerini tam karşılamak.

**Görevler:**
- `formai.app/terms` ve `formai.app/privacy` canlı URL'leri host et (statik sayfa, Notion embed veya basit GitHub Pages).
- `lib/core/utils/legal_urls.dart`'taki placeholder yorumunu kaldır; URL'leri canlı kaynağa point et.
- iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) yaz: veri kategorileri (Email, Health & Fitness, Camera, Device ID), tracking durumu (no tracking).
- Play Console → App content → Data Safety formunu doldur (kamera izni açıklaması, sağlık verisi toplama, 3rd party paylaşım yok).
- `ios/Runner/Info.plist` içinde `NSCameraUsageDescription` metninin güncel ve Türkçe olduğunu doğrula ("Antrenman sırasında formunu analiz etmek için kamerana ihtiyacımız var.").
- Android `AndroidManifest.xml`'de `CAMERA` permission açıklamasını ve rationale stratejisini gözden geçir.
- `.env` dosyasının `.gitignore`'da olduğunu doğrula; değilse ekle.
- `auth_provider.deleteAccount` RPC çağrısını end-to-end test et (UI → Supabase RPC → user row silme → local prefs temizleme → `/auth`'a yönlendirme).
- KVKK "verilerimi sil" aksiyonunu profil > Hesap Ayarları altında görünür kıl.

---

## Faz 42 · Gözlemlenebilirlik (Sentry + Analytics + AppLogger) 🔴

**Hedef:** Prod'da ne olduğunu görmek — crash, istisna, funnel adımları.

**Görevler:**
- `sentry_flutter` paketini ekle; `main.dart` `_BootGate` içinde `SentryFlutter.init(options: ...)` bootstrap.
- `tracesSampleRate: 0.2`, `environment: kReleaseMode ? "prod" : "dev"`, `dsn`'i `.env`'den oku.
- `core/utils/app_logger.dart` yaz: `AppLogger.info/warning/error` fasadı. Tüm `debugPrint(e, st)` çağrılarını (auth_provider, workout_camera_screen, meal_plan_timeline, monetization_provider, audio_feedback, vb.) bu fasada yönlendir.
- `AppLogger.error` içinde Sentry `captureException` + breadcrumb.
- PII flag: kullanıcı metriklerini (kilo, boy, hedef) PII olarak işaretle; raw kullanıcı ID Sentry'ye gönderilmesin.
- Analytics katmanı ekle: `firebase_analytics` ya da `posthog_flutter` — tercih seçimi Faz başında netleşir.
- iOS ATT (`app_tracking_transparency`) paketi + runtime prompt; iOS 14.5+ için zorunlu.
- Custom event sözlüğü: `onboarding_step_completed`, `workout_started`, `workout_completed`, `paywall_viewed`, `purchase_succeeded`, `recipe_added_to_plan`.

---

## Faz 43 · Supabase RLS ve Veri Güvenliği 🔴

**Hedef:** Prod'da kullanıcıların birbirinin verisini göremeyeceğinden emin olmak.

**Görevler:**
- `supabase_rls_policies.sql` dosyası oluştur; aşağıdaki policy'leri yaz ve apply et:
  - `recipes` tablosu: `SELECT` herkese açık (`authenticated` + `anon`); `INSERT/UPDATE/DELETE` yalnızca `service_role`.
  - `user_progress` tablosu: `SELECT/INSERT/UPDATE/DELETE` yalnızca `auth.uid() = user_id` koşuluyla.
  - `recipes.tags` kolonunu değiştirmek isteyen admin'lere ayrı `UPDATE USING` policy'si.
- `user_metrics`'in Supabase'e taşınması için migration planı (şu an SharedPreferences): yeni `user_metrics` tablosu + RLS ile `auth.uid() = user_id` + profile sync provider.
- `supabase_seed_recipes.sql` ve patch dosyalarının idempotent olduğunu doğrula (yeniden çalıştırmak duplicate yaratmamalı; gerekirse `ON CONFLICT DO NOTHING` ekle).
- Integration test: farklı iki kullanıcı oluştur, user A user B'nin `user_progress` satırlarını listeleyebiliyor mu? (Ret bekleniyor.)
- Supabase dashboard → Auth → Rate limits review; anon signup için kötüye kullanımı önle.

---

## Faz 44 · QA Otomasyonu ve CI/CD 🟡

**Hedef:** Regression'ları kod geçmeden yakalayan bir güvenlik ağı kurmak.

**Görevler:**
- `test/widget_test.dart` placeholder'ını sil.
- Unit testler yaz:
  - `workout_generator_service` — hedef + seviye kombinasyonları için beklenen gün kompozisyonu.
  - `next_best_meal_service` — verilen makro eksiklikleri için doğru tarif sıralaması.
  - `Recipe.fromJson` — List ve String array formatları.
  - `_parseTags` — curly-brace + virgül + tırnak varyantları.
- Widget testler:
  - Paywall render smoke test (offerings null / offerings dolu / entitlement aktif).
  - `_TodayTaskCard` üç durum: activeDay var, program complete, activeDay null.
  - Onboarding `PageView` navigation — geri/ileri + son adım → finish callback.
- Integration test (`integration_test/` klasörü + `patrol` veya built-in integration_test paketi): onboarding tamamla → workout başlat → beslenme sekmesine geç → paywall'ı göster.
- GitHub Actions workflow (`.github/workflows/ci.yml`): her PR'da `flutter format --set-exit-if-changed`, `flutter analyze`, `flutter test`.
- Coverage raporu (opsiyonel): codecov badge.

---

## Faz 45 · RevenueCat Üretim Finalizasyonu & Soft Freemium 🔴

**Hedef:** Ödeme akışını gerçek para kabul edecek hale getirmek ve fiyat modelini devreye almak.

**Görevler:**
- `.env`'e prod API anahtarlarını ekle: `RC_API_KEY_IOS`, `RC_API_KEY_ANDROID`.
- `main.dart` `_BootGate` platform'a göre doğru key ile `Purchases.configure` çağırıyor mu — doğrula.
- Google Play Console'da ürünleri yarat: `formai_pro_monthly`, `formai_pro_quarterly`, `formai_pro_yearly`; fiyatları ₺149 / ₺299 / ₺799 olarak TR locale için ayarla.
- App Store Connect'te aynı ürün ID'leriyle subscription group yarat; otomatik yenileme + trial (opsiyonel 3-gün) konfigürasyonu.
- RevenueCat dashboard'da "FormAI Pro" entitlement'ını üç ürüne de bağla.
- `kProEntitlementId` sabitini iki platformda ismin aynı case'te olduğuna göre doğrula (boşluk dâhil).
- Paywall copy'sini App Store şablonuna göre revize et: otomatik yenileme uyarısı, iptal yolu, fiyat açıklaması, Terms/Privacy link görünürlüğü.
- Rate prompt: `in_app_review` paketi; 3. workout tamamlanınca bir kez request (30 günlük cooldown).
- Empty state audit: her paid-feature için "bu premium" kartının UI'da belirgin olması.
- Test: TestFlight + Play Internal Testing kanallarında fiyat görünürlüğü, satın alma, iptal, restore.

---

## Faz 46 · Onboarding Optimizasyonu ve Funnel Analitiği 🟡

**Hedef:** 13 adımı kısaltmak, drop-off'u ölçmek, ilk A/B test altyapısını kurmak.

**Görevler:**
- Beslenme sorularını (`_DietPreferenceStep`, `_AllergiesStep`, `_MealFrequencyStep`, `_PrepTimeStep`) onboarding'den çıkar; `OnboardingScreen` total step 13 → 9.
- Bu 4 soru için "first-use prompt" pattern'i: kullanıcı ilk kez Beslenme sekmesini açtığında modal sheet'te sor ("Tarifleri kişiselleştirmek için…").
- `_WizardHeader` progress bar copy'sine "N soru kaldı" ve son 2 adımda "neredeyse bitti" ekle.
- Hassas adımlarda (yaş, kilo, hedef) sağ-üst köşede "Neden soruyoruz?" info icon + bottom-sheet açıklama.
- Faz 42'den gelen analytics hook'uyla `onPageChanged` callback'inde `onboarding_step_completed` event'i at (adım adı + step index ile).
- Remote Config entegrasyonu: Firebase Remote Config veya Supabase Edge Function + SharedPreferences variant cache. İlk A/B: 8-adım vs 9-adım onboarding.
- Conversion rate (onboarding complete / onboarding start) dashboard metriği.

---

## Faz 47 · Kırık Butonların Gerçek Ekranlara Bağlanması 🟡

**Hedef:** Faz 40'ta gizlenen placeholder butonları yeniden açmak — bu sefer gerçek ekranlarla.

**Görevler:**
- **Takvim görünümü** (`gelisim_tab` → `_DayGridSection`): yeni `/progress/calendar` route'u; ay bazlı grid + gün tamamlanma durumları + tap ile gün detay modal.
- **Koç önerileri listesi** (`_AiCoachCard` → `_launchSuggestions`): `/progress/suggestions` route'u; active day odaklı top-3 öneri (ör. "karın çalış", "su iç", "X tarifini dene").
- **Rozet galerisi** (`_BadgesSection` → "Tümünü Gör"): `/progress/badges` route'u; tüm rozetler grid + aktif/kilitli filter.
- **Tüm tarif keşfi** (`nutrition_tab` → "Tümünü Gör"): `/nutrition/discover` route'u; arama + filter chip'leri + pagination (Faz 48 pagination ile koordine).
- **Önceki egzersize geç** (`workout_camera_screen`): `_previousExercise` notifier method'u; state'i güncellemek için `activeExerciseIndex--`.
- **Profil > Hesap Ayarları** menü öğeleri (Değiştir, şifre, bildirim tercihleri): her biri ya gerçek flow'a ya da Supabase profile edit ekranına bağlan.
- **Support kanalı:** profile altında "Destek" satırı; `url_launcher` ile `mailto:support@formai.app`.
- **Plan "yakında" placeholder'ı** (`plan_detail_screen` `_ComingSoonNote`): boş planlar için "abonelik al ve üst planlara eriş" CTA.
- **Kategori boş state'i** (`category_recipes_screen`): "Henüz tarif yok" yerine "Benzer tarifler" önerisi.

---

## Faz 48 · Performans ve Ölçeklenebilirlik — Pre-Launch 🟡

**Hedef:** 10K+ kullanıcıda app'in çömelmeyen, cold-start hızlı, provider disiplini temiz olması.

**Görevler:**
- `recipesProvider` cursor-based pagination: `SELECT ... LIMIT 20 OFFSET ?` yerine `range(from, to)` ile; nutrition_tab + category_recipes_screen + /nutrition/discover.
- `_ExpandedDecisionPanel` memoization: `Consumer` veya `ref.watch(...select(...))` ile sadece değişen slice'lar build'e girsin.
- `recipesProvider.invalidate` sign-out handler'a ekle (`auth_provider.signOut` içinde).
- Cold start optimizasyonu:
  - `RevenueCat.configure` onboarding bitene kadar ertelensin.
  - Supabase init asenkron başlasın, splash frame blocking olmasın.
  - Baseline cold start ölçümü (Firebase Performance veya manual timestamps) → hedef <2.5s.
- `workout_camera_screen` frame throttling: `isPreparing == true` iken pose analyzer çağrısı skip edilsin (şu an her frame çağrılıyor).
- Magic number konsolidasyonu: `_kcalPerDay`, `_freeDayLimit`, `_programLength`, `_neon`, `_neonDeep` vb. `core/constants/app_constants.dart` + `core/theme/app_colors.dart`'a taşı.
- `nutrition_tab` filter chip state'ini (`_active`) local widget'tan `FilterChipsProvider`'a taşı — test edilebilirlik + dark mode varyant uyumu için.
- Dead code scan: `dart_code_metrics` ya da `flutter analyze --no-fatal-infos` ile ölü import/unused variable.

---

## Faz 49 · UI Polish — Haptic, Motion, Loaders 🟢

**Hedef:** "İyi görünen bir app"ten "premium hissedilen bir app"e geçiş — mikroanimasyonlar ve geri bildirim.

**Görevler:**
- Haptic policy: tüm primary CTA'larda `HapticFeedback.mediumImpact()`, secondary CTA'larda `lightImpact`, success toast'larda `selectionClick`. Ortak `app_haptics.dart` dosyası.
- Skeleton loader widget (`SkeletonBox`, `SkeletonLine`) core/widgets altında; recipes list, Gelişim grid, plan detail list için kullan.
- `RefreshIndicator` Beslenme + Gelişim sekmelerinde; `recipesProvider.invalidate` + `workoutSessionProvider.invalidate`.
- Kalori halkası animasyonu: yemek eklendiğinde `TweenAnimationBuilder(0.8s, easeOutCubic)` yumuşak geçiş; şu an anlık zıplıyor.
- AI Koç avatarı pulse: Lottie yerine `ScaleTransition(0.95 → 1.05)` nefes efekti — avatar "nefes alan" birşeye dönüşür.
- Workout kamera: form skoru 80+ olduğunda pozitif pulse (`HapticFeedback.heavyImpact`), 50-'de uyarıcı titreşim (`HapticFeedback.lightImpact` 2x). `_analyzeForm` callback'inde threshold check.
- SnackBar default tema: floating + rounded + neon accent ile tutarlı hale getir.

---

## Faz 50 · İçerik Operasyonu — Admin Panel Temelleri 🟡

**Hedef:** SQL editöründen kurtulup haftada 5-10 tarif ekleyebilen bir içerik boru hattı oluşturmak.

**Görevler:**
- Admin rol tanımı: Supabase `auth.users.raw_app_meta_data.role = 'admin'` + RLS policy'sinde admin bypass.
- Tercih 1: Retool bağlantısı (Supabase PostgreSQL connector), `recipes` + `exercises` CRUD ekranları, image upload → Supabase Storage bucket.
- Tercih 2: Basit Flutter web admin app (aynı repo içinde `admin/` klasörü) — sadece iç ekip erişir.
- Resim standardizasyonu: recipes için 800x600 WebP, egzersiz thumbnail için 400x400 WebP; Storage upload'da otomatik transform.
- Mandatory field checklist: tariflerde `title`, `meal_type`, `calories`, `protein/carbs/fat`, `prep_time_minutes`, `image_url`, `tags` — boş olanlara panel save etmez.
- `exercises` tablosunu Supabase'e taşı (şu an `workout_repository.dart`'da hard-coded 43 egzersiz); migration script + Admin CRUD ile yönet.
- İçerik pipeline dokümantasyonu (`docs/CONTENT_OPS.md`): freelance diyetisyen brief + onay akışı + süper admin yayın adımı.

---

## Faz 51 · Video ve Asset CDN Göçü 🟡

**Hedef:** 100K kullanıcıda Supabase Storage bandwidth'ini devirmeyecek bir video dağıtım altyapısı.

**Görevler:**
- Cloudflare R2 veya Bunny Stream hesabı aç; custom domain tanımla (`cdn.formai.app`).
- Supabase Storage'daki mevcut video varlıklarını CDN bucket'ına migrate et (bir kerelik script).
- `workout_repository._videoUrl` helper'ını CDN URL'ine point et; `.env`'e `CDN_BASE_URL` ekle.
- HLS dönüşümü (opsiyonel, Bunny otomatik yapıyor): `.mp4` → `.m3u8` + segment'lar; ilk saniye hızlı başlasın.
- Video cache (`flutter_cache_manager` özel instance) — aynı video ikinci açılışta diskten çalar.
- Bandwidth monitoring dashboard: CDN → usage alerts (10 GB/gün threshold).
- Fallback: CDN 404 durumunda Supabase Storage URL'ine düşme (ileri geri uyumluluk).

---

## Faz 52 · Dashboard Evrimi — Sesli Özet, Retrospektif, Momentum 🟢

**Hedef:** Gelişim + Beslenme hero'larını pasif tracker'dan aktif koça dönüştürmek.

**Görevler:**
- Sabah TTS özeti (`flutter_local_notifications` scheduled + `flutter_tts`): "Günaydın. Bugün 1800 kcal hedefin var. Öğlen [tarif] öneririm."
- Haftalık retrospektif kartı (pazar 20:00): "Bu hafta 4/7 antrenman · %72 beslenme hedefi · X kcal yakıldı. Gelecek hafta için: …"
- Momentum warning push: streak 2 gün düşerse notification ("Seriye dönmek için 10 dakika yeterli").
- `workoutSessionProvider` state change listener → streak düşüşü tespiti.
- "User-first audit" pass: her sayısal stat (%72, 3 gün, 1800 kcal) bir eyleme bağlanmalı. `Gelişim` tab'ının 3 stat kartı zaten bağlı — Beslenme hero'sundaki makro çubuklarını da "öneri yap" CTA'sına bağla.
- Kişiselleştirilmiş landing: streak tier'a göre Gelişim karşılama copy'si ("Şampiyon koşusu — 7+ gün serideyken", "Geri dönüş — streak = 0 + önceki streak > 0").

---

## Faz 53 · Tema — Dark/Light ve Erişilebilirlik 🟢

**Hedef:** App Store Accessibility smoke'dan geçmek + açık tema tercih eden kullanıcıları kaybetmemek.

**Görevler:**
- `ThemeProvider` (Riverpod) + `MaterialApp.themeMode` bağlantısı; system/light/dark üç seçenek.
- Açık tema color token'ları: mevcut `_neon`, `_success`, `_orange` koruyarak background/surface/onSurface paletini light için üret.
- `profile_tab` altında "Tema" satırı (System / Dark / Light).
- Adaptive typography: `MediaQuery.textScalerOf(context)` ile scale factor >1.3 durumunda tüm hero text'ler 2 satıra sığsın.
- `Semantics` label'ları kritik CTA'lara (Antrenmana Başla, Paywall "Devam Et", Profil menü öğeleri).
- Contrast ratio audit: AA level için Orange (#F97316) on dark background kontrol et; gerekirse tonu kaydır.
- RTL readiness (gelecek için): `Directionality` test — şu an Türkçe LTR ama altyapı hazır olsun.

---

## Faz 54 · Sosyal Paylaşım ve Viral Döngü 🟢

**Hedef:** Organik büyüme için paylaşılabilir an'lar yaratmak.

**Görevler:**
- `share_plus` paketi entegre; paylaşım sheet'i iOS + Android native.
- Paylaşım kartları: "%X program tamamlandım" (Gelişim tab'ının sağ-üst ikonu), "Rozet kazandım" (yeni rozet unlock'unda modal).
- Görsel template'ler: her paylaşım için 1080x1920 story + 1080x1080 square PNG render (offscreen canvas + `RepaintBoundary.toImage`).
- Deep link altyapısı (`uni_links` veya `app_links`): paylaşılan link → in-app preview.
- Referral kodu: her kullanıcıya 6-karakter kod; davet edilen kullanıcı kaydolursa her iki tarafa 1 aylık Pro boost.
- Paylaşım event'i analytics: `share_initiated` + `share_completed`.

---

## Faz 55 · iOS Widget'ları ve Live Activities 🟢

**Hedef:** App dışında marka hatırlanırlığı — home screen ve Dynamic Island.

**Görevler:**
- iOS Home Screen widget (`home_widget` paketi veya native WidgetKit): günün görevi + % kaldı + "Başla" deeplink.
- Widget veri push'u: `workoutSessionProvider` state change'lerinde `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget`.
- Live Activity (iOS 16.1+): antrenman başladığında aktivite başlat; Dynamic Island "N. set · kalan süre" gösterimi.
- Android Glance widget equivalent: `home_widget`'ın Android tarafı Jetpack Glance ile.
- "Bugün" Apple Watch complication (ileri aşama, opsiyonel).

---

## Faz 56 · Launch-Sonrası Büyüme — A/B, UGC, ASO Ops 🟢

**Hedef:** İlk 30 gün kullanıcı davranışından öğrenip ürünü sürekli keskinleştirmek.

**Görevler:**
- Remote Config tabanlı feature flag sistemi (Faz 46'da başladıysa genişlet): paywall varyantları (soft vs hard), onboarding copy A/B.
- User-Generated Content MVP:
  - Kullanıcı tarif ekleme formu (moderation queue'ya düşer).
  - Admin panel (Faz 50) moderation view.
  - "Favori tarifim" + shopping list (haftalık plan için ingredients export).
- ASO deneyleri: App Store listing için 3 başlık varyantı, 5 screenshot varyantı; App Store / Play Console A/B test.
- Türkçe içerik pazarlaması: YouTube Shorts + TikTok — her egzersiz için 15 sn klip; app store link organik.
- Destek ticket sistemi: Zendesk veya Helpscout entegrasyonu; in-app "Destek" ekranından konu başlığı seçimi + mesaj.
- Churn anketi: iptal eden kullanıcıya 1 soruluk "neden" anketi (exit survey).

---

## Özet Tablosu

| Faz | Başlık | Öncelik | Tahmini Süre |
| --- | --- | --- | --- |
| 40 | App Store Blokörleri & Temizlik | 🔴 | 1 oturum |
| 41 | Gizlilik, Hukuk & Mağaza Uyumu | 🔴 | 1 oturum |
| 42 | Gözlemlenebilirlik (Sentry + Analytics) | 🔴 | 2 oturum |
| 43 | Supabase RLS & Veri Güvenliği | 🔴 | 1 oturum |
| 44 | QA Otomasyonu & CI/CD | 🟡 | 2 oturum |
| 45 | RevenueCat Prod & Soft Freemium | 🔴 | 1 oturum |
| 46 | Onboarding Optimizasyonu & Funnel | 🟡 | 1-2 oturum |
| 47 | Kırık Butonlar → Gerçek Ekranlar | 🟡 | 3-4 oturum |
| 48 | Performans & Ölçeklenebilirlik | 🟡 | 2 oturum |
| 49 | UI Polish — Haptic & Motion | 🟢 | 1-2 oturum |
| 50 | İçerik Operasyonu — Admin Panel | 🟡 | 3-5 oturum |
| 51 | Video & Asset CDN Göçü | 🟡 | 2 oturum |
| 52 | Dashboard Evrimi — Sesli Özet | 🟢 | 2 oturum |
| 53 | Tema — Dark/Light & Erişilebilirlik | 🟢 | 1-2 oturum |
| 54 | Sosyal Paylaşım & Viral Döngü | 🟢 | 2 oturum |
| 55 | iOS Widget'ları & Live Activities | 🟢 | 2-3 oturum |
| 56 | Launch-Sonrası Büyüme | 🟢 | Süreklilik |

## Kritik Yol (Launch'a Kadar)

Mağaza yayınına gitmeden önce **zorunlu** fazlar (🔴):
**40 → 41 → 42 → 43 → 45**

Bu 5 faz tamamlandığında TestFlight + Play Internal Testing'e soft-launch yapılabilir. Geri kalan 🟡 ve 🟢 fazları paralel olarak 4-6 haftalık bir sprint planına dağıtılabilir; kritik olmayanlar launch-sonrası veri döngüsüyle önceliklenir.

## Hatırlatma

Bu yol haritası **Faz 39 raporunun yürütme planıdır**. Rapor güncellendikçe (yeni tech debt, yeni özellik talebi, yeni mağaza kuralı) bu dosya da güncellenmelidir. Her faz tamamlandığında başlığın yanına `✅` emojisi eklenir; yarım kalan fazlar `⏳` ile işaretlenir.
