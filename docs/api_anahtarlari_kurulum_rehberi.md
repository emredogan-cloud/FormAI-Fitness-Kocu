# API Anahtarları Kurulum Rehberi

**Sürüm:** 1.0
**Tarih:** 2026-05-04
**Hedef Kitle:** Project Manager (PM)
**Amaç:** `.env` dosyasındaki production anahtarlarını (`SENTRY_DSN`, `POSTHOG_API_KEY`, `POSTHOG_HOST`, `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`) sıfırdan üretmek için tıklama-tıklama tarif.
**Kapsam:** ROADMAP §1.1 — Faz 84 (Production `.env` Provisioning).

---

## 0. Başlamadan Önce — Dikkat Et

1. **Repo'daki `.env` dosyasını ASLA git'e commit'leme.** `.gitignore` zaten engelliyor olmalı, ama her dolduruş sonrası `git status` ile kontrol et.
2. Anahtarları **Slack/Discord/email** üzerinden plain-text gönderme — gerekirse 1Password / Bitwarden secure note kullan.
3. Tüm dashboard'larda **iki faktörlü doğrulamayı (2FA)** aç. Production anahtarı barındıran hesaplara TOTP olmadan girilebilir olmamalı.
4. `.env` dosyasını dolduruken **çift tırnak** kullan: `SENTRY_DSN="https://..."` (boşluk veya `?` içeren değerler tırnak olmadan parse hatası verir).
5. Anahtarı kopyaladıktan sonra **bir kez bile** ekranda göründüğünde silinmiş kabul et — bazı dashboard'lar (özellikle RevenueCat secret keys) anahtarı **yalnızca tek seferlik** gösterir.

---

## 1. SENTRY_DSN — Hata Telemetrisi

**Ne işe yarıyor?** Crash + exception toplama. Faz 42'de eklendi. Boş bırakırsan uygulama çalışır ama production'daki crash'leri göremezsin.

**Not:** Bu anahtar repo'daki `.env` içinde halihazırda dolu görünüyor (`https://80384be98f1fae8a96633f71beb9b9f3@o4511297850834944.ingest.de.sentry.io/4511297853128785`). Yine de **sıfırdan yeni proje açmak** istersen veya anahtar rotasyonu gerekirse aşağıdaki adımları uygula.

### 1.1 Sentry hesabı + projesi oluştur

1. Tarayıcıda **https://sentry.io/signup/** adresine git.
2. "Sign up with Google" / "Sign up with GitHub" / email seç. (Tavsiye: organizasyon hesabı için ayrı bir email — örn. `dev@formai.app`.)
3. İlk oturumda Sentry sana **organization slug** soracak. Örn: `formai`. (Bu URL'de görünecek: `formai.sentry.io`.)
4. "Choose your data center" sorusunda **EU (Frankfurt)** seç — KVKK ve GDPR uyumu için tercih edilen seçenek. (US seçersen DSN `ingest.us.sentry.io`, EU seçersen `ingest.de.sentry.io` olur. Mevcut `.env` zaten `de.sentry.io` kullanıyor.)
5. "Create your first project" ekranında:
   - **Platform:** "Flutter" ara, seç.
   - **Alert frequency:** "Alert me on every new issue" (default).
   - **Project name:** `formai-flutter` (veya `sixpack-ai-flutter`).
   - **Team:** default team `#formai` veya `#sixpack-ai`.
   - "Create Project" butonuna bas.

### 1.2 DSN'i bul + kopyala

Sentry seni doğrudan onboarding ekranına atar. Burada Flutter SDK kurulum talimatları var; içinde `Sentry.init(...)` örneği gösteriyor — DSN o örnek içinde.

**Onboarding'i kapattıysan elle bul:**

1. Sol kenar çubuğundan **Settings** (en altta, ⚙️ dişli ikonu) → tıkla.
2. Sol panelden **Projects** → tıkla.
3. Liste içinden **`formai-flutter`** projesine tıkla.
4. Sol panelden **Client Keys (DSN)** → tıkla.
5. Açılan sayfada "DSN" başlığı altında bir URL göreceksin:
   ```
   https://<HASH>@o<ORG_ID>.ingest.de.sentry.io/<PROJECT_ID>
   ```
6. Sağdaki **kopyala** ikonuna bas.

### 1.3 `.env`'e yaz

```env
SENTRY_DSN="https://<HASH>@o<ORG_ID>.ingest.de.sentry.io/<PROJECT_ID>"
```

> **Doğrulama:** Uygulamayı release modda aç, deliberately bir crash tetikle (örn. ayarlar sayfasında debug butonu varsa). 1-2 dakika sonra Sentry → **Issues** sekmesinde crash'i görmelisin.

---

## 2. POSTHOG_API_KEY + POSTHOG_HOST — Ürün Analitiği

**Ne işe yarıyor?** Funnel + retention + feature usage tracking. Faz 42'de eklendi. Boş bırakırsan aktivasyon/dropoff metriklerini hiç göremezsin.

**Not:** Repo'daki `.env` halihazırda `phc_qPggVXvjyHLL93LhjSuiKHdsF2YaYSMfwKXQ5vSDqX9c` ve `https://us.posthog.com` ile dolu. Sıfırdan kurulum için aşağıdaki adımları uygula; yoksa mevcut anahtarın doğru host ile eşleştiğini (US/EU) kontrol et.

### 2.1 PostHog hesabı + projesi oluştur

1. Tarayıcıda **https://posthog.com/signup** adresine git.
2. **KRITIK ADIM — Region seçimi:** "Where would you like to host your data?" sorusu çıkar:
   - **🇺🇸 United States (US Cloud)** → host `https://us.posthog.com`
   - **🇪🇺 European Union (EU Cloud)** → host `https://eu.posthog.com`
   - KVKK uyumu için **EU** öner; ancak mevcut `.env` US'i kullanıyor, projeyi yeniden açıyorsan tutarlı kal.
3. Email + şifre ile kaydol. Email'i doğrula.
4. İlk girişte "Create your organization" ekranında:
   - **Organization name:** `FormAI` (veya `SixPack AI`).
   - "Create" butonuna bas.
5. Sonra "Create your first project" ekranında:
   - **Project name:** `FormAI Production`.
   - "Create project" butonuna bas.

### 2.2 Project API Key'i bul + kopyala

1. Sol kenar çubuğunun **en altında** profil avatarın var. Onun **hemen üstünde** (alt kısımda) ⚙️ **Settings** ikonu → tıkla.
   - Alternatif yol: Sol üstten proje adına tıkla → "Project settings" seç.
2. Açılan ayarlar sayfasında, sol panelden **Project** kategorisi → **General** sekmesinde olmalısın.
3. Sayfayı azıcık kaydır; **"Project API Key"** kutusunu göreceksin. Değer şu formatta:
   ```
   phc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
4. Sağdaki **kopyala** ikonuna bas.

> **⚠️ DİKKAT:** PostHog'ta iki tür anahtar vardır:
> - **Project API Key** (`phc_…` ile başlar) → mobil/web client'larda kullanılır, **bunu kullan**.
> - **Personal API Key** (`phx_…` ile başlar) → admin/script kullanımı için, **bunu KULLANMA**.

### 2.3 Host URL'sini doğrula

Adım 2.1'de seçtiğin region'a göre:
- **US Cloud seçtiysen** → `POSTHOG_HOST="https://us.posthog.com"`
- **EU Cloud seçtiysen** → `POSTHOG_HOST="https://eu.posthog.com"`

> **Eski referans:** Bazı eski PostHog dokümanlarında `https://app.posthog.com` host'u görünür — bu artık **deprecated**. PostHog Mart 2024'te US ve EU cloud'larını ayırdı; yeni hesaplarda `app.posthog.com` redirect ile çalışsa da tavsiye edilen, region-spesifik host kullanmaktır.

### 2.4 `.env`'e yaz

```env
POSTHOG_API_KEY="phc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
POSTHOG_HOST="https://us.posthog.com"   # veya https://eu.posthog.com
```

> **Doğrulama:** Uygulamayı debug modda aç, onboarding'i tamamla. PostHog → sol panelde **Activity** → **Live events** sekmesinde 30 saniye içinde event'lerin akmasını bekle (`$pageview`, `onboarding_step_completed` vb).

---

## 3. REVENUECAT_ANDROID_KEY + REVENUECAT_IOS_KEY — Abonelik Yönetimi

**Ne işe yarıyor?** Google Play / App Store abonelik akışları. Faz 45'te eklendi. Boş bırakırsan uygulama fallback hardcoded paywall'a düşer ve **gerçek satın alma çalışmaz**.

### 3.1 RevenueCat hesabı + projesi oluştur

1. Tarayıcıda **https://app.revenuecat.com/signup** adresine git.
2. Email + şifre ile kaydol. Email'i doğrula.
3. İlk girişte "Create your first project" ekranı:
   - **Project name:** `FormAI` (veya `SixPack AI`).
   - "Create Project" butonuna bas.

### 3.2 Android uygulamasını ekle ve API key al

1. Sol üstte proje adının yanındaki açılır menüde projenin seçili olduğundan emin ol.
2. Sol kenar çubuğunda **en altta** ⚙️ **Project Settings** → tıkla.
3. Açılan sayfada üst tab'lardan **"Apps"** sekmesi seçili olmalı. Değilse seç.
4. Sağ üstte **"+ New"** veya **"+ Add app"** butonuna bas.
5. Açılan modaldan **"Play Store"** seç (Android için).
6. Form:
   - **App name:** `FormAI Android`
   - **Google Play package name:** `com.formai.sixpack` (kodun beklediği bundle ID; `lib/features/monetization/providers/monetization_provider.dart` ile uyumlu).
   - **Service Account credentials JSON:** Şimdilik atlayabilirsin (purchase verification için sonra gerekecek). "Save" / "Add" bas.
7. App eklendikten sonra "Apps" listesinde **`FormAI Android`** satırına tıkla.
8. Sayfanın üst kısmında **"API keys"** veya **"Public API keys"** bölümünü göreceksin.
9. **"Public app-specific API key"** alanında değer şu formatta:
   ```
   goog_xxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
10. Sağdaki kopyala ikonuna bas. Bu **REVENUECAT_ANDROID_KEY**.

### 3.3 iOS uygulamasını ekle ve API key al (iOS yayını başladığında)

> **PM notu:** Şu an yalnızca Google Play hesabın olduğu için iOS adımını **launch sonrasına bırakabilirsin**. Kod, iOS API key boşsa fallback paywall'a düşüyor (hata vermiyor). Apple Developer hesabı açtıktan sonra geri dön.

1. **Project Settings → Apps → "+ Add app"** → **"App Store"** seç.
2. Form:
   - **App name:** `FormAI iOS`
   - **App Store bundle ID:** `com.formai.sixpack` (Android ile aynı).
   - "Save" / "Add" bas.
3. Eklenen app'e tıkla → **"Public app-specific API key"** alanını bul. Format:
   ```
   appl_xxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
4. Kopyala. Bu **REVENUECAT_IOS_KEY**.

### 3.4 `.env`'e yaz

```env
REVENUECAT_ANDROID_KEY="goog_xxxxxxxxxxxxxxxxxxxxxxxxxxx"
REVENUECAT_IOS_KEY="appl_xxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

iOS'i ertelediysen `REVENUECAT_IOS_KEY=` satırını **boş bırak** (silme — kod yokluğu kontrol ediyor):

```env
REVENUECAT_ANDROID_KEY="goog_xxxxxxxxxxxxxxxxxxxxxxxxxxx"
REVENUECAT_IOS_KEY=
```

---

## 4. ⚠️ KRİTİK — `.env.example`'daki İsim Tutarsızlığı

`.env.example` dosyası eski şablona ait ve **YANLIŞ** isim kullanıyor. Aşağıdaki tabloyu referans al:

| `.env.example`'daki YANLIŞ isim       | Kullanman gereken DOĞRU isim         | Neden?                                                                                                                                                  |
|---------------------------------------|-------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `REVENUECAT_APPLE_KEY`                | `REVENUECAT_IOS_KEY`                | `lib/features/monetization/providers/monetization_provider.dart:184` `dotenv.env['REVENUECAT_IOS_KEY']` okuyor. `APPLE_KEY` adıyla yazarsan kod **null** alır ve fallback paywall'a düşer. |
| `REVENUECAT_GOOGLE_KEY`               | `REVENUECAT_ANDROID_KEY`            | Aynı dosyada `:186` satırı `dotenv.env['REVENUECAT_ANDROID_KEY']` okuyor. `GOOGLE_KEY` adıyla yazarsan Android purchase çalışmaz.                       |

**Doğru `.env` blok şablonu (kopya-yapıştır için):**

```env
# Faz 42 — Gözlemlenebilirlik
SENTRY_DSN="https://<HASH>@oXXX.ingest.de.sentry.io/XXX"
POSTHOG_API_KEY="phc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
POSTHOG_HOST="https://us.posthog.com"

# Faz 45 — RevenueCat (DOĞRU isimler — .env.example yanıltıcı)
REVENUECAT_ANDROID_KEY="goog_xxxxxxxxxxxxxxxxxxxxxxxx"
REVENUECAT_IOS_KEY="appl_xxxxxxxxxxxxxxxxxxxxxxxx"
```

---

## 5. Doldurma Sonrası Doğrulama Checklist

`.env` doldurulduktan sonra **terminal'de** şunları çalıştır:

```bash
# 1. .env'in commit'lenmediğini garantile
git status   # ".env" listede GÖRÜNMEMELİ (çünkü .gitignore engelliyor)

# 2. Anahtarların yüklendiğini test et — debug build aç
flutter run --release   # release modu Sentry/PostHog'u tetikler
```

**Manuel kontroller (uygulama açıldıktan sonra):**

- [ ] Sentry → Issues sekmesinde 5 dakika içinde **deliberate test crash** görünüyor.
- [ ] PostHog → Live events'de `$pageview` event'leri akıyor.
- [ ] Internal Testing track'inde test cihazıyla `formai_pro_monthly` satın alma → paywall kapanıyor → `isProProvider == true`.
- [ ] Restore Purchases butonu çalışıyor.

---

## 6. Sorun Giderme

| Belirti                                                            | Olası Sebep                                              | Çözüm                                                                                                |
|--------------------------------------------------------------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| Uygulama açılırken `Could not initialize Sentry` log'u             | DSN format hatası, çift tırnak eksik                     | `.env`'de `SENTRY_DSN="https://..."` formatında çift tırnak kullan                                   |
| PostHog event'leri Live events'de görünmüyor                       | Yanlış `POSTHOG_HOST` (US key + EU host veya tersi)      | API key'i hangi region'da oluşturduğunu hatırla; host'u eşleştir                                     |
| Paywall fallback'a (hardcoded) düşüyor                             | RevenueCat key isimleri yanlış (APPLE_KEY/GOOGLE_KEY)    | İsimleri `REVENUECAT_IOS_KEY` / `REVENUECAT_ANDROID_KEY` olarak düzelt                               |
| Satın alma "There was an error" hatası veriyor                     | RevenueCat'te Google Play credentials JSON eklenmemiş    | RevenueCat → Apps → FormAI Android → Service Account JSON'unu Play Console'dan üret + yükle          |
| Restore Purchases boş dönüyor                                      | Test hesabıyla satın alma yapılmamış veya farklı app ID  | Bundle ID `com.formai.sixpack`'in hem Play Console hem RevenueCat'te aynı olduğunu doğrula           |

---

## 7. Sonraki Adımlar (PM Aksiyon Listesi)

1. ✅ Bu dokümanı oku.
2. ⏳ Yukarıdaki 1-3 numaralı adımları sırayla uygula → 3 anahtar üret.
3. ⏳ `.env` dosyasını yerelinde aç → Bölüm 4'teki şablonu kopya-yapıştır → değerleri doldur.
4. ⏳ Bölüm 5'teki doğrulama checklist'ini sırayla yürüt.
5. ⏳ Tüm checkbox'lar yeşilse → ROADMAP §1.4 (RevenueCat ürün konfigürasyonu) ve §1.5 (Supabase SQL apply) maddelerine geç.

---

**Bağlı doküman:** `docs/ROADMAP.md` §1.1 (Production `.env` doldurulması) — bu rehber o maddenin operasyonel uzantısıdır.
