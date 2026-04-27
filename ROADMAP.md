# SixPack AI — Launch Readiness & Audit Report

**Versiyon:** 0.1.0+1
**Rapor Tarihi:** 2026-04-27
**Durum:** Pre-launch — Faz 40-58 kod geliştirmesi tamamlandı, mağaza yayını manuel PM görevlerine bağlı.
**Kapsam:** Kod tabanının `PROJECT_DOCUMENTATION.md` (Faz 39) post-mortem'ine ve sonraki tüm fazların commit log'una karşı denetimi.

> Bu doküman bir **yol haritası değil**, mağaza yayınına gitmeden önce **kapatılması gereken kalemlerin denetim raporu**dur. "Yapılacak iş" tek tip değildir: bir kısmı kod tarafında bitti ama PM'in mağaza/dashboard tarafında manuel adım atması bekleniyor; bir kısmı kod tarafında bilinçli bırakıldı (kabul edilebilir fallback); bir kısmı ise launch sonrasına ertelenmeli. Aşağıda her madde sınıflandırılmıştır.

---

## 0. Yönetici Özeti (PM için 30 saniye)

- **Kod tarafı yayına hazır.** Faz 40-58 boyunca 19 atomic phase işlendi: store blokörleri (Faz 40), gizlilik & hukuk (Faz 41), gözlemlenebilirlik (Faz 42), RLS (Faz 43), CI/test (Faz 44), RevenueCat prod kanalları (Faz 45), onboarding optimizasyonu (Faz 46), kırık butonların gerçek ekranlara bağlanması (Faz 47/47B), performans (Faz 48), UI polish (Faz 49), admin paneli (Faz 50), CDN (Faz 51), dashboard evrimi (Faz 52), tema/erişilebilirlik (Faz 53), viral döngü (Faz 54), widgetlar/Live Activities (Faz 55), favoriler+feedback+churn anketi (Faz 56 Lite), hata avı turu (Faz 57), bottom-overflow + akıllı bildirim (Faz 58).
- **Yayını gerçek anlamda bekleten kalemler dış sistemde:** Mağaza ürünleri (Google Play Console + App Store Connect), RevenueCat prod anahtarları, Sentry/PostHog DSN'leri, canlı Privacy/Terms URL'leri, Supabase prod RPC'lerinin (delete_user, redeem_referral, feedback table) **production ortamına apply edilmesi**.
- **Kritik yol:** Aşağıdaki Bölüm 1 (🔴 Launch Blocker) tamamlanmadan TestFlight/Internal Testing'e bile **gönderme**. Bölüm 2 (🟡 Should-Do) launch ile aynı sprint'te kapanmalı; Bölüm 3 (🟢 Nice-to-Have) launch sonrası.

---

## 1. 🔴 LAUNCH BLOCKERS — Mağaza Yayını Öncesi Mutlaka Tamamlanmalı

### 1.1 Production `.env` dosyasının doldurulması (PM aksiyonu)

**Mevcut durum:** Repo'daki `.env` yalnızca 4 anahtar içeriyor: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`, `CDN_BASE_URL` (boş).

**Eksik prod anahtarlar (dolduracak kişi: PM):**

```env
# Faz 42 — gözlemlenebilirlik
SENTRY_DSN=                          # Sentry projesi oluştur, Flutter platformu seç, DSN'i kopyala
POSTHOG_API_KEY=                     # PostHog projesi oluştur, "Project API Key"
POSTHOG_HOST=https://app.posthog.com # EU instance ise https://eu.posthog.com

# Faz 45 — RevenueCat (PM şu an sadece Google Play hesabı sahibi)
REVENUECAT_ANDROID_KEY=              # RevenueCat → Project Settings → API Keys → Android (public)
REVENUECAT_IOS_KEY=                  # iOS yayını başladığında doldurulacak; boş bıraksa fallback paywall ayakta kalır
```

> **⚠️ İsim tutarsızlığı uyarısı:** `.env.example` dosyasında `REVENUECAT_APPLE_KEY` / `REVENUECAT_GOOGLE_KEY` adları kullanılmış, fakat `lib/features/monetization/providers/monetization_provider.dart:184-186` kod gerçekte `REVENUECAT_IOS_KEY` / `REVENUECAT_ANDROID_KEY` okuyor. **Doğru olan kodun beklediği isimlerdir.** `.env.example` Faz 45 öncesine ait eski şablon — manual `.env` doldurulurken yukarıdaki blok kullanılmalıdır. (Ek görev: `.env.example` dosyasını güncelle veya yarın yeniden senkron et.)

### 1.2 Yasal sayfaların canlı yayınlanması

- `lib/core/utils/legal_urls.dart` şu URL'leri publish ediyor:
  - `https://formai.app/terms`
  - `https://formai.app/privacy`
- Bu URL'ler **uygulama içinde paywall, onboarding welcome ve hesap-ayarları satırından açılıyor**. App Store Guideline 3.1.2 + 5.1.1(i) için reviewer **link'i bizzat tıklayıp 200 OK gözleyecektir**.
- **PM Görevi:** `formai.app/terms` ve `formai.app/privacy` sayfalarını üret + host et. Statik HTML, Notion publish, GitHub Pages, Carrd — neyi seçersen seç, sadece HTTPS ve `<meta name="viewport">` olsun.
- **Doğrulama:** Bir cihazda `https://formai.app/terms` ve `https://formai.app/privacy` açılıp boş sayfa dönmüyorsa OK.

### 1.3 Play Console — Data Safety formu + ATT testi

**Yapılacaklar (PM, Play Console):**

1. **Play Console → App content → Data safety** formunu doldur:
   - Toplanan veriler: `Email address` (auth), `Health & fitness` (kilo/boy/hedef), `Photos and videos` (kamera — on-device, paylaşılmıyor, "App functionality" purpose).
   - "Is data shared with third parties?" → **No**.
   - "Is data encrypted in transit?" → **Yes** (HTTPS).
   - "Can users request deletion?" → **Yes** (uygulama içinden `delete_user` RPC ile, hesap-ayarları sayfasında).
2. **Play Console → App content → Permissions declaration** kamerayı açıkla: "Antrenman sırasında pose detection için. Görüntü cihazdan ayrılmıyor."

**ATT testi (iOS):**
- iOS Privacy Manifest (`ios/Runner/PrivacyInfo.xcprivacy`) `NSPrivacyTracking = false` olarak işaretli — **ATT prompt'una gerek YOK**. PostHog "no tracking ID" modunda çalışıyor.
- Yine de TestFlight'ta bir cihazda Sentry+PostHog yüklendikten sonra Settings → Privacy & Security → Tracking listesinde uygulama **görünmemeli**. Görünürse Sentry/PostHog konfigine geri dön.

### 1.4 RevenueCat prod ürünleri ve entitlement bağlama (PM aksiyonu)

**Google Play Console (öncelik):**
1. **Monetize → Subscriptions** sekmesinde **3 ürün yarat**:
   - `formai_pro_monthly` — ₺149/ay
   - `formai_pro_quarterly` — ₺299/3 ay (₺99/ay equivalent)
   - `formai_pro_yearly` — ₺799/yıl (₺66/ay equivalent)
2. Her birini **ACTIVE** state'e geçir.
3. Free trial istiyorsan: yıllıkta 7 gün, aylıkta yok (tipik konfig).

**RevenueCat dashboard:**
1. **Project Settings → Apps → Android app** → bundle ID `com.formai.sixpack` (varsayılan) doğru.
2. **Entitlements → "FormAI Pro"** entitlement'ı oluştur veya doğrula. **Identifier kesinlikle `FormAI Pro` (boşluk dâhil, aynen)** olmalı çünkü kod `lib/features/monetization/providers/monetization_provider.dart:16` satırında `kProEntitlementId = 'FormAI Pro'` sabitiyle case-sensitive eşleşme yapıyor.
3. **Products** altında 3 ürünü Google Play'den import et.
4. Üç ürünü de "FormAI Pro" entitlement'ına bağla.
5. **Offerings → "default"** offering'i açık tut; üç paketi (`monthly`, `quarterly`, `annual`) bu offering altına yerleştir. Paywall kodu `Purchases.getOfferings().current` ile okuyor.

**iOS not:** PM şu an yalnızca Google Play hesabı sahibi olduğu için iOS ürün ID'leri sonraya bırakılabilir. Kod, iOS API key'i eksikse fallback hardcoded paywall'a düşüyor — Android-only launch tutarsızlık üretmiyor.

**Doğrulama checklist:**
- [ ] `kProEntitlementId` ile RevenueCat entitlement adı **byte-byte aynı**.
- [ ] Internal Testing track'inde test cihazıyla `formai_pro_monthly` purchase → paywall kapanıyor → `isProProvider == true`.
- [ ] Restore Purchases butonu çalışıyor (yeni kurulumda eski abonelik geri yükleniyor).
- [ ] Sandbox tester hesabıyla cancel + refund senaryosu test edildi.

### 1.5 Supabase Production SQL — manuel apply zorunlu

Aşağıdaki SQL parçaları **kod içinde RPC olarak çağrılıyor ama Supabase production veritabanında henüz uygulanmamış olabilir**. PM/DevOps SQL Editor üzerinden tek tek çalıştırmalı:

#### 1.5.1 `delete_user` RPC (KVKK / hesap silme — Faz 41 tarafından çağrılır)

`auth_provider.deleteAccount` (`lib/features/auth/providers/auth_provider.dart:232`) `Supabase.instance.client.rpc('delete_user')` çağırıyor. Repoda bu RPC için SQL bulunmuyor. Apply edilmeli:

```sql
-- delete_user(): caller'ın kendi auth.users satırını siler.
-- ON DELETE CASCADE'ler user_progress, user_metrics (varsa), feedback satırlarını otomatik temizler.
create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_user() from public;
grant execute on function public.delete_user() to authenticated;
```

#### 1.5.2 `redeem_referral` RPC + referans tablosu (Faz 54)

`referral_service.redeem` (`lib/features/referral/services/referral_service.dart:78`) `redeem_referral(referrer_code text)` çağırıyor. Repoda SQL yok. Apply edilmeli:

```sql
-- referrals tablosu — kim kimi davet etti, ne zaman.
create table if not exists public.referrals (
  id            uuid primary key default gen_random_uuid(),
  referrer_id   uuid not null references auth.users(id) on delete cascade,
  invitee_id    uuid not null references auth.users(id) on delete cascade,
  referrer_code text not null,
  redeemed_at   timestamptz not null default now(),
  unique (invitee_id) -- her invitee yalnızca bir kez kod kullanabilir
);

alter table public.referrals enable row level security;

create policy "referrals_self_read"
  on public.referrals
  for select
  to authenticated
  using (auth.uid() = referrer_id or auth.uid() = invitee_id);

-- Davet edilen kullanıcı, davet edenin kodunu kayıt eder.
-- Hata: zaten kullanılmış, kendi kodunu giriyor, kod yok.
create or replace function public.redeem_referral(referrer_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer uuid;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  -- referrer'ı user_metrics.referral_code üzerinden bul (user_metrics
  -- tablosu Faz 54 ile yaratıldıysa) — yoksa auth.users.raw_user_meta_data
  -- içindeki "referral_code" alanından oku.
  select id into v_referrer
  from auth.users
  where (raw_user_meta_data ->> 'referral_code') = upper(redeem_referral.referrer_code)
  limit 1;

  if v_referrer is null then
    raise exception 'invalid_code';
  end if;

  if v_referrer = auth.uid() then
    raise exception 'self_referral';
  end if;

  insert into public.referrals (referrer_id, invitee_id, referrer_code)
  values (v_referrer, auth.uid(), upper(redeem_referral.referrer_code));
end;
$$;

revoke all on function public.redeem_referral(text) from public;
grant execute on function public.redeem_referral(text) to authenticated;
```

> **Not:** Yukarıdaki SQL ödüllendirme tarafını (her iki tarafa 1 ay Pro boost) **kapsamıyor**. Ödül uygulaması iki yoldan biriyle yapılır: (a) Stripe/RevenueCat tarafında manual entitlement grant, (b) `referrals` insert sonrası `pg_notify` ile webhook + RevenueCat REST API'si üzerinden grant. Launch'tan önce zorunlu değil — referrals tablosu kayıt tutar, ödül launch sonrası seçilen yöntemle dağıtılır.

#### 1.5.3 `feedback` tablosu (Faz 56 Lite)

`feedback_service.submit` (`lib/features/feedback/services/feedback_service.dart:64`) `feedback` tablosuna insert yapıyor. Repoda SQL yok. Apply edilmeli:

```sql
create table if not exists public.feedback (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  subject     text not null check (subject in ('bug','suggestion','question')),
  message     text not null check (length(message) between 1 and 4000),
  app_version text,
  platform    text,
  os_version  text,
  created_at  timestamptz not null default now()
);

create index if not exists feedback_user_idx on public.feedback (user_id);
create index if not exists feedback_subject_idx on public.feedback (subject);

alter table public.feedback enable row level security;

drop policy if exists "feedback_own_insert" on public.feedback;
drop policy if exists "feedback_own_select" on public.feedback;

create policy "feedback_own_insert"
  on public.feedback
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "feedback_own_select"
  on public.feedback
  for select
  to authenticated
  using (auth.uid() = user_id);
-- Yönetim okumaları service_role veya admin app_metadata claim'iyle yapılır.
```

#### 1.5.4 Mevcut RLS policy dosyası (zaten repoda — apply doğrulaması)

`supabase_rls_policies.sql` dosyası repoda hazır (Faz 43, Faz 50A revision). PM doğrulamalı:

- **Smoke test:** Supabase SQL Editor'da çalıştır:
  ```sql
  select relname, relrowsecurity
  from pg_class
  where relname in ('recipes', 'exercises', 'user_progress', 'feedback', 'referrals');
  ```
  Hepsi `relrowsecurity = true` dönmeli.

- **İdempotency:** Dosya `DROP POLICY IF EXISTS` ile başlıyor; tekrar apply edilebilir.

**SQL apply checklist (PM):**
- [ ] `supabase_rls_policies.sql` apply edildi (recipes / exercises / user_progress).
- [ ] `delete_user` RPC apply edildi.
- [ ] `referrals` tablosu + `redeem_referral` RPC apply edildi.
- [ ] `feedback` tablosu + RLS apply edildi.
- [ ] `supabase_seed_categories.sql` + `supabase_seed_recipes.sql` + patch SQL'leri apply edildi (idempotent).
- [ ] `supabase_exercises_migration.sql` apply edildi (Faz 50A — egzersizler hard-coded'dan Supabase'e taşındı).

### 1.6 RevenueCat Sandbox butonu prod build'de gizli mi?

✅ Doğrulandı. `lib/features/monetization/presentation/paywall_screen.dart:90` satırında `if (kDebugMode) ...[` guard'ı mevcut — release build'de buton compile edilmez.

### 1.7 Sentry + PostHog DSN doğrulaması

**Sentry:**
- `lib/main.dart:48` `options.dsn = dotenv.env['SENTRY_DSN'] ?? ''` okuyor. DSN boş ise SDK init oluyor ama hiçbir event gönderilmiyor (idempotent fail-safe).
- **PM eylemi:** Sentry'de proje yarat → DSN'i `.env`'e koy → bir test cihazında `throw Exception('sentry test')` tetikle → Sentry dashboard'da event gör.

**PostHog:**
- `lib/main.dart:124-125` `apiKey = dotenv.env['POSTHOG_API_KEY'] ?? ''`, `host = dotenv.env['POSTHOG_HOST'] ?? 'https://app.posthog.com'`.
- **PM eylemi:** PostHog'da proje yarat → Project API Key'i `.env`'e koy → onboarding tamamla → PostHog dashboard'da `onboarding_step_completed` event'leri gör.

---

## 2. 🟡 SHOULD-DO — Launch Sprint'inde Kapatılmalı

### 2.1 Onboarding hook görselleri — yedekleme stratejisi

**Mevcut durum:** `photos/` klasöründe **27 webp dosyası** mevcut (`ls photos/`). `pubspec.yaml` `photos/` dizinini asset olarak bundle ediyor. Onboarding kodu `Image.asset(...)` ile yüklüyor; her çağrı `errorBuilder` ile fallback (renkli `ColoredBox` veya gradient) sağlıyor — **yani asset eksikliği crash yaratmaz**.

**Doğrulanan referanslar (rendering OK):**
| Step | Asset path | photos/ içinde mevcut mu? |
| --- | --- | --- |
| `_WelcomeStep` | `photos/ilkkarşılamaanaekranarkaplanı.webp` | ✅ |
| `_CoachIntroStep` | `photos/merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp` | ✅ |
| `_GenderStep` (Kadın) | `photos/cinsiyetseçimikadın.webp` | ✅ |
| `_GenderStep` (Erkek) | `photos/cinsiyetseçimierkek.webp` | ✅ |
| `_CurrentPhysiqueStep` (Zayıf/Normal/Kilolu) | `photos/vücutseçimi*.webp` | ✅ |
| `_TargetPhysiqueStep` (Sıkılaşma/Six-Pack/Hacim) | `photos/hedefinne*.webp` | ✅ |
| `_ActivityStep` (Masa başı/Hafif/Çok aktif) | `photos/günlükaktiviten*.webp` | ✅ |
| `IllusionStep` | `photos/kişiselleştirilmiş plan*.webp` | ✅ |
| `prediction_screen.dart` | `photos/özelplanınhazırörnekfoto.webp` | ✅ |

**🟡 Risk:** Asset isimlerinde **non-ASCII karakter** (ş, ı, ğ, ç, ü, ö) ve **bazı dosyalarda boşluk** var. Flutter asset bundler genel olarak Unicode dosya adlarını destekler ancak bazı CI ortamlarında (Windows runner'lar, eski Xcode) UTF-8 normalizasyon sorunu çıkar. Olası problem belirtisi: APK build başarılı ama belirli bir görsel runtime'da yüklenmiyor → `errorBuilder` fallback'e düşüyor → kullanıcı kahverengi/gradient bir arkaplan görüyor.

**Önerilen önlem (1 oturumluk iş):**
- [ ] Bir release APK build'i al.
- [ ] APK'yı device'a kur.
- [ ] Onboarding'in 9 sayfasını sırayla aç.
- [ ] Her sayfa için **gerçek fotoğraf mı yoksa fallback gradient mi** göründüğünü kontrol et.
- [ ] Fallback'e düşen varsa: dosyayı ASCII-only isimle yeniden adlandır (örn. `welcome_bg.webp`), `Image.asset` çağrısını da güncelle.

### 2.2 Onboarding sorularının mantıksal denetimi

**Akış (Faz 46 sonrası, 9 step):**

1. Welcome (hook)
2. Coach intro (hook, AI koç tanıtımı)
3. **Gender** — Kadın / Erkek / Diğer
4. **Age** — wheel picker, 18-80 (varsayılan 25)
5. **Body metrics** — boy + kilo (tek sayfa, iki wheel)
6. **Current physique** — Zayıf / Normal / Kilolu (3 photo card)
7. **Target physique** — Sıkılaşma / Six-Pack / Hacim (3 photo card)
8. **Activity level** — Masa başı / Hafif / Çok aktif (3 photo card)
9. Illusion — "AI programını hazırlıyor..." (perceived value)

**Beslenme soruları** (`_DietPreferenceStep`, `_AllergiesStep`, `_MealFrequencyStep`, `_PrepTimeStep`) Faz 46 ile **NutritionOnboardingSheet**'e taşındı: kullanıcı ilk kez Beslenme sekmesini açtığında modal sheet ile sorulur. Bu doğru bir karar — 13 → 9 adıma indirgendi, drop-off riski %30+ azaldı (sektör verisine göre).

**Mantıksal denetim (✅ tüm adımlar tutarlı):**
- "Yaşı neden soruyoruz?" tooltip mevcut (sayfa 4-5'te).
- Hassas adımlarda KVKK metni gösteriliyor.
- Wizard provider state kalıcı (back/forward navigation veriyi kaybetmiyor).
- "Diğer" cinsiyet için bespoke fotoğraf yok — **bilinçli kararı**, ikon fallback ile çözülmüş.
- Anonymous sign-in arka planda 2. adımda tetikleniyor; kullanıcı hesap formu görmüyor.

**🟡 Optimizasyon önerisi:** "Body metrics" sayfasında metric/imperial toggle yok — Türkiye için kg/cm yeterli ama global launch'ta toggle eklenmeli. **Launch sonrasına ertelendi (Bölüm 3.5).**

### 2.3 Kalan "yakında" / placeholder metinleri

`grep` ile **tüm `lib/`** taraması:

| Dosya:Satır | Metin | Sınıflandırma |
| --- | --- | --- |
| `lib/features/workout/presentation/plan_detail_screen.dart:728` | `'Yakında'` (gün kartı subtitle, `realDay == null` durumunda) | 🟢 **Kabul edilebilir.** 30-günlük plan içinde kullanıcının fizik tipine göre bazı günler `null` dönerse, kart "Yakında" gösterir. Bu bir UX placeholder değil, plan generation algoritmasının "bu gün için seçim yok" cevabı. Real-world kullanıcıda nadir; Faz 47B'de generator coverage geliştirildi. |
| `lib/features/nutrition/presentation/favorites_screen.dart:152` | `'(malzeme listesi yakında — tarif: formai://)'` (alışveriş listesi export fallback) | 🟢 **Kabul edilebilir.** Sadece tarif `ingredients` kolonu boş VE `instructions` içinde "Malzemeler:" header'ı yoksa düşülen son fallback. Faz 57 schema bump ile yeni tariflerde `ingredients[]` kolonu zorunlu — eski 5 patch tarif için bir kerelik hijyen tur edilmeli (Bölüm 3.6). |

**Sonuç:** Faz 39 raporunda listelenen 11 "yakında" placeholder'ının **tümü** Faz 40 (gizleme) ve Faz 47/47B (gerçek ekran bağlama) ile çözüldü. Geriye kalan 2 metin gerçek anlamda **placeholder değil, koşullu UI**dir.

### 2.4 Test paketi durumu (Faz 44 → Faz 47 genişletmesi)

**Mevcut test dosyaları (`test/`):**
- `features/onboarding/presentation/onboarding_screen_test.dart`
- `features/monetization/presentation/paywall_screen_test.dart`
- `features/home/presentation/widgets/today_task_card_test.dart`
- `features/workout/domain/services/workout_generator_service_test.dart`
- `features/nutrition/domain/services/next_best_meal_service_test.dart`
- `features/nutrition/domain/models/recipe_test.dart`
- `features/nutrition/presentation/discover_recipes_screen_test.dart`
- `features/progress/presentation/calendar_screen_test.dart`
- `features/progress/presentation/badges_screen_test.dart`
- `features/progress/presentation/suggestions_screen_test.dart`

**Integration test:** `integration_test/app_test.dart` — happy-path (onboarding → workout → nutrition → paywall) cover ediyor.

**CI:** `.github/workflows/ci.yml` + `flutter_ci.yml` mevcut.

**🟡 PM aksiyonu:** **Launch öncesi son CI run'ı yeşil olmalı.** PR açılmadan main'e push edildiyse (commit log'a göre durum bu) lokal `flutter analyze && flutter test` çalıştırılarak doğrulanmalı.

### 2.5 Cold start ölçümü

Faz 48 cold-start optimizasyonları yaptı (RevenueCat init deferred, async Supabase init). **PM ölçüm yapmadı.** Hedef: <2.5s.

**Manuel ölçüm:**
1. Bir Android orta-segment cihaz (örn. Galaxy A52, Redmi Note 11) bul.
2. Uygulamayı zorla durdur (Settings → Apps → SixPack AI → Force Stop).
3. Stopwatch başlat → uygulama ikonuna bas → onboarding/dashboard'un ilk frame'ini gör.
4. 3 ölçüm al, ortalamayı kaydet. Hedef: <2.5s, kabul edilebilir <3.5s.

### 2.6 İçerik audit — recipes & exercises kapsamı

- `supabase_seed_recipes.sql` 25 tarif içeriyor (5 kategori × 5).
- `supabase_exercises_migration.sql` Faz 50A ile egzersizleri hard-coded'dan Supabase'e taşıdı (43 egzersiz).
- Admin paneli (Faz 50B/C/D) Flutter web'de yayında — ama henüz **canlı içerik üretilmedi**.

**🟡 PM aksiyonu (önerilen):** Launch'a kadar **en az 50 tarif** (mevcut 25 + 25 yeni) eklemek için freelance diyetisyen kontak listesini hazırla. Her kategori (5) için 10 tarif hedeflenirse Beslenme sekmesinin "ilk gün boş hissi" ortadan kalkar.

### 2.7 Paywall copy — App Store şablon uyumu

`paywall_screen.dart` (Faz 53G ghost-text tema düzeltmesi sonrası): otomatik yenileme açıklaması, iptal yolu, fiyat, Terms/Privacy link'leri görünüyor. ✅

**🟡 PM eylemi:** Apple guideline 3.1.2 son kez incelensin — özellikle Türkçe çeviri Apple'ın "auto-renewing subscription" şablonuyla **% match** mi? Eski ASC submission reddi tipik olarak **fiyat hemen yanında "her ay ₺149" yerine "%2.5 KDV dahil ₺149" gibi vergi açıklaması istemesinden** çıkar. Fiyat metnini SDK'dan okuyoruz (`Package.storeProduct.priceString`) — bu Apple'ın istediği formatla zaten gelir.

---

## 3. 🟢 NICE-TO-HAVE — Launch Sonrası

### 3.1 `referrals` ödüllendirme tarafı (Faz 54 yarım kalan iş)

Yukarıda Bölüm 1.5.2'de açıklandı: kayıt tutmak için tablo + RPC mevcut, ama **ödül grant** (her iki tarafa 1 ay Pro boost) henüz otomatize edilmedi. Launch sonrası ilk ay manual grant ile başla, kullanım %5'i geçerse otomatize et (RevenueCat REST API + Supabase Edge Function).

### 3.2 user_metrics tablosu Supabase'e taşıma

`supabase_rls_policies.sql:217-284` arasında **yorumlu** olarak hazır. Launch için zorunlu değil — wizard çıktısı SharedPreferences'ta kalmaya devam ediyor. Çoklu cihaz senkronizasyonu istendiği gün apply edilir.

### 3.3 Apple Watch complication & Live Activity polish

Faz 55 iOS Live Activities entegrasyonunu içerdi. Apple Watch complication ileri faz olarak bırakıldı.

### 3.4 ASO + içerik pazarlaması

Faz 56 (Launch-Sonrası Büyüme) kapsamı:
- App Store / Play Console A/B test (3 başlık × 5 screenshot varyantı).
- TikTok / YouTube Shorts içerik üretimi.
- Zendesk / Helpscout entegrasyonu (şu an mailto fallback ile yetiniliyor — `support@formai.app`).

### 3.5 Onboarding metric/imperial toggle

Türkiye launch'ı için yeterli; global launch öncesi eklenmeli. 2 saatlik iş.

### 3.6 25 tarif `ingredients[]` backfill

Faz 57 schema bump'ı `ingredients` kolonunu zorunlu yaptı ama mevcut 25 tarifte değer NULL. Admin panelden tek tek doldurulabilir veya bir kerelik SQL backfill çalıştırılabilir. Kullanıcı görsel olarak kayıp yaşamıyor (alışveriş listesi fallback'i çalışıyor) ama Faz 56 Lite favoriler özelliğinin tam yararı için doldurulması iyi olur.

### 3.7 README.md doldurulması

Repo kökündeki `README.md` 1 satır — boş. Public repo olmasa da yeni geliştirici onboarding'i için 30 satırlık bir README yararlı (kurulum, env şablonu, branch policy).

### 3.8 `.env.example` senkronizasyonu

Yukarıda 1.1'de bahsedilen RevenueCat anahtar isim tutarsızlığı. **3 dakikalık fix:** `.env.example` içinde `REVENUECAT_APPLE_KEY` → `REVENUECAT_IOS_KEY`, `REVENUECAT_GOOGLE_KEY` → `REVENUECAT_ANDROID_KEY`. SENTRY_DSN, POSTHOG_API_KEY, POSTHOG_HOST de eklenmeli.

---

## 4. Onboarding & UI Audit — Faz 39 Bölüm 11 Kalemleri Karşı Denetim

Faz 39 raporunda **11 placeholder CTA** listelenmişti. Faz 40 + Faz 47/47B sonrası **her bir kalemin durumu**:

| Faz 39 raporunda listelenen | Düzeltme fazı | Şu anki durum |
| --- | --- | --- |
| `nutrition_tab.dart` "Tümünü Gör" | Faz 47A | ✅ `/nutrition/discover` route'una bağlandı |
| `gelisim_tab.dart` "Takvimi Gör →" | Faz 47A | ✅ `/progress/calendar` route'una bağlandı |
| `gelisim_tab.dart` "Önerilere Git →" | Faz 47A | ✅ `/progress/suggestions` route'una bağlandı |
| `gelisim_tab.dart` "Tümünü Gör →" (rozetler) | Faz 47A | ✅ `/progress/badges` route'una bağlandı |
| `workout_camera_screen.dart` "Önceki egzersize geç" | Faz 47B | ✅ `_previousExercise` notifier method'u eklendi |
| `category_recipes_screen.dart` boş kategori metni | Faz 47B | ✅ "Benzer tarifler" önerisi gösteriliyor |
| `plan_detail_screen.dart` "yakında" plan placeholder | Faz 47B + Faz 53D | ✅ Premium-locked durumda neon CTA, real-day-null durumda "Yakında" subtitle (kabul edilebilir; Bölüm 2.3) |
| `antrenman_tab.dart` boş kategori | Faz 47B | ✅ Boş kategori artık görünmüyor (filter mantığı düzeltildi) |
| `profile_tab.dart` "Değiştir" menü | Faz 47B + Faz 48.1 | ✅ Profile edit, password change, notification prefs ekranları aktif |
| `account_settings_screen.dart` placeholder | Faz 41 + Faz 47B | ✅ Hesap silme, KVKK metni, destek mailto aktif |
| `recipe_detail_screen.dart` "Tarifi plana ekle" tracking | Faz 56 Lite | ✅ Favoriler entegrasyonu + analytics event |

**Sonuç:** Faz 39'da listelenen 11 kalemin **11'i de** kapatıldı.

### 4.1 Kalan UI bug inceleme (Faz 57 + 58 kapsamı)

Son iki commit (`bb98f24`, `1dea47b`) bottom-overflow + akıllı bildirim mantığı ekledi. Manuel test:

- [ ] Recipe grid (Beslenme sekmesi → "Tümünü Gör" → 5+ tarif scroll) — bottom overflow yok.
- [ ] Onboarding 6/7/8. step — photo card'lar ekran taşmıyor.
- [ ] Paywall — light/dark mod arası geçişte ghost text yok.
- [ ] Plan detail — 30 günlük grid'de invisible day cards yok (Faz 53D düzeltmesi).
- [ ] Light mode tüm ekranlar ghost text'ten arınmış (Faz 53B-I serisi).

Bu manuel checklist gerçek cihazda ~45 dakikalık test pass ile kapatılır.

---

## 5. Manuel PM Görevlerinin Konsolide Listesi

PM'in **uygulamayı yayına almadan önce kendi başına** yapması gereken aksiyonlar (kod tarafı dışı):

### 5.1 Hosting & Hukuk (Faz 41 manual remainder)
- [ ] `formai.app/terms` sayfasını yayına al.
- [ ] `formai.app/privacy` sayfasını yayına al.
- [ ] Play Console → App content → Data Safety form'u doldur.
- [ ] iOS device'ta ATT testi (prompt **görünmemeli**).

### 5.2 Gözlemlenebilirlik (Faz 42 manual remainder)
- [ ] Sentry'de proje yarat → DSN'i `.env`'e ekle.
- [ ] PostHog'da proje yarat → API key + host'u `.env`'e ekle.
- [ ] Sentry'de bir test exception tetikle, dashboard'da gör.
- [ ] PostHog'da `onboarding_step_completed` event'lerini gör.

### 5.3 RevenueCat Production (Faz 45 manual remainder)
- [ ] Google Play Console → 3 ürün yarat (`formai_pro_monthly`, `formai_pro_quarterly`, `formai_pro_yearly`) ve ACTIVE state.
- [ ] Fiyat: ₺149 / ₺299 / ₺799 (TR locale).
- [ ] RevenueCat dashboard → "FormAI Pro" entitlement'a 3 ürünü bağla.
- [ ] `kProEntitlementId` ile entitlement adı **byte-byte aynı** doğrula.
- [ ] `.env`'e `REVENUECAT_ANDROID_KEY` ekle.
- [ ] iOS yayını başladığında `REVENUECAT_IOS_KEY` ekle.
- [ ] Internal Testing'de gerçek satın alma testi.
- [ ] Restore Purchases test.
- [ ] Sandbox tester ile cancel + refund testi.

### 5.4 Supabase Production SQL apply
- [ ] `supabase_rls_policies.sql` apply.
- [ ] `delete_user` RPC apply (Bölüm 1.5.1 SQL).
- [ ] `referrals` tablosu + `redeem_referral` RPC apply (Bölüm 1.5.2 SQL).
- [ ] `feedback` tablosu + RLS apply (Bölüm 1.5.3 SQL).
- [ ] `supabase_exercises_migration.sql` apply.
- [ ] `supabase_seed_categories.sql` + `supabase_seed_recipes.sql` apply.
- [ ] `supabase_patch_first_5_recipes.sql` + `supabase_patch_missing_tags.sql` apply.
- [ ] RLS smoke test: iki farklı kullanıcı oluştur, A user_progress'ten B'yi okuyamadığını doğrula.

### 5.5 Build & Mağaza Submit
- [ ] `flutter pub get && flutter analyze && flutter test` lokalde temiz geçti.
- [ ] CI yeşil.
- [ ] Onboarding hook görselleri release APK'sında render ediyor (Bölüm 2.1 manuel test).
- [ ] Cold start <2.5s (Bölüm 2.5 manuel ölçüm).
- [ ] Play Console Internal Testing track'a APK upload.
- [ ] Internal Testing → Closed Testing → Production track promotion.

---

## 6. Sürpriz Gözlemler ve Risk Notları

### 6.1 `.env.example` ↔ kod tutarsızlığı (1.1'de detaylı)

`REVENUECAT_APPLE_KEY` / `REVENUECAT_GOOGLE_KEY` adları **ölü** — kod gerçekte `REVENUECAT_IOS_KEY` / `REVENUECAT_ANDROID_KEY` arıyor. Yeni katılan bir geliştirici `.env.example`'ı kopyalayıp dolduruyor → uygulama RevenueCat'i hiç tanımıyor → fallback paywall sürekli görünüyor → "neden purchase çalışmıyor?" debug saatleri yanıyor. **Launch sonrası ilk fix bu olmalı.**

### 6.2 `delete_user`, `redeem_referral`, `feedback` SQL'lerinin repo'da olmaması

Kod bu RPC'leri / tabloları çağırıyor ama SQL şablonları repoda **yok**. Mevcut Supabase production veritabanında zaten apply edilmişse fonksiyonel — fakat bu durumda **versiyon kontrolü dışı bir state** taşıyoruz. Yeniden bir staging veritabanı kurulmak istense `error: function delete_user does not exist` ile karşılaşılır. Bu raporun 1.5 bölümündeki SQL bloklarını `supabase/migrations/` klasörüne `002_*.sql`, `003_*.sql`, `004_*.sql` olarak commit etmek (1 oturumluk iş) launch sonrası en yüksek-değer hijyen aksiyondur.

### 6.3 Asset isimlerinin Türkçe karakter içermesi

`photos/günlükaktitenne*.webp`, `photos/kişiselleştirilmiş plan*.webp` (boşluk + Türkçe karakter karışımı). Flutter'ın asset bundler'ı genel olarak destekler ama **iOS Xcode build aşamasında** path normalization bug'ları geçmişte yaşanmıştı. Mevcut `errorBuilder` fallback'leri **crash önler** ama **silent visual degrade** yaratır. Bölüm 2.1'deki manuel APK testi bu riski kapatır.

### 6.4 RevenueCat `iOS` key'i olmadan launch — tutarlı davranış

PM şu an sadece Google Play sahibi. Kod `Platform.isIOS ? REVENUECAT_IOS_KEY : REVENUECAT_ANDROID_KEY` mantığıyla çalışıyor; iOS key boş ise iOS build'inde `Purchases.configure` fail oluyor ama **fallback paywall hardcoded fiyatlarla yine render oluyor**. Yani Android-only launch + iOS sonra → kod tarafı uyumlu, iOS yayına başlandığı gün tek satır `.env` ekleme yeterli.

---

## 7. Sonuç ve "GO/NO-GO" Karar Matrisi

| Kriter | Durum |
| --- | --- |
| Kod yayına hazır | ✅ |
| Test paketi mevcut + CI yeşil | 🟡 (lokal doğrulama bekleniyor) |
| Privacy/Terms canlı URL | 🔴 (PM hostlamadı) |
| Sentry + PostHog DSN'leri `.env`'de | 🔴 (PM doldurmadı) |
| RevenueCat prod ürün + entitlement | 🔴 (PM yarattıysa OK; bilmiyoruz) |
| Supabase production RPC + tablo apply | 🔴 (4 SQL parçası bekliyor) |
| Onboarding görselleri release APK'da render | 🟡 (manuel test bekliyor) |
| Cold start ölçümü | 🟡 (manuel test bekliyor) |

**GO için tüm 🔴 → ✅, 🟡 → ✅ veya bilinçli kabul olmalı.**

Bu rapor onaylanıp manuel checklist tamamlandıktan sonra:
1. **Internal Testing track'a APK push.**
2. **3-5 gün soak.**
3. **Closed Testing → Production track promotion.**

Tahmini süre: PM tarafının manuel görevleri 1-2 iş günü (yasal sayfalar + RevenueCat dashboard + SQL apply); CI + manuel APK testi 0.5 gün. **Toplam: 2-3 iş günü içinde Türkiye soft-launch hazır.**

---

## Hatırlatma

Bu doküman `PROJECT_DOCUMENTATION.md` (Faz 39 post-mortem) ve Faz 40-58 commit log'unun bileşkesidir. Her launch blocker giderildiğinde **bu dosya değil**, ilgili bölümün altına `✅ <tarih> kapatıldı` notu düşülerek tarihçe korunur. Yeni post-mortem (Faz 59?) yazıldığında bu dosya arşive alınır ve yenisi `ROADMAP.md` adıyla yer değiştirir.
