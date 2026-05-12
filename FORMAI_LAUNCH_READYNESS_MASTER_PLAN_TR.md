# 🚀 FORMAI — LAUNCH READINESS MASTER PLAN

> **Versiyon:** 1.0 · Phase 137 — Full Application Launch Audit
> **Tarih:** 2026-05-12
> **Sahip:** Emre Dogan · `emredogan-cloud`
> **Branch:** `main` · **App Version:** `0.1.0+5` · **Package:** `com.emredogan.formaifit`
> **Belge tipi:** Founder-operational launch command center.

Bu belge FormAI'nin **geliştirme aşamasından canlı yayına geçişi** için tek doğru kaynaktır. Boş tavsiye yok — somut dosya yolları, satır numaraları, blockerlar, çözüm adımları, Play Console'da hangi butona tıklayacağına kadar.

---

## 📑 İÇİNDEKİLER

1. [TL;DR — Yayına Çıkabilir miyiz?](#1-tldr--yayına-çıkabilir-miyiz)
2. [Mevcut Durum Özeti (Sayılarla)](#2-mevcut-durum-özeti-sayılarla)
3. [🔴 Kritik Blockerlar (Launch Engelleri)](#3--kritik-blockerlar-launch-engelleri)
4. [🟠 High-Severity Sorunlar (Launch Öncesi Şiddetle Önerilir)](#4--high-severity-sorunlar)
5. [🟡 Medium-Severity Sorunlar (Polish / Launch Sonrası Kabul Edilebilir)](#5--medium-severity-sorunlar)
6. [🟢 Üretime Hazır Olan Kısımlar](#6--üretime-hazır-olan-kısımlar)
7. [⚡ EN HIZLI GÜVENLİ LAUNCH YOLU (7–10 Gün)](#7--en-hızlı-güvenli-launch-yolu)
8. [📘 Google Play Yayın Operasyon Kılavuzu (Adım Adım)](#8--google-play-yayın-operasyon-kılavuzu)
9. [🛬 Post-Launch Öncelik Yol Haritası](#9--post-launch-öncelik-yol-haritası)
10. [⚠️ Launch Sonrası En Büyük Riskler ve Mitigasyon](#10-️-launch-sonrası-en-büyük-riskler)
11. [📋 Eylem Listesi (Ana Checklist)](#11--eylem-listesi-ana-checklist)
12. [📎 Ek: Referans Dosya ve Hat Sayıları](#12--ek-referans-dosya-ve-hat-sayıları)

---

## 1. TL;DR — Yayına Çıkabilir miyiz?

### Verdict: **"BLOCKED — 6 kritik blocker var. İç test (Internal Testing) için hazır, Production rollout için DEĞİL."**

| Aşama | Durum | Süre |
|---|---|---|
| **Production Rollout (Genel Açık Sürüm)** | 🔴 **HAYIR** | 7–10 gün düzeltme |
| **Closed Testing (Kapalı Test, 100 kullanıcıya kadar)** | 🟠 **Belirli koşullarla** | 3–4 gün düzeltme |
| **Internal Testing (İç Test, 100 kişiye kadar)** | 🟢 **EVET, bugün yüklenebilir** | bugün |

**Brutally honest değerlendirme:** Uygulama mimari olarak %90 hazır. Phase 94 startup resilience, ProGuard kapsamı, RevenueCat 3-tier paywall, Sentry PII scrubbing, dark/light theme, Türkçe lokalizasyon, 19-adımlı sinematik onboarding, 138 egzersiz, 15 analyzer ile pose detection — bunların hepsi çalışıyor.

**Ama yayını engelleyen şeyler:**
1. Upload keystore parolası plaintext olarak repoda (güvenlik açığı)
2. `flutter build appbundle` çıktısı yok (Play Store .aab zorunlu)
3. Asset path hatası — runtime'da çökme tetikleyebilir
4. KVKK + COPPA için yaş kapısı yok
5. RevenueCat receipt validation server tarafında yapılmıyor (compliance riski)
6. Admin paneli sadece UI'da gizli (RLS yok)

Bu 6 blockerın hepsi **toplam 1–2 mühendislik haftası** içinde çözülebilir.

---

## 2. Mevcut Durum Özeti (Sayılarla)

### Teknik Stack
- **Framework:** Flutter 3.41.9 (manuel kurulum, `~/dev/flutter`)
- **State:** flutter_riverpod ^3.3.1
- **Routing:** go_router ^17.2.1
- **Backend:** supabase_flutter ^2.5.6 (auth + storage + RLS)
- **IAP:** purchases_flutter ^8.1.1 (RevenueCat)
- **AI/CV:** google_mlkit_pose_detection ^0.14.1 (cihaz üzerinde)
- **Analytics:** posthog_flutter ^5.3.0
- **Crash:** sentry_flutter ^9.6.0
- **Notifications:** flutter_local_notifications ^21.0.0

### Boyut & Kapasite
| Metrik | Değer |
|---|---|
| Toplam Dart lib/ kod | ~80+ feature modülü |
| Release APK (universal) | **138 MB** |
| Release APK (arm64-v8a) | **119 MB** |
| AAB tahmini boyut | ~50–60 MB (sıkıştırılmış) |
| `photos/` dizini | 70 MB |
| `assets/` dizini | 3.4 MB |
| Egzersiz sayısı | 138 (Phase 96 sonrası) |
| Egzersiz analyzer | 15 sınıf, 94 ID kapsamı |
| Onboarding adım | 19 ekran (≈8–10 dakika) |
| Abonelik tier | 3 (`formai_pro_monthly` / `_3month` / `_annual`) |
| minSdk / targetSdk | 24 / 36 (✅ Play Console 2025+ uyumlu) |

### Yayın Hedefi
- **Platform:** Google Play (Android) — **iOS sonra**
- **Pazar:** Türkiye birincil, Türkçe-first
- **Para birimi:** TRY (₺249,99 / ay, ₺499,99 / 3 ay, ₺999,99 / yıl)
- **Free Trial:** 7 gün ücretsiz deneme (Play Console üzerinden)

---

## 3. 🔴 Kritik Blockerlar (Launch Engelleri)

Launch için **kesinlikle** kapatılması gereken sorunlar. Tahmini toplam: **3–5 mühendislik günü.**

---

### B-1 · Upload Keystore Parolası Plaintext (GÜVENLİK)

**Dosya:** `/home/emre/Downloads/SixPack-AI/android/key.properties`
**Sorun:** `storePassword=formai123` ve `keyPassword=formai123` plaintext.
**Risk:** Eğer bu dosya git geçmişinde ya da CI loglarında sızarsa, **upload keystore'un kontrolü dışına çıkar** — Play Store'a senin adına başkası APK yükleyebilir. Bu **anahtar değişimi gerektiren** geri dönülmez bir hatadır.

**Neden önemli (Founder bakış açısı):** Play Store her app için tek bir upload key'e bağlıdır. Bu çalınırsa app'ı silmen ya da yeniden ismini değiştirip yeni bir paketle başlatman gerekir. 200 indirme aldıysan o varlığı kaybedersin.

**Çözüm:**
1. `android/key.properties` dosyasının `.gitignore`'da olduğunu doğrula (✅ `/android/.gitignore:14` zaten orada).
2. Eski `upload-keystore.jks` ve `key.properties`'i SİL (yedek al önce).
3. Yeni keystore üret:
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias formai-upload
   ```
   Parola olarak **en az 24 karakter rasgele** kullan (örnek: `openssl rand -base64 24`).
4. Yeni parolayı **1Password / Bitwarden** gibi bir kasaya kaydet.
5. `key.properties`'i yeni parolalarla yeniden oluştur (bu dosya repoda DEĞİL).
6. **ÖNEMLİ:** İlk yayınlama Play Console üzerinden Play App Signing'i aktif et — Google senin için bir app signing key tutar ve sen sadece upload key'i kullanırsın. Upload key'i kaybedersen Google'a kanıt göndererek yenileyebilirsin.

**Zorluk:** Kolay (15 dakika).
**Aciliyet:** İLK İŞ.

---

### B-2 · Eksik Asset Dosyaları (Runtime Crash Riski) — ✅ ÇÖZÜLDÜ (Phase 138)

**Dosya:** `lib/features/workout/data/workout_repository.dart`
**Orijinal audit (Phase 137):** 2 cardio webp eksik (cardio_mobility_stretch, cardio_full_body_flow).

**Phase 138 derin inceleme keşfi:** Orijinal audit'ten sonra 2 cardio dosyası filesystem'e eklendi (PNG içerikli `.webp` uzantısı, 1.86 MB + 1.98 MB; Flutter magic-byte ile decode eder, sorun yok). Ancak `_regionalTemplates` ve `_equipmentTemplates` listesindeki **22 farklı `_PlanTemplate.image` referansı** dosya yok — Bölgeler tab ve Equipment strip her açıldığında 22 ayrı "Unable to load asset" event fırlatıyordu.

Eksik 22 referans (substitüsyon uygulandı):

| Eksik referans | Yeni atanan dosya |
|---|---|
| core_static_resistance | core_athletic |
| core_lower_abs | core_steel_abs |
| core_oblique_burner | core_athletic |
| core_mobility_flow | core_steel_abs |
| chest_bodyweight_burst | chest_full_growth_burst |
| chest_plyo_explosive | chest_activation_growth |
| chest_beginner_flow | chest_fat_burn_basic |
| back_bodyweight_activation | back_v_taper |
| back_postural_corrective | back_posture_basic |
| back_hanging_workout | back_v_taper |
| shoulders_advanced_bodyweight | shoulders_giant |
| shoulders_mobility_opening | shoulders_v_taper |
| shoulders_scapular_stability | shoulders_power_burst |
| arms_bodyweight_burst | arms_quick_tone |
| arms_triceps_bodyweight | arms_steel |
| arms_hanging_grip | arms_explosive_super |
| legs_glute_activation | legs_quad_strength |
| legs_single_leg_bodyweight | legs_cardio_strength |
| legs_plyometric_burst | legs_elite_sculpt |
| legs_sumo_adductor | legs_power_day |
| cardio_hiit_burst | cardio_full_body_burst |
| cardio_shadow_box | cardio_morning_quick |

**Validation:**
- `comm -23 <dart-refs> <filesystem-files>` → 0 eksik referans.
- `flutter analyze lib/features/workout/data/workout_repository.dart` → No issues found.
- Runtime: `Image.asset` her `_PlanTemplate.image` için artık bundled bir webp resolve ediyor; precache zinciri Sentry'ye event göndermiyor.

**Risk / takip:**
- Cards şimdi muscle-group bazlı paylaşımlı hero imagery kullanıyor (örn. core_athletic 3 template'e servis ediyor). Launch-blocker değil — bespoke art post-launch polish.
- Filesystem'deki 2 büyük PNG-as-webp dosyası (1.86 + 1.98 MB) decode oluyor ama APK'ya +3.7 MB ekliyor. Post-launch optimize edilebilir.
- 4 orphan dosya tespit edildi (push_limits_*.webp) — referanssız ama bundled. Toplam ~400 KB; ihmal edilebilir.

**Commit:** `54a6cb2` — fix(workout): phase 138 B-2 - map 22 missing webp refs to existing assets
**Push:** ✅ `0b6a8b0..54a6cb2 main -> main`
**Rollback:** `git revert 54a6cb2` (dönüş visual-fallback gradient'lerine ve event spam'a).

---

### B-3 · App Bundle (.aab) Üretilmemiş

**Sorun:** Şu anda repoda sadece `.apk` çıktıları var. Google Play **yeni uygulamalar için `.aab` (Android App Bundle) zorunlu** (Ağustos 2021'den beri).

**Risk:** Play Console "Yeni Sürüm Oluştur" sayfasında .apk yüklemen reddedilir. Play 138 MB universal APK yerine cihaz başına 50–60 MB split bundle indirmesini ister.

**Çözüm:**
```bash
# Production build (signed):
flutter build appbundle --release

# Çıktı: build/app/outputs/bundle/release/app-release.aab
```

Bu adım için **B-1 (yeni keystore) tamamlanmış olmalı** çünkü .aab Play Store upload'a senin upload key'inle imzalanmış olmalı.

**Doğrulama:**
```bash
# Bundle'ın imzalı olduğunu kontrol et:
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

**Zorluk:** Kolay (5 dakika, build için 5–10 dakika derleme).
**Aciliyet:** Launch'tan hemen önce, her sürüm için.

---

### B-4 · Yaş Kapısı Yok (COPPA / Play Politikası) — ✅ ÇÖZÜLDÜ (Phase 138)

**Karar (founder onayı):** 18+ hard threshold — PhysicalDataStep wheel'inin alt sınırı (18) ve Play Console "Target audience: 18+" önerisi (Adım O) ile aligned.

**Uygulanan mimari:**
- Yeni route: `AppRoutes.ageGate` (`/age-gate`).
- Yeni dosya: `lib/features/onboarding/presentation/age_gate_screen.dart`. Year-of-birth Cupertino wheel (1940–güncel yıl, default 2000) + "Devam Et" CTA. < 18 sonucu non-dismissible block ekranıyla `SystemNavigator.pop()`.
- Yeni AppPreferences alanları: `ageVerified`, `setAgeVerified({required int birthYear})`, `birthYear`. Persist anahtarları: `sixpack.age_verified`, `sixpack.birth_year`.
- Router redirect: `isFirstTime && !ageVerified` → `/age-gate`; `isFirstTime && ageVerified` → `/onboarding`. Legacy install'ler (`isFirstTime=false`) grandfathered.
- `PopScope(canPop: false)` Android back gesture'ı bloklar — gate'ten çıkışın tek yolu birth year submit veya `SystemNavigator.pop()`.

**Sorun:** Onboarding'de yaş alanı var (`wizard_provider.dart` içinde `age: int?`) ama **13 yaşından küçükler için engelleyici kontrol yok**.

**Risk:**
- Play Store **Children & Families** politikası gereği eğer uygulaman 13 yaş altına yönelik **değilse**, mutlaka yaş kapısı koymalısın.
- Eğer 13 yaş altı kullanıcılara veri toplarsan (analytics, e-mail, photo) **Play tarafından askıya alınma** riski yüksek.
- KVKK + GDPR 16 yaş altı için ebeveyn onayı ister (EU).

**Neden önemli:** Yaş kapısı olmadan Play Console "Data Safety" formunu doğru dolduramazsın. Form yanlış doldurulursa app rejected.

**Çözüm:** Onboarding'deki yaş seçim adımına aşağıdaki kontrolü ekle:
```dart
// onboarding wizard step (yaş adımı sonunda)
if (selectedAge < 13) {
  // Kullanıcıyı nazikçe bilgilendir ve onboarding'i sonlandır:
  showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Üzgünüz'),
    content: const Text(
      'FormAI 13 yaş altı kullanıcılar için uygun değildir. '
      'Lütfen bir yetişkin eşliğinde değerlendirin.'
    ),
    actions: [
      TextButton(
        onPressed: () => SystemNavigator.pop(),
        child: const Text('Uygulamayı Kapat'),
      ),
    ],
  ));
  return;
}
```

13-15 yaş arası için (KVKK gri alan) ek bir "Velin onaylıyor mu?" checkbox ekleyebilirsin. Konservatif yaklaşım: 18+ kısıtlaması ve store listing'de "Rated for 12+" işaretlemek.

**Zorluk:** Kolay (1 saat: kod + Play Console Data Safety formu).
**Aciliyet:** Production rollout öncesi MUTLAKA.

**Validation:**
- `flutter analyze lib/core lib/features/onboarding` → No issues found.
- Router redirect testleri (manuel akış):
  - Fresh install → `/age-gate` (onboarding'e ulaşmıyor).
  - Birth year 2010 → block screen, "Uygulamayı Kapat" → SystemNavigator.pop().
  - Birth year 2000 → `setAgeVerified` → `/onboarding`.
  - Sonraki açılışlarda gate atlanıyor (verified flag).
- Analytics consent compatibility: gate ekranı PostHog event göndermiyor; onboarding step_0 event'i sadece gate geçildikten sonra ateşleniyor.

**Risks:**
- Self-attestation seviyesinde rigor (kullanıcı yalan söyleyebilir). Play Console Data Safety formundaki "age gate var mı?" sorusu için yeterli.
- Under-18 mode için forward path: `_minAge` düşür + parental consent branch ekle; gate'i silme.

**Commit:** `3e7b0b8` — feat(onboarding): phase 138 B-4 - 18+ age verification gate
**Push:** ✅ `3ae8302..3e7b0b8 main -> main`
**Rollback:** `git revert 3e7b0b8` (legacy users impact: bir kez `/onboarding`'a re-route, harmless).

---

### B-5 · RevenueCat Receipt Validation Server-Side Yok — 🟡 CODE HAZIR, PM/Founder DEPLOY GEREKİYOR (Phase 138)

**Uygulanan mimari:**
- **Yeni tablo:** `public.pro_entitlements` (`supabase/migrations/003_create_pro_entitlements.sql`). Bir kullanıcı = bir satır; PK `user_id` → `auth.users(id)`. RLS: kullanıcı kendi satırını okuyabilir; yazma yalnızca `service_role` bypass ile (webhook fonksiyonu üzerinden).
- **Yeni edge function:** `supabase/functions/revenuecat-webhook/index.ts` (Deno). RC `Authorization: Bearer <shared-secret>` header'ını doğrular, event type → `is_active` mapping yapar, `last_event_id` ile idempotency-check, sonra upsert.
- **Founder runbook:** `supabase/functions/revenuecat-webhook/README.md` — deploy adımları, RC dashboard config, validation checklist.

**Client değişmedi (intentional):**
- `monetization_provider.dart`'taki `Purchases.getCustomerInfo()` okuması korundu — bu commit pure additive. Premium flow, paywall, restore akışları aynen çalışıyor.
- `pro_entitlements` tablosu future RLS-protected Pro endpoint'ler için bekliyor; client cross-check sonraki phase.

**Founder'ın yapması gereken (Claude bunları auto-execute ETMEZ):**
1. `openssl rand -base64 48` → güçlü shared secret üret, 1Password'a kaydet.
2. `supabase secrets set REVENUECAT_WEBHOOK_SECRET=<secret>` ile Supabase'e yükle.
3. Migration: `supabase db push --linked` (eğer remote bağlıysa) veya Supabase Studio SQL Editor üzerinden `003_create_pro_entitlements.sql` content'ini çalıştır.
4. Function deploy: `supabase functions deploy revenuecat-webhook --no-verify-jwt`. (JWT verify kapalı çünkü RC kullanıcı JWT'si göndermez — kendi Bearer header'ı ile auth eder.)
5. RC dashboard → Integrations → Webhooks → + Add:
   - URL: `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook`
   - Authorization header: aynı secret (RC otomatik `Bearer ` prefix ekler).
   - Event types: tüm subscription event'lerini enable et.
6. Sandbox validation (README'deki 5-step checklist).

**Sorun:** `supabase/functions/` dizini **yok**. RevenueCat entitlement'ı sadece client tarafında okunuyor (`monetization_provider.dart:96-99`).

**Risk:**
- Rootlu cihazda kullanıcı SharedPreferences'ı değiştirip premium'a geçebilir.
- RevenueCat webhook'u Supabase'e push etmiyorsa, kullanıcının subscription state'i Supabase'deki `profiles` tablosunda yansımıyor — RLS politikaları premium-only kaynakları koruyamıyor.
- Play Console subscription policy "Establish entitlement on a secure server" gereksinimini karşılamıyor.

**Neden önemli:** Bu sadece compliance değil, **gelir kaybı riski**. Premium'u bedavaya alanlar conversion'ı bozar.

**Çözüm:** Bir Supabase Edge Function yaz:

```typescript
// supabase/functions/revenuecat-webhook/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  // RevenueCat webhook auth header doğrulaması
  const authHeader = req.headers.get('Authorization')
  if (authHeader !== `Bearer ${Deno.env.get('REVENUECAT_WEBHOOK_SECRET')}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const body = await req.json()
  const event = body.event
  const userId = event.app_user_id

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION events
  const isActive = ['INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE'].includes(event.type)

  await supabase
    .from('profiles')
    .update({
      pro_active: isActive,
      pro_expires_at: event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null,
      pro_product_id: event.product_id,
      updated_at: new Date().toISOString(),
    })
    .eq('id', userId)

  return new Response('OK')
})
```

RevenueCat dashboard'da Webhook URL: `https://<your-project>.supabase.co/functions/v1/revenuecat-webhook`.

Sonra RLS politikalarını `profiles.pro_active = true` üzerine kur, client'taki `isProProvider`'ı Supabase'den de oku.

**Zorluk:** Orta (4–6 saat: edge function + RevenueCat webhook setup + RLS policy + client provider güncellemesi).
**Aciliyet:** Production rollout öncesi.

**Validation (Phase 138 code-side):**
- Edge function balance check (braces / parens / signature) → temiz.
- Migration SQL idempotent (`create table if not exists`, `drop trigger if exists` pattern).
- RLS test contract: anonymous + non-owner authenticated → 0 satır görür; service_role bypass yazabilir.
- Idempotency: `last_event_id` match'inde response `{ok:true, idempotent:true}`, satır mutate edilmez.

**Commit:** `e43859a` — feat(monetization): phase 138 B-5 - RevenueCat server-side validation
**Push:** ✅ `6da0f65..e43859a main -> main`
**Rollback:** `supabase functions delete revenuecat-webhook` + `DROP TABLE public.pro_entitlements CASCADE`. Flutter client değişmedi, pre-B-5 davranışına otomatik düşer.

**Open item (founder action required):** Deploy + RC dashboard config + sandbox validation. Bu adımlar yapılana kadar B-5 fiilen aktif değil — tablo + function repository'de bekliyor.

---

### B-6 · Admin Paneli Güvenlik Sınırı Değil — ✅ ÇÖZÜLDÜ (Phase 138)

**Bulgu (deep inspection):**
- Table-level RLS `public.recipes` ve `public.exercises` üzerinde Phase 50A'da zaten doğru kurulu (`supabase/sql/rls_policies.sql`). INSERT/UPDATE/DELETE `app_metadata.role = 'admin'` gerektiriyor.
- **Storage gap:** Admin form'lar `recipes_images`, `exercises_media`, `exercises` bucket'larına `uploadBinary` çağırıyor (admin_recipe_form.dart:413, admin_exercise_form.dart:628). Phase 74'ün `fix_video_storage_rls.sql` dosyası SELECT'i public açıyor ama **WRITE policy yok** → herhangi bir authenticated kullanıcı (Supabase anonymous auth dahil) admin bucket'larına arbitrary media yükleyebilir.

**Uygulanan mimari:** `supabase/migrations/004_admin_storage_rls.sql`:
- Table-level admin RLS defensive olarak yeniden assert ediliyor (idempotent).
- `storage.objects` üzerinde 3 yeni policy: `admin_buckets_insert / update / delete`. Predicate: `bucket_id in (...) AND app_metadata.role = 'admin'`.
- Public SELECT policy'leri (video + image okuma) korunuyor.

**RPC ve diğer admin yüzeyler:**
- `delete_user` ve `redeem_referral` RPC'leri — per-user, `auth.uid()` ile internal scope; admin gate'i gerekmiyor.
- Admin-only ek RPC tespit edilmedi.

**Dosya:** `lib/core/routing/app_router.dart:120-124`, `lib/features/admin/`
**Sorun:** Admin paneline erişim router'da JWT `app_metadata['role']=='admin'` kontrolü ile gateleniyor. Bu sadece **UI gate'i** — kriptografik bir güvenlik sınırı değil.

**Risk:** Eğer Supabase tablolarının RLS politikaları admin rolünü kontrol etmiyorsa, JWT'sini elle düzenleyen kullanıcı admin endpoint'lere REST üzerinden erişebilir.

**Çözüm:**
1. Supabase Studio → SQL Editor → her admin tablosuna (exercises, recipes vs. yazma yetkisi gerektirenler) RLS policy ekle:
   ```sql
   -- Örnek: exercises tablosuna admin INSERT izni
   CREATE POLICY "Admins can manage exercises"
   ON exercises FOR ALL
   USING (
     (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
   );
   ```
2. `app_metadata` `user_metadata`'dan farkı **kullanıcının kendisi değiştiremez** — sadece service role anahtarıyla değişir. Bu doğru kullanım.

**Zorluk:** Orta (2 saat: tüm admin tablolarını listele, her birine policy yaz, test et).
**Aciliyet:** Production öncesi.

**Validation steps (founder run-book — migration uygulanınca):**
1. Supabase Studio → Auth → Users → bir test kullanıcısı seç → app_metadata'dan `role` sil. JWT yenilensin.
2. Bu kullanıcıyla `storage.objects` üzerine `INSERT (bucket_id='recipes_images', name='test.jpg', owner=auth.uid())` → RLS reject olmalı.
3. Aynı kullanıcıya `{"role":"admin"}` ata, JWT yenilensin → aynı INSERT geçmeli.
4. `curl` ile anon endpoint'ten `/storage/v1/object/public/exercises/<filename>` → 200 OK (read path bozulmadı).

**Commit:** `9a99a18` — feat(security): phase 138 B-6 - admin storage RLS hardening
**Push:** ✅ `b93b802..9a99a18 main -> main`
**Rollback:** Migration'daki 3 write policy'yi drop et; public SELECT'ler kalır. Pre-B-6 davranış: "yazma herhangi bir authenticated user için açık", bu zaten kapatmak istediğimiz regression.

**Open item (founder action required):** Migration'ı uygula. `supabase db push --linked` veya Supabase Studio SQL Editor üzerinden `004_admin_storage_rls.sql` content'ini çalıştır.

---

## 4. 🟠 High-Severity Sorunlar

Launch'ı durdurmaz ama günler içinde ilk 100 kullanıcı sorun yaşatabilir. **Closed Testing'e geçmeden önce çözmen önerilir.**

---

### H-1 · Onboarding Mid-State Persistence Yok — ✅ ÇÖZÜLDÜ (Phase 138)

**Uygulanan mimari (commit `dfec2ca`):**
- `WizardState.fromJson` + `WizardController.restoreFromJson` — checkpoint blob'undan tam state geri kurma. Eski versiyon checkpoint'ler için forward-compatible (missing field → default).
- `AppPreferences.saveWizardCheckpoint / loadWizardCheckpoint / clearWizardCheckpoint` — anahtarlar: `sixpack.wizard_state_json` + `sixpack.wizard_step_index`.
- `OnboardingScreen.initState`: checkpoint senkron olarak restore ediliyor (flash of step 0 yok). Bozuk blob → log + clear.
- `ref.listenManual<WizardState>`: 25+ setter'ı tek tek dekore etmeden her mutation'da autosave.
- `_next()` / `_back()`: provider mutation olmayan step transition'lar için de explicit checkpoint write.
- `_finish()`: `completeOnboarding()` sonrası checkpoint temizleniyor (re-onboarding fresh başlasın).

**Validation:**
- `flutter analyze lib/features/onboarding lib/core` → No issues.
- Decode tolerance: enum token / nullable int / missing key / malformed list — hepsi safe.
- Step index clamp: bir release değişiminde `_totalSteps` farklı olsa bile kullanıcı sınır dışına stranded olmuyor.

**Risks:**
- Provider mutation başına disk write. SharedPreferences in-memory + async flush → düşük cost. Per-character typing ÇAĞRILMIYOR çünkü TextField setX() commit'te fire ediyor. Profiling baskı gösterirse Timer ile debounce.

**Commit:** `dfec2ca` — feat(onboarding): phase 138 H-1 + H-7 - wizard checkpoint persistence
**Rollback:** `git revert dfec2ca`. saveUserMetrics intact, sadece checkpoint key kaybolur, in-memory wizard'a dönülür.

**Dosya:** `lib/features/onboarding/providers/wizard_provider.dart`, `lib/features/onboarding/presentation/onboarding_screen.dart:200`
**Sorun:** Wizard state in-memory (Riverpod). 8. adımda app crash'lerse veya kullanıcı backgrounddan döndüğünde OS app'ı öldürmüşse, 0'dan başlıyor.

**Etki:** 19 adımlık 8–10 dakikalık onboarding'de %30+ drop-off olası. PostHog funnel data hâlâ adımları izliyor ama recovery yok.

**Çözüm:** Her `_next()` çağrısında wizard state'ini SharedPreferences'a `sixpack.wizard_state_json` anahtarıyla yaz. `initState()`'te restore et.

```dart
// wizard_provider.dart
Future<void> _persistState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('sixpack.wizard_state_json', jsonEncode(state.toJson()));
  await prefs.setInt('sixpack.wizard_step_index', _currentStepIndex);
}

// onboarding_screen.dart initState'te
final saved = prefs.getString('sixpack.wizard_state_json');
if (saved != null) {
  ref.read(wizardProvider.notifier).restoreFromJson(jsonDecode(saved));
  _index = prefs.getInt('sixpack.wizard_step_index') ?? 0;
}
```

**Zorluk:** Kolay-Orta (2-3 saat).
**Aciliyet:** Yüksek.

---

### H-2 · KVKK / Analytics Consent Banner Yok

**Sorun:** PostHog `main.dart:324-339`'da onboarding'den önce başlatılıyor. KVKK (6698) `açık rıza` gerektirir.

**Risk:** Türkiye'de KVKK çağrıyla 20.000–1.500.000 TL idari para cezası verebilir. Düşük olasılık ama yüksek hasarlı risk.

**Çözüm:** İlk açılışta (`_BootGate` sonrasında, onboarding'den önce) bir consent dialog:

```dart
// İlk açılışta gösterilir, prefs.consentAccepted=false ise.
showDialog(
  barrierDismissible: false,
  builder: (_) => AlertDialog(
    title: const Text('Gizlilik Tercihlerin'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'FormAI deneyimini iyileştirmek için anonim kullanım '
          'verileri toplar. İstediğin zaman kapatabilirsin.'
        ),
        CheckboxListTile(
          title: const Text('Anonim analytics kabul ediyorum'),
          value: consentAnalytics,
          onChanged: ...,
        ),
        CheckboxListTile(
          title: const Text('Crash raporları (anonim) kabul ediyorum'),
          value: consentCrash,
          onChanged: ...,
        ),
      ],
    ),
    actions: [
      TextButton(
        child: const Text('Sadece zorunlu'),
        onPressed: () => _saveAndContinue(analytics: false, crash: false),
      ),
      FilledButton(
        child: const Text('Hepsini kabul et'),
        onPressed: () => _saveAndContinue(analytics: true, crash: true),
      ),
    ],
  ),
);
```

Eğer kullanıcı reddederse `Posthog.disable()` ve Sentry `enabled: false` ile init et.

**Zorluk:** Orta (3-4 saat).
**Aciliyet:** Türkiye launch öncesi yüksek.

---

### H-3 · OnBackInvokedCallback Android 12+ Hatası

**Dosya:** `android/app/src/main/AndroidManifest.xml`
**Sorun:** Logcat'te tekrarlayan uyarı: `OnBackInvokedCallback is not enabled for the application`.

**Risk:** Android 13+ predictive back gesture devre dışı. Kullanıcı UX'te küçük bir bozukluk görür. Crash yok ama Play Console "App Quality" sinyali düşer.

**Çözüm:** `<application>` tag'ine ekle:
```xml
<application
    android:label="FormAI"
    android:name="${applicationName}"
    android:icon="@mipmap/launcher_icon"
    android:enableOnBackInvokedCallback="true">
```

**Zorluk:** Trivial (1 dakika).
**Aciliyet:** Düşük ama trivial olduğu için hemen yap.

---

### H-4 · ML Kit Eski Cihazda Crash Riski

**Dosya:** `lib/features/workout/presentation/workout_camera_screen.dart`
**Sorun:** `google_mlkit_pose_detection: ^0.14.1` `minSdk=24` cihazlarda çalışır, ama ML Kit Play Services bulunmayan eski cihazlarda (örn. eski Huawei, ROM modifiyeli) init throw eder.

**Çözüm:** Camera screen'de Play Services availability kontrolü:
```dart
// workout_camera_screen.dart
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

Future<bool> _checkMlKitAvailable() async {
  try {
    final detector = PoseDetector(options: PoseDetectorOptions());
    await detector.close();
    return true;
  } catch (e) {
    return false;
  }
}

// ML Kit yoksa: timed mode fallback
if (!await _checkMlKitAvailable()) {
  // Pose detection yerine: süre bazlı sayım, manuel "Bitti" butonu
  return _TimedWorkoutMode();
}
```

**Zorluk:** Orta (3-4 saat).
**Aciliyet:** Yüksek (her crash %0.5 conversion düşürür).

---

### H-5 · Egzersiz Safety / Kontrendikasyon Filtresi Yok

**Dosya:** `lib/features/workout/models/workout_plan_model.dart`, generator
**Sorun:** Onboarding'de sağlık durumu (kalp problemi, sırt fıtığı, hamilelik) sorulmuyor. Generator herkese aynı pool'dan seçim yapıyor.

**Risk:**
- Fitness app sorumluluk yasası gri alan.
- KOAH, kalp, omurga problemi olan kullanıcının yüksek tempolu HIIT yapması medikal sorun yaratırsa Play Store şikayet üzerine app'ı askıya alabilir.

**Çözüm (MVP):**
1. Onboarding'e bir disclaimer adımı ekle:
   > "Sağlık problemin varsa antrenmana başlamadan önce doktoruna danış. Onaylıyorum: ☐"
2. Egzersiz modeline `contraindications: List<String>` (örn. `['lower_back', 'shoulder']`) ekle.
3. Generator'da kullanıcının seçtiği injury'leri filtreden hariç tut.

**Daha sonra:** Tam onboarding'de "Geçmişte yaralanma yaşadın mı?" sorusu.

**Zorluk:** Orta (1 gün — model + generator + UI).
**Aciliyet:** Orta-Yüksek (compliance + UX).

---

### H-6 · ProGuard'a Supabase Keep Rule Eksik

**Dosya:** `android/app/proguard-rules.pro`
**Sorun:** Supabase Java SDK obfuscation altında reflection kullanan dataclass'lar kırılabilir.

**Çözüm:** Ekle:
```
-keep class com.supabase.** { *; }
-keep class io.supabase.** { *; }
-dontwarn com.supabase.**
-dontwarn io.supabase.**

# Riverpod (genelde safe ama insurance):
-keep class com.tudorpop.flutter_riverpod.** { *; }
```

**Zorluk:** Trivial.
**Aciliyet:** Orta — Release smoke test'e kadar bekleyebilir.

---

### H-7 · Anonymous → Email Geçişinde Wizard State Kaybı — ✅ ÇÖZÜLDÜ (H-1 ile birlikte, commit `dfec2ca`)

H-1'in autosave mimarisi her wizard mutation'ında state'i SharedPreferences'a yazıyor. Auth ekranına ulaşmadan ÖNCE state zaten persist edilmiş olduğu için `_persistWizardMetrics`'in early-return koşulu (gender + age null) artık problem değil — checkpoint kanalı bağımsız olarak çalışıyor ve OnboardingScreen relaunch'da state'i geri yüklüyor.

**Dosya:** `lib/features/auth/presentation/auth_screen.dart:45-49`
**Sorun:** Auth flow `gender + age` doluysa metrics kaydediyor, değilse yutuyor.

**Çözüm:** Auth ekranına girmeden önce **her durumda** wizard state'i SharedPreferences'a yaz (H-1'in çözümü bu sorunu da çözüyor).

**Zorluk:** H-1 ile birleşik.
**Aciliyet:** Yüksek.

---

## 5. 🟡 Medium-Severity Sorunlar

Launch'ı engellemez, soft-launch + iterasyonla çözülebilir.

| ID | Konu | Çözüm | Tahmini Süre |
|---|---|---|---|
| M-1 | `PopScope(canPop: false)` onboarding'de eksik | Android back'i geçişli yapma | 30 dk |
| M-2 | Workout camera mid-session back-press confirm yok | "Antrenmanı bırak?" dialog | 1 saat |
| M-3 | `_restTimer` / `_prepTimer` lifecycle audit | dispose'da cancel'ı kontrol et | 1 saat |
| M-4 | `network_security_config.xml` yok | XML ekle, cleartext denied | 30 dk |
| M-5 | "30 günde karın kası" sağlık iddiası | Disclaimer ekle: "Sonuçlar diet + tutarlılığa bağlı" | 30 dk |
| M-6 | Notification icon explicit declare yok | `<meta-data android:name="com.dexterous...default_notification_icon" .../>` | 30 dk |
| M-7 | SharedPreferences write fail catch yok (`_finish()`) | try/catch + toast | 30 dk |
| M-8 | Camera "in use by another app" exception | try/catch + retry dialog | 1 saat |
| M-9 | Year-in-review yıl sonu dışında manual entry | "Yolculuğunu Gör" pill ekle | 1 saat |
| M-10 | "Pending/Deferred" purchase state explicit handle yok | `PurchaseOutcome.pending` ekle | 1 saat |
| M-11 | Notifications icon test Android 13+ | Emulator test | 1 saat |

---

## 6. 🟢 Üretime Hazır Olan Kısımlar

Bunları **bozmaman gerekiyor** — bunlar app'ın güçlü tarafı.

### 6.1 Startup Resilience (Phase 94)
- **Dosya:** `lib/main.dart:46-148`
- 4 katmanlı error guard (`runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` + `ErrorWidget.builder`)
- `.env` eksikse de boot ediyor → `_MissingConfigurationError` ekranı
- Sentry init failure'da bile `runApp` çağrılıyor
- Supabase 8s timeout, PostHog 5s timeout
- **Black screen riski yok** (deleted RELEASE_BLACK_SCREEN_ROOT_CAUSE_REPORT.md sorunu çözülmüş)

### 6.2 ProGuard / R8 Hardening
- **Dosya:** `android/app/proguard-rules.pro`
- ML Kit pose + vision keep ✓
- MediaPipe internals keep ✓
- CameraX/Camera2 keep ✓
- Sentry / PostHog / RevenueCat keep ✓
- Google Sign-In v7 keep ✓
- flutter_local_notifications Gson keep ✓
- home_widget keep ✓
- Firebase components keep ✓

### 6.3 RevenueCat Integration
- **Dosya:** `lib/features/monetization/`
- 3 tier ürün ID doğrulanmış: `formai_pro_monthly`, `formai_pro_3month`, `formai_pro_annual`
- Restore Purchases butonu ✓
- Manage Subscription (Play Store deep link) ✓
- Auto-renewal disclosure ✓ (`paywall_screen.dart:1567-1571`)
- Terms + Privacy linkleri tappable ✓
- Free trial CTA "7 gün ücretsiz dene" ✓
- Race prevention (CTA gated on `_purchasesConfigured && offerings != null`) ✓
- Debug bypass `kDebugMode` ile sınırlı ✓

### 6.4 Sentry PII Scrubbing
- **Dosya:** `lib/main.dart:114-125`
- `beforeSend` hook user.email, ipAddress, data alanlarını temizliyor
- `sendDefaultPii` false (default)

### 6.5 Privacy Policy + Terms URL Live
- **Dosya:** `lib/core/utils/legal_urls.dart:17-18`
- `https://d2srybp77lgcpy.cloudfront.net/privacy.html`
- `https://d2srybp77lgcpy.cloudfront.net/terms.html`
- CloudFront üzerinden serve, tappable.

### 6.6 Account Deletion Flow (KVKK/GDPR)
- **Dosya:** `lib/features/auth/providers/auth_provider.dart:289-322`
- Supabase RPC `delete_account()` (SECURITY DEFINER) implemented
- SharedPreferences temizleniyor
- Session sıfırlanıyor

### 6.7 Camera ML Kit Disclosure
- **Dosya:** `lib/features/workout/presentation/workout_camera_screen.dart:178-226`
- OS permission'dan **önce** explainer dialog
- Turkish text: "Görüntüler kaydedilmez ve hiçbir sunucuya gönderilmez"
- Permanently denied state handle ediliyor

### 6.8 Onboarding Sinematik Akışı (Phases 124-133)
- 19 ekran, 3 act yapısı (Hook → Bonding → Buildup → Revelation → Commitment)
- Coach chat micro-conversation
- AI thinking cadence + depth
- PostHog funnel tracking her adımda
- Türkçe-first, hiç İngilizce fallback yok
- Equipment soru + safe filter (Phase 133)

### 6.9 Workout Engine
- 138 egzersiz, deterministic client-side generation
- Fingerprint cache (`goal|level|hasEquipment`)
- 15 analyzer + SilentHoldAnalyzer fallback
- Camera lifecycle (didChangeAppLifecycleState dispose)
- Wakelock enable/disable matched
- Single-flight gate (`_isProcessingFrame`)
- 15 FPS throttle (thermal-safe)

### 6.10 XP / Badge / Level System (Phase 3.B/C)
- Üç ayrı ledger: `awardedSessionDays`, `awardedBadgeIds`, `awardedStreakMilestones`
- Idempotent — restart'ta double-fire yok
- LevelUp animations route-gated (dashboard topmost'ken)

### 6.11 Dark + Light Theme Parity
- **Dosya:** `lib/core/theme/app_theme.dart`
- Her iki mod fully supported, system setting respected
- Bottom nav + snackbar + status bar flip ediyor

### 6.12 Android Manifest
- targetSdk 36 (Play Console 2025+ compliant)
- minSdk 24 (ML Kit MediaPipe requirement)
- Permissions justified: CAMERA, INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, USE_EXACT_ALARM, SCHEDULE_EXACT_ALARM
- Hiçbir sensitive permission (LOCATION, RECORD_AUDIO, READ_MEDIA_*) yok

---

## 7. ⚡ EN HIZLI GÜVENLİ LAUNCH YOLU

**Hedef:** 7–10 gün içinde Play Store **Production rollout** (%10 staged).

### Gün 0–1: Güvenlik Sıfırla
- [ ] B-1: Yeni keystore üret + parolayı kasaya at
- [ ] B-3: `flutter build appbundle --release` ile ilk .aab üret
- [ ] B-6: Supabase RLS policies admin tabloları için
- [ ] H-3: `enableOnBackInvokedCallback` ekle (1 dk)
- [ ] H-6: Supabase keep rule ekle (1 dk)

### Gün 2: Asset + Crash Önleyiciler
- [ ] B-2: Eksik 2 cardio webp'sini çöz (Option A: rename, Option B: gerçek dosya ekle)
- [ ] H-4: ML Kit availability check + timed mode fallback
- [ ] H-1 + H-7: Wizard mid-state persistence (2-3 saat)

### Gün 3: Compliance
- [ ] B-4: Yaş kapısı (1 saat)
- [ ] H-2: KVKK consent banner (3-4 saat)
- [ ] B-5: RevenueCat webhook Supabase function (4-6 saat)

### Gün 4: Smoke + UX Patch
- [ ] M-1: `PopScope(canPop: false)` onboarding
- [ ] M-2: Workout back-press confirm
- [ ] M-7: SharedPreferences fail catch
- [ ] M-5: "30 günde" disclaimer
- [ ] M-10: Pending purchase outcome
- [ ] H-5: Egzersiz safety disclaimer + basit injury filter

### Gün 5: Internal Testing Upload
- [ ] **Play Console → Internal Testing** track'e .aab yükle
- [ ] 5–10 kişiyle yarım gün test
- [ ] Sentry'de 0 crash, 0 missing asset event olduğunu doğrula
- [ ] PostHog funnel'da onboarding tamamlanma oranı %50+

### Gün 6: Closed Testing
- [ ] Internal'dan Closed Testing'e promote
- [ ] 20–50 tester davet et (Telegram + Twitter beta listesi)
- [ ] Play Console Store Listing'i doldur (sonraki bölüm)
- [ ] Data Safety formunu doldur
- [ ] App Content questionaire'i tamamla

### Gün 7–8: Closed Test Monitoring
- [ ] Crash-free rate izle: hedef >%99
- [ ] Sentry'de yeni event olursa fix
- [ ] PostHog conversion funnel: paywall→purchase >%5

### Gün 9: Production Submission
- [ ] Production track'e Closed'dan promote
- [ ] Staged Rollout: %10 başlat
- [ ] Crash/review/uninstall metric'lerini izle 24-48 saat

### Gün 10: Tam Rollout
- [ ] Sorunsuzsa %100
- [ ] Sorun varsa rollback (%0 staged → yeni AAB hazırla)

---

## 8. 📘 Google Play Yayın Operasyon Kılavuzu

Bu bölüm sıfırdan Play Console'a ilk uygulamasını yükleyen bir kurucu için yazılmıştır. Hangi butona basacağına kadar.

### 8.1 Hazırlık Checklist (Tüm Adımlar Öncesi)

```
☐ Google Play Console hesabı ($25 lifetime)
☐ Geliştirici kimliği doğrulanmış (KVK + Tax ID)
☐ Yayın AAB dosyası hazır
☐ Privacy Policy URL (formai.app/privacy)
☐ Terms of Service URL (formai.app/terms)
☐ Destek e-posta adresi (support@formai.app)
☐ Geri ödeme politikası URL'si (opsiyonel)
☐ Uygulama ikonu 512x512 PNG
☐ Feature graphic 1024x500 PNG
☐ En az 2 telefon ekran görüntüsü 1080x1920+
☐ Tablet ekran görüntüsü (opsiyonel ama önerilir)
☐ App description (kısa + uzun) Türkçe
☐ App category seçimi (Health & Fitness)
☐ Test cihazlarında çalıştığı doğrulanmış AAB
```

### 8.2 Play Console İlk Kurulum

#### Adım A — Uygulama Oluştur
1. **Play Console → All apps → "Create app" (sağ üst)**
2. **App details:**
   - **App name:** `FormAI` (max 50 karakter)
   - **Default language:** `Turkish - tr-TR`
   - **App or game:** `App`
   - **Free or paid:** `Free` (in-app subscription olduğu için)
3. **Declarations:**
   - "Developer Program Policies" checkbox: ✓
   - "US export laws" checkbox: ✓
4. **Create app**

#### Adım B — Geliştirici Profili (eğer yeni)
1. **Settings → Developer account → Account details**
2. Doldur: Display name (genel görünüm), email, phone, address (KVK gerektirir)
3. **Settings → Payments profile** (subscription geliri için Google'a banka bilgisi)

### 8.3 Internal Testing — İlk Yükleme

#### Adım C — Internal Test Track Oluştur
1. **Sol menü: Test ve Yayınla → Test → İç Test (Internal Testing)**
2. **"Create new release"**
3. **App signing by Google Play:** Onayla (Google senin için signing key tutar, sen sadece upload key kullanırsın)
   - Eğer önce upload key vermiş olman gerekiyor: "Use Play App Signing → Upload a key signed with the upload certificate"
   - `upload-cert.pem`'i yükle (zaten projede var: `/upload-cert.pem`)
4. **App bundles → Upload:** Drag&drop ile `build/app/outputs/bundle/release/app-release.aab`
5. **Release name:** `0.1.0 (5) — Internal Test 1`
6. **Release notes (Turkish):**
   ```
   İlk iç test sürümü.

   - 19 adımlık sinematik onboarding
   - 138 egzersiz, AI form analizi
   - 30 günlük antrenman programı
   - Premium tier (RevenueCat)
   ```
7. **Save → Review release → Start rollout to Internal testing**

#### Adım D — Testers Ekle
1. **Test ve Yayınla → Test → İç Test → Testers tab**
2. **Create email list:** "FormAI Internal" gibi bir isim
3. CSV ya da elle 100 kişiye kadar e-posta ekle
4. **Save → Copy invite link** → Telegram/WhatsApp gruplarına gönder
5. Her tester linkten kendi Google hesabıyla "Accept invite"
6. Sonra Play Store'da arama yaparak FormAI'yi bulup indirebilir

#### Adım E — Internal Test Doğrula
- 3-5 gerçek cihazda yükle (Android 8 / 11 / 13 / 14 — fragmentasyon test)
- Onboarding bitir → paywall göster → test purchase (Play Console'da test hesabını "License Testing" altında "tester" olarak ekle)
- Crash olursa Sentry'de gör + fix → yeni AAB → Adım C tekrar (versionCode bumple, otomatik `flutter.versionCode`)

### 8.4 Closed Testing — 20-100 Beta Kullanıcı

#### Adım F — Closed Test Track
1. **Test ve Yayınla → Test → Kapalı Test (Closed Testing) → Create new track**
2. Track name: `Beta` (örnek)
3. **Create new release**, AAB'i yükle (genelde Internal'dan promote edebilirsin: "Promote release → Closed testing → Beta")
4. Release notes ekle (kısa, kullanıcı yüzlü)
5. Testers tab → email list "FormAI Beta" → daha geniş davet
6. **Start rollout**

#### Adım G — Closed Test Periyodu
- En az 14 gün → Google'ın "Production'a geçmek istiyor musun?" propmtu için **14 gün'lük closed test geçmişi gerekiyor** (yeni geliştirici hesapları için)
- Bu sürede crash-free %, conversion, retention izle
- Sorun yoksa Production'a promote

### 8.5 Store Listing — Marketing Sayfası

#### Adım H — Main Store Listing
1. **Büyütme → Store presence → Main store listing**
2. **App name (Turkish):** `FormAI — Yapay Zeka Fitness Koçun`
3. **Short description (max 80 karakter):**
   > `30 günde formuna kavuş. AI form analizi + kişisel antrenman.`
4. **Full description (max 4000 karakter):**
   ```
   FormAI, fitness yolculuğunda yanında yapay zeka destekli özel
   antrenörün gibi davranan bir uygulamadır.

   ✦ 30 GÜNLÜK KİŞİSEL PROGRAM
   Hedefin, deneyim seviyen ve ekipman durumuna göre özel
   programlanır.

   ✦ AI FORM ANALİZİ
   Telefonunun kamerası ile egzersiz formunu cihazında analiz eder.
   Görüntüler kaydedilmez, hiçbir sunucuya gönderilmez.

   ✦ 138 EGZERSİZ
   Karın, göğüs, sırt, bacak, kol, omuz — her bölge için bilimsel
   seviyeli antrenmanlar.

   ✦ İLERLEME TAKİBİ
   XP, seviye, rozet — oyunlaştırılmış motivasyon.

   ✦ BESLENME ÖNERİLERİ
   Kalori takibi, tarif kütüphanesi, haftalık yemek planlama.

   ✦ KÜÇÜK BAŞLA, BÜYÜK SONUÇ
   İlk 3 günü ücretsiz dene, sonra FormAI Pro ile devam et.

   FormAI Pro — Premium Üyelik:
   • Aylık ₺249,99
   • 3 Aylık ₺499,99
   • Yıllık ₺999,99 (en avantajlı)
   • 7 gün ücretsiz deneme

   Aboneliği istediğin zaman Play Store'dan iptal edebilirsin.

   Gizlilik Politikası: https://formai.app/privacy
   Kullanım Şartları: https://formai.app/terms

   * Sonuçlar bireysel çabaya, beslenmeye ve tutarlılığa göre değişir.
     Sağlık problemin varsa antrenmana başlamadan önce doktoruna danış.
   ```

#### Adım I — Graphic Assets
1. **App icon:** 512x512 PNG (zaten `tool/app_icon.png` mevcut, scale up)
2. **Feature graphic:** 1024x500 PNG (Play Store header görseli — `asosystem/` klasöründen)
3. **Phone screenshots (zorunlu):** En az 2, max 8 adet 1080x1920 PNG/JPEG
   - Önerilen sıra: Onboarding hero → Workout in action → AI analiz overlay → Progress dashboard → Paywall
4. **7-inch tablet screenshots (opsiyonel):** 1920x1200 — eğer tablet desteklemiyorsan boş bırak
5. **10-inch tablet screenshots (opsiyonel):** 2560x1600

#### Adım J — Categorization
1. **App category:** `Health & Fitness`
2. **Tags:** "Fitness", "Workout", "Personal Trainer", "AI Coach"
3. **Contact details:**
   - Email: `support@formai.app`
   - Website: `https://formai.app`
   - Phone: opsiyonel

### 8.6 App Content — Politika Sayfaları

Burası kritik. Yanlış doldurursan **app rejected**.

#### Adım K — Privacy Policy
1. **Politika ve programlar → App content → Privacy policy**
2. URL: `https://d2srybp77lgcpy.cloudfront.net/privacy.html`
   (Üretim için: kendi domain'inden serve edersen daha sağlam)
3. **Save**

#### Adım L — App Access
1. **App content → App access**
2. **All functionality is available without special access:** ❌ NO (auth gerekli)
3. Test credentials sağla:
   - **Username/email:** `playreview@formai.app` (özel olarak oluşturduğun)
   - **Password:** Güçlü bir parola
   - **Instructions:**
     ```
     1. Open the app.
     2. Tap "Email ile devam et" on auth screen.
     3. Sign in with the above credentials.
     4. Onboarding will appear — complete all 19 steps.
     5. Pro features visible after step "Plan Detail".
     ```

#### Adım M — Ads
1. **App content → Ads → Does your app contain ads?**: **No** (FormAI reklamsız)

#### Adım N — Content Rating (IARC Questionnaire)
1. **App content → Content rating → Start questionnaire**
2. Email: `support@formai.app`
3. **Category:** `Reference, News, or Educational` (Health/Fitness için)
4. Sorular (FormAI için tipik cevaplar):
   - Violence: **No**
   - Sexual content: **No**
   - Strong language: **No**
   - Controlled substances: **No**
   - Gambling: **No**
   - User-generated content sharing: **No**
   - Personal info sharing: **No**
   - Location sharing: **No**
5. **Submit** → Sonuç: tahmini **Everyone (Herkes)** rating

#### Adım O — Target Audience and Content
1. **App content → Target audience and content**
2. **Target age groups:** `18+ only` (çocuklara yönelik DEĞİL — yaş kapısı koyduğun için)
3. **Appeal to children:** **No, my app is not designed for children**
4. **Save**

#### Adım P — Data Safety (EN ÖNEMLİ)
Bu form yanlış doldurulursa Play Store kalıcı olarak app'ı reject eder.

1. **App content → Data safety → Start**
2. **Does your app collect or share any of the required user data types?** YES

**Veri kategorileri (FormAI için):**

| Veri Tipi | Topluyor mu? | Paylaşıyor mu? | Optional? | Amaç |
|---|---|---|---|---|
| **Personal info / Name** | YES | NO | Yes | App functionality (kullanıcının ismi koç chat'inde) |
| **Personal info / Email address** | YES | NO | No | Account management |
| **Personal info / User IDs** | YES | NO | No | Account management, Analytics (anonymized) |
| **Health and fitness / Health info** | YES | NO | No | App functionality (boy, kilo, BMI) |
| **Health and fitness / Fitness info** | YES | NO | No | App functionality (workout logs) |
| **Photos and videos / Photos** | NO | NO | — | Camera frames on-device only, **transmit edilmiyor** |
| **Camera / Camera** | YES | NO | Yes | App functionality (pose detection, **veri saklanmaz**) |
| **Financial info / Purchase history** | YES | NO | No | App functionality (RevenueCat → Supabase) |
| **App activity / In-app actions** | YES | NO | Yes | Analytics, App functionality (PostHog, anonim) |
| **App activity / Crash logs** | YES | NO | Yes | Analytics (Sentry, scrubbed) |
| **App activity / Diagnostics** | YES | NO | Yes | Analytics |
| **Device or other IDs** | YES | NO | Yes | Analytics (PostHog anonymized) |

**Security practices:**
- ✅ Data is encrypted in transit (HTTPS to Supabase/RevenueCat/Sentry/PostHog)
- ✅ Users can request data deletion (account deletion flow exists)
- ✅ Users can request their data
- ✅ Privacy policy URL provided

3. **Save → Submit for review**

#### Adım R — News App / Health App declarations
1. **App content → Health declarations** (Health & Fitness category için ZORUNLU)
2. **Does your app provide health information?** YES (workout suggestions)
3. **Are health features substantiated?** Açıklama: "Workout suggestions are general fitness guidance based on user-reported preferences (goal, experience, equipment). Not medical advice. Disclaimer shown in onboarding."
4. **Does it process Protected Health Information (PHI)?** NO

#### Adım S — Government App / Financial App declarations
**Skip** (uygulanmıyor).

#### Adım T — News
**Skip** (uygulanmıyor).

#### Adım U — COVID-19 contact tracing
**Skip** (uygulanmıyor).

### 8.7 Pricing — Subscription Setup

#### Adım V — Subscription Products Tanımla
1. **Para kazanma → Monetization setup → Subscriptions → Create subscription**
2. **Product ID:** `formai_pro_monthly` (kod ile birebir aynı olmalı)
3. **Name:** `FormAI Pro — Aylık`
4. **Description:** `Tüm premium özelliklere sınırsız erişim`
5. **Subscription period:** `1 month`
6. **Free trial:** `7 days` (Play Console'da seçilen tier'a göre)
7. **Pricing:**
   - Default price: `₺249.99 TRY`
   - Other countries: Auto-convert (önerilir) ya da elle gir
8. **Tax & compliance:** KDV otomatik Türkiye'de eklenir
9. **Save and add another** → 3 ay + yıllık için de aynısı:
   - `formai_pro_3month` — `₺499.99 TRY` — `3 months`
   - `formai_pro_annual` — `₺999.99 TRY` — `1 year` — Free trial 7 gün

#### Adım W — RevenueCat ↔ Play Sync
1. **RevenueCat Dashboard → Projects → FormAI → Apps → Google Play**
2. Service Account JSON yükle: `formai-494015-f262599d264a.json` (zaten repoda var)
3. **Bundle ID:** `com.emredogan.formaifit`
4. Test: RevenueCat dashboard'da "Test purchase" Play Console license testing modunda

### 8.8 Production Release

#### Adım X — Production Track
1. **Test ve Yayınla → Production → Create new release**
2. AAB upload (Closed'dan promote etmek daha güvenli: "Promote release → Production")
3. **Release name:** `0.1.0 (5) — Soft Launch`
4. **Release notes (Turkish, max 500 karakter per lokal):**
   ```
   İlk genel sürüm! 🚀

   Bu sürümde:
   ✦ AI form analizi ile 138 egzersiz
   ✦ 30 günlük kişisel program
   ✦ 7 gün ücretsiz Pro deneme
   ✦ Türkçe sesli antrenör

   Geri bildirim için: support@formai.app
   ```
5. **Countries / regions:**
   - Başlangıç önerisi: SADECE **Türkiye** (Turkey)
   - 1-2 hafta sonra: KKTC + diğer Türkçe konuşulan bölgeler
6. **Rollout:** **Staged rollout %10** (kritik!)
7. **Review release → Start rollout to Production**

#### Adım Y — Submission to Review
- Google review süresi: 24 saat–7 gün (yeni geliştirici hesaplarında daha uzun)
- Status: `In review` → `Pending publication` → `Live`
- Email notification gelir.

### 8.9 Post-Submission Monitoring

#### Adım Z — Day 1-7 İzleme
1. **Quality → Android vitals**
   - Crash rate: hedef <%1
   - ANR rate: hedef <%0.5
2. **Quality → Reviews & ratings**
   - 1-3★ yorumlara <24 saat içinde yanıt ver
3. **Test ve Yayınla → Pre-launch report**
   - Google'ın otomatik test cihazlarındaki crash raporları
4. **PostHog → Funnels**
   - Onboarding tamamlanma: hedef >%40
   - Paywall → purchase: hedef >%3
   - Day 1 retention: hedef >%30
5. **Sentry → Issues**
   - Yeni crash zero olmalı
   - Eğer yeni issue: triage → fix → patch release (versionCode bump)

#### Adım AA — Staged Rollout Genişletme
- 24 saat %10'da sorunsuzsa → **Production → Manage → Resume rollout → 25%**
- 48 saat sorunsuzsa → **50%**
- 72 saat sorunsuzsa → **100%**

Sorun çıkarsa: **Halt rollout** (rollout dondurulur, yeni indirici alamaz, mevcutlar etkilenmez).

---

## 9. 🛬 Post-Launch Öncelik Yol Haritası

İlk 90 gün için öncelikler:

### Hafta 1: Stabilizasyon
1. **Crash-free %99.5+** sağla. Sentry alerts'i Slack'e bağla.
2. **Play Console reviews:** her 1-3★ yorumun 24 saat içinde yanıtla.
3. **PostHog funnel anomaly:** her gün onboarding → paywall → purchase dropoff'unu izle.

### Hafta 2-4: Retention Tuning
4. **Day 1 retention <%30** ise → onboarding cinematic'i kısalt (Phase 124'ün geri kanadı).
5. **Day 7 retention <%15** ise → push notification template'lerini gözden geçir.
6. **Day 30 retention <%5** ise → workout difficulty curve'unu düşür.

### Ay 2: Subscription Optimization
7. **Paywall A/B test:** RevenueCat Experiments ile fiyatlandırma + CTA copy + tier sırası test et.
8. **Win-back campaign:** Churn olan kullanıcılara 50% indirim push (RevenueCat retention API).
9. **Annual emphasis:** Yıllık planı default seçili getir (en yüksek ARPU).

### Ay 3: AI & Yeni Özellikler
10. **LLM-driven coach chat:** Anthropic Claude API ya da Supabase Edge Function üzerinden gerçek AI chat (şu an hardcoded text).
11. **More analyzers:** SilentHold'a giden 53 egzersiz için yenileri (sırt, omuz egzersizleri öncelikli).
12. **Health Connect entegrasyonu:** Google Fit'ten weight + step verisi (kullanıcı opt-in).

### Sürekli (Her Hafta)
- **App Store Optimization (ASO):** Screenshot + description + tag A/B test.
- **Community building:** Twitter/X + Instagram'da day-by-day kullanıcı dönüşüm hikayeleri.
- **Localization:** İngilizce + Arapça eklemek için intl/l10n setup.

---

## 10. ⚠️ Launch Sonrası En Büyük Riskler

### Risk 1 — Churn (En Büyük)
**Sebep:** Free trial sonunda otomatik abonelik başladığında kullanıcı "Bilmiyordum" der ve iptal eder.

**Mitigasyon:**
- Trial bitmeden 24 saat önce push notification: "Trial yarın bitiyor, beğenmedinse şimdi iptal edebilirsin."
- RevenueCat Cancel Flow A/B test.
- PostHog `subscription_cancelled` event'e churn survey ekle.

### Risk 2 — Performance Variance (Eski Cihaz)
**Sebep:** Android 8-10'lu eski cihazlarda pose detection ısınması + frame drop.

**Mitigasyon:**
- Sentry'de cihaz başına crash rate dashboard'u.
- minSdk 24 (low-end exclude) zaten doğru.
- H-4 (ML Kit availability fallback) production'a kadar bitir.

### Risk 3 — App Size & Install Fail
**Sebep:** Universal APK 138 MB. AAB ile 50-60 MB olsa bile mobile data'da indirme yapan kullanıcı vazgeçer.

**Mitigasyon:**
- `flutter build appbundle --release --split-debug-info=...` ile debug sembolleri ayır.
- `photos/` 70 MB → recipe/onboarding görsellerini WebP'den AVIF'a düşürmek (Phase 138+ önerisi).
- Play Console size threshold: 100 MB üstü "Large download warning" gösterir.

### Risk 4 — Subscription Conversion Düşüklüğü
**Sebep:** Türkiye'de premium fitness app conversion %1-3 (genel pazar). Bizim hedef %5.

**Mitigasyon:**
- Paywall kopya A/B testi (RevenueCat Experiments).
- Free-tier'in 3 günlük süresi optimize: belki 7 güne çıkar.
- Yıllık tier'da gerçek savings highlight: "₺2.999,99 idi" daha agresif.

### Risk 5 — Crash Spikes (Beklenmedik)
**Sebep:** Cihaz fragmentation (özellikle MIUI, OneUI custom ROM'lar).

**Mitigasyon:**
- Sentry Slack alerting kur: yeni issue >5 user etkilediğinde anında haber.
- Patch release SLA: kritik crash → 48 saat içinde patch AAB.

### Risk 6 — Weak Review Count
**Sebep:** Yeni app'lerin ranking'i ilk 50-100 review'a bağlı.

**Mitigasyon:**
- App-in-app review prompt (Day 30 + workout streak >=14 olduğunda).
- Beta tester'lardan review iste (Closed Test sonrası).
- Twitter beta listesi → erken adopter community.

### Risk 7 — Poor First-Session Completion
**Sebep:** Kullanıcı onboarding bitirir ama ilk antrenmanı tamamlamaz (camera permission red, ML Kit donma).

**Mitigasyon:**
- H-4 (ML Kit fallback) MUTLAKA bitir.
- Onboarding sonrası 30 saniye **demo workout** koy (kamera değil, animasyon).
- Sentry'de `workout_session_started` vs `workout_session_completed` ratio izle.

### Risk 8 — Play Policy Rejection
**Sebep:** "30 günde karın kası" gibi unsubstantiated claim, yaş kapısı eksik, data safety form yanlış.

**Mitigasyon:**
- Store listing'de "Sonuçlar bireysel çabaya bağlıdır" disclaimer.
- B-4 yaş kapısı kesinlikle ekle.
- Data Safety formunu B-5 (RevenueCat webhook server-side validation) ile uyumlu doldur.

### Risk 9 — Oversized Crash from Old Subscriptions
**Sebep:** Eski `_quarterly` / `_yearly` ürün ID'leri Play Console'da yetim kalırsa, restore flow bunları okuyup hata atabilir.

**Mitigasyon:**
- Play Console subscription'lar listesinde sadece 3 ürün olduğundan emin ol.
- Kod tarafında `formai_pro_quarterly` ve `formai_pro_yearly` string'lerini ara, hiçbiri kalmamış olmalı (memory'deki Phase 93 notunda confirmed dead).

### Risk 10 — Supabase Quota / Cost Patlaması
**Sebep:** Free tier 500MB DB + 2GB egress. 1000 kullanıcı egzersiz video stream'le hızla aşar.

**Mitigasyon:**
- CloudFront CDN (CDN_BASE_URL .env'de boş şu an) production'da SET et.
- Supabase pro tier ($25/ay) hazırda dursun.
- Egzersiz videoları CloudFront'a sync (manuel ya da otomatik pipeline).

---

## 11. 📋 Eylem Listesi (Ana Checklist)

### 🔴 BLOCKER — Launch İçin Mutlaka Kapatılması Gerekenler

```
[ ] B-1  Yeni upload keystore üret, parolayı kasaya at, key.properties yenile
[x] B-2  ✅ 22 eksik webp referansı (regional + equipment templates) substitüsyonla çözüldü — commit 54a6cb2
[ ] B-3  flutter build appbundle --release ile imzalı .aab üret
[x] B-4  ✅ 18+ age gate (founder onayı) — /age-gate route + year picker + block screen — commit 3e7b0b8
[~] B-5  🟡 Code hazır (commit e43859a) — founder deploy + RC dashboard config bekliyor (README'de runbook)
[~] B-6  ✅ Code hazır (commit 9a99a18) — admin storage RLS migration uygulanması bekliyor
```

### 🟠 HIGH — Closed Testing'e Geçmeden Önce

```
[x] H-1  ✅ Wizard checkpoint autosave + restore (commit dfec2ca)
[ ] H-2  KVKK consent banner (Posthog/Sentry'den önce gösterilir)
[ ] H-3  AndroidManifest'e enableOnBackInvokedCallback="true"
[ ] H-4  ML Kit availability check + timed mode fallback (eski cihaz)
[ ] H-5  Egzersiz safety disclaimer + basic injury filter
[ ] H-6  ProGuard rules: Supabase keep + dontwarn
[x] H-7  ✅ H-1 autosave channel mid-flow loss'u kapatıyor (commit dfec2ca)
```

### 🟡 MEDIUM — Soft Launch Sırasında / Sonrasında

```
[ ] M-1   PopScope(canPop: false) onboarding screen'e
[ ] M-2   Workout camera mid-session Android back confirm dialog
[ ] M-3   _restTimer / _prepTimer dispose audit
[ ] M-4   network_security_config.xml ekle (cleartext denied)
[ ] M-5   Health claims disclaimer (Play Store listing + in-app)
[ ] M-6   Notification icon explicit declare in AndroidManifest
[ ] M-7   onboarding _finish() SharedPreferences write try/catch
[ ] M-8   Camera "in use by another app" exception handle
[ ] M-9   Year-in-review manual entry pill
[ ] M-10  Pending/Deferred purchase outcome explicit handle
[ ] M-11  Notifications Android 13+ runtime permission test
```

### 📦 PLAY CONSOLE OPERASYON

```
[ ] PC-1  Google Play Console hesabı + $25 ödendi
[ ] PC-2  Developer profile complete (KVK, tax, payments)
[ ] PC-3  App created (FormAI, com.emredogan.formaifit)
[ ] PC-4  App signing — Play App Signing onaylandı
[ ] PC-5  Internal Test track kuruldu, ilk AAB yüklendi
[ ] PC-6  Internal testers (10-20 kişi) davet edildi
[ ] PC-7  Privacy Policy URL girdildi
[ ] PC-8  App access test credentials sağlandı
[ ] PC-9  Content rating questionnaire submitted
[ ] PC-10 Data Safety form completed
[ ] PC-11 Target audience: 18+ Only
[ ] PC-12 Health declaration submitted
[ ] PC-13 Subscription products tanımlandı (3 tier, TRY)
[ ] PC-14 Free trial 7 days (annual) configured
[ ] PC-15 RevenueCat service account JSON Play Console'a bağlandı
[ ] PC-16 Store listing dolduruldu (icon, screenshots, description)
[ ] PC-17 Feature graphic 1024x500 yüklendi
[ ] PC-18 Closed Testing track 14 gün boyunca çalıştı
[ ] PC-19 Production track Staged Rollout %10 başlatıldı
[ ] PC-20 Sentry + PostHog dashboards live monitoring
```

---

## 12. 📎 Ek: Referans Dosya ve Hat Sayıları

Hızlı referans için tüm önemli dosya yolları:

### Startup & Resilience
- `lib/main.dart:46-148` — 4-layer error guard (Phase 94)
- `lib/main.dart:114-125` — Sentry PII scrubbing
- `lib/main.dart:264` — Supabase 8s timeout
- `lib/main.dart:331-339` — PostHog 5s timeout

### Onboarding
- `lib/features/onboarding/presentation/onboarding_screen.dart` — Ana ekran
- `lib/features/onboarding/providers/wizard_provider.dart:263-306` — WizardState
- `lib/features/onboarding/presentation/steps/` — 19 ekran

### Workout Engine
- `lib/features/workout/services/analyzer_factory.dart` — 15 analyzer mapping
- `lib/features/workout/services/workout_generator_service.dart` — Plan generation
- `lib/features/workout/data/workout_repository.dart:971, 999` — **Eksik asset referansları**
- `lib/features/workout/presentation/workout_camera_screen.dart` — Camera + ML Kit
- `lib/features/workout/models/workout_plan_model.dart` — Plan model

### Monetization
- `lib/features/monetization/providers/monetization_provider.dart:16` — Entitlement ID "FormAI Pro"
- `lib/features/monetization/providers/monetization_provider.dart:209-238` — RevenueCat init
- `lib/features/monetization/presentation/paywall_screen.dart:1155-1159` — Fallback fiyatlar
- `lib/features/monetization/presentation/paywall_screen.dart:499-550` — Restore butonu

### Auth & Privacy
- `lib/features/auth/providers/auth_provider.dart:289-322` — `deleteAccount()` RPC
- `lib/core/utils/legal_urls.dart:17-18` — Privacy + Terms URL

### Android Native
- `android/app/build.gradle.kts` — Build config (signing, minify, ProGuard)
- `android/app/proguard-rules.pro` — 136 satır keep rules
- `android/app/src/main/AndroidManifest.xml` — Permissions + activities
- `android/key.properties` — **Plaintext parola, değiştirilmeli**

### Supabase
- `supabase/sql/` — Schema migrations
- `supabase/functions/` — **YOK** (RevenueCat webhook için oluşturulmalı)

### Telemetri & Logging
- `lib/core/services/analytics_service.dart` — PostHog wrapper
- `lib/core/services/app_logger.dart:35, 58, 87` — Sentry breadcrumbs
- `logs.txt` — Dev log (`Unable to load asset` hataları görülüyor)

---

## 🎯 Kapanış

FormAI **çok güçlü bir teknik temele** sahip. Phase 1'den 137'ye kadar inşa edilen mimari:
- Resilient startup
- Type-safe state management
- Server-backed auth + RLS
- Cinematic onboarding
- Production-grade pose detection
- 3-tier RevenueCat integration
- Türkçe-first localization

Bu güçlü temelin üzerinde 6 kritik blocker var ve hepsi **bir mühendislik haftası içinde çözülebilir**.

**Karar:**
1. Bu hafta blockerları kapat.
2. Önümüzdeki hafta Internal Testing → Closed Testing.
3. 3 hafta sonra Production Staged %10.
4. 4 hafta sonra %100 Türkiye launch.

Sonraki adım: **B-1 (keystore) ve B-2 (asset) ile başla. Bu ikisini bugün çözebilirsin.**

— Son —

> Bu belge `FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md` olarak commit edilmiştir. Her phase bittiğinde checkbox'ları güncelle. Launch sonrası ay 1'de yeniden audit gerekecektir.
