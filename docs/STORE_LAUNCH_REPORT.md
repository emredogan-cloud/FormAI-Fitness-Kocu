# SixPack AI — Mağaza Yayını Stratejisi

**Versiyon:** 0.1.0+1
**Rapor Tarihi:** 2026-05-02
**Kapsam:** Play Store yayın hazırlığı için pazarlama, monetizasyon, mağaza görselleri ve rekabet analizi.

> **Bu doküman `ROADMAP.md`'nin tekrarı değildir.** Mühendislik launch blocker'ları (yasal sayfalar, RevenueCat anahtarları, Supabase RPC'leri, vb.) için kanonik referans `docs/ROADMAP.md` dosyasıdır — orada listelenen ⛔ Bölüm 1 kalemleri tamamlanmadan bu raporun hiçbir kısmı tek başına yayın için yeterli değildir.
>
> Bu rapor şu boşluğu doldurur: kod tarafı kapatıldıktan sonra **kullanıcıya görünen** tarafın (mağaza listing'i, paywall, ilk açılış deneyimi, rekabet farkları) sıkı denetimi.

---

## 0. Yönetici Özeti (PM için 60 saniye)

| Alan | Durum | Aksiyon |
|---|---|---|
| Kod sağlığı | Yeşil — `dart analyze lib/` temiz, 15/15 generator testi geçiyor | — |
| Hero görsel hizalama | **Faz 87'de düzeltildi** (bu commit'te) | Cihazda doğrula |
| Egzersiz video oynatma | **Player kodu sağlam**; tek tek video dosyaları için cihazda probe gerek | `bash scripts/diagnose_videos.sh` |
| Yasal sayfalar (Privacy/Terms) | ⛔ Henüz live değil | ROADMAP §1.2 |
| RevenueCat prod ürünleri | ⛔ Henüz oluşturulmadı | §6 + ROADMAP §1.4 |
| Mağaza görselleri | ❌ Üretilmedi | §5 + Midjourney promptları |
| Sentry/PostHog DSN | ⛔ `.env`'de boş | ROADMAP §1.1 |
| Rakip analizi | Bu raporda | §4 |

**Kritik yol:** ROADMAP §1 + bu raporun §5 (mağaza görselleri) + §6 (RevenueCat sandbox→prod migration) tamamlanmadan **soft launch'a bile gönderme**.

---

## 1. Play Store Red Flags

Aşağıdaki 11 risk Google Play submit reddinin veya yayın sonrası 1 yıldız spam'inin **en sık nedenleridir**. Tek tek doğrulama:

### 1.1 Crash senaryoları

- **Boş Supabase pool'u (offline cold start):** Şu an `WorkoutGenerator.generate30DayPlan` 30 dinlenme günü stub'u dönüyor — crash yok ama anlamsız UX. _Test:_ Uçak modu + ilk açılış. _İyileştirme:_ Boş pool'da "İnternet bağlantısını kontrol et" overlay'i; mevcut `BrandedMediaFallback` zaten retry CTA'sıyla genişletilebilir.
- **Onboarding ortasında çıkış/öldürme:** WizardState `SharedPreferences`'a yazılıyor mu? _Test:_ 3. adımda app'i kill, yeniden aç → kullanıcı baştan mı başlıyor yoksa kaldığı yerden mi?
- **Paywall'da network kesilmesi:** RevenueCat paket fetch başarısız olduğunda fallback paywall ayakta mı? (ROADMAP §1.6'ya göre kontrollü.)
- **Video player + boş URL:** Faz 76 düzeltmesinde kapatıldı (`ExerciseGuidePlayer` non-http path'leri reject edip `_FallbackTile`'a düşüyor).

### 1.2 Eksik / yanlış metadata

- **Privacy Policy URL:** Play Console → App content → Privacy policy alanı **zorunlu**. ROADMAP §1.2 maddesindeki `formai.app/privacy` canlı yayında değilse submit reddedilir.
- **Data Safety formu:** Hangi veriyi topladığını/işlediğini bildirmen lazım. Topladıkların: e-posta (auth), boy/kilo/yaş (onboarding), antrenman tamamlanma kayıtları (Supabase), Sentry crash trace'leri, PostHog event'leri. ROADMAP §1.3 ile beraber doldur.
- **Hedef kitle (Target audience):** Fitness app'ler için "13+" tipik. Çocuklara yönelik içerik yok beyanı.
- **Reklamlar:** Hayır beyanı; uygulamada reklam yok.
- **Açıklama metni:** 80 karakter kısa açıklama + 4000 karakter uzun açıklama. Kısa açıklama hooks olmalı: _"30 günde sıkı karın — kişisel AI antrenörünle"_ gibi.

### 1.3 Bozuk özellikler / boş ekranlar

- **Bölgeler chip'ine tıkla → boş plan listesi:** Faz 47B'nin `_ComingSoonNote` kart'ı "Premium ile aç" CTA'sıyla değerlendirilmiş, fakat reviewer Premium subscription'a girmeyi denemez. _Önlem:_ Reviewer için demo hesap (Play Console → App content → Sign-in info).
- **"Yakında" / placeholder copy'ler:** ROADMAP §2.3 maddesi bunları listeliyor; submit öncesi temizlenmeli.
- **"Sıfır içerik" durumu:** Henüz hiç tarif favoriye eklemediği bir kullanıcı favorites_screen'i açtığında ne görüyor? Boş state mesajı + örnek bir CTA olmalı.

### 1.4 Performans / ANR riski

- **İlk 30 günlük plan üretimi cold cache'te:** Supabase fetch + 30 gün plan üretimi = ~1-2 saniye. Phase 49 skeleton zaten orada; ANR riski yok ama loading overlay'in 2 sn'i geçmemesi için telemetri kur (PostHog event: `plan_generation_completed_seconds`).
- **Görsel asset boyutu:** Bu commit öncesi `photos/meals/` 699 MB idi (sahte WebP'ler). Faz 84 hotfix'i ile 64 MB'a düştü. APK boyutu için Android App Bundle (`flutter build appbundle`) kullan; Play Console install size indirimini Play Asset Delivery üzerinden yapar.
- **Video buffer süresi:** 3G/4G'de ilk video frame'i gelene kadar geçen süreyi PostHog'a logla (`video_first_frame_ms`); >3 sn ise ya Storage CDN'ini etkinleştir ya da düşük bitrate'li bir varyant üret.

### 1.5 Erişilebilirlik

- **Renk kontrastı:** Faz 53C/D ile temaya geçildi; light/dark her ikisi WCAG AA seviyesinde mi? Quick check: TalkBack'i aç → hero card "BAŞLA" butonu okunuyor mu?
- **Dinamik yazı boyutu:** Sistem font scale 1.4x'e alındığında card title taşma yapıyor mu?

---

## 2. Pre-launch Checklist (PM tek tek doğrulayacak)

Aşağıdaki liste yayından **48 saat önce** baştan sona yapılmalıdır. Madde başına ortalama süre 5-15 dk.

```text
[ ] Tüm metinler Türkçe + tutarlı sözlük (Sıkılaşmak / Hacim / Six-Pack)
[ ] Onboarding 1→sonuna kadar uçak modunda denenmiş
[ ] Onboarding sonrası app kill → yeniden aç → kaldığı yerden devam ediyor
[ ] İlk antrenman seansı: 1 gün × 5 egzersiz, video + kamera açılıyor
[ ] Antrenman ortasında telefon çağrısı simülasyonu → resume çalışıyor
[ ] Tüm 51 egzersiz video URL'sinin 200 döndüğünü doğrula:
        bash scripts/diagnose_videos.sh
[ ] Plan detail hero'su tüm 3 kaynak için tam genişlik render ediyor:
      - Dashboard "Günlük Meydan Okuma" kartından
      - Ekipmanlı Egzersizler strip'inden (7 kart)
      - Bölgeler listesinden (~24 plan)
[ ] Light + Dark tema her ekran için manuel geçiş
[ ] Paywall: sandbox satın al → entitlement aktif → "Programını Yenile"
    ile yeni içerikler kilitleri açılıyor
[ ] Paywall: restore purchases akışı (paid sandbox → sil → yeniden yükle)
[ ] Hesap sil (KVKK): delete_user RPC çağrılıyor, oturum kapanıyor
[ ] Profil → Goal değiştir (sixpack → bulk): plan otomatik
    yeniden üretiliyor (Faz 86 fingerprint cache invalidation)
[ ] App Bundle (.aab) Play Console'a yüklenip Internal Testing'de
    ≥1 cihazda gerçek test edildi
[ ] Play Console → App content → Privacy policy URL = canlı, 200 OK
[ ] Play Console → App content → Data safety = doldurulmuş
[ ] Play Console → Store listing → Screenshots = 4-6 adet (§5)
[ ] Sentry test event tetiklendi (Settings → "Test crash" gibi
    debug-only butonu kullan; release build'de gizle)
[ ] PostHog'da onboarding_completed eventi gelen veride var
```

---

## 3. Feature Improvements (yayın öncesi)

ROADMAP'in 🟡 Should-Do bölümü tüm bunları detaylandırıyor; aşağıda **kullanıcı algısı** açısından MUST-FIX olanları öne çıkardık:

1. **İlk seansta "Aha moment".** Şu an: kullanıcı onboarding'i bitirir, dashboard'u görür, "BAŞLA"ya tıklar, kameralı egzersiz ekranı açılır. _Eksik:_ İlk seansın sonunda "1. günü tamamladın — yarın 2. gün için seni bekliyoruz" tipi celebration overlay ve ilk push notification opt-in promptu. Retention'da D1→D2 dropoff'u yarıya indirir.

2. **Streak görselleştirmesi.** ROADMAP'te bahsi geçmiyor ama her fitness app'in temel retention loop'u: `Header'da güncel streak (3🔥) + en uzun streak (12) + bugünkü hedef`. Şu an streak hesaplanıyor (`_streakOf` antrenman_tab.dart:200) ama hero card'da görsel emphasis düşük.

3. **Onboarding'in son adımında "Programın hazırlanıyor..." mikroanimasyonu.** Algılanan değer artar; şu an direkt dashboard'a düşüyor. 1.5-2 sn animasyon + "Hedefin: Sıkılaşmak. Seviyeniz: Orta. Programın hazırlanıyor..." metni. Kod tarafı bedava — generator zaten kümülatif log'lar veriyor, sadece UI overlay eklenecek.

4. **"Bugün ne yiyeceğim?" beslenme dashboard kartı.** Mevcut `Beslenme` sekmesini biliyoruz ama kullanıcı dashboard'dan tek tıkla bugünün önerisini görmüyor. 2-3 öğün rotasyonu hero card'ın altına eklenebilir.

5. **Apple Watch / Android Wear teaser.** ROADMAP §3.3 launch sonrasına atılmış. Doğru karar — fakat mağaza listing'inde "Apple Watch desteği yakında" beyan etme; submit reddi olur. Sessiz bekle.

---

## 4. Rakip Analizi

### 4.1 Freeletics

**Güçlü tarafları:**
- AI antrenör persona'sı (named coach: "Coach") — duygusal bağ kuruyor.
- "Hell Week" gibi tematik challenge event'leri — virality.
- Video kalitesi yüksek (1080p, profesyonel set).
- Free trial + monthly + yearly — yıllık `~%55` indirim.

**Bizim hızlıca kopyalayabileceğimiz:**
- ✅ **AI antrenör adı/karakteri.** Bizim `_challengeTitleFor` zaten dinamik başlıklar üretiyor. Buna bir maskot/karakter eklemek = sadece copy + bir adet illustration. Önerilen: **"Aysu"** veya **"Demir"** (Türkçe persona).
- ✅ **Tematik challenge event'i.** Bayram öncesi "Bayrama 30 gün" özel program; mevcut 30-day program'ın yeniden brand'i.
- ⚠️ **Profesyonel video çekimi:** Maliyetli; launch sonrasına bırak.

### 4.2 Nike Training Club

**Güçlü tarafları:**
- Ücretsiz model (Nike marka değeri sayesinde) — biz bunu yapamayız.
- "Workout history" görseli mükemmel: takvim + ısı haritası.
- Ünlü antrenör cameo'ları (LeBron, Cristiano).

**Bizim hızlıca kopyalayabileceğimiz:**
- ✅ **30 günlük takvim + ısı haritası** dashboard'da. Şu an `_StickyRemainingHeader` "X gün kaldı" diyor; takvim grid'i çok daha güçlü.
- ⚠️ **Ücretsiz katman:** Bizim freemium şu an "ilk 7 gün free, sonrası premium" (`AppConstants.freeDayLimit`). Nike'la rekabet için 7 günü 14 güne çıkarma seçeneği A/B test'e değer (§6.3).

### 4.3 Fitify

**Güçlü tarafları:**
- Hızlı onboarding (3 adımda paywall).
- Body scan / before-after photo özelliği.
- Vücut bölgelerine göre kısa "10 minutes for X" özelleştirilmiş antrenmanlar.

**Bizim hızlıca kopyalayabileceğimiz:**
- ✅ **Before/after photo.** Faz 18'deki `defaultLeanPhotoUrl` / `defaultMuscularPhotoUrl` zaten "before/after" pozisyonlanmış. Eksik: **kullanıcının kendi before/after fotoğrafını yükleme** özelliği. ImagePicker zaten projede (`image_picker: ^1.2.x`).
- ✅ **"10 dakika için..." kısa antrenmanlar:** Mevcut `_pushLimitsTemplates` (artık `_equipmentTemplates`) bunun bir formu. Daha agresif — duration 10 dk olan tematik plan'lar.
- ⚠️ **Onboarding'i 3 adıma indirme:** Bizimki kaç adım? Wizard'ı say. >5 ise launch öncesi sıkıştır.

### 4.4 Fark Edilmesi Gereken Eksiğimiz

| Özellik | Freeletics | Nike | Fitify | SixPack AI |
|---|---|---|---|---|
| AI persona | ✅ | ❌ | ❌ | ⚠️ Title only |
| Streak görsel | ✅ | ✅ | ✅ | ⚠️ Hesaplı, görsel zayıf |
| Before/after foto | ❌ | ❌ | ✅ | ❌ |
| Sosyal/share | ✅ | ✅ | ❌ | ⚠️ Faz 54 partial |
| Beslenme entegre | ❌ | ❌ | ❌ | ✅ **Bizim avantajımız** |
| Türkçe içerik | ⚠️ Çeviri | ⚠️ Çeviri | ⚠️ Çeviri | ✅ **Bizim avantajımız** |
| AI form check (kamera) | ❌ | ❌ | ❌ | ✅ **Bizim avantajımız** |

**Pozisyonlama mesajı:** Türkiye'de **Türkçe + AI form check + entegre beslenme** üçlüsünü sunan tek app. Mağaza listing'i bunu öne çıkarmalı.

---

## 5. Mağaza Görsel Stratejisi

**Kısa cevap: EVET — özel görseller üretmeli.** Ekran görüntüsü = mağaza CVR'ının `~%60`'ını belirler.

### 5.1 Play Store ekran görüntüsü tipleri

Play Console **2-8 adet** screenshot kabul ediyor. Önerilen 6'lı set:

| # | Tür | Mesaj | Format |
|---|---|---|---|
| 1 | Hero / value prop | "30 günde sıkı karın — kişisel AI antrenörün cebinde" | Telefon mockup + dashboard ekranı |
| 2 | Feature: AI form check | "Kamerada hatalı formu yakalar" | Pose detection ekranı + örnek hata uyarısı |
| 3 | Feature: Plan üretimi | "Hedefine göre 30 gün, 30 farklı seans" | Plan listesi + checkmark animasyonu |
| 4 | Feature: Beslenme | "Tarif + makro hesabı tek uygulamada" | Beslenme sekmesi + favori tarif |
| 5 | Feature: Ekipmanlı / Bölge | "Her bölge için özel plan: Göğüs, Sırt, Bacak..." | Antrenman tab'ı + 7 ekipman kartı |
| 6 | Sosyal kanıt | "★ 4.7 — 'İlk haftada fark ettim'" | Kullanıcı testimonial overlay'i |

### 5.2 Layout standartları

- Telefon mockup: **Pixel 8 Pro** (Play Store'un default'u Pixel görünümünü öne çıkarıyor) — bireysel pencerelere 1080×1920.
- Üst banner: 60 px high, marka mor (`#6A3DFF`)→mavi (`#4DA6FF`) gradient.
- Üst banner copy: ekran başlığı (yukarıdaki "Mesaj" sütunu).
- Sağ alt köşeye küçük ikon (24×24): app launcher ikonunun monochrome versiyonu.
- Background: koyu (`#0F0A1F` gibi) → screenshot'ta ekran ışığı pop yapsın.

### 5.3 Midjourney prompt'ları (mağaza görselleri)

Aşağıdakiler **mağaza marketing materyalleri** için Midjourney v6 promptları. Apple Store / Play Store screenshot'larının ARKA PLANI olarak kullan; ön plana cihaz mockup'ı eklemek için ayrıca Figma / Photoshop bileşenleri gerekir.

#### Hero / value prop (#1)

```
Studio fitness photography, fit Turkish-Mediterranean man in dark grey
performance tee performing a focused crunch on a textured charcoal mat,
side profile, soft purple-to-blue gradient rim lighting, dark cinematic
gym background with subtle bokeh, clean negative space on the right for
phone mockup overlay, professional 4K, --ar 9:16 --style raw
```

#### Feature: AI form check (#2)

```
Editorial split-screen fitness photography, athlete performing a squat
with red overlay highlighting incorrect knee tracking on the left frame,
green overlay confirming corrected form on the right frame, neon cyan
body-keypoint dots, dark moody gym background, minimal text-safe negative
space at the top, professional 4K, --ar 9:16 --style raw
```

#### Feature: Plan üretimi (#3)

```
Conceptual fitness illustration, calendar grid floating in zero-gravity
with 30 day-cells, some cells marked with checkmarks glowing in neon
green, others rendered as muscular silhouettes, dark navy background with
subtle aurora-purple light leaks, minimal flat-design style with cinematic
depth, --ar 9:16 --style raw
```

#### Feature: Beslenme (#4)

```
Top-down food photography, vibrant Mediterranean breakfast plate with
labneh, olives, cherry tomatoes, whole-wheat bread, and avocado, on a
matte dark wood surface, soft window light from the upper-left, small
floating macro-nutrient circular badges (P 28g · C 32g · F 14g) overlaid
in neon-cyan, professional editorial 4K, --ar 9:16 --style raw
```

#### Feature: Ekipmanlı strip (#5)

```
Stylized fitness collage, 7 muscular body-region silhouettes (chest, back,
shoulder, biceps, triceps, leg, abs) arranged in a 2x4 grid with one
empty slot, each silhouette glowing in a distinct neon colour from the
SixPack AI brand palette (purple, cyan, magenta, lime, gold, pink,
electric blue), dark gradient background, futuristic UI feel, --ar 9:16
--style raw
```

#### Sosyal kanıt (#6)

```
Authentic candid fitness photography, real-feeling Turkish woman in her
30s celebrating after a workout, sweat sheen, gentle smile of
accomplishment, dark home gym with warm ambient light, slight motion
blur on the background, no logos, clean negative space at the bottom-right
for testimonial card overlay, professional 4K, --ar 9:16 --style raw
```

#### Before/after (Feature Graphic — 1024×500)

```
Editorial before-after fitness photography, single Turkish-Mediterranean
man split vertically: lean physique on the left, defined muscular
physique on the right, identical pose and lighting, dark studio
background with subtle vertical light strips between the two halves,
neon purple-to-blue gradient line dividing the panels, clean negative
space at top for headline overlay, professional 4K, --ar 1024:500
--style raw
```

> Üretim notu: Midjourney çıktısını Photoshop / Figma'da telefon mockup overlay'i ve banner copy ile birleştir. Sadece arka plan AI tarafından üretilir; cihaz çerçevesi ve copy elle eklenir, böylece reviewer "AI-generated screenshot" gibi bir sebeple reddedemez.

### 5.4 Feature Graphic (1024×500)

Play Store listing'in en üst banner'ı. Yukarıdaki son prompt + üzerine telefon mockup + slogan:
- **Slogan:** "30 GÜNDE FARK YARAT — KİŞİSEL AI ANTRENÖRÜN"
- **Sub-slogan:** "Kamerada form düzeltme · Türkçe · Beslenme entegre"

---

## 6. Revenue Strategy — RevenueCat

### 6.1 RevenueCat nedir, neden kullanıyoruz?

**RevenueCat = subscription/IAP yönetim servisi.** Apple StoreKit + Google Play Billing'i tek API arkasında topluyor. Bizim açımızdan kazandırdıkları:

- **Receipt validation backend.** Apple/Google'dan dönen makbuzu doğrulayıp `is_active`/`expires_at` bilgisi tutar — bizim Supabase üzerinde bu mantığı yazmamıza gerek kalmaz.
- **Cross-platform entitlement.** iOS'ta Apple Pay ile alan kullanıcı Android'e geçtiğinde aynı abonelik aktif (`pro` entitlement).
- **Pricing experiments.** Aynı paketi birden fazla price point'le test etme (A/B).
- **Dashboard.** Aktif abone sayısı, churn, retention, MRR — Apple Connect / Play Console'a girmeden tek pencerede.
- **Webhook'lar.** Trial-to-paid, cancellation, billing issue → backend'e push notification + Sentry/PostHog event.

**Maliyet:** Aylık MTR (Monthly Tracked Revenue) <\$10K → ücretsiz. Üstü %1.

### 6.2 Subscription paketleri

**Önerilen yapı (3 SKU):**

| SKU ID | Süre | Fiyat (TR) | Trial | Hedef segment |
|---|---|---|---|---|
| `sixpack_weekly_basic` | 1 hafta | ₺79 | Yok | Fiyat bilince meraklı |
| `sixpack_monthly_pro` | 1 ay | ₺199 | 7 gün | Çoğunluk — varsayılan vurgu |
| `sixpack_yearly_pro` | 1 yıl | ₺1,499 (~₺125/ay, %38 indirim) | 7 gün | High-LTV |

**Neden weekly de var?** Türkiye'de düşük gelir grubunda haftalık satın alma davranışı yaygın; yıllık paket çok yüksek bir taahhüt olarak algılanıyor. Weekly paket "öncelik geçidi" olarak çalışır — kullanıcı 2-3 hafta abone olduktan sonra yıllık'a upgrade etme oranı yüksek.

**Trial stratejisi:**
- Weekly'de trial yok (zaten fiyatı düşük, riski az).
- Monthly + yearly'de **7 gün ücretsiz**. Apple/Google kuralı: trial bitiminin 24 saat öncesinde "Trial bitiyor — iptal etmek için" push tetikle.

### 6.3 Freemium / paywall timing

**Mevcut durum (`AppConstants.freeDayLimit = 7`):** 30 günlük programın ilk 7 günü ücretsiz; 8. günden itibaren her gün karşılığında paywall açılıyor. **Bu doğru bir başlangıç.**

**A/B test fikirleri (RevenueCat Experiments + PostHog):**

| Test | Variant A | Variant B | Hipotez |
|---|---|---|---|
| Free day count | 7 (mevcut) | 14 | 14 günde habit oluşma → conversion x1.3 |
| Paywall timing | Day 8'de hard | Day 8'de soft + day 10'da hard | Soft paywall'ın sürtünmesi düşük; conversion +%15 |
| Default plan vurgusu | Yearly | Monthly | TR pazarında yıllık yüksek bariyer; monthly default → trial uptake +%20 |
| Trial uzunluğu | 7 gün | 3 gün | 3 gün trial-to-paid'ı %25 artırabilir |

**Önerilen ilk test:** Default plan vurgusu (yearly→monthly). Bizim mevcut paywall'ımız hangi paketi öne çıkarıyor? `lib/features/monetization/` içine bakıp doğrula; gerekirse RevenueCat Experiments üzerinden değiştir (kod redeploy gerekmez).

### 6.4 Dev → Production migration plan

ROADMAP §1.4 zaten manual checklist veriyor; aşağıda **adım sırası** önemli:

1. **(PM)** Google Play Console'da 3 SKU'yu **ürün** olarak oluştur (Active state).
2. **(PM)** RevenueCat dashboard → Project → Products → 3 ürünü Apple/Google ile bind et.
3. **(PM)** RevenueCat → Entitlements → `pro` adında bir entitlement aç. 3 ürünü bu entitlement'a bağla.
4. **(PM)** RevenueCat → Project Settings → API Keys → **Production** Android key'ini kopyala.
5. **(PM)** `.env` dosyasında `REVENUECAT_ANDROID_KEY=<prod_key>` (sandbox key'in üzerine yaz).
6. **(Dev)** Android release build → internal testing track → 5+ kullanıcıya dağıt.
7. **(Test)** Sandbox satın alma akışını gerçekten dene:
   - Yeni hesap oluştur (öncesinde test edilmemiş Google hesabı).
   - Trial başlat → entitlement aktif → Premium içerik açılıyor.
   - Trial iptal → 24 saat sonra entitlement düşüyor.
   - Restore purchases → entitlement geri geliyor.
8. **(Prod)** Tüm test maddeleri yeşilse Production track'e gönder.

**Sandbox → Production geçişi sırasında kaçınılması gereken hatalar:**
- ❌ Sandbox key ile prod build çıkma (RevenueCat dashboard'da "Sandbox" işareti tüm transaction'larda görünür → Apple/Google reviewer dikkatini çeker).
- ❌ Prod'da product ID yazım hatası (`sixpack_monthy_pro` gibi typo) → app store reviewer "Product not found" hatası alır.
- ❌ Trial period uyumsuzluğu (Apple'da 7 gün, Google'da 3 gün ayarlama) → cross-platform entitlement bug'ı.

---

## 7. Roadmap Analizi (cross-reference)

> Tam denetim raporu `docs/ROADMAP.md` içinde. Aşağıda sadece bu mağaza yayını perspektifinden **bitirilmemiş** kalemleri özetliyoruz, çift dokümantasyon önlenir.

### 7.1 ROADMAP'ten bu rapor için yorumlanacak başlıklar

- **§1.1 (Production .env):** Sentry/PostHog DSN ve RevenueCat prod anahtarları olmadan §6'daki RevenueCat setup eksik kalır. **Bu raporun ön koşulu.**
- **§1.2 (Yasal sayfalar):** Privacy Policy URL = Play Console submit'in zorunlu alanı (§1.2 red flag).
- **§1.3 (Data Safety):** Bu raporun §1.2 kontrol listesinde tekrar listelendi — aynı maddedir.
- **§1.4 (RevenueCat prod ürünleri):** Bu raporun §6.4'te detaylandı.
- **§1.5 (Supabase prod SQL apply):** `delete_user`, `redeem_referral`, `feedback` table — submit edilebilir ama "Hesabımı sil" maddesi çalışmazsa Apple Guideline 5.1.1(v) reddi olur.
- **§2.3 ("Yakında" placeholder'ları):** Bu raporun §1.3'te tekrar gündemde — submit reviewer "broken / under construction screens" red flag'i.

### 7.2 Bu rapordan ROADMAP'e geri eklenmesi önerilen başlıklar

ROADMAP'i değiştirmiyoruz (kullanıcı talimatı), fakat aşağıdakiler bir sonraki ROADMAP revizyonunda değerlendirilmeli:

- Streak görsel iyileştirmesi (§3 madde 2) — mevcut ROADMAP'te yok.
- AI persona / antrenör karakteri (§4.1) — yeni başlık.
- Before/after photo özelliği (§4.3 / Fitify benchmark) — yeni başlık.
- A/B test backbone (RevenueCat Experiments + PostHog correlation) — §6.3.
- "Aha moment" celebration overlay (§3 madde 1).
- Onboarding "plan hazırlanıyor" mikroanimasyonu (§3 madde 3).

---

## 8. Ek Öneriler (analytics, retention, notifications, habit loops)

### 8.1 Analytics — minimum viable event seti

PostHog event taksonomisi (kebab-case zorunlu, snake_case alan adları):

```text
onboarding_started
onboarding_step_completed     { step: 'goal' | 'physique' | 'level' | ... }
onboarding_completed          { duration_seconds, dropoff_step }
plan_generated                { goal, level, pool_size }
day_started                   { day_number, exercise_count }
exercise_completed            { slug, set_number, reps_or_seconds }
day_completed                 { day_number, total_seconds, ai_corrections_count }
streak_milestone_reached      { streak_days: 3 | 7 | 14 | 30 }
paywall_shown                 { trigger: 'day_8' | 'plan_locked' | ... }
paywall_dismissed             { duration_seconds }
trial_started                 { sku }
purchase_succeeded            { sku, price_local, currency }
account_deleted               (KVKK)
```

Conversion funnel: `onboarding_started → onboarding_completed → day_started → day_completed (D1) → day_completed (D7) → trial_started → purchase_succeeded`.

### 8.2 Retention — habit loop tasarımı

Her başarılı fitness app'in özünde **3 katmanlı habit loop** var:

1. **Trigger** — push notification (sabah 8'de "Bugün 12. günün, 5 egzersiz seni bekliyor")
2. **Action** — antrenman ekranını aç + ilk reps'i yap (sürtünme < 5 saniye olmalı)
3. **Reward** — gün tamamlama animasyonu + streak +1 + "yarın için hatırlatıcı kuruldu" toast

**Bizdeki mevcut implementasyon:**
- Trigger: ✅ Faz 52 streak warning notification + Faz 58 akıllı bildirim
- Action: ⚠️ Antrenman ekranı açılış süresi kalibre edilmedi (cold start ölçülmedi — ROADMAP §2.5)
- Reward: ⚠️ Mevcut SessionCompleteOverlay sade, "celebration" hissi düşük

**Önerilen iyileştirme:** Day completion overlay'a **streak emoji burst** + "yarın için 24 saat sonra" özelleştirilmiş push notif setup'ı (mevcut altyapı zaten var).

### 8.3 Push notification stratejisi

Mevcut altyapı: `lib/core/services/notification_service.dart`. ROADMAP Faz 52 + 58 referansları. Eksik öneriler:

| Notification | Tetikleyici | İçerik | Öncelik |
|---|---|---|---|
| Hatırlatıcı | Her gün 18:00 | "Bugün 12. gün — 18 dakikada bitirebilirsin." | P0 |
| Streak risk | Gün geçti, antrenman yapılmadı | "Streak'ini kaybetmek üzere — son 4 saat." | P0 |
| Trial bitiş | Trial bitimi - 24 saat | "Yarın trial bitiyor. Premium'u dene veya iptal et." | P1 |
| Comeback | 3 gün dropoff | "Seni özledik. Bugün 15 dakikada başla." | P1 |
| Yeni içerik | Haftalık | "Bu hafta 3 yeni Ekipmanlı plan eklendi" (içerik geldikçe) | P2 |
| Sosyal proof | Aylık | "Bu hafta 1.247 kişi seninle aynı programı tamamladı." | P2 |

**Sıklık tavanı:** Haftada en fazla 5. Aşılırsa kullanıcı opt-out ediyor → push notif kanalı tamamen ölü.

### 8.4 Habit micro-design

- **Streak grace period.** Kullanıcı bir günü kaçırırsa **1 günlük "free pass"** hakkı (haftada 1) ver. Streak korunur, kullanıcı "battım, baştan başlayayım" demez. Implementasyon: `markDayCompleted` içine "if missed_yesterday and grace_used_this_week == false → skip rest day insert".
- **Milestone unlock.** 7 günlük streak'te bir badge animasyonu + paylaşılabilir story görseli (Faz 54'ün referral altyapısı yarım — birinin tamamlanması bunu unlock'lar).
- **"Sosyal kanıt counter" header'da.** "12.847 kişi şu an antrenman yapıyor" canlı sayaç (PostHog session count'undan beslenecek). Marketing açıdan güçlü.

### 8.5 Analytics → Privacy çakışması (Türkiye/KVKK)

- PostHog'da kullanıcı ID'si **e-posta değil**, Supabase auth UUID olmalı. ROADMAP §1.3 + Data Safety formu doldururken bunu beyan et.
- Sentry breadcrumb'ları PII içermiyor mu? `AppLogger.error` çağrılarında `data: {'email': ...}` olmadığını doğrula (grep'le hızlıca tara).

---

## 9. Yayın Karar Matrisi

| Kontrol | Ağırlık | Durum | Action owner |
|---|---|---|---|
| ROADMAP §1.1-1.7 (kod tarafı blocker) | ⛔ Zorunlu | Bekleyen | PM |
| Bu raporun §1 (red flags) audit | 🔴 Yüksek | Manual review | PM + Dev |
| Mağaza görselleri (§5) | 🔴 Yüksek | Üretilmedi | Designer + PM |
| RevenueCat sandbox→prod (§6.4) | 🔴 Yüksek | Bekleyen | PM |
| Pre-launch checklist (§2) | 🟡 Orta | Bekleyen | PM (48h önce) |
| Rakip pozisyonlama mesajı (§4.4) | 🟡 Orta | Net değil | PM (listing copy) |
| Push notification stratejisi (§8.3) | 🟡 Orta | Altyapı var, copy eksik | Dev + Designer |
| Analytics event seti (§8.1) | 🟢 Düşük | Eksiklikler tolere edilir | Dev (post-launch) |

**GO koşulu:** ⛔ + 🔴 satırlarının tümü yeşil. 🟡'lar kabul edilebilir kalemler — soft launch'la kapatılabilir.

---

## 10. Hatırlatma

- Bu rapor **stratejik** bir doküman; tek başına yayın için yeterli değildir. ROADMAP.md mühendislik blocker'larının kanonik referansıdır.
- Mağaza görselleri için Midjourney prompt'ları (§5.3) **arka plan üretimi içindir**; cihaz mockup ve copy elle eklenir.
- RevenueCat fiyatları (§6.2) Türkiye pazarına göre önerildi — Apple/Google reviewer ülke bazında fiyatlandırma esnekliği veriyor; rekabet analizini final vermeden önce Sensor Tower / data.ai gibi bir araçla cross-check yap.
- A/B test fikirleri (§6.3) sadece RevenueCat'in **paid** tier'ında çalışır — soft launch sonrası MTR \$10K'i geçtiğinde aktive olur. İlk 6 ayda statik fiyatlandırma yeterli.
