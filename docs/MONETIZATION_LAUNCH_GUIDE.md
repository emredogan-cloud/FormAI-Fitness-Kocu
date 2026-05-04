# Monetization Launch Guide — Random Bir Kullanıcının Aboneliği Banka Hesabına Düşene Kadar Tüm Yol

**Sürüm:** 1.0
**Tarih:** 2026-05-04
**Hedef Kitle:** Project Manager (PM) — daha önce hiç Play Console / GCP / RevenueCat kurmamış varsayımı.
**Faz:** Phase 86 (Monetization Launch — Ödeme Akışı End-to-End).

---

## 0. Para Akışının Büyük Resmi (Önce Bu, Sonra Adımlar)

```
[Kullanıcı]
   │  (uygulama içi paywall'da "Yıllık" butonuna basar)
   ▼
[Google Play Billing]   ← Google kullanıcının kartından çeker, %15 komisyon keser
   │
   ▼
[RevenueCat]            ← Google'dan webhook alır: "Bu user 1 yıllık abone oldu"
   │                       Entitlement state'ini "FormAI Pro = active" yapar
   ▼
[Uygulama]              ← RevenueCat SDK paywall'u kapatır, isProProvider = true
   │
   ▼
[Google Merchant Account] ← Net tutar (kalan %85) burada birikir
   │
   ▼ (her ay otomatik payout)
[Senin Türk Bankan IBAN'ın] ← Para buraya yatar
```

**5 zorunlu kurulum fazı vardır:**

| Faz | Ne yapıyor? | Yapmazsan ne olur? |
|-----|-------------|---------------------|
| **A** | Play Developer hesabı + ödeme profili | Hiçbir uygulama yayınlayamazsın; ödeme alamazsın |
| **B** | App + ilk `.aab` upload (Closed Testing) | Google `com.emredogan.formai`'yi tanımaz |
| **C** | GCP Service Account + Play Developer API | RevenueCat ürün/satın-alma doğrulaması yapamaz |
| **D** | RevenueCat'e GCP JSON yükle + entitlement bağla | SDK satın almayı doğrulayamaz, paywall kapanmaz |
| **E** | Play Console'da abonelik ürünleri yarat | Paywall'da paket gözükmez, satın alma boş döner |

Aşağıda her fazın **tıklama-tıklama tarifi** var. Sırayla yap; bir öncekini tamamlamadan diğerine geçme.

---

## Faz A — Google Play Developer Hesabı + Ödeme Profili (Bank Wire)

> **Süre:** 1-3 gün (Google identity verification için bekleme dahil).
> **Ücret:** Tek seferlik **$25 USD** (yaklaşık ₺850 — kart üzerinden Google'a ödeme).
> **Önkoşul:** Şahsi veya şirket Google hesabı + geçerli kredi kartı + TC kimlik (bireysel) veya vergi levhası (şirket) + Türk banka IBAN'ın.

### A.1 Developer hesabı aç

1. Tarayıcıda **https://play.google.com/console/signup** adresine git.
2. Google hesabınla giriş yap (uzun vadeli proje sahibi olacak hesap — `emre30283@gmail.com` veya kurumsal `dev@formai.app` gibi).
3. **"Continue and accept the Google Play Developer Distribution Agreement"** sayfasında çıkacak iki seçenekten:
   - **An organization** (şirket — vergi levhası gerek)
   - **Yourself** (bireysel — TC kimlik yeterli)
   Birini seç. Daha sonra değiştirilemez. (Bireysel başlayıp sonra şirkete geçirmek istersen yeni hesap açman gerekir.)
4. Kimlik bilgilerini doldur:
   - **Public developer name** — Play Store'da app sayfasında "FormAI" altında görünecek isim. "FormAI" veya "FormAI Studio" yaz.
   - **Email**, **phone**, **address** — Google identity verification için.
5. **$25 USD kayıt ücretini** kredi kartınla öde. Ödeme onaylanınca Google sana 1-2 gün içinde **identity verification** maili gönderir; istenen belgeyi (TC kimlik fotoğrafı veya pasaport) Play Console üzerinden upload et. Onay genelde 24-48 saatte gelir.

### A.2 Ödeme profili (Payment profile) — Para alabilmek için ZORUNLU

> **Bu adım atlanırsa app yayınlanır ama bir kuruş bile bankaya geçmez.** Google'ın merchant account'u olmadan abonelik gelirleri "askıda" kalır.

1. **Play Console → Sol kenar çubuğu → Setup → Payments profile** (Türkçe arayüzde: "Ödeme profili"). Tıkla.
2. Açılan sayfada **"Set up a payments profile"** butonuna bas.
3. **Account type:** "Individual" (bireysel) veya "Business" (şirket) — Faz A.1'de seçtiğinle aynı olmalı.
4. **Name and address:** TC kimlik üzerindeki tam adın ve faturalandırma adresin (bireysel) veya şirket unvanı + vergi adresi.
5. **Tax information:**
   - **Bireysel:** TC kimlik no'nu vergi numarası olarak gir.
   - **Şirket:** Vergi numarasını ve vergi dairesini gir. Eğer KDV mükellefiyse "VAT/GST registered: Yes" seç.
6. **Bank account (en kritik adım):**
   - **Account holder name:** TC kimliğinde yazan adın (bireysel) veya şirket unvanı (şirket). Bankadaki hesap sahibi adıyla **byte-byte aynı** olmalı, yoksa wire reddolur.
   - **Bank name:** Türk bankan (Garanti BBVA, İş Bankası, Akbank vb.).
   - **SWIFT/BIC code:** Bankanın SWIFT kodu (Garanti = `TGBATRIS`, İş Bankası = `ISBKTRIS`, Akbank = `AKBKTRIS`, Yapı Kredi = `YAPITRIS`, Ziraat = `TCZBTR2A`). Şüphe varsa banka ile teyit et.
   - **IBAN:** TR ile başlayan 26 haneli IBAN'ın. Boşluksuz, kesintisiz yaz.
   - **Bank address:** Bankanın merkez şube adresi (Google internet üzerinden teyit ediyor; üst düzeyde Google'ın doğrulama servisi adresi otomatik bulur).
7. **Save** bas. Google sana birkaç gün içinde IBAN'a **küçük bir test deposit** (genelde 0.01–0.50 TRY arası) gönderir. **Bunu onaylamadan ödeme alamazsın.**
8. Test deposit geldiğinde (1-3 iş günü), **Payments profile → Verify deposit amount** ekranına dön ve gelen tutarı kuruş cinsinden yaz (örn. `0.27 TRY`). Onaylandıktan sonra hesabın "active" olur.

### A.3 Payout schedule (Ödeme takvimi) bilgisi

- Google ay sonunda biriken tutarı **takip eden ayın 15'inde** wire ile gönderir (eşik: $1 USD).
- Gelen tutar wire FX rate'i ile USD → TRY dönüştürülür (Garanti'de güne göre %0.5–2 spread).
- Türk bankan **swift mesajını** alıp parayı hesabına aktarır (1-2 iş günü).
- **İlk payout için 60+ gün bekleme** olabilir (Google'ın "first payment hold" politikası).

> **Vergi notu:** Bireysel developer'sın ve geliri yıllık beyanda gelir vergisine tabi olarak göster (serbest meslek değil; arızi gelir / ticari gelir, mali müşavirine danış). Şirket isen normal kurumlar vergisi + KDV (KDV genelde reverse-charge mekanizmasıyla Google'da kalır). Mali müşavir olmadan vergi tarafına dokunma.

---

## Faz B — Uygulama Yarat + İlk `.aab` Upload (Closed Testing)

> **Neden gerekli?** Play Console, `applicationId`'yi (`com.emredogan.formai`) **ancak bir AAB upload edilince** "tanır". Tanınmadan abonelik ürünü oluşturamazsın (Faz E için ön koşul). Closed Testing track'i en hızlı yol — production review beklemeden çalışır.

### B.1 Yeni app oluştur

1. **Play Console → Sol üstte "All apps" → "Create app"** butonu. Tıkla.
2. Form:
   - **App name:** `FormAI` (veya `FormAI — 30 Günde Karın Kası`).
   - **Default language:** `Turkish — tr-TR` (veya `English — en-US` eğer global hedefliyorsan; default'u sonra değiştirmek zor).
   - **App or game:** `App`.
   - **Free or paid:** `Free` (uygulamanın kendisi ücretsiz; abonelik in-app).
   - **Declarations:** "Developer Program Policies" + "US export laws" iki checkbox'ı işaretle.
3. **Create app** butonuna bas. App detay sayfasına yönlendirileceksin.

### B.1.5 Package Name Ownership Verification (Android Developer Identity)

> **Neden gerekli?** Google, `com.emredogan.formai` namespace'inin gerçekten sana ait olduğundan emin olmak ister. Bunu, Play Console'un sana verdiği özel bir kodu APK/AAB içine bir asset dosyası olarak gömüp upload etmenle doğrular. Bu adım atlanırsa Play Console "Package name verification pending" uyarısı verir ve hiçbir release yayınlatmaz.

> **Phase 87 not:** Bu repo'da bu adım zaten tamamlanmıştır (`android/app/src/main/assets/adi-registration.properties` dosyası mevcut). Future package name değişikliklerinde aynı flow tekrarlanır.

1. **Play Console → app → Setup → App integrity → Developer identity** ekranında "Verify package ownership" CTA'sı çıkar.
2. Google sana **tek satırlık bir verification snippet** gösterir (örn. `DB27CRRZGEI32AAAAAAAAAAAAAAAA`). Bu kodu kopyala.
3. Yerel projede dosyayı oluştur:
   ```bash
   mkdir -p android/app/src/main/assets
   echo -n "DB27CRRZGEI32AAAAAAAAAAAAAAAA" > android/app/src/main/assets/adi-registration.properties
   ```
   - Dosya adı **kesin olarak** `adi-registration.properties` olmalı (büyük/küçük harf önemli).
   - İçerik **sadece** snippet olmalı — extra newline veya boşluk **yok**.
4. Signed APK derle:
   ```bash
   flutter build apk --release
   # Çıktı: build/app/outputs/flutter-apk/app-release.apk
   ```
   - Eğer Google bu adımda **debug APK** kabul ediyorsa (bazı projelerde olur): `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`.
   - Release APK için `android/key.properties` + `upload-keystore.jks` hazır olmalı (Faz B.2 önkoşulu ile aynı).
5. Play Console'un Developer Identity ekranına dön → **"Upload signed APK"** butonu → derlenmiş APK'yı yükle.
6. Google APK içindeki `assets/adi-registration.properties` dosyasını okur, snippet'i doğrular ve "Package name verified ✓" rozeti verir. (1-5 dakika sürebilir.)
7. Doğrulama tamamlanınca Faz B.2'ye geç (`.aab` derle + Closed Testing upload).

### B.1.6 Skeleton APK — Eğer Verification APK 160 MB'ı Aşıyorsa (Phase 88)

> **Sorun:** Play Console'un Developer Identity ekranı upload edilen APK için **160 MB hard limit** uygular. FormAI'nin tam release APK'sı (~180 MB universal) bu sınırı aşar. Sebepler: 3 ABI native libs (~91 MB toplam), ML Kit pose modelleri (~12 MB), 64 MB meal görselleri, 7 MB workout görselleri.
>
> **Çözüm:** Sadece ownership verification için, geçici bir "skeleton" APK derle — verification snippet bundle edilmiş kalır, ağır asset'ler bundle dışı bırakılır, ABI başına bölünür. Bu APK Google'a sadece namespace ownership ispatlamak için yüklenir; **kullanıcılara dağıtılmaz, kalıcı release değildir**.

**Adımlar:**

1. **`pubspec.yaml`'da `flutter:` asset bloğunu geçici olarak yorum satırına çevir:**
   ```yaml
   #flutter:
    # uses-material-design: true
     #assets:
     #  - .env
      # - "photos/"
      # - "photos/meals/"
      # - "photos/workouts/"
   ```
   - `adi-registration.properties` dosyası `android/app/src/main/assets/` altında oturduğu için Flutter'ın `flutter:` asset bloğundan **bağımsız** olarak APK'ya gömülür (native Android assets path'i; `flutter_assets/`'tan ayrı). Yani bu dosya skeleton build'de de bundle'a girer.

2. **Split-per-ABI APK derle:**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release --split-per-abi
   # Çıktılar:
   # build/app/outputs/flutter-apk/app-arm64-v8a-release.apk     (~40-50 MB)
   # build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk   (~35-45 MB)
   # build/app/outputs/flutter-apk/app-x86_64-release.apk        (~45-55 MB)
   ```
   - **Universal APK yerine `--split-per-abi` kullanmak APK'yı ~3x küçültür** çünkü her APK sadece tek ABI native lib'i içerir (universal hepsini içerir).
   - Play Console'a **`app-arm64-v8a-release.apk`** yükle (modern Android cihazlarda en yaygın ABI).
   - Boyut hala 160 MB'ı aşıyorsa: `flutter build apk --debug --split-per-abi` ile debug build dene; debug APK genelde release'in yarısı boyutunda olur (Google verification step'i debug APK'yı bazen kabul eder).

3. **Doğrulama bitince, derhal pubspec.yaml'ı eski haline döndür:**
   ```bash
   git checkout pubspec.yaml
   ```
   - **🚨 KRİTİK:** Skeleton pubspec ile yapılan APK çalışmaz — `.env` yok, asset'ler yok, material-design font yok. Closed Testing veya production release **asla** skeleton pubspec ile derleme. Verification yeşil tik aldıktan sonra ilk iş pubspec'i revert + Faz B.2 ile **gerçek** `.aab`'yi derlemek.

### B.1.7 İmza Uyuşmazlığı (Signature Mismatch) Çözümü (Phase 89)

> **Hata mesajı:** Play Console verification adımında *"The uploaded APK has a different signature"* / *"İmza uyuşmazlığı"* uyarısı çıkar. Bu, APK'nın imzalandığı anahtarla Google'ın `com.emredogan.formai` için kayıt ettiği fingerprint **eşleşmiyor** demektir.

> **Yanlış refleks:** Yeni bir `upload-keystore.jks` üretmek. Bu **DURUMU KÖTÜLEŞTİRİR** — yeni keystore'un fingerprint'i de mevcut kayıtla eşleşmeyecek ve Google bir önceki upload key'i unutmayacağı için update push'lama yeteneğini **kalıcı olarak** kaybedebilirsin. Mevcut `android/app/upload-keystore.jks` (Phase 59C'de üretilmiş, alias `upload`, 2053'e kadar geçerli) korunur — silinmez, üzerine yazılmaz.

#### Sebep diagnoz akışı (sırayla çalıştır)

1. **Mevcut upload key fingerprint'ini al:**
   ```bash
   keytool -list -v -keystore android/app/upload-keystore.jks -storepass formai123 -alias upload | grep "SHA-256"
   ```
   Çıktı (örnek): `A4:0A:5F:81:5F:D9:EA:F5:DB:D9:D1:66:2E:A5:84:28:80:36:72:93:A6:AE:AE:49:9C:69:6D:3B:DF:F4:33:18`

2. **Debug key fingerprint'ini al** (Flutter `--debug` build'leri bunu kullanır):
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey | grep "SHA-256"
   ```

3. **Az önce derlenen APK'nın gerçekte hangi anahtarla imzalandığını gör:**
   ```bash
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep "SHA-256"
   ```

4. **Karşılaştır:**
   - APK fingerprint = adım 2 (debug key) → APK yanlışlıkla **debug build** olarak yapılmış. Çözüm: aşağıdaki "Force Clean Release Build" akışını çalıştır.
   - APK fingerprint = adım 1 (upload key) ama Google hala reddediyor → Google başka bir key kayıt etmiş. Çözüm: aşağıdaki "Path A — Upload Key Reset".

#### Force Clean Release Build (debug fallback'i elimine etmek için)

`android/app/build.gradle.kts:93-97` `key.properties` dosyası **olmadığında** debug imzaya düşer. Build environment'ında `key.properties` varlığını ve cache'i temizleyip yeniden derle:

```bash
# Proje kökünden çalıştır
ls -la android/key.properties      # var olmalı (gitignored)
ls -la android/app/upload-keystore.jks   # var olmalı (gitignored, 2728 bytes)

flutter clean
flutter pub get
flutter build apk --release --split-per-abi

# Doğrula — fingerprint adım 1 ile eşleşmeli
apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep "SHA-256"
```

Eşleşiyorsa Play Console'a `app-arm64-v8a-release.apk` yükle. Eşleşmiyorsa — `flutter doctor -v` çıktısını kontrol et, Gradle cache'i temizle (`cd android && ./gradlew clean`), tekrar build et.

#### Path A — Upload Key Reset (Google yanlış fingerprint kayıt etmişse)

> **Ne zaman uygula:** APK gerçekten upload key ile imzalanmış (adım 3 ↔ adım 1 eşleşti) ama Google hala "different signature" diyor. Bu, `com.emredogan.formai` paket adı altında daha önce **başka bir key** ile bir APK upload'lanmış demektir (eski test build, farklı makine, vb.). Google upload key'i namespace'e bağlar ve değişimi sadece resmi reset akışıyla kabul eder.

1. **Public certificate'i mevcut keystore'dan çıkar (PEM formatında):**
   ```bash
   keytool -export -rfc \
     -keystore android/app/upload-keystore.jks \
     -alias upload \
     -storepass formai123 \
     -file upload-cert.pem
   ```
   `upload-cert.pem` dosyası ~1-2 KB olur. **Bu public cert; private key değil — Google'a göndermek güvenlidir.**

2. **Play Console → app → Setup → App integrity → App signing → "Request upload key reset"** linkine tıkla.

3. Açılan formda **sebep** olarak "Lost or compromised key" değil, **"Other"** seç (henüz prod release yok, sadece verification mismatch). Açıklama: *"Phase 88 verification step uploaded a debug-signed APK by mistake; need to register the correct upload key."* (veya gerçek sebep ne ise.)

4. **`upload-cert.pem` dosyasını upload et.** Google 1-2 iş günü içinde reset onayı maili gönderir.

5. Onay geldikten sonra B.1.5/B.1.6'daki verification adımını **aynı `upload-keystore.jks`** ile tekrar yap — bu sefer Google fingerprint'i tanır ve "Package name verified ✓" verir.

> **🔒 Güvenlik notu:** `formai123` zayıf bir parola ve `key.properties` içinde plaintext olarak duruyor. Verification dansı için tolerans gösteriyoruz; **public release öncesi** parolayı 20+ karakter rastgele bir parolaya çevir (`keytool -storepasswd` + `keytool -keypasswd` + `key.properties` güncelleme). Aksi halde keystore yanlışlıkla leak olursa imza yetkisi kaybedilir.

### B.2 İlk `.aab` derle (yerel terminal)

> **Önkoşul:** Android keystore (`upload-keystore.jks`) hazır olmalı. Daha önce `flutter build appbundle --release` çıktın varsa bu adımı atla.

```bash
# Proje kökünden çalıştır
cd /home/emre/Downloads/SixPack-AI
flutter build appbundle --release
# Çıktı: build/app/outputs/bundle/release/app-release.aab
```

### B.3 Closed Testing track'e upload

1. **Play Console → app → sol kenar çubuğu → Test and release → Testing → Closed testing**.
2. Sağ üstte **"Create new track"** veya default `alpha` track'i kullan (default yeterli).
3. Track sayfasında **"Releases"** sekmesi → **"Create new release"** butonu.
4. Açılan sayfada:
   - **App bundles** kutusuna `app-release.aab` dosyasını sürükle-bırak (veya "Upload" butonu).
   - Upload bittikten sonra Google **"Signed by app integrity"** mesajı verir — Google Play App Signing'i kabul et (default).
   - **Release name:** Otomatik `1 (1.0.0)` çıkar; istersen `Phase 86 — first upload` yaz.
   - **Release notes:** Tek satır yeterli — "Initial closed testing release."
5. **Save → Review release → Start rollout to Closed testing** bas. Google review birkaç saatte tamamlanır (closed testing için review kısa).
6. **Testers** sekmesinde bir email listesi yarat (kendi gmail'in + 1-2 test cihazı). Bu adım yapılmazsa testers app'i indiremez.

### B.4 Doğrulama — `applicationId` Play Console'da görünüyor mu?

Upload bitince **app → Dashboard** sayfasının üstünde "Package name: `com.emredogan.formai`" yazısı görünmeli. Görünmüyorsa AAB'nin namespace'i yanlış demektir; `android/app/build.gradle.kts:31,50` kontrol et.

---

## Faz C — GCP Service Account (Server-to-Server Erişim)

> **Neden gerekli?** RevenueCat senin Play Console'una **kullanıcı parolası ile değil**, bir **Service Account JSON anahtarı** ile bağlanır. Google bu yöntemle "Play Developer API" üzerinden ürün doğrulama, abonelik durumu sorgulama vb. yapar. JSON anahtarı yüklenmeden RevenueCat tüm işlemleri "demo mode"da kalır.

### C.1 Google Cloud projesi yarat (yoksa)

1. **https://console.cloud.google.com/** adresine git, Play Developer hesabınla giriş yap.
2. Sol üstte **proje seçici** (header'da "Google Cloud" yazısının yanında) → **"NEW PROJECT"** butonu.
3. Form:
   - **Project name:** `FormAI Production`.
   - **Organization:** Yoksa "No organization" otomatik seçilir.
   - **Location:** Yoksa boş bırak.
4. **Create** bas. Proje oluşturulup üst-seçici bunu seçecek.

### C.2 Google Play Android Developer API'yi aç

1. Sol kenar çubuğu (≡ menu) → **APIs & Services → Library**.
2. Arama kutusuna `Google Play Android Developer API` yaz, ilk sonuca tıkla.
3. **Enable** butonuna bas. ~30 saniyede aktif olur.
4. (Aynı işlemi opsiyonel olarak `Google Play Developer Reporting API` için de yap — RevenueCat refund bilgisi için faydalı.)

### C.3 Service Account yarat

1. Sol kenar çubuğu → **IAM & Admin → Service Accounts**.
2. Üstte **"+ CREATE SERVICE ACCOUNT"** butonu.
3. Form 1 (Service account details):
   - **Service account name:** `revenuecat-play-bridge`
   - **Service account ID:** Otomatik oluşur (`revenuecat-play-bridge@formai-production.iam.gserviceaccount.com`).
   - **Description:** `Bridges RevenueCat ↔ Google Play Developer API for entitlement verification.`
   - **Create and continue** bas.
4. Form 2 (Grant this service account access to project): **Atla** — Play Console tarafında yetki vereceğiz, GCP IAM tarafında değil. **Continue** bas.
5. Form 3 (Grant users access to this service account): **Atla**. **Done** bas.
6. Service Accounts listesinde yeni hesabın görünmeli.

### C.4 JSON key oluştur

1. Listede **`revenuecat-play-bridge@…`** satırına tıkla.
2. Üst sekmelerden **KEYS** seç.
3. **ADD KEY → Create new key** butonu.
4. Modal'da **JSON** seçili (default). **Create** bas.
5. **Tarayıcı otomatik bir `.json` dosyası indirir.** Dosya adı: `formai-production-xxxxxxxx.json`.

> **🔒 GÜVENLİK:** Bu JSON dosyası **production private key** içerir. Asla:
> - Git repo'ya commit etme (yanlışlıkla bile).
> - Slack/email'de plain-text gönderme.
> - Public bir bilgisayarda açma.
>
> Yapılması gereken: 1Password / Bitwarden secure note olarak sakla; sadece RevenueCat dashboard'una upload et; lokal kopyayı upload sonrası SİL.

### C.5 Service Account'ı Play Console'a tanıt + Finance permission ver

> **Bu adım atlanırsa Service Account JSON yararsız** — GCP'de yaratılmış olsa bile Play Console "Bu account benim verilerime erişemez" der.

1. **Play Console → Sol kenar çubuğu → Users and permissions** (en altta, ⚙️ Setup grubu).
2. Üst sekmelerden **"Users"** seçili. **"Invite new users"** butonuna bas.
3. **Email address** kutusuna Faz C.3'te oluşan service account email'ini yapıştır:
   ```
   revenuecat-play-bridge@formai-production.iam.gserviceaccount.com
   ```
4. **Permissions** sekmesinde:
   - **App permissions** kategorisinden **FormAI**'yi seç (sadece bu app için yetki).
   - Aşağıdaki yetkileri **TIK ATLA** (RevenueCat tüm bunlara ihtiyaç duyar):
     - ✅ **View app information and download bulk reports (read-only)**
     - ✅ **View financial data, orders, and cancellation survey responses**
     - ✅ **Manage orders and subscriptions**
     - ✅ **Reply to reviews** (opsiyonel ama refund response için faydalı)
5. **Account permissions** kategorisinden hiçbir şey seçme — sadece app-level yetki yeter.
6. **Invite user** bas. Service account davet edildikten sonra "Pending" yazsa bile çalışır (insan olmadığı için davet kabul etmez; doğrudan aktif).

### C.6 Doğrulama

24 saat bekle (Google IAM cache propagasyonu). Sonra Faz D'ye geç. Erken denersen RevenueCat upload anında "Permission denied" hatası verir.

---

## Faz D — RevenueCat Wiring (JSON Upload + Entitlement Mapping)

> **Önkoşul:** RevenueCat hesabı ve `FormAI` projesi açık (Faz API_KEYS_SETUP_GUIDE Bölüm 3'e bak). Faz C tamamlanmış ve service account JSON dosyan elinde.

### D.1 Android app'i RevenueCat'e tanıt (zaten yapılmadıysa)

1. **https://app.revenuecat.com/** → giriş yap.
2. Sol üstte proje seçicide **`FormAI`** seçili.
3. Sol kenar çubuğu → ⚙️ **Project Settings → Apps** sekmesi.
4. Eğer Android app yoksa: **"+ New"** → **"Play Store"** seç.
5. Form:
   - **App name:** `FormAI Android`
   - **Google Play package name:** `com.emredogan.formai` (üretim `applicationId`'si — `android/app/build.gradle.kts:50`).
   - **Save** bas.

### D.2 Service Account JSON'u upload et

1. Az önce oluşturduğun (veya zaten var olan) `FormAI Android` app satırına tıkla.
2. Açılan sayfada **"Service Account Credentials"** veya **"Google Play Service Account"** başlıklı bir kutu görünür. İçinde **"Upload Credentials"** veya **"Choose File"** butonu.
3. Faz C.4'te indirdiğin `formai-production-xxxxxxxx.json` dosyasını seç → **Upload**.
4. RevenueCat 30-60 saniye içinde "Validating credentials…" sonrasında ya **yeşil tik (✓ Verified)** ya da kırmızı X gösterir.
   - **Yeşil:** Hazırsın. Faz D.3'e geç.
   - **Kırmızı:** En sık 3 sebep:
     - Google Play Android Developer API enabled değil (Faz C.2'ye dön).
     - Service Account Play Console'a invite edilmemiş veya finance permission yok (Faz C.5'e dön).
     - 24 saat propagasyon süresi geçmemiş — yarın tekrar dene.
5. Upload başarılı olduktan sonra lokal JSON dosyasını **güvenli bir yere taşı veya sil** (RevenueCat'te artık var; lokalde tutmaya gerek yok).

### D.3 Entitlement oluştur

> **Entitlement** RevenueCat'in soyutlama katmanı: "Bu kullanıcı Pro mu?" sorusunun karşılığı. Birden fazla ürün (monthly, yearly) aynı entitlement'a bağlanır; kod sadece entitlement'a bakar (ürünlerle uğraşmaz).

1. RevenueCat dashboard sol kenar çubuğu → **Entitlements** (ana navigasyonda, Project Settings'de değil).
2. Sağ üstte **"+ New"** butonu.
3. Form:
   - **Identifier:** **`FormAI Pro`** — **boşluk dâhil, byte-byte aynı**. Kod `lib/features/monetization/providers/monetization_provider.dart:16` satırında `kProEntitlementId = 'FormAI Pro'` sabitiyle case-sensitive eşleşme yapıyor. Yanlış yazarsan paywall hiç kapanmaz.
   - **Display name:** `FormAI Pro` (kullanıcıya görünmüyor; admin reference).
4. **Add** bas. Entitlement listede görünmeli.

### D.4 Ürünleri import et + entitlement'a bağla

> Bu adım Faz E ürünleri yaratıldıktan **sonra** yapılır. Sıralama kritik: önce Play Console'da ürünleri yarat (Faz E), sonra buraya geri dön.

Faz E'yi tamamladıktan sonra:

1. RevenueCat → sol kenar çubuğu → **Products** (Entitlements'in altında).
2. **"+ New"** → **"Import from app store"** → Play Store seç.
3. Listede Faz E'de yarattığın 3 ürün görünmeli (`formai_pro_monthly`, `formai_pro_quarterly`, `formai_pro_yearly`). Hepsini import et.
4. Her ürünün satırına tıkla → **"Attached entitlements"** alanından `FormAI Pro` seç → Save.
5. Bu işlemi 3 ürün için tek tek tekrarla.

### D.5 Offering oluştur — paywall'ın okuduğu yapı

> **Offering** RevenueCat'in paket gruplama katmanı. Paywall kodu `Purchases.getOfferings().current` çağırıyor; "current" tag'li offering'i okuyor.

1. RevenueCat → sol kenar çubuğu → **Offerings**.
2. Default'ta `default` adlı bir offering vardır. Yoksa **"+ New"** → identifier `default`.
3. Default offering satırına tıkla → **"+ Add Package"** butonu.
4. Üç paketi sırayla ekle:
   - **Identifier:** `$rc_monthly` → **Product:** `formai_pro_monthly` seç.
   - **Identifier:** `$rc_three_month` → **Product:** `formai_pro_quarterly` seç.
   - **Identifier:** `$rc_annual` → **Product:** `formai_pro_yearly` seç.

   > `$rc_*` prefix'i RevenueCat'in standart paket identifier'ları — paywall kodunun beklediği isimler.
5. Offering'in sağ üstünde **"Make current"** butonu varsa bas (default offering'in "current" olduğunu garantile).

---

## Faz E — Play Console'da Subscription Ürünleri Yarat

> **Önkoşul:** Faz B tamamlanmış (AAB upload edilmiş, app Play Console'da tanınıyor).

### E.1 Subscription product'ları aç

1. **Play Console → app → sol kenar çubuğu → Monetize → Products → Subscriptions**.
2. Sağ üstte **"Create subscription"** butonu.

### E.2 İlk ürün — `formai_pro_monthly`

1. Form:
   - **Product ID:** `formai_pro_monthly` — **bir kez set edilince değiştirilemez**, dikkat et. Snake_case, küçük harf, alt çizgi ayraçlı.
   - **Name:** `FormAI Pro — Aylık` (kullanıcıya Play Store'da görünür).
   - **Description:** `30 günlük FormAI Pro üyeliği. Tüm AI antrenman planları, beslenme önerileri ve gelişmiş analizler.`
2. **Save** bas. Ürün detay sayfasına yönlendirileceksin.
3. **Base plans** bölümü → **"Add base plan"** butonu.
   - **Base plan ID:** `monthly`.
   - **Type:** `Auto-renewing`.
   - **Billing period:** `1 month`.
   - **Renewal type:** `Auto-renewing`.
   - **Grace period:** `7 days` (Google'ın önerdiği — kullanıcı kart sorununda 7 gün abonelik aktif kalır).
   - **Account hold:** `30 days` (grace period bittikten sonra hold).
   - **Resubscribe:** Enabled.
   - **Pricing → Add countries:** `Türkiye → ₺149.00`.
   - Diğer ülkeler için Google'ın "auto-conversion" suggesti'sini kabul et veya manuel tutarlar gir.
   - **Activate** bas.
4. **Offers** bölümü (free trial için) — bu ürün için trial istemiyorsan atla.

### E.3 İkinci ürün — `formai_pro_quarterly`

Yukarıdakini tekrarla:
- **Product ID:** `formai_pro_quarterly`
- **Name:** `FormAI Pro — 3 Aylık`
- **Base plan ID:** `quarterly`, **Billing period:** `3 months`, **Pricing:** `Türkiye → ₺299.00`.

### E.4 Üçüncü ürün — `formai_pro_yearly` (free trial dahil)

- **Product ID:** `formai_pro_yearly`
- **Name:** `FormAI Pro — Yıllık`
- **Base plan ID:** `annual`, **Billing period:** `1 year`, **Pricing:** `Türkiye → ₺799.00`.
- **Offers → Add offer:**
  - **Offer ID:** `freetrial7d`
  - **Eligibility:** "Developer determined" → "New customers only".
  - **Phases:** Phase 1 → "Free" → 7 days.
  - **Activate**.

### E.5 Üç ürünü de "Active" state'e geçir

Subscriptions sayfasında üç ürünün de status'ünün **"Active"** olduğundan emin ol. Eğer "Inactive" görünüyorsa, ürün satırına tıkla → "Activate" bas.

### E.6 RevenueCat'e geri dön → import + bağla

Faz D.4'e dön → ürünleri import et → `FormAI Pro` entitlement'ına bağla → offering'e ekle.

---

## End-to-End Doğrulama Checklist

Bu sırayı takip et; bir madde fail ederse o fazın detayına geri dön.

### Faz A doğrulaması
- [ ] Play Console giriş yapıldı; "All apps" sayfası açılıyor.
- [ ] Payments profile → "Verified" + IBAN onaylanmış (test deposit verify edilmiş).

### Faz B doğrulaması
- [ ] App "FormAI" Play Console'da görünüyor.
- [ ] Closed Testing track'inde 1+ release var, status "Available".
- [ ] App → Dashboard üstünde "Package name: com.emredogan.formai" görünüyor.

### Faz C doğrulaması
- [ ] GCP Console → APIs & Services → Enabled APIs: "Google Play Android Developer API" ✓.
- [ ] IAM & Admin → Service Accounts: `revenuecat-play-bridge` listede ✓.
- [ ] Service account JSON key indirildi ve güvenli yere kaydedildi.
- [ ] Play Console → Users and permissions: service account email "Active" ve 4 finance permission tikli.

### Faz D doğrulaması
- [ ] RevenueCat → Project Settings → Apps → FormAI Android: "Service Account ✓ Verified" yeşil.
- [ ] Entitlements: `FormAI Pro` (boşluk dâhil, case-sensitive) listede.
- [ ] Products: 3 ürün import edilmiş ve hepsi `FormAI Pro` entitlement'ına attached.
- [ ] Offerings → `default` "current" tag'li ve 3 paket içeriyor.

### Faz E doğrulaması
- [ ] Play Console → Subscriptions: 3 ürün hepsi "Active" state.
- [ ] Her ürün için en az bir base plan ve Türkiye pricing tanımlı.

### End-to-end satın alma testi (gerçek para harcamadan)
1. Play Console → **Setup → License testing** → kendi gmail'ini ekle. Bu hesapla satın alma yaparken Google **fake card** kullanır, gerçek para çekmez.
2. Closed Testing track'inde test cihazına app'i indir.
3. Onboarding'i tamamla → Paywall'a git → "Yıllık" butonuna bas.
4. Google Play purchase sheet açılır → "1 BUY for ₺0.00 (Test)" yazısı görünür → satın al.
5. **Beklenen:** Paywall otomatik kapanır, profil sayfasında "Pro" rozeti görünür, `isProProvider == true` olur.
6. RevenueCat → **Customers** sekmesi → email'ini ara → "FormAI Pro" entitlement'ın "active" görünmeli.
7. Play Console → **Order management** → test order'ı görünmeli (status: "Test purchase").

---

## İlk Gerçek Satışın Bankaya Düşüş Timeline'ı

```
Gün 1 ──── Random kullanıcı ₺149/ay aboneliği satın alır.
                 ↓ (anında)
                Google Play Billing kullanıcının kartından çeker.
                 ↓ (~5 saniye)
                RevenueCat webhook ile haberdar olur, entitlement aktif.
                 ↓ (~10 saniye)
                Uygulamada paywall kapanır, kullanıcı Pro.

Gün 1-30 ── Kullanıcının 14 günlük Google "money-back guarantee" penceresi.
                Bu süre boyunca refund ederse Google hesabından düşürülür.

Ay sonu ─── Google ay sonu (örn. 31 Mayıs) net kazancı ($)/(₺) hesaplar.
                Bizim ₺149 → Google %15 keser → ~₺126.65 net.

Ertesi ay
15'i ────── Google payout'u IBAN'ına gönderir (USD wire).
                FX dönüşümü USD → TRY bankan tarafından yapılır.
                
+1-2 iş
günü ────── Para hesabına geçer. SMS bildirimi gelir.
```

> **İlk payout için 60+ gün:** İlk satıştan sonra Google "first payment hold" uygular (genelde 30-60 gün). Sonraki aylar düzenli akar.

---

## Sıradaki Adımlar (PM Aksiyon Listesi)

1. ✅ Bu dokümanı baştan sona oku.
2. ⏳ Faz A: Play Developer hesabı aç + payment profile (IBAN test deposit verify dahil ~3-5 gün).
3. ⏳ Faz B: `flutter build appbundle --release` → Closed Testing'e upload.
4. ⏳ Faz C: GCP Service Account JSON üret + Play Console'da finance permission ver. **24 saat bekle.**
5. ⏳ Faz D: RevenueCat'e JSON upload → entitlement `FormAI Pro` yarat.
6. ⏳ Faz E: 3 subscription ürün yarat → Faz D.4'e dön → import + bağla → offering'e ekle.
7. ⏳ End-to-end test: License testing email ekle → test cihazıyla "₺0.00 test purchase" → RevenueCat customer ✓.
8. ⏳ Production'a hazırsın: Closed Testing → Open Testing → Production track promote.

---

## İlgili dokümanlar

- `docs/api_anahtarlari_kurulum_rehberi.md` — Sentry/PostHog/RevenueCat key'leri (Faz D ile bağlı; RevenueCat key'leri Faz D doğrulamasından önce `.env`'e yazılmalı).
- `docs/ROADMAP.md` §1.4 — RevenueCat ürün konfigürasyon kontrolü.
- `lib/features/monetization/providers/monetization_provider.dart:16` — `kProEntitlementId = 'FormAI Pro'` sabiti (Faz D.3'teki entitlement adıyla byte-byte eşleşmeli).
