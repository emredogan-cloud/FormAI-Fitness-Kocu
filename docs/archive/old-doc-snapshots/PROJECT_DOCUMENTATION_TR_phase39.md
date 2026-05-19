# SixPack AI — Proje Dokümantasyonu

**Versiyon:** 0.1.0+1
**Son güncelleme:** 2026-04-24 (Faz 39)
**Durum:** Pre-launch · 38 geliştirme fazı tamamlandı

Bu doküman, 30 günlük AI destekli fitness koçu olan SixPack AI'ın mevcut durumunu, güçlü ve zayıf yönlerini, mağaza yayınına giden yoldaki blokörleri ve uzun vadeli ürün yol haritasını özetler. Product Manager bakış açısıyla yazılmıştır; "burada ne var?", "ne çalışıyor?", "ne eksik?" ve "sonraki adım ne olmalı?" sorularına kısa, kararlı cevaplar vermeyi amaçlar.

---

## 1. Teknoloji Yığını ve Mimari

### 1.1 Runtime & Paketler

| Katman | Teknoloji | Sürüm | Not |
| --- | --- | --- | --- |
| Framework | Flutter / Dart | Flutter ≥3.22 · Dart ≥3.4 | Tek kod tabanı (iOS + Android). |
| State management | `flutter_riverpod` | 3.3.1 | AsyncNotifier + Provider deseni; global tekil kaynaklar. |
| Backend | `supabase_flutter` | 2.5.6 | Auth + Postgres + Storage. |
| Routing | `go_router` | 17.2.1 | Redirect tabanlı auth/onboarding akışı. |
| Config | `flutter_dotenv` | 6.0.0 | `.env` içindeki `SUPABASE_URL` / `RC_*` anahtarları. |
| Computer Vision | `camera` + `google_mlkit_pose_detection` | 0.12 / 0.14 | On-device pose estimation (cihazdan ayrılmaz). |
| Ses koçu | `flutter_tts` | 4.0.2 | Türkçe ses geri bildirimi, runtime dil seçimi. |
| Lokal persistans | `shared_preferences` | 2.2.2 | Wizard çıktısı, plan cache, dev override flag'ları. |
| Video | `video_player` | 2.8.6 | Egzersiz rehber videoları (Supabase Storage). |
| IAP | `purchases_flutter` (RevenueCat) | 8.1.1 | Entitlement: `FormAI Pro`. |
| Push / Reminder | `flutter_local_notifications` + `timezone` | 21 / 0.11 | Yerel hatırlatıcı altyapısı (aktif zamanlama henüz UI'dan tetiklenmiyor). |
| Chart | `fl_chart` | 1.2.0 | Tarihi görsel; Gelişim sekmesi kendi container-tabanlı grafiklerine geçti (Faz 36b). |
| Auth (sosyal) | `google_sign_in` + `sign_in_with_apple` + `crypto` | 7.2 / 7.0.1 / 3.0.7 | Apple nonce + Supabase link. |
| Diğer | `permission_handler`, `wakelock_plus`, `url_launcher` | — | Kamera izni, ekran uyanık tutma, harici link. |

### 1.2 Klasör Yapısı — Feature-First, Domain-Driven-Lite

```
lib/
├── core/
│   ├── routing/app_router.dart          # Tek merkezli GoRouter + guard
│   ├── services/app_preferences.dart    # SharedPreferences fasadı
│   ├── utils/                           # legal_urls, audio_feedback, placeholder_images
│   └── widgets/error_card.dart          # Ortak hata panosu
├── features/
│   ├── auth/           # Sign-in screen + Google/Apple provider
│   ├── home/           # Dashboard scaffold + sekmeler (Antrenman / Beslenme / Gelişim / Profil)
│   ├── monetization/   # RevenueCat provider + Paywall
│   ├── nutrition/      # Recipe data + meal plan + "Next Best Meal" service
│   ├── onboarding/     # 13 adımlı wizard + prediction hook + illusion
│   └── workout/        # 30-günlük program + ad-hoc planlar + pose kamera
└── main.dart           # BootGate: .env, Supabase, RevenueCat init
```

Her feature kendi `data / domain / presentation / providers` katmanlarına sahip; sıkı DDD değil, **feature-first + katmanlı tekrarlama**. Küçük bir ekip için ideal: değişiklik bir feature klasörüne hapsolmuş olur.

### 1.3 Veri Akışı

1. **Kaynak-tek** prensibi: Supabase (recipes, user_progress) + SharedPreferences (wizard + plan cache).
2. Her feature'ın Riverpod provider'ı kendi cache stratejisini yönetir (`workoutSessionProvider` örneği: cache-or-generate).
3. UI, `ref.watch(...)` ile `AsyncValue` akışlarına abone olur; loading / error / data üçlüsü tek yerde çözülür.

### 1.4 Güncel Ekranlar (haritadan)

- `/` Dashboard (4 sekmeli bottom nav)
- `/onboarding` 13 adımlı wizard
- `/prediction` AI tahmin ekranı
- `/auth` Google + Apple + anon sign-in
- `/plan-detail` 30 günlük ekran + özel plan ekranı (iki yüzlü)
- `/workout` Kamera + pose analizi oturumu
- `/paywall` RevenueCat paywall (fallback fiyatlı)
- `/recipe` Tarif detay
- `/nutrition/category/:type` Kategori tarif listesi
- `/account-settings` Hesap ayarları

---

## 2. Uygulamanın Güçlü ve Zayıf Yönleri

### 2.1 Güçlü Yönler

- **AI Decision Engine (Beslenme hero panosu):** `_ExpandedDecisionPanel` kullanıcıya tek ekranda kalori halkası + makrolar + "AI öneri satırı" + "Next Best Meal" kartı sunuyor. Karar yorgunluğunu azaltan nadir ekranlardan.
- **On-device pose analizi:** `google_mlkit_pose_detection` ile kamera akışı cihazdan çıkmıyor. Gizlilik hikayesi güçlü.
- **30 günlük kişisel program motoru:** `workout_generator_service` kullanıcı hedefi + aktivite seviyesine göre rotayı anlık üretir, `_planKey = v2` versiyonlaması ile eski install'ları yeniden üretir.
- **Radar grafiği yerine "tekil karar" odağı:** Ana ekranlar "bir sonraki adım ne?" sorusuna cevap verir — tipik fitness app'lerdeki 5 rakam / 5 grafik yorgunluğuna düşmez.
- **Dil ve kültüre yerli uyum:** Türkçe TTS, Türkçe tarif veri tabanı, Türk kullanıcı arayüzü.
- **RevenueCat fallback modu:** `purchases_flutter` init başarısız olursa paywall hardcoded fiyatlarla ayakta kalıyor (dev/test kolaylığı).

### 2.2 Zayıf Yönler

- **Offline deneyim sınırlı:** Supabase yoksa Beslenme sekmesi büyük ölçüde boşalır. Cache/empty state var ama "tamamen offline" akış tasarlanmadı.
- **Telemetri yok:** Firebase Analytics / PostHog / Sentry entegrasyonu yok. Launch sonrası funnel kaybı tespit edilemez.
- **Crash reporting yok:** Kullanıcı cihazında patlayan istisna sessizce `debugPrint`'e düşüyor; prod'da görünmez.
- **QA otomasyonu neredeyse sıfır:** `test/` klasöründe yalnızca `widget_test.dart` (default starter). Regression'ları yakalayan sistem yok.
- **İçerik yönetimi manuel:** Tarif seedleri SQL patch ile (`supabase_patch_first_5_recipes.sql`, `supabase_seed_recipes.sql` vb.). Ölçeklemez.
- **Egzersiz videoları büyük + CDN yok:** Supabase Storage bucket doğrudan bağlanıyor; video_player her açılışta aynı dosyayı yeniden çekebilir.

---

## 3. Engellemeyen Teknik Borç

Bu kalemler çalışıyor ama refactor zamanı geldiğinde dokunulmalı.

- **Image caching yok:** `Image.network` her açılışta yeniden indirir. `cached_network_image` paketi ile ~1 günlük iş; özellikle tarif kartları ve kategori hero'ları için.
- **Recipe pagination yok:** `recipesProvider` tüm tarifleri tek `SELECT * FROM recipes` ile çeker. 500+ tarifte UI gecikmeye başlar. Cursor/range tabanlı pagination'a geçilmeli.
- **`fl_chart` paket gereksizliği:** Gelişim sekmesi kendi container chart'ına geçti (Faz 36b). `fl_chart` hâlâ `pubspec.yaml`'da — kaldırılırsa APK ~300 KB ufalır.
- **`docs/<region>/` asset klasörleri:** Faz 35'te Unsplash'e geçildi ama klasörler pubspec asset listesinde kaldı. ~10-20 MB binary dead-weight.
- **`Beslenme-Photos/` untracked klasörü:** Git `?? Beslenme-Photos/` olarak görüyor. Ya `.gitignore`'a eklenmeli ya da projeye formal olarak bağlanmalı.
- **State management dağınıklığı noktaları:** `nutrition_tab` filter chip state'i widget-local (`_active` field). İyi çalışıyor ama future-me için provider'a taşımak test edilebilirliği artırır.
- **`debugPrint` log'ları:** `auth_provider`, `workout_camera_screen`, `meal_plan_timeline` ve `monetization_provider`'da `debugPrint(e, st)` satırları var. Prod'da bunları Sentry breadcrumb'a yönlendiren bir soyutlama (örn. `AppLogger.error`) eklenmeli.
- **Magic number'lar:** `_kcalPerDay = 250`, `_freeDayLimit = 3` gibi sabitler `gelisim_tab.dart`'a gömülü. Bunları `core/constants/app_constants.dart`'a toparlamak tek tıkla düzenleme imkânı verir.

---

## 4. UI/UX İyileştirme Fikirleri

### 4.1 Kısa Vadeli (1-2 hafta)

- **Haptic feedback haritası:** `HapticFeedback.mediumImpact()` bazı CTA'larda var, bazılarında yok. Tüm primary butonlarda ortak haptic politikası.
- **Skeleton loader'lar:** Şu an yalnızca `CircularProgressIndicator` gösteriliyor. Tarif kartları + Gelişim grid'i için skeleton animasyonu eklenirse perceived performance artar.
- **Pull-to-refresh:** Beslenme ve Gelişim sekmelerinde yok. `RefreshIndicator` ile `recipesProvider` + `workoutSessionProvider` invalidate edilmeli.
- **Gerçek-zamanlı kalori halkası animasyonu:** Yemek eklendiğinde halka doğrudan zıplıyor. `TweenAnimationBuilder` ile yumuşak geçiş (0.8 sn, easeOutCubic).
- **Dark/Light mode toggle:** Uygulama katı dark mode; bazı kullanıcılar açık tema ister. `ThemeProvider` + `MaterialApp.themeMode` ile değiştirilebilir.

### 4.2 Orta Vadeli (1 ay+)

- **Kişiselleştirilmiş landing:** Kullanıcı 3+ gün serisinde "şampiyon koşusu", 1 gün serisinde "geri dönüş kartı" gibi farklı dashboard açılışları.
- **Animasyonlu AI Koç avatarı:** Gelişim sekmesindeki avatar statik resim; Lottie animasyonu veya "nefes alma" pulse eklenebilir.
- **Paylaşım:** "%72 tamamladım!" tweet/story ekranı. Viral döngü için kritik.
- **Haptic Form Score pulse:** Egzersiz sırasında form skoru 80+ olduğunda pozitif titreşim; 50- olduğunda uyarıcı titreşim.

### 4.3 Uzun Vadeli (3 ay+)

- **Adaptive typography:** Font boyutunu cihaz metriklerine göre ayarla. Büyük font erişilebilirlik için şart.
- **Widget desteği:** iOS Home Screen widget'ı — günün görevi + %kaldı.
- **Live Activities (iOS):** Antrenman sırasında Dynamic Island'ta süre + set sayısı.

---

## 5. Onboarding Durumu ve Öneriler

### 5.1 Mevcut Akış (13 adım)

`_WelcomeStep` → `_CoachIntroStep` → Cinsiyet → Yaş → Boy/Kilo → Mevcut Fizik → Hedef Fizik → Aktivite → Diyet → Alerji → Öğün Sıklığı → Hazırlık Süresi → `IllusionStep` → `/prediction`.

### 5.2 Güçlü Yanlar

- Her adım tek soru, minimum friction. Sadece 2 step (Boy/Kilo + Yaş) birden fazla input alıyor.
- `IllusionStep` "AI programını hazırlıyor..." algısı yaratıyor — perceived value.
- Silent anonymous sign-in (`signInAnonymously`) arka planda çalışıyor; kullanıcı hesap formuyla boğulmuyor.

### 5.3 Drop-off Riskleri & Öneriler

- **13 adım uzun:** Sektörde gözlemlenen funnel kaybı tipik olarak ilk 4-5 adımdan sonra hızlanır. Öneri: Beslenme sorularının (Diyet / Alerji / Öğün / Hazırlık) **launch sonrasına** ertelenmesi. Onboarding sadece 8-9 adım kalır, beslenme soruları ilk tarif keşfinde sorulur ("Size uygun tarifleri göstermek için…").
- **Progress bar eksik state telkinleri:** Şu an `step/total` rakamsal. "3 soru kaldı", "neredeyse bitti" copy'si eklenirse bırakma oranı düşer.
- **"Neden soruyoruz?" tooltip'i:** Hassas veriler (kilo, aktivite) için küçük bilgi butonu ekle.
- **A/B test altyapısı yok:** Onboarding varyantlarını deneyebilmek için Remote Config + Analytics gerekli.

### 5.4 Metrikleme Önerisi

Onboarding'in her adımında `analytics.track('onboarding_step_completed', {step: N})` eventi atılmalı. İlk 2 hafta verisinden "hangi adımda ne kadar kayıp" net çıkar.

---

## 6. App Store / Google Play Blokörleri

Red riski yüksek → düşük sıralıdır.

### 🔴 Kesin Blokörler

1. **Placeholder gizlilik politikası URL'i:** `lib/core/utils/legal_urls.dart` → `https://formai.app/terms` ve `https://formai.app/privacy` henüz canlı değil. App Store guideline 5.1.1(i) ve Play Data Safety için şart.
2. **Data Safety / App Privacy formları:** Supabase email'i, sağlık verisi (kilo/boy) ve kamera kullanımı toplanıyor. iOS privacy manifest ve Play Data Safety form'u eksik.
3. **Missing `NSCameraUsageDescription` kontrolü:** iOS Info.plist'te açıklamanın güncel olması şart (pose detection için).
4. **iOS ATT (App Tracking Transparency):** Analytics eklendiğinde şart. Şu an analitik yok, dolayısıyla şu an risk yok ama eklenir eklenmez ATT prompt lazım.

### 🟡 Muhtemel Red Sebepleri

5. **RevenueCat "FormAI Pro" entitlement konfigürasyonu eksik olabilir:** Dev override flag'ı (`_kDevProOverrideKey`) prod build'de olmamalı; paywall üzerindeki sandbox butonu yalnızca `kDebugMode` arkasına alınmalı.
6. **Restore Purchases butonu:** Paywall ekranında `_buildRestoreButton` var — ✅. Doğrulandı, risk yok.
7. **Subscription terms görünürlüğü:** Paywall'da "otomatik yenileme", "iptal" ve "fiyat" bilgileri, Terms/Privacy link'leri birlikte görünmeli. Şu an link var, copy'nin App Store şablonuna tam uyması lazım.
8. **Boş durum (empty state) kapsamı dar:** Örneğin kullanıcının tarifi yoksa "0 kcal" gözüküyor; bazı boş durumlar için hala `SizedBox.shrink` dönüyor — reviewer "buton çalışmıyor" olarak yorumlayabilir.
9. **Paylaşım/Social reviewer riski:** Yok (henüz paylaşım yok).

### 🟢 Düşük Riskli Ama Eklenmeli

10. **Rate prompt:** Apple'ın `SKStoreReviewController` veya Play'in In-App Review API'si. Feature değil ama store'larda organik büyümeye yardım eder.
11. **Support e-mail veya form:** Uygulama içinden ulaşım yolu. Profil sekmesinde yer var, henüz aktif değil.
12. **Uzun vadeli SLA:** Sağlık verisi toplandığı için KVKK/GDPR için "delete my data" butonu canlı olmalı. `auth_provider.deleteAccount` RPC çağrısı var — UI'dan bağlanmış görünüyor; end-to-end test edilmeli.

---

## 7. Pazar Rekabetçiliği

### 7.1 Rakip Analizi

| Rakip | Odak | SixPack AI Avantajı |
| --- | --- | --- |
| **Freeletics** | Bodyweight HIIT | Türkçe + AI koç + kamera tabanlı form analizi (rakipte yok). |
| **Fitbod** | Strength planı + ekipman tabanlı | Bizde 30 günlük narrative + beslenme entegrasyonu. |
| **MyFitnessPal** | Kalori takibi | Biz yemeği "saymak" yerine "ne yiyeyim" kararına odaklıyoruz. |
| **Nike Training Club** | Marka gücü + geniş kütüphane | Biz kişiye özel 30 günlük rota üretiyoruz. |
| **Lokal rakipler (FitBoost, Fityard vs.)** | Yerel tarifler | Bizde pose detection + AI decision engine var. |

### 7.2 Diferansiyasyon Köşe Taşları

1. **"Bu hafta ne yemeliyim?" sorusuna cevap:** MyFitnessPal "ne yediğini kaydet" der; biz öneri yapıyoruz. Kritik mesaj.
2. **On-device form skoru:** Kamera + pose + ses koçu kombinasyonu rakiplerin çoğunda yok ya da premium-only.
3. **30 günlük narrative:** Kullanıcı "program bitti, ne oldu?" sorusunu sorduğu an bir sonraki 30 günlük rotaya köprü kurabilir (programmatic continuation).
4. **Türkiye pazarı için yerel fiyatlandırma:** ₺ cinsinden agresif fiyat (rakip çoğunlukla $7-15/ay USD'ye takılıyor).

### 7.3 Konumlandırma Önerisi

- **Hedef persona:** 22-35 yaş, ofis çalışanı, haftada 2-3 kez egzersiz yapmaya çalışan, Türkçe içerik arayan, fiyat hassasiyeti orta.
- **Anahtar mesaj:** "Yapay zeka koçun her gün cebinde. Her öğünde ne yemen gerektiğini söyler, her tekrarı izler, 30 günde sonucu görürsün."
- **ASO (App Store Optimization):** "fitness", "karın kası", "beslenme", "diyet", "kalori hesapla" anahtar kelimelerine odaklan. "AI koç" rekabeti henüz düşük Türkçe'de.

---

## 8. İçerik Stratejisi

### 8.1 Mevcut Durum

- Tarifler manuel SQL seed'leriyle ekleniyor: `supabase_seed_recipes.sql` (25 tarif), `supabase_patch_first_5_recipes.sql` (instruction upgrade), `supabase_patch_missing_tags.sql`.
- Egzersizler `workout_repository.dart` içinde hard-coded (43 egzersiz + 20+ plan).
- Bu yapı ölçeklenmiyor: yeni bir tarif = SQL editor'a gidip elle insert, push.

### 8.2 Ölçeklenebilir Model

**Faz A — Admin Panel (1-2 hafta iş)**
- Supabase RLS + JWT admin rolü.
- Basit Retool / Supabase Studio UI.
- Tarif CRUD, egzersiz CRUD, tag yönetimi.
- Resim yükleme doğrudan Supabase Storage'a.

**Faz B — İçerik Pipeline (sürekli)**
- Haftada 5-10 tarif eklemek için freelance diyetisyen + iç içerik ekibi.
- Egzersiz videolarını tek bir formatta (1080p, 10 sn loop, portrait) standardize et.
- Her egzersiz için `shortTip`, `description`, `targetMuscle`, `isCardio` mandatory.

**Faz C — User-Generated Content (opsiyonel, 6+ ay)**
- Kullanıcı tarif ekleyebilir → onaylı tarifler havuzuna düşer.
- "Favori tarifim" + "sepet" işlevi.

### 8.3 Egzersiz Videolarının Akıbetı

Şu an Supabase Storage bucket doğrudan bağlı. Büyüdükçe bandwidth maliyeti patlar. Öneri: Cloudflare R2 + stream CDN + HLS. Kısa vadede `cached_network_image` benzeri video cache (`video_cache`, `flutter_cache_manager` custom).

---

## 9. Dashboard Durumu ve Evrimi

### 9.1 Mevcut "Decision Panel"

Beslenme sekmesi hero SliverAppBar'ı (`_ExpandedDecisionPanel`) 4 blok halinde:
1. Bugün başlığı + skor + seri pilleri.
2. Kalori halkası (traffic-light renk).
3. Protein/Karb/Yağ makroları.
4. AI insight satırı ("N kcal fazla aldın — yürüyüş yap") + Next Best Meal kartı + tek yeşil "Hemen Ekle" CTA.

Bu panel, tipik fitness dashboard'larının "5 rakam + 5 grafik" yorgunluğunu kırar. Bir ekranda **ne yapılmalı**, **neden**, **nasıl** sorularını birden cevaplar.

### 9.2 Evrim Yol Haritası

- **Haftalık yerine günlük sesli özet:** Her sabah "Bugün 1800 kcal hedefin var, öğlen Izgara Tavuk Kinoa öneririm" — TTS zaten entegre.
- **Haftalık retrospektif:** Pazar akşamı "Bu hafta 4/7 antrenman, 3/7 hedefte beslenme. Bir sonraki hafta..." kartı.
- **Momentum uyarısı:** Seri 2 gün düşerse AI koç özel push gönderir ("Seriye dönmek için 10 dakika yeterli").
- **"Önce kullanıcı, sonra rakam" motto'su:** Rakip app'lerin aksine, her rakam bir eylemle bağlantılı olmak zorunda.

---

## 10. Dar Boğazlar ve Ölçeklenebilirlik

### 10.1 Supabase Kapasitesi

| Kaynak | Free Tier | 100K user'da beklenen | Risk |
| --- | --- | --- | --- |
| Database | 500 MB | ~5-10 GB (user_progress, recipes) | 🟡 Pro plan ($25/ay) şart. |
| Storage (videos) | 1 GB | 50+ GB | 🔴 CDN'e taşınmalı. |
| Realtime connections | 200 concurrent | 1K+ peak | 🟡 Pro plan + connection pooling. |
| Auth MAU | 50K | 100K | 🟡 Pro + $0.00325 / MAU üstü. |
| Edge Functions | 500K/ay invocation | 3-5M | 🟡 Pro plan şart. |

**Kritik aksiyon:** Launch öncesi Pro plan rezerve et. Storage için Cloudflare R2 / Bunny Stream alternatifi araştır.

### 10.2 Client-Side Dar Boğazlar

- **Pose detection CPU spike:** MLKit pose ~15-20 FPS'de çalışıyor. Düşük-end Android'de frame drop gözleniyor. Frame throttling (her 3 frame'den 1'i) şu an `workout_camera_screen`'de var, ama `isPreparing` varken de frame skip uygulanmıyor.
- **Dashboard build maliyeti:** `_ExpandedDecisionPanel` her frame'de `ref.watch` 5+ provider. Memoization fırsatı var.
- **Provider invalidation zincirleri:** `auth_provider` sign-out'ta `workoutSessionProvider` invalidate ediyor — iyi. Ama recipesProvider sign-out'ta invalidate edilmiyor — bir sonraki kullanıcı önceki tarif cache'ini görebilir.

### 10.3 Cold Start

`main.dart` → `_BootGate` içinde Supabase init + RevenueCat init + dotenv load senkron yapılıyor. 2.5-3 sn cold start hedefi için:
- RevenueCat init'i **onboarding tamamlandıktan sonraya** öteleme (ilk açılışta gerekmiyor).
- Supabase init asenkron başlasın, UI ilk frame'de splash gösterirken init devam etsin.

---

## 11. Kırık / Dummy Butonlar ve Vaat Edilen Özellikler

Grep taramasıyla tespit edilen placeholder CTA'lar (prod'a gitmeden önce ya sessize alınmalı ya da gerçek bir eylem bağlanmalı).

| Ekran / Dosya | Buton / Aksiyon | Şu anki davranış |
| --- | --- | --- |
| `nutrition_tab.dart:71` | "Tümünü Gör" (Tarif Keşfet) | SnackBar: "Tüm tarif keşfi yakında!" |
| `gelisim_tab.dart:791` | "Takvimi Gör →" (30 Gün grid başlığı) | SnackBar: "Takvim görünümü yakında." |
| `gelisim_tab.dart:1473` | "Önerilere Git →" (AI Koç kartı) | SnackBar: "Koç önerileri yakında." |
| `gelisim_tab.dart:1640` | "Tümünü Gör →" (Rozetler) | SnackBar: "Rozet galerisi yakında." |
| `workout_camera_screen.dart:792` | Önceki egzersize geç | SnackBar: "Önceki egzersize geçiş yakında" |
| `category_recipes_screen.dart:293` | Kategoride tarif yok durumu | Metin: "Yeni tarifler yakında ($category)." |
| `plan_detail_screen.dart:1133` | Henüz egzersizi olmayan bölge planı | Metin: "{plan.title} — yakında" |
| `antrenman_tab.dart:332` | Boş kategori placeholder | Metin: "Bu bölge için plan yakında eklenecek." |
| `recipe_detail_screen.dart:535` | "Tarifi plana ekle" (başarılı) | SnackBar — bu gerçek bir aksiyon ama UI'dan takip edilmiyor. |
| `account_settings_screen.dart:62` | Ayarlar placeholder | SnackBar (profil akışı eksik). |
| `profile_tab.dart:291` | "Değiştir" / bazı menü öğeleri | SnackBar geçici. |

**Launch öncesi öneri:** Her "yakında" SnackBar'ı ya gerçek sayfaya bağla (Takvim / Öneriler / Rozet galerisi), ya da ilgili CTA'yı UI'dan gizle. Reviewer kural kitabı: **"Working UI" prensibi — görünür buton mutlaka bir yere gitmeli.**

---

## 12. Monetizasyon ve RevenueCat Stratejisi

### 12.1 Mevcut Durum (Fallback Mode)

- `SubscriptionNotifier._load` RevenueCat `Purchases.getCustomerInfo()` ve `getOfferings()` çağrılarını try/catch içinde tutar.
- API key eksikse / offline ise neutral state döner → paywall hardcoded fiyatlarla render olur (`ModelPaywall` benzeri placeholder).
- `isProProvider` live entitlement **OR** dev override flag'ı kontrol eder; Sandbox butonu SharedPreferences flag'ını flip eder (debug kolaylığı).
- Entitlement ID: `FormAI Pro` (case-sensitive, boşluk dâhil).

### 12.2 Launch Öncesi Yapılacaklar

1. **RevenueCat dashboard'da prod API anahtarları `.env`'e eklenmeli** (Android + iOS ayrı).
2. **Ürünler (monthly / quarterly / yearly) Play Console + App Store Connect'te onaylanmalı.**
3. **Sandbox butonu `kDebugMode` arkasına alınmalı** (prod build'de görünmemeli). Şu an göründüğü için App Store review takılır.
4. **`kProEntitlementId` iki mağazada da aynı case ile tanımlanmalı.**
5. **Restore Purchases** zaten var — doğrulandı.

### 12.3 Pricing Modeli Önerileri

**Seçenek A — Soft Freemium (önerilir)**
- İlk 3 gün ücretsiz (mevcut `_freeDayLimit = 3`).
- 4. günden itibaren paywall (aylık / 3 aylık / yıllık).
- Aylık ₺149 · 3 aylık ₺299 (₺99/ay) · yıllık ₺799 (₺66/ay).
- Fiyat anchor'ı: rakip Freeletics'in Türkiye fiyatı yaklaşık ₺199/ay.

**Seçenek B — Hard Paywall**
- Onboarding bitince direkt paywall. İlk sürüm için riskli; LTV yüksek olabilir ama ASO ve organik büyüme için zor.

**Seçenek C — Hybrid (deneysel)**
- Ücretsiz: 30-günlük karın plan + 5 tarif/gün.
- Pro: bespoke bölgesel planlar + sınırsız tarif keşfi + AI Coach önerileri + kamera form skoru detayı.

### 12.4 LTV / CAC Hesabı

İlk veri olmadan tahmin; launch sonrası Analytics ile doğrulanmalı:
- **Beklenen conversion:** %3-5 (sektör ortalaması freemium fitness).
- **Aylık churn:** %15-20 (sezonsal).
- **LTV:** 6 ay × ₺99 = ~₺600 (Orta senaryo).
- **CAC tavanı:** LTV/3 = ₺200. TikTok/Meta ads'te Türkiye'de install başına ₺12-25 bekleniyor → CAC ₺150-300 civarında, marjinal kâr var.

---

## 13. Güvenlik ve QA

### 13.1 Supabase Row-Level Security (RLS)

**Durum:** RLS policies projede yazılı değil (doğrudan konfigüre edilmiş olabilir ama repo'da SQL dosyası yok). Launch öncesi kontrol listesi:

- [ ] `recipes` tablosu: `SELECT` herkese açık, `INSERT/UPDATE/DELETE` yalnızca admin.
- [ ] `user_progress` tablosu: `WHERE user_id = auth.uid()` tüm mutasyonlarda.
- [ ] `user_metrics` (şu an SharedPreferences'ta; Supabase'e taşındığında RLS şart).
- [ ] Anon user'lara `INSERT` hakkı yalnızca `user_progress`'e veriliyor mu? Tahmini evet; doğrulanmalı.

### 13.2 Veri Hijyeni

- Kamera frame'leri sunucuya **gönderilmiyor** (on-device MLKit). ✅ Gizlilik için güçlü.
- Wizard çıktısı SharedPreferences'ta JSON olarak duruyor. Hassas veri (kilo, hedef) cihaz dışına çıkmıyor — ama Supabase profile tablosuna eşitleme yapılıyorsa RLS şart.
- `.env` içindeki `SUPABASE_URL` / `SUPABASE_ANON_KEY` APK'ya gömülüyor. ANON key zaten public; bu beklenen bir durum. SERVICE_ROLE_KEY kesinlikle client'a konulmamalı — şu an konulmamış, iyi.

### 13.3 Crash Reporting / Observability

- **Eksik.** Sentry, Firebase Crashlytics, veya Bugsnag entegrasyonu yok.
- **Öneri:** Sentry.io + `sentry_flutter` paketi. Önerilen konfig:
  - Prod'da `tracesSampleRate: 0.2`.
  - `debugPrint` log'ları breadcrumb olarak Sentry'ye yollansın.
  - Privacy: user metrics PII olarak işaretlensin.

### 13.4 QA Otomasyonu

- `test/widget_test.dart` sadece Flutter starter placeholder.
- **Minimum test yatırımı (launch öncesi 1 haftalık iş):**
  - Unit test: `workout_generator_service`, `next_best_meal_service`, `Recipe.fromJson`, `_parseTags` (tag parser).
  - Widget test: Paywall render smoke, `_TodayTaskCard` state variants, Onboarding navigation.
  - Integration test (patrol veya integration_test): happy-path (Onboarding → Workout → Nutrition → Paywall).
- **CI:** GitHub Actions + `flutter test` + `flutter analyze` her PR'da.

### 13.5 Secret Yönetimi

- `.env` dosyası pubspec'e asset olarak eklenmiş — APK'ya dahil oluyor. iOS için `flutter_dotenv` asset yükleme uyumlu.
- RevenueCat keys ve Supabase keys `.env`'de. .env dosyası commit'e girmemeli (`.gitignore` kontrol edilmeli — eğer repo public olacaksa şart).

---

## Özet — Launch Öncesi Zorunlu Kontrol Listesi

1. 🔴 Gerçek Privacy Policy + Terms URL'leri yayınla, `legal_urls.dart` güncelle.
2. 🔴 iOS Info.plist + Android manifest izin açıklamalarını tamamla.
3. 🔴 Supabase RLS policies yaz ve test et (recipes + user_progress).
4. 🔴 RevenueCat prod anahtarları + Sandbox butonu `kDebugMode` guard.
5. 🔴 Tüm "yakında" SnackBar'ları ya bağla ya gizle.
6. 🟡 Sentry (crash reporting) entegrasyonu.
7. 🟡 En kritik 3 path için widget test (paywall, onboarding, workout start).
8. 🟡 Analytics (Firebase veya PostHog) + onboarding funnel eventleri.
9. 🟡 Pull-to-refresh + skeleton loader en kritik 2 ekrana.
10. 🟢 `fl_chart` paketini kaldır, `docs/` asset klasörlerini pubspec'ten çıkar.
11. 🟢 Image caching (`cached_network_image`).

---

## Sonuç

SixPack AI, 38 fazın sonunda **pre-launch seviyesinde, mimari olarak sağlıklı, UX olarak rakiplerinin önünde bir temel** haline geldi. Ana boşluk: **gözlemlenebilirlik (analytics / crash reporting)** ve **mağaza blokörleri (gerçek privacy URL, RLS, RevenueCat prod anahtarları)**. Bu iki başlık kapandıktan sonra Türkiye pazarına soft-launch yapılabilir; 2-4 haftalık bir veri döngüsüyle onboarding + paywall varyantları A/B test edilip global açılışa hazırlanabilir.

İçerik tarafı ise launch-sonrası en büyük operasyonel yük olacak — admin paneli yatırımı erken yapılmalı. Aksi halde her yeni tarif/egzersiz developer saati harcar.

**Bir sonraki öneri fazı (Faz 40):** Gerçek Privacy Policy + Terms hostlama, Sentry entegrasyonu, "yakında" SnackBar'larının ya gizlenmesi ya da gerçek sayfaya bağlanması.
