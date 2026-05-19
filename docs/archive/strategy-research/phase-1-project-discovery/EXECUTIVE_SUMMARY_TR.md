# YÖNETİCİ ÖZETİ — FAZ 1: PROJE KEŞFİ

**Proje:** SixPack AI / FormAI Fit (`pubspec name: sixpack_ai`, sürüm `0.1.0+5`)
**Tarih:** 2026-05-08
**Statü:** Yapısal harita. Yalnızca tespit. Strateji ve öneri Faz 2'den itibaren başlar.

> Bu özet, `PROJECT_STRUCTURE_MAP.md` belgesinin Türkçe yöneticilere yönelik kısaltılmış halidir. Tüm referanslar, kanıt ve dosya yolları için ana belgeye bakınız.

---

## 1. STACK KISA ÖZET

- **Çatı:** Flutter ≥3.22, Dart ≥3.4
- **Durum yönetimi:** flutter_riverpod 3.3.1
- **Yönlendirme:** go_router 17.2.1
- **Backend / Auth:** Supabase 2.5.6
- **Abonelik:** RevenueCat (purchases_flutter 8.1.1)
- **Gözlemlenebilirlik:** Sentry 9.6 + PostHog 5.3 + ATT 2.0
- **Kamera + AI:** Google ML Kit BlazePose + flutter_tts (sesli koç)
- **Yerel önbellek:** SharedPreferences + cached_network_image + flutter_cache_manager
- **Skeleton yükleyici:** shimmer 3.0 (Faz 49)
- **Native köprüler:** iOS WidgetKit + Live Activity (SwiftUI), Android AppWidgetProvider (Kotlin)
- **11 özellik modülü:** admin, auth, feedback, home, monetization, nutrition, onboarding, progress, referral, workout

---

## 2. KRİTİK MİMARİ TESPİTLERİ

### 2.1 Bootstrap ve dayanıklılık (Faz 94)
`main.dart` 4 katmanlı hata koruması içerir: `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` + özel `ErrorWidget.builder`. `_BootGate` üç adımı sıralı çalıştırır: `.env` (timeout yok, log) → Supabase init (8 sn timeout) → PostHog init (5 sn timeout). RevenueCat **bilinçli olarak ertelenmiştir** — onboarding bitişinde veya ilk girişte tembel başlatılır. Sentry init kendi try/catch'i içinde paralel çalışır.

> Otomatik bellek notu: bu sözleşme korunmalıdır, açılmamalıdır.

### 2.2 Yönlendirme
**18 adlandırılmış rota.** Yeniden yönlendirme sırası: referans → ilk-açılış kontrolü → oturum kontrolü → onboarding-sonrası → auth-sonrası → admin yetkisi. `formai://` ve `https://formai.app/` derin bağlantıları tanımlı. Referans bağlantıları auth/onboarding kapılarını **bilerek atlar**; workout/today bağlantıları kapıya tabi.

### 2.3 4 sekmeli ana iskelet
`DashboardScreen` IndexedStack ile: **Antrenman / Beslenme / Gelişim / Profil**. Açılış sekmesi: Antrenman (index 0). Rozet kutlamaları yalnızca **Gelişim** sekmesinde tetiklenir; başka sekmedeyken açılan rozetler sıraya girer.

---

## 3. KULLANICI YOLU HARİTASI — ÖZET

### 3.1 Onboarding — 12 ana adım + 7 ertelenen beslenme adımı = **19 ekran**
Adımlar: Welcome → Coach Intro → Cinsiyet → Hedef → Deneyim (hibrit) → Günlük süre → Aktivite (hibrit) → Fiziksel veriler (3 CupertinoPicker) → Ağrı noktası (hibrit) → Analiz illüzyonu (6 sn) → Dinamik AI raporu → Ön-paywall özet → `_finish()` → anonim Supabase oturumu → `/paywall`.

**Yapısal tespitler:**
- **Adım-arası kaydetme yok.** Adım 1–11 arası uygulama öldürülürse durum kaybolur, kullanıcı Adım 1'den başlar.
- **Cinsiyet seçeneği asimetrisi:** Kadın + Erkek görselli, Diğer sadece ikonlu.
- **`/prediction` rotası tanımlı ama atlanıyor.** Wizard çıkışı doğrudan `/paywall`'a gidiyor; rota mevcut ancak varsayılan akışın parçası değil (Faz 60C).
- **Adım 8'de yapay 1.5 sn "Metabolizmanı hesaplıyorum…" gecikmesi** (gerçek hesap değil — labor illusion).
- **Adım 2'de 4 sn'lik daktilo animasyonu** sırasında CTA pasif; "Geçmek için ekrana dokun" ipucuyla atlanır.

### 3.2 Ana ekran — Antrenman + Gelişim
**Antrenman sekmesi:** Header + Haftalık Hedef + Bölüm başlığı + Challenge Hero (320 px) + Ekipman şeridi + Bölgesel filtre + plan listesi.
**Gelişim sekmesi:** **9 yığılı bölüm** — Header + Program İlerleme + Streak + Bugünkü Görev (CTA "ANTRENMANA BAŞLA") + 30 günlük grid (5×6) + 3 istatistik kartı (haftalık/kalori/antrenman) + Pazar günleri Haftalık Geçmiş + AI Koç + Rozetler.

**Ana CTA "ANTRENMANA BAŞLA" konumu:** Bugünkü Görev kartı içinde, ekrandan ~420–450 px aşağıda — gün/odak/süre/seviye metadatasının altında.

**Yapısal tespitler:**
- **9 bölüm tek bir Gelişim sekmesinde yığılı.**
- **Ücretsiz/Pro kapısı (Gün 4+) CTA dokunulduğunda fark ediliyor;** önceden uyarı yok.
- **Antrenman + Gelişim rol çakışması:** her ikisi de antrenman girişi sunuyor.
- **Yükleme durumu tutarsızlığı:** Gelişim skeleton, Antrenman ortalanmış spinner.

### 3.3 Streak (seri) sistemi
Ardışık tamamlanan günler; istirahat günleri seriyi kırmaz. Ardışık olmayan ilk gün seriyi 0'a çeker. `maxStreak` filigranı SharedPreferences'ta saklanır → AI Koç'un "Geri dönüş zamanı" mesajını besler.

---

## 4. PARA KAZANMA / PAYWALL ÖZETİ

### 4.1 Planlar (otomatik bellek notu)
- `formai_pro_monthly` (Aylık, sol, 180 px) — fallback ₺249,99
- `formai_pro_3month` (3 Ay, sağ, 180 px) — fallback ₺499,99
- `formai_pro_annual` (Yıllık, **varsayılan**, orta, 220 px) — "POPÜLER" rozeti, **7 gün ücretsiz deneme** çubuğu, fallback ₺999,99, pasif "₺2.999,99 idi" referans çizgisi
- Yetki kimliği (entitlement): `'FormAI Pro'`
- Eski `_quarterly` / `_yearly` ID'leri ölü (otomatik bellek)

### 4.2 Paywall tetikleyici yüzeyleri (7 adet)
1. Onboarding sonrası (prediction CTA)
2. E-posta giriş sonrası
3. OAuth giriş sonrası
4. Bugünkü Görev kartı (Gün 4+)
5. Plan-detay gün döşemesi (Gün 4+)
6. Bölgesel/ekipman planı (kilit aç CTA)
7. Profil → "FormAI Premium" / Antrenman PRO rozeti

### 4.3 Faz 94 zorunlu auth kapısı
Anonim kullanıcılar paywall'da satın alma denediğinde **kapatılamayan** alt sayfa açılır (`barrierDismissible: false`); RevenueCat tarafında anonim satın alma engellenir. Tek-tetik kilidi (`_authGateShown`) yeniden tetiklemeyi önler.

### 4.4 Faz 95 dinamik fiyat
RC Offerings'tan `package.storeProduct.priceString` (locale-formatlı, ₺); yüklenirken skeleton; fallback yalnızca null paket çözümlendiğinde.

### 4.5 Yapısal tespitler
- Üst görünür alanda **3 etkileşimli yüzey:** ana CTA + restore + kapatma X.
- CTA çift kapılı: `_purchasesConfigured && offerings?.current != null`.
- Yıllık kart 220 px (diğerleri 180 px) — rozetin ötesinde görsel önceliklendirme.
- Yasal alt yazı **10.5pt @ 0.55 alfa** — küçük yazı.
- Bölgesel plan teaser'ı: egzersiz listesi %35 opaklığa düşürülüyor, başlık ve CTA tam parlak.

---

## 5. GÖRSEL DİL VE TASARIM SİSTEMİ

### 5.1 Renk paleti (kısaca)
- **Marka neon:** `#8E5BFF` (mor), `#4DA6FF` (mavi-mor), `#6A3DFF` (derin mor), `#00F0FF` (siber mavi), `#39FF14` (neon yeşil)
- **Anlamsal:** success `#22C55E`, danger `#FF4D6D`, orange `#F97316` / `#B45309` (Faz 53 WCAG AA), amber `#FFBA4D`, pink `#FF4DDB`
- **Karanlık yüzey:** `#0B0B12` arkaplan, `#0F0F14` kart yüzeyi
- **Açık yüzey (Faz 53):** `#F7F8FA` arkaplan, `#FFFFFF` kart, `#111118` ana metin, `#565B66` ikincil metin (5.07:1 kontrast)

### 5.2 Tipografi ve animasyon
Sistem fontları (Google Fonts ithal edilmiyor); Material 3 ColorScheme.fromSeed varsayılanları. **Lottie/Rive yok** — tüm animasyonlar Flutter native (`AnimationController`, `Tween`, `SlideTransition`, `FadeTransition`) + custom painter (analiz illüzyonu sweep ringi, alan grafiği, dalga formu çubukları) + shimmer (1400 ms). **Yalnızca Material Icons** kullanılıyor; Cupertino veya özel SVG yok.

### 5.3 Varlık envanteri
- `/photos/` (kök): 51 dosya (.webp + 1 PNG ikon) — Türkçe dosya adları
- `/photos/meals/`: 298 .webp tarif görseli (Faz 69)
- `/photos/workouts/`: 32 .webp plan küçük resmi (Faz 70)
- `/Beslenme-Photos/`: 15 .jpeg eski referans, **çalışma anında referans yok** (kullanılmıyor görünüyor)
- **Mağaza ekran görüntüleri repo'da gömülü değil** — `asosystem/` altında yalnızca prompt dosyaları var

---

## 6. ÇAPRAZ KESEN GÖZLEMLER

### 6.1 Veri akışı
Supabase tabloları: `exercises`, `recipes`, `user_progress`, `user_metrics`, `feedback` + rozet tablosu (kod içinde isim açık değil).

### 6.2 Tekrarlanan mantık
- Rozet tahminleri (predicate) Gelişim sekmesi + Badges ekranı arasında **çoğaltılmış** — tek noktadan yönetilmiyor.
- Streak hesabı Antrenman + Gelişim sekmelerinde paralel.

### 6.3 Anonim kullanıcı kurtarma
`auth.was_anonymous` bayrağı ayakta ama oturum silinmişse — sessizce **yeni anonim kullanıcı** oluşturulur; eski RLS kilitli verileri yetim kalır. Tasarımsal kabul edilen bir trade-off.

### 6.4 Workout akışı
Tap-başla → egzersiz başlangıcı arası **5 ekran** (hazırlık 3 sn → kamera → set arası dinlenme → seans tamamlama → dashboard'a dönüş). ML Kit BlazePose ~15 FPS ile (66 ms throttle + tek-uçuş kilidi termal koruma için). ~16 egzersiz-spesifik analiz servisi factory deseniyle dağıtılır.

---

## 7. MEVCUT DOKÜMANLARA İLİŞKİN NOT

Repo'da zaten 5+ strateji belgesi var: `MASTER_LAUNCH_ROADMAP.md`, `MONETIZATION_LAUNCH_GUIDE.md`, `PROJECT_DOCUMENTATION.md`, `ROADMAP.md`, `AI_CONTEXT_REPORT.md`, ayrıca kök dizinde `ASO_VISUAL_MASTERPLAN.md` (88 KB), `GOOGLE_PLAY_MASTERPLAN_TR.md` (64 KB), `PROGRESS_SECTION_MASTERPLAN.md` (97 KB), `STARTUP_FLOW_ANALYSIS.md` ve 3 release-hardening dokümanı.

Bu mevcut belgeler **kullanıcı tarafına yönelik strateji + sürüm artefaktları**dır. `/reports/` ağacı ise **UX araştırma çıktısı** olarak ayrı tutulmuştur ve mevcut belgelerle birlikte yaşamak üzere tasarlanmıştır — değiştirme amacı yoktur.

---

## 8. SONRAKİ FAZLARIN GİRDİSİ

| Faz | Ajanlar | Ana odak yüzeyleri | Bu haritadan girdiler |
|---|---|---|---|
| 2. Ürün Analizi | Ürün Yapısı + Görsel UI | tüm uygulama | §3, §5, §7 |
| 3. Psikoloji | Kullanıcı Psikolojisi + Fitness Davranış Bilimi | onboarding, dashboard, streak, paywall trial | §4, §5.6–5.7, §6.5 |
| 4. Pazar İstihbaratı | Rakip Analizi | dış (Freeletics, Hevy, Fitbod, Centr, BetterMe, NTC, vb.) | (iç haritaya gerek yok) |
| 5. UX Optimizasyonu | Veri-Odaklı UX + Mobil UX + **Dashboard İstihbaratı (öncelik)** | §5 (Gelişim) | §5, §6 |
| 6. Uygulanabilirlik | Mühendislik Doğrulama | Flutter stack uyumu | §1, §10, §11 |
| 7. Final Sentez | Strateji Birleştirici | hepsi | tümü |

Faz 1 **tamamlanmış ve kilitlidir.** Sonraki fazlarda yapısal harita çıkarılmaz; yalnızca bu belgeyle çelişki bulunduğunda erratum eklenir.

---

**FAZ 1 SONU — FAZ 2 İÇİN ONAY BEKLENMEKTEDIR.**
