# FormAI - App Store & Market Readiness Audit

> Bu denetim, Phase 6 (RevenueCat entegrasyonu) başlamadan önce uygulamanın
> mevcut hâlinin Apple App Store ve Google Play Store tarafından reddedilme
> riskini ve kullanıcıyı kaybetme (retention) riskini belirlemek için
> yapılmıştır. Bulgular, repo taraması sonucu bulunan **dosya:satır**
> referanslarıyla desteklenir.

---

## 1. App Store Rejection Risks (Hard Blockers)

Bu bölümdeki maddeler, uygulama mevcut hâliyle submit edilirse **Apple veya
Google tarafından reddedilmesi neredeyse kesin** olan konulardır.

### 1.1 Paywall: Restore Purchases + Terms/Privacy linkleri yok, ödeme sahte

**Dosya:** `lib/features/monetization/presentation/paywall_screen.dart:124, 153, 802–818`

- **"Satın Alımları Geri Yükle" butonu yok.** Apple Guideline 3.1.1, kullanıcı
  cihazını değiştirdiğinde veya uygulamayı yeniden yüklediğinde aboneliğini
  geri yükleyebilmesi için **görünür bir "Restore" butonu** bulunmasını
  zorunlu kılar. Mevcut ekranda böyle bir buton hiç yok.
- **Gizlilik Politikası ve Kullanım Şartları linkleri yok.** Paywall'un
  altındaki `_LegalFooter` yalnızca düz metin olarak "7 günlük deneme
  süresinin sonunda abonelik otomatik başlar." yazıyor. Apple, ödeme
  ekranında **tıklanabilir** Terms ve Privacy linkleri ister (Guideline 3.1.2).
- **Ödeme sahte.** `_simulatePurchase()` yalnızca bir SnackBar gösterip
  ekranı kapatıyor — RevenueCat veya StoreKit bağlantısı yok. Gerçek
  ödeme akışı olmadan submit edilemez.

**Verdict:** Bu tek başına reddedilme sebebi. Phase 6'nın birinci görevi.

### 1.2 Kamera izni kalıcı reddedildiğinde kurtarma yolu yok

**Dosya:** `lib/features/workout/presentation/workout_camera_screen.dart:76–102`

```dart
final status = await Permission.camera.request();
if (!status.isGranted) {
  if (!mounted) return;
  setState(() => _error = 'Camera permission is required to analyze your form.');
  return;
}
```

- Kullanıcı izni **kalıcı olarak reddettiyse** (`permanentlyDenied`) kontrol
  yok. `request()` artık çağrılsa bile OS direkt `denied` döner —
  kullanıcı bilgisi olmadan bir daha asla izin ekranını göremez.
- Ekranda Ayarlar'a yönlendiren bir CTA yok; `openAppSettings()` hiçbir
  yerde çağrılmıyor. Kullanıcı siyah ekranda bir İngilizce hata metniyle
  takılıp kalır.
- Apple Review kamera izninin reddedildiği senaryoyu test eder; bu eksiklik
  doğrudan reject sebebidir.

### 1.3 Antrenman sırasında ekran kilitleniyor (Wakelock yok)

**Dosya:** `lib/features/workout/presentation/workout_camera_screen.dart:1–953`

- Kod tabanında `wakelock_plus`, `Wakelock`, veya `SystemChrome` kullanımı
  **yok**. 20+ dakika süren bir antrenmanda kullanıcı ekrana dokunmadığı
  için cihaz kilitlenir, kamera akışı kesilir, seans kaybolur.
- Apple Fitness/Health kategorisindeki uygulamalar için aktif antrenman
  sırasında screen-on beklenen bir davranıştır.

### 1.4 Gizlilik Politikası / Kullanım Şartları onboarding'de tıklanamıyor + ML Kit disclosure yok

**Dosya:** `lib/features/onboarding/presentation/onboarding_screen.dart:224–226`

```dart
const Text(
  'Devam ederek Kullanım Şartları ve Gizlilik Politikasını kabul edersin.',
  ...
)
```

- Yalnızca **düz metin** — linkler yok. Kullanıcı kabul ettiği metinleri
  okuyamıyor. Apple ve Google, signup akışında Terms/Privacy'e
  tıklanabilir erişim bekler.
- **Google ML Kit disclosure eksik.** Kamera izni istenmeden önce
  kullanıcıya "Görüntüler cihazınızda işlenir, kaydedilmez, sunucuya
  gönderilmez" açıklaması **hiçbir yerde** gösterilmiyor. Profil →
  Gizlilik ekranında var (Phase 5'te eklendi) ama kamera izninin
  istendiği onboarding akışında **yok**.

### 1.5 Boot sırasında Supabase.initialize hatası yakalanmıyor

**Dosya:** `lib/main.dart:38–41`

```dart
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL'] ?? '',
  anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
);
```

- try/catch yok. `.env` eksikse veya Supabase DNS timeout yaparsa
  `_BootGate` Future'ı ebediyen splash ekranında asılı kalır —
  kullanıcıya ne hata gösterilir, ne retry verilir.
- Review ekibinin uçak modu senaryosu testinde doğrudan crash olarak
  işaretlenir.

---

## 2. Market Failure Risks (Retention Killers)

Uygulama store'a girse bile ilk 48 saatte silinmesine neden olacak UX/teknik
sorunlar.

### 2.1 ML Kit BlazePose her kare için çalışıyor → cihaz ısınıyor, pil akıyor

**Dosya:** `lib/features/workout/presentation/workout_camera_screen.dart:122–133`

```dart
void _onCameraImage(CameraImage image) {
  if (_isBusy || _isPaused) return;
  ...
  _isBusy = true;
  _processImage(image).whenComplete(() => _isBusy = false);
}
```

- Tek koruma `_isBusy` bayrağı — yani mevcut kare işleniyor olursa bir
  sonraki atlanıyor. Ama kare işleme 30 ms'den kısa sürdüğünde **her
  saniye 30 kare boyunca ML Kit pose inference** çalışır.
- Alt-orta segment cihazlarda (iPhone 11, Android Redmi) 15 dakika sonra
  cihaz elde yakar, pil %20+ düşer, kullanıcı "bu app telefonumu
  eritiyor" kaygısıyla siler. Fitness uygulamalarında en sık görülen
  kayıp sebebi.

### 2.2 Rep tamamlandığında haptic feedback yok

**Bulgu:** Kod tabanında `HapticFeedback` veya `Vibration` çağrısı **tek bir
yerde bile** yok.

- Rep sayıldığında, set bittiğinde, HAZIRLAN! countdown'ında titreşim
  yok. Sadece TTS + görsel güncelleme var.
- AirPods/kulaklık takmayan, spor salonunda müzik çalan, veya telefonu
  yere bırakıp uzaktan takip eden kullanıcı tempoyu hissedemiyor.
- Home Workout, Nike Training Club gibi rakiplerde bu beklenen bir his.

### 2.3 Asset bundle boyutu 128 MB (yalnızca videolar) — ilk indirme acısı

**Dosya:** `assets/videos/` (41 adet mp4 × ~3 MB)

- Toplam: **~128 MB videos + 3.6 MB photos + 2 MB docs ≈ 134 MB** install-time
  asset. Store size'a 20–30 MB native binary eklenince **ilk indirme
  150+ MB**.
- iOS'ta hücresel veriyle indirme Apple tarafından 200 MB'a kadar
  izniyor ama "bu app ne diye 150 MB?" algısı dönüşüm oranını düşürür.
- Android'de APK size limit 150 MB — şu an sınırı zorluyoruz.
- Çözüm yoksa videolar **yeniden indirme akışını kaybeder** (yeniden
  install = 130 MB yeniden indir).

### 2.4 Misafir kullanıcı hesap açtığında ilerleme kayboluyor

**Dosya:** `lib/features/auth/presentation/auth_screen.dart:80–94`,
`lib/features/onboarding/presentation/onboarding_screen.dart:62–71`

- Kullanıcı "Misafir Olarak Devam Et" ile `signInAnonymously()` yaparak
  14 gün antrenman yapabilir — `user_progress` Supabase tablosuna
  anonim user_id ile yazılır.
- Sonra "Hesap Oluştur" ile email/password ile kayıt olduğunda **yeni
  user_id** oluşur. `linkIdentity()` veya `signUpWithEmail()`'in
  anonim session ile merge etme çağrısı **yok**.
- Sonuç: 14 günlük streak, 8 tamamlanan gün, kilo/boy/hedef bilgileri —
  hepsi orphan olur. Kullanıcı "neden sıfırlandı?" diye app'i siler.

### 2.5 markDayCompleted Supabase senkronu sessizce yutuyor

**Dosya:** `lib/features/workout/data/workout_repository.dart:1033–1052`

```dart
try {
  await _client.from(_progressTable).upsert({...});
} catch (_) {
  // Offline or network error — local cache will re-sync on next load.
}
```

- Hata yutuluyor, kullanıcıya geri bildirim yok. Telefonu değiştiren
  kullanıcı, progresin bulutta olduğunu sanıyor ama aslında sadece local.
- "local cache will re-sync on next load" yorumu iyi niyetli ama
  `_completedDays()` de yalnızca okumada merge yapıyor, **başarısız
  yazılanları retry etmiyor**. Kalıcı data loss riski var.

### 2.6 Kamera çözünürlüğü + throttle eksikliği = düşük FPS

**Dosya:** `lib/features/workout/presentation/workout_camera_screen.dart:107`

- `ResolutionPreset.medium` seçimi iyi — `high/max` olsa pose detector
  patlardı. Ancak throttle olmadığı için eski cihazlarda UI frame drop
  görülür: kullanıcı "app takılıyor" hisseder.

### 2.7 Kullanıcı dostu olmayan hata ekranları

**Dosya:** `workout_camera_screen.dart:442–450`,
`dashboard_screen.dart` (antrenman_tab'da benzer)

```dart
error: (err, _) => Center(
  child: Text('Workout load failed: $err',
      style: const TextStyle(color: Colors.white)),
),
```

- Stack trace benzeri string **beyaz yazıyla ham** gösteriliyor.
  Tüm uygulama Türkçe ama hata metinleri İngilizce + teknik. Bir daha
  Antrenman tab'ına dönmek için app'i restart etmek gerekiyor.

---

## 3. Recommended Action Plan

Risk sırasına göre (P0 = submit blocker, P1 = yüksek churn, P2 = iyileştirme).

### P0 — Submit'ten Önce MUTLAKA Yapılacaklar

| # | İş | Efor | Risk |
|---|----|------|------|
| 1 | **RevenueCat gerçek entegrasyon**: `purchases_flutter` SDK'sı zaten `pubspec.yaml`'da var. Paywall'a `Purchases.getOfferings()` + `purchasePackage()` bağla. | ~1 gün | §1.1 |
| 2 | **Restore Purchases butonu** ekle: Paywall footer'ına outline buton. `await Purchases.restorePurchases()`, sonra entitlement kontrol et, SnackBar ile feedback ver. | ~1 saat | §1.1 |
| 3 | **Gizlilik/Terms linkleri**: Paywall footer + onboarding disclaimer metinleri `RichText` ile linkify, `url_launcher` ile harici URL'e açılsın (şimdilik `Profil → Gizlilik` bottom sheet'ine navigate etmek de yeter). | ~2 saat | §1.1, §1.4 |
| 4 | **Kamera `permanentlyDenied` handler**: `Permission.camera.request()` sonucunu switch'e sok; `permanentlyDenied` ise "Ayarlara Git" butonu göster, `openAppSettings()` çağır. | ~30 dk | §1.2 |
| 5 | **Wakelock**: `wakelock_plus` dependency ekle, `WorkoutCameraScreen.initState`'te `WakelockPlus.enable()`, `dispose`'ta `WakelockPlus.disable()`. | ~20 dk | §1.3 |
| 6 | **ML Kit / on-device disclosure**: Kamera izni istenmeden önce (camera ekranının ilk frame'inde) tek sefer modal: "FormAI, formunu cihazında Google ML Kit ile analiz eder. Görüntüler kaydedilmez, sunucuya gönderilmez." Onay tıklanınca kamera izni iste. | ~1 saat | §1.4 |
| 7 | **Boot resilience**: `_BootGate._init()` içindeki `Supabase.initialize` + `dotenv.load` çağrılarını try/catch içine al. Hata olursa splash üzerinde "Bağlantı kurulamadı. Tekrar Dene" butonu göster. | ~45 dk | §1.5 |

### P1 — Submit Geçer Ama 7-Günde Churn Yapacaklar

| # | İş | Efor |
|---|----|------|
| 8 | **Pose detector throttle**: `_onCameraImage`'a "her N'inci kareyi işle" sayacı ekle (N=2 → 15 fps). Kalite kaybı belirsiz, pil kazancı belirgin. | ~15 dk |
| 9 | **Haptics**: Rep counter'da `HapticFeedback.lightImpact()`, set tamamlandığında `HapticFeedback.mediumImpact()`, HAZIRLAN!'ın son saniyelerinde `selectionClick()`. | ~30 dk |
| 10 | **Anonim→gerçek hesap merge**: `AuthScreen._submit`'te, signUp çağrısından önce `ref.read(currentUserProvider)?.isAnonymous` kontrol et. Anonymous ise `_client.auth.updateUser(UserAttributes(email: ..., password: ...))` kullan — bu user_id'yi korur. | ~2 saat |
| 11 | **Supabase upsert retry**: `markDayCompleted`'da fail olursa day_number'ı `sixpack.pending_sync` anahtarına push et; app resume'unda `_flushPending()` çağır. | ~1.5 saat |
| 12 | **Türkçe hata ekranları**: `workoutSessionProvider`'ın error widget'ı retry butonlu, Türkçe mesajlı, neon temalı bir `_ErrorCard` olsun. | ~45 dk |

### P2 — Orta Vadede Maliyet/Fayda

| # | İş | Efor |
|---|----|------|
| 13 | **On-demand video delivery**: 41 mp4'ü Supabase Storage'a taşı, ilk açılışta sadece ilk haftanın videolarını prefetch et, Gün 8+ için arka planda indir. İlk indirme ~30 MB'a düşer. | ~1 gün |
| 14 | **Video asset compression**: H.264 → H.265/HEVC (~%40 küçülme), 720p → 480p (PIP için yeterli). | ~2 saat |
| 15 | **Battery/thermal telemetri**: Batarya %/dakika ve termal state'i (iOS `ProcessInfo.thermalState`) metrik olarak topla; ılımlı cihazlarda FPS'i düşür. | ~1 gün |

### Özet

- **Phase 6 (Monetization)**'ı başlatmadan önce yukarıdaki P0 #1-3 çözülmeden
  TestFlight'a bile gönderilmemeli.
- P0 toplam eforu **1-2 iş günü**. P1 bir hafta tam efor.
- P2 Phase 7+'ya ertelenebilir ama §2.3 (bundle size) büyüdükçe
  deneme indirme maliyeti artacak — 50'inci egzersiz eklenmeden
  çözülmesi lazım.
