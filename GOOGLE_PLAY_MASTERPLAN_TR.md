# GOOGLE PLAY MASTERPLAN — FORMAI / SIXPACK AI

> **Belge tipi:** Confidential Founder Launch Playbook
> **Hazırlık:** Mobil büyüme stratejisi + Elite ASO playbook
> **Hedef pazar:** TR (öncelik) → MENA → Global (EN)
> **Paket adı:** `com.emredogan.formaifit`
> **App adı (mevcut):** SixPack AI — *30 Günde Karın Kası*
> **Stack:** Flutter 3.22+ / Supabase / RevenueCat / ML Kit Pose Detection
> **Abonelik SKU:** `formai_pro_monthly` · `formai_pro_3month` · `formai_pro_annual`

---

## İÇİNDEKİLER

1. [Google Play Yayın Stratejisi](#1-google-play-yayin-stratejisi)
2. [App Store Optimization (ASO)](#2-app-store-optimization-aso)
3. [İsim Önerileri ve Pozisyonlama](#3-i̇sim-onerileri-ve-pozisyonlama)
4. [İkon Stratejisi](#4-i̇kon-stratejisi)
5. [Screenshot Masterplan](#5-screenshot-masterplan)
6. [Feature Graphic Stratejisi](#6-feature-graphic-stratejisi)
7. [Play Store Psikolojisi](#7-play-store-psikolojisi)
8. [Rakiplerden Sıyrılma Stratejisi](#8-rakiplerden-siyrilma-stratejisi)
9. [Abonelik & Paywall Stratejisi](#9-abonelik--paywall-stratejisi)
10. [İlk 1000 Kullanıcı Stratejisi](#10-i̇lk-1000-kullanici-stratejisi)
11. [Yorum & Puan Stratejisi](#11-yorum--puan-stratejisi)
12. [Google Play Console Adım Adım](#12-google-play-console-adim-adim)
13. [Yayın Öncesi Checklist](#13-yayin-oncesi-checklist)
14. [Yayın Sonrası İlk 30 Gün Stratejisi](#14-yayin-sonrasi-i̇lk-30-gun-stratejisi)

---

## 1. GOOGLE PLAY YAYIN STRATEJİSİ

### 1.1 Stratejik Felsefe — "Sessiz Güç" Lansmanı

Bir fitness uygulaması için *en tehlikeli şey* lansmanı **production'a** doğrudan göndermektir. Play Store algoritması ilk 72 saatte uygulamaya bir "kalite skoru" atar; bu skor uninstall, crash-free, retention ve rating sinyalleriyle hesaplanır. **İlk 1.000 kullanıcı** algoritma için bir "future weight" yaratır. Bu yüzden önce cilalanır, sonra ölçeklendirilir.

### 1.2 Soft Launch Stratejisi (3 Faz)

#### **FAZ 0 — Internal Testing (Hafta 0-1)**
- **Katılımcı:** 5–15 kişi (dev ekibi + 2-3 yakın arkadaş)
- **Amaç:** Crash hunting, deep-link doğrulama, RevenueCat sandbox satın alma akışı
- **Kapı kriteri (gate):** %0 fatal crash, paywall %100 yüklenebilir, onboarding tam akış
- **Süre:** Maksimum 7 gün (uzun internal test demotivasyondur)

#### **FAZ 1 — Closed Testing / Soft Launch (Hafta 1-3)**
- **Hedef ülkeler:** Türkiye + 1 küçük "ısınma" pazarı (önerim: **Romanya, Polonya veya Vietnam**). Türkiye anadiliniz olduğu için ana ölçüm; ikinci ülke ise *İngilizce ASO* için ucuz veri toplama.
- **Katılımcı sayısı hedefi:** 200-500 kapalı test kullanıcısı
- **Kapı kriterleri:**
  - Crash-free users ≥ **%99,5**
  - D1 retention ≥ **%35**
  - D7 retention ≥ **%15**
  - Onboarding completion ≥ **%70**
  - Paywall view-to-purchase ≥ **%2,5**
- **Toplama yöntemleri:**
  - Reddit r/turkey, r/Tekirdag, r/istanbul, r/gym (yumuşak post)
  - Discord fitness sunucuları (3-5 niş sunucu)
  - Yakın çevre: WhatsApp grupları (kontrol grubu için ideal)

#### **FAZ 2 — Open Testing (Hafta 3-5)**
- Closed testing aşamasından gelen sinyaller temizken Play Store'da "Erken erişim" rozetiyle açılır
- Hedef: 1.000-3.000 yükleme
- Bu fazın amacı: ASO sinyallerini uyarmak (Google Play algoritması "open testing" kullanıcılarını da retention sinyali olarak okur)

#### **FAZ 3 — Production Staged Rollout (Hafta 5+)**
- **Aşamalı dağıtım:**
  - %1 → 24 saat izle
  - %5 → 48 saat izle
  - %20 → 48 saat izle
  - %50 → 72 saat izle
  - %100 → kapatma
- **Otomatik halt kriterleri:**
  - ANR rate > %0,47 (Google'ın "kötü davranış" eşiği) → ROLLBACK
  - Crash rate > %1,09 → ROLLBACK
  - Rating ortalaması bir günde 4,0 altına düşerse → DURDUR + araştır
  - Uninstall rate D1 > %35 → DURDUR + onboarding'i incele

### 1.3 Crash-Free Eşikleri (KESİN KURALLAR)

| Metrik | Hedef | Acil Eşik | Kritik Eşik |
|---|---|---|---|
| Crash-free users | ≥ %99,7 | %99,3 | %98,5 (rollback) |
| Crash-free sessions | ≥ %99,9 | %99,7 | %99,4 (rollback) |
| ANR rate | < %0,20 | %0,35 | %0,47 (Google penalize) |
| Excessive wakeups | < %5 | %8 | %10 |

### 1.4 Retention Hedefleri (Sektör Benchmarkları + Özel Hedef)

Fitness sektörü ortalamaları (referans: Adjust 2025 benchmark):
- Sektör D1: %25 — **FormAI hedef: %38+**
- Sektör D7: %10 — **FormAI hedef: %18+**
- Sektör D30: %3 — **FormAI hedef: %7+**

> **Neden bu yüksek hedefler?** AI pose detection, bir fitness uygulamasının commodity olmaktan çıktığı yerdir. Eğer retention sektör ortalamasındaysa, **AI özelliğinizi ya kullanıcı keşfetmiyor ya da onboarding çok zayıf** demektir.

### 1.5 KPI Roadmap (90 Gün)

| Hafta | Toplam İndirme | DAU | Trial → Paid | MRR | Rating |
|---|---|---|---|---|---|
| W1 | 500 | 200 | %3 | $50 | 4,3+ |
| W2 | 1.500 | 600 | %4 | $200 | 4,4+ |
| W4 | 5.000 | 1.500 | %5 | $700 | 4,5+ |
| W8 | 20.000 | 5.000 | %6 | $3.500 | 4,5+ |
| W12 | 60.000 | 12.000 | %7 | $12.000 | 4,5+ |

> **Kritik içgörü:** Trial-to-paid yüzdesi *zamanla artmalı* — çünkü ASO trafiği daha kaliteli kullanıcı getirmeye başlar. Eğer %5'te takılırsa paywall'ınızda yapısal bir sorun var.

---

## 2. APP STORE OPTIMIZATION (ASO)

### 2.1 ASO Felsefesi — "İndirme değil, dönüşüm"

ASO'nun %30'u keyword, %70'i conversion'dur. Çoğu kurucu keyword'lere takılır; oysa **listing'e gelen kullanıcının yüklemeye dönmemesi**, listing'i hiç görmeyen kullanıcıdan daha pahalıdır (algoritma sizi cezalandırır).

### 2.2 Türkçe Keyword Stratejisi

#### **Birincil semantic cluster — "Karın Kası / Six-Pack"**
- karın kası egzersizi
- 30 günde karın kası
- karın kası antrenmanı
- six pack uygulaması
- karın kası programı
- evde karın kası
- hızlı karın kası
- erkekler için karın kası

#### **İkincil cluster — "Form / Vücut Geliştirme"**
- ev antrenmanı
- evde spor
- vücut geliştirme uygulaması
- fitness uygulaması türkçe
- spor uygulaması
- fit kal
- form tutma

#### **Üçüncül cluster — "AI / Akıllı Antrenör"**
- yapay zeka antrenör
- ai fitness koçu
- akıllı antrenman programı
- kişisel antrenör uygulaması
- ai spor

#### **Pivot cluster — "Disiplin / Alışkanlık"**
- 30 gün challenge
- disiplin uygulaması
- alışkanlık takibi
- günlük antrenman
- streak fitness

#### **Long-tail (en az rekabet, en yüksek niyet)**
- 30 günde altı paket karın
- evde karın kası nasıl yapılır
- yapay zeka ile spor
- form takip uygulaması
- karın kası 4 hafta

### 2.3 İngilizce Keyword Stratejisi

#### **Birincil cluster — "Six-Pack / Abs"**
- six pack abs workout
- 30 day abs challenge
- ab workouts at home
- six pack in 30 days
- abs trainer
- core workout
- six-pack tracker

#### **İkincil cluster — "AI Fitness"**
- ai fitness coach
- ai personal trainer
- ai workout
- form check ai
- pose detection workout
- ai gym

#### **Üçüncül cluster — "Home Workout"**
- home workout men
- no equipment workout
- bodyweight training
- gym at home
- 7 minute abs

#### **Long-tail**
- abs workout for men no equipment
- ai form correction app
- six pack workout 30 day
- ai posture trainer fitness

### 2.4 Title Optimization

#### **Önerilen başlık (30 karakter):**
```
FormAI: Karın Kası AI Koçu
```
*30 karakter — Play Store hard limit.*

**Neden bu başlık?**
- "FormAI" → marka (SEO için sahiplenilebilir, marka sorgusu)
- "Karın Kası" → ana arama terimi (yüksek hacim, niyet)
- "AI Koçu" → diferansiyasyon + kategori (rakiplerin %95'i bunu söylemiyor)

#### **Alternatif başlıklar (A/B testing için):**
1. `FormAI — 30 Gün Karın Kası AI` (challenge + AI)
2. `Karın Kası AI: 30 Günlük Form` (keyword-first)
3. `FormAI: AI Fitness & Karın Kası` (genişletilmiş)

> **Tuzak:** Başlığa "ücretsiz" yazmak amatör algısı yaratır ve premium pozisyonu yok eder.

### 2.5 Subtitle / Short Description (80 karakter)

Play Store'da bu alan *aramaya en güçlü etkiyi yapan ikinci alandır*. 80 karakterin **her birini hak etmelisiniz**.

#### **Önerilen short description:**
```
AI form düzelten, 30 günde karın kası getiren akıllı fitness koçun.
```
*(78 karakter)*

#### **Alternatifler:**
1. `Yapay zeka antrenörünle 30 günde karın kası. Forma gir, disipline kal.` (74)
2. `30 günlük AI destekli karın kası programı. Evde, ekipmansız, kanıtlanmış.` (76)
3. `AI pose detection ile her hareketin sayılır. 30 günde altı paket.` (66)

### 2.6 Long Description Psikolojisi

Long description Play Store algoritması için **keyword density taraması** yapılan alandır. Ama insan kullanıcı bu alanın sadece **ilk 3 satırını** okur. Bu yüzden **iki katmanlı** yazılmalıdır.

#### **Yapı (sırayla):**

**Katman 1 — Hook (ilk 3 satır):**
- Bir sorun/hayal cümlesiyle başla
- Keyword içerme zorunlu değil — duygusal kanca öncelikli

```
30 gün önce başla. Aynanın karşısına çıktığında kendini tanıma.
FormAI, yapay zeka destekli karın kası antrenörün.
Form'unu düzeltir, ilerlemeni hatırlar, disiplinini ödüllendirir.
```

**Katman 2 — "Neden FormAI?" (4-7 satır):**
- Sosyal kanıt cümlesi (eğer varsa)
- 3 ana özellik bullet'ı
- Diferansiyasyon

**Katman 3 — Özellikler (keyword-rich):**
- 30 Günlük Karın Kası Programı
- AI Form Detection — her hareketin sayılır
- Akıllı Antrenör — vücuduna göre adapte olur
- Streak ve Disiplin Takibi
- Evde, Ekipmansız Antrenman
- Erkekler ve Kadınlar İçin Programlar

**Katman 4 — Premium ve abonelik (yasal zorunlu):**
- 7 günlük ücretsiz deneme
- Aylık / 3-aylık / yıllık planlar
- İptal kolay, trial ücretsiz
- Linkler: Gizlilik & KVKK

**Katman 5 — Gizli keyword sandığı (alt):**
- Kategori, alternatif sorgular
- "ai fitness koçu", "form takibi", "karın egzersizi" gibi 8-12 keyword

### 2.7 Semantic Keyword Clustering (Algoritma için)

Google Play'in BERT-tabanlı algoritması artık keyword *tekrarını* değil, **semantic alanı** ödüllendiriyor. Bu yüzden listing'inizde 5 farklı semantic alanın hepsi var olmalı:

| Semantic Alan | Anahtar Kavram | Yer |
|---|---|---|
| Body goal | karın kası, altı paket, sıkı | başlık + ilk paragraf |
| Method | AI, akıllı, form düzeltme | başlık + alt başlık |
| Time commitment | 30 gün, günlük, hafta | hook |
| Place | evde, ekipmansız | bullet |
| Identity | disiplin, challenge, form | tagline |

### 2.8 Competitor Keyword Gaps

Türkiye Play Store'unda fitness rakiplerinin (Fitify, Workout for Men, Home Workout — No Equipment) keyword analizi yapıldığında **boşluklar:**

| Boşluk Keyword | Aylık arama (tahmini) | Rekabet |
|---|---|---|
| "yapay zeka antrenör" | Orta | Düşük |
| "30 gün karın kası" | Yüksek | Orta |
| "ai form düzeltme" | Düşük | Çok düşük |
| "ai fitness koçu türkçe" | Orta | Çok düşük |
| "karın kası programı erkek" | Yüksek | Yüksek |
| "akıllı spor uygulaması" | Düşük | Düşük |

> **Strateji:** "yapay zeka" + "karın kası" kombinasyonu **niche dominance** yaratır. Hiçbir Türkçe rakip bu iki kavramı aynı listing'de güçlü kullanmıyor.

---

## 3. İSİM ÖNERİLERİ VE POZİSYONLAMA

> **Önemli not:** Mevcut "SixPack AI" ismi *çok generic ve agresif* — Play Store'da bu kelime kombinasyonunu içeren onlarca app var. Marka olarak savunulabilir değil. **FormAI** çok daha güçlü bir alternatif (zaten paket adında var).

### 3.1 Premium Hissi Veren İsimler

| İsim | Psikolojik Algı | Brandability | Hatırlanabilirlik | Startup Hissi |
|---|---|---|---|---|
| **FormAI** | Form + AI = "akıllı form" | 9/10 (kısa, sahiplenilebilir, .com müsait kontrol et) | 9/10 | 10/10 |
| **Coreon** | Core + on (sürekli core) | 8/10 | 7/10 | 9/10 |
| **Atria** | Antik + lüks his | 7/10 | 6/10 | 8/10 |
| **Forma** | Form Türkçe + İtalyan vibes | 8/10 | 9/10 | 8/10 |
| **Iron AI** | Demir + AI (sertlik) | 7/10 | 8/10 | 7/10 |

### 3.2 AI-Odaklı İsimler

| İsim | Psikolojik Algı | Yorum |
|---|---|---|
| **FormAI** | Form'u öğreten yapay zeka | En güçlü adayları arasında. Türkçe-İngilizce çift okunur. |
| **CoachAI** | AI koçun | Generic ama Türkçe pazarda etkili |
| **Repi** | Rep (tekrar) + i (smart) | Kısa, modern, brandable |
| **PoseUp** | Pose + Up (yukarı) | Pose detection vurgusu |
| **NeuroFit** | Sinir + fit | Lüks, akıllı çağrışımı |

### 3.3 Fitness-Performance İsimleri

| İsim | Psikolojik Algı |
|---|---|
| **Sixly** | Six (paket) + ly (sonek = brand) |
| **Coregram** | Core + gram (Insta benzetme) |
| **AbCore** | Abs + Core, doğrudan |
| **Faze** | Faz (program safhası) |
| **Routy** | Routine (rutin) — disiplin çağrışımı |

### 3.4 Habit-Focused (Alışkanlık) İsimler

| İsim | Psikolojik Algı |
|---|---|
| **Streakly** | Streak vurgusu — Duolingo benzetmesi |
| **DailyForm** | Günlük form |
| **Hammer** | Hedefe çakma |
| **Iron Streak** | Sert + sürekli |

### 3.5 Minimalist Startup Stili

| İsim | Hissiyat |
|---|---|
| **FORM.** | Tek kelime, nokta. Premium. |
| **Six.** | Aşırı minimalist (ama jenerik) |
| **Atlas** | Klasik, güçlü |
| **Mass** | Vücut kütlesi, kısa, brandable |

### 3.6 KARAR — Stratejik Tavsiye

> **Birinci tercih: `FormAI`**
>
> **Neden?**
> 1. **Çift dilli okunur:** "Form-AI" (İngilizce) ve "Form'ay" (Türkçe) — global brand potansiyeli
> 2. **Paket adıyla uyumlu:** `com.emredogan.formaifit` zaten kullanımda
> 3. **AI pozisyonunu** isim seviyesinde sahipleniyor — rakipler bunu yapamıyor
> 4. **6 karakter** — App Store + sosyal medya handle yedeklenebilir
> 5. **"Form"** kelimesi Türkçe'de hem "fitness form" hem "vücut formu" hem "doğru pozisyon" demek. Üç anlamı birden tutuyor.
> 6. **Title slot kazandırır:** "FormAI: Karın Kası AI Koçu" — keyword + brand bir arada

> **İkinci tercih: `Forma`**
> Türkçe pazarda daha sıcak, ama İngilizce pazarda "form" generic.

> **DİKKAT:** "SixPack AI" ismini production'a taşımayın. Marka tescili imkansız, Play Store algoritması generic ismi cezalandırır, premium pozisyonlama mümkün değil.

---

## 4. İKON STRATEJİSİ

### 4.1 İkon Psikolojisi

İkon, **0,4 saniyede** kullanıcının "premium mu, çöp mü?" kararını verdiği yerdir. Bu kararı verirken kullanıcı bilinçli düşünmez — *gestalt* algılar:

- **Kontrast:** İkon listede beyaz arka planda diğer ikonlardan **ayrışıyor mu?**
- **Renk dengesi:** Tek bir hakim renk + bir aksan rengi (ikiden fazla renk = ucuz his)
- **Form:** İkonun negatif boşlukları temiz mi?
- **Centerpiece:** Tek bir simge mi, kalabalık bir sahne mi?

### 4.2 Renk Psikolojisi

#### **Fitness için kazanan renkler:**
| Renk | Psikolojik etki | FormAI uygunluğu |
|---|---|---|
| **Lacivert / Deep Navy** | Güven, premium, disiplin | **YÜKSEK** |
| **Siyah + neon yeşil aksan** | Performans, gece spor, gym | **YÜKSEK** |
| **Volkanik turuncu** | Enerji, motivasyon | Orta — kategori klişesi |
| **Soft mor / electric purple** | AI çağrışımı, modern | **YÜKSEK** (AI vurgusu için) |
| **Saf beyaz + altın aksan** | Lüks, premium fitness | Yüksek (Apple Fitness vibes) |

#### **Kaçınılacak renkler:**
- Kırmızı tek başına (öfke, ucuz, "ücretsiz spor uygulaması" klişesi)
- Lime yeşil + neon (Asya pazar klişesi, premium algı kırar)
- Pastel renkler (kadın-fitness niche dışında zayıf)

### 4.3 Premium İkon Yönü — 3 Direksiyon

#### **Yön A — "Neon AI Core"**
- Arka plan: Saf siyah veya çok koyu lacivert (#0A0E1A)
- Merkez: Tek bir abstract "core/pasta dilimi" çizimi — neon mavi-mor gradient
- Tipografi: Yok (sembol-only)
- Hissiyat: NeuroFit, Whoop, Strava premium hissi
- **CTR Tahmini:** Yüksek (kategori dışı)

#### **Yön B — "Monogram F"**
- Arka plan: Deep navy → koyu mor gradient
- Merkez: Stilize "F" harfi (hafif italik, modern sans-serif, gradient stroke)
- Hafif glow
- Hissiyat: Notion, Linear, Cal.com premium teknoloji ürünü hissi
- **CTR Tahmini:** Yüksek (premium uygulamalar arasında ayrışır, jenerik fitness arasında ayrışmaz — A/B test gerekli)

#### **Yön C — "Abstract Six"**
- Arka plan: Sol-üst yumuşak ışık + alt-sağ koyu
- Merkez: 6 yatay çizgi (abs çağrışımı), gradient fade
- Hissiyat: Sembolik, anlam katmanlı
- **CTR Tahmini:** Orta-Yüksek (anlam katmanı kategoriyi anlatıyor)

### 4.4 CTR Optimizasyonu

İkon CTR'sini **A/B test etmeden** prod'a sokmayın. Google Play Console "Store listing experiments" üzerinden 14 günlük testle %15-40 CTR farkı yakalayabilirsiniz.

#### **Test edilecek varyantlar:**
1. Yön A vs Yön B (Sembol-only vs Monogram)
2. Lacivert vs Siyah arka plan
3. Glow var vs glow yok
4. Tek renk vs gradient

### 4.5 Dark/Light Kontrast Stratejisi

Play Store'da kullanıcının telefonu light mode olabilir → ikon **beyaz arka planda** test edin.
Karanlık modda olabilir → **siyah arka planda** test edin.
**Her iki ortamda da** kontrast korunmalı.

> Pro ipucu: İkonun *ortasındaki* simge çok küçükse, küçük thumbnail boyutunda (48x48) silinir. Simge ikonun **%55-65'ini** doldurmalı.

### 4.6 Kaçınılacak Hatalar

- ❌ İkon içinde **uzun yazı** ("Six Pack AI" yazısı — okunmaz)
- ❌ **Foto / gerçek vücut fotoğrafı** — ucuz, generic, telif riski
- ❌ **Çok fazla element** (dumbell + figür + kalp + ateş = panik)
- ❌ Apple/Material **default ikonlarından kopya** hissi
- ❌ Beyaz arka plan + ince yazı (App Store'da kaybolur)
- ❌ İkon kenarına çok yakın elementler (Android maskesi kırpar)

---

## 5. SCREENSHOT MASTERPLAN

> Bu **en önemli** bölüm. Screenshot'lar Play Store conversion'ının %50'sinden fazlasını belirler. Title okunmaz, ikon görülür, **screenshot'a güvenilir.**

### 5.1 Screenshot Felsefesi — "Storyboarding"

8 screenshot, bir mini-film olmalı:
- Screenshot 1 = **Hook** (ne yapıyor bu uygulama?)
- Screenshot 2 = **Promise** (hayat nasıl değişecek?)
- Screenshot 3 = **Proof** (gerçekten çalışıyor mu?)
- Screenshot 4-6 = **Mechanism** (nasıl çalışıyor?)
- Screenshot 7 = **Identity** (ben kim olacağım?)
- Screenshot 8 = **CTA** (başla)

Kullanıcı ortalama **2,4 screenshot** swipe eder. Yani **ilk 3 screenshot** indirme kararını verir. Geriye kalan 5 sadece **ikna doğrulayıcı.**

### 5.2 Screenshot Sıra Psikolojisi

İlk 3'ün altın kuralı: **Hook → Promise → Proof.**
- **Hook:** "Bu app benim sorunumu çözüyor" diye düşündürmeli
- **Promise:** "Hayatım değişebilir" diye hissettirmeli
- **Proof:** "Bu numara değil" diye emin ettirmeli

### 5.3 Screenshot 1 — HOOK

**Konsept:** "30 Günde Karın Kası — AI Koçunla"

**Layout:**
- Üstte (top 35%): **Büyük başlık** + **Alt başlık**
- Ortada (middle 50%): **Telefon mockup** içinde uygulamanın ana ekranı
- Altta (bottom 15%): Sosyal kanıt (4,8 ★ — 1.200+ kullanıcı) — *eğer varsa*

**Metin:**
- **Headline:** "30 Günde Karın Kası"
- **Subtext:** "AI Koçun her hareketini sayar"

**Tipografi:**
- Headline: 64-72pt, ekstra bold (Inter Black, Satoshi Black, SF Pro Black)
- Subtext: 28-32pt, medium

**Background:**
- Deep navy → koyu mor gradient (45° açı)
- Hafif noise tekstür (premium hissi için kritik)

**UI Highlight:**
- Telefon mockup'ın etrafında **soft glow** (mor + mavi)
- Telefon ekranında "Streak: 7 gün" rozeti **highlight** edilmiş

**Duygu tetikleyicisi:** "Bu yapılabilir bir şey" hissi (zaman + sonuç + araç)

**Conversion goal:** Swipe etme niyeti yaratmak.

**Psikolojik etki:** *Specificity heuristic* — "30 gün" gibi spesifik sayılar kredibilite yaratır. Generic "kas yap" mesajı kazanmaz.

---

### 5.4 Screenshot 2 — PROMISE

**Konsept:** "Aynanın karşısına çık"

**Layout:**
- Üstte: Headline
- Ortada: Telefon mockup'ında "Önce / Sonra" ekranı veya progress dashboard
- Altta: Subtext + ufak vurgulu rozet

**Metin:**
- **Headline:** "Bedenin değişiyor."
- **Subtext:** "Disiplin senin, plan FormAI'nın."

**Background:**
- Telefon arkasında çok hafif sıcak ışık (motivasyon için)
- Gradient: Lacivert → ince sıcak akzan

**UI Highlight:**
- Progress chart'ı **glow** ile vurgula
- "+%23 güç artışı" gibi mock metrik göster (eğer ürün gerçekten ölçüyorsa)

**Conversion goal:** Hayal kurdurmak.

**Psikolojik etki:** *Identity priming* — "Bedenin değişiyor" cümlesi kullanıcıyı **gelecekteki kendisiyle** bağlar.

---

### 5.5 Screenshot 3 — PROOF (AI showcase)

**Konsept:** "Her hareketin sayılır — AI form düzeltme"

**Layout:**
- Telefon mockup'ında **canlı pose detection** ekranı
- Kullanıcının silüetinin üstünde AI'nın çizdiği **iskelet noktaları** (yeşil noktalar + çizgiler)
- "Form: Mükemmel ✓" gibi bir UI label

**Metin:**
- **Headline:** "AI hatalarını sen düşünmeden düzeltir."
- **Subtext:** "ML Kit pose detection — gerçek zamanlı form geri bildirimi."

**Background:**
- Ekran içinde gerçek bir antrenman alanı (telefonun içindeki kamera görüntüsü)
- Telefon dışında: nötr koyu

**UI Highlight:**
- **Yeşil glow** doğru forma sinyal
- AI nokta-nokta çizgileri animasyon hissi versin (statik bile olsa)

**Conversion goal:** Diferansiyasyon.

**Psikolojik etki:** *Authority transfer* — "AI" kelimesi otoriter teknoloji algısı yaratır. Görünür AI → güven.

---

### 5.6 Screenshot 4 — MECHANISM (Plan)

**Konsept:** "30 günlük yapılandırılmış program"

**Layout:**
- Calendar view veya timeline içinde 30 günlük plan
- Bazı günler "tamamlandı" ✓, bazıları kilitli, bugünkü gün **vurgulu**

**Metin:**
- **Headline:** "Net plan. Sıfır kafa karışıklığı."
- **Subtext:** "Her gün ne yapacağını biliyorsun."

**Conversion goal:** *Cognitive load* azaltma — "düşünmeyeceğim" hissi satar.

**Psikolojik etki:** *Decision fatigue eliminator* — kullanıcı "ben kendim plan yapamam" der; hazır plan bu yükü alır.

---

### 5.7 Screenshot 5 — STREAK / DISIPLIN

**Konsept:** "Disiplin ödüllendirir"

**Layout:**
- Streak rozetleri / takvim view
- "12 gün üst üste" tarzı büyük sayı
- Hafif animasyon hissi (statik bile olsa partikül efekt)

**Metin:**
- **Headline:** "12 gün üst üste."
- **Subtext:** "Bırakmayanlar değişir."

**Conversion goal:** Habit psikolojisi.

**Psikolojik etki:** *Loss aversion* — streak başladığında kullanıcı bunu kaybetmek istemez (Duolingo prensibi).

---

### 5.8 Screenshot 6 — KOÇ KİŞİSELLEŞTİRMESİ

**Konsept:** "Senin vücuduna göre adapte olur"

**Layout:**
- Profil ekranı: yaş, kilo, hedef
- Plan'ın kişiselleştirildiğini gösteren UI elementleri

**Metin:**
- **Headline:** "Sana göre, sana özel."
- **Subtext:** "AI koçun seni öğrenir."

**Conversion goal:** Personalization premium algısı.

**Psikolojik etki:** *Endowment* — "bu plan benim" duygusu sahiplenme yaratır.

---

### 5.9 Screenshot 7 — KİMLİK / TRANSFORMATION

**Konsept:** "Yeni bir 'sen'"

**Layout:**
- Lifestyle imagery (uygulamadan bağımsız) — disiplinli, kendine güvenli birinin silüeti
- Üzerine app UI elementi katmanı

**Metin:**
- **Headline:** "Disiplinli olan kazanır."
- **Subtext:** "Form, sadece bir görünüm değil — bir kimlik."

**Conversion goal:** Aspirational identity satışı.

**Psikolojik etki:** *Identity-based marketing* — kullanıcı bir özellik satın almıyor, **bir kimlik** satın alıyor.

---

### 5.10 Screenshot 8 — CTA (Final)

**Konsept:** "Bugün başla"

**Layout:**
- "Ücretsiz başla" butonu görseli (gerçek butonun screenshot'ı)
- Hafif "FREE 7 DAYS" rozet
- Telefon ekranı: onboarding'in ilk ekranı

**Metin:**
- **Headline:** "İlk 30 günün başlasın."
- **Subtext:** "7 gün ücretsiz, istediğin an iptal et."

**Conversion goal:** İndirme niyetini "şimdi"ye sıkıştırmak.

**Psikolojik etki:** *Action priming* — kullanıcı butonu görmüş gibi olur, gerçek butona basma eşiği düşer.

---

### 5.11 Screenshot Flow Stratejisi — Neden Swipe Ediyor / Etmiyor?

#### **Swipe etmeye iten:**
- Screenshot 1'de **bilgi kıtlığı + merak boşluğu** (ne kadar süre? Nasıl?)
- Headline'lar arasında **anlatı akışı** — sıradaki screenshot bir önceki sorunun cevabı gibi
- Visual unity (renk paleti, font, mockup tarzı **birebir aynı**)

#### **Swipe'ı durduran (kötü):**
- Aynı UI screenshot'ı farklı yazılarla (algı: tek özellik var)
- Inconsistent renk paleti (kafa karışıklığı)
- Aşırı yazı yoğunluğu (cognitive overload)
- Ekran içinde okunmayan minik UI (telefonu yakınlaştırma çabası)

### 5.12 Tipografi ve Boyutlandırma

| Element | Boyut | Ağırlık | Renk |
|---|---|---|---|
| Headline | 64-80pt | Black/ExtraBold | Saf beyaz |
| Subtext | 28-36pt | Medium/SemiBold | Beyaz %85 opacity |
| UI accent label | 18-22pt | Medium | Brand mavi/mor |
| Numerical proof | 96-128pt | Black | Brand neon |

> **Kural:** Headline tek satırda kalsın. İki satıra düşerse kelimeyi sadeleştir.

### 5.13 Gradient ve Glow Kullanımı

#### **Gradient:**
- Arka plan gradient: 45° açı, 2-3 stop
- En iyi kombinasyon FormAI için: `#0F0C29 → #302B63 → #24243E` (premium gece teknolojisi)
- *Solid* renk arka plan = ucuz his

#### **Glow:**
- Sadece **odak noktasını** vurgulamak için kullan (telefon mockup, key UI)
- Glow rengi = brand aksan rengi (mor veya neon mavi)
- Aşırı glow = casino app hissi

### 5.14 Sosyal Kanıt Yerleştirmesi

İlk 3 screenshot'ın *en az birinde* sosyal kanıt olmalı:
- "★ 4,8 — 1.200+ aktif kullanıcı"
- "✓ Producthunt #2 of the day"
- "❤️ Türkiye'nin en sevilen AI fitness'ı"

> **Etik not:** Sosyal kanıt **gerçek olmalı.** Sahte review veya rating Play Store'dan kalıcı ban riski.

### 5.15 Premium Algı Taktikleri

| Taktik | Etki |
|---|---|
| Telefon mockup gölgesi (soft, alt) | "Real product" hissi |
| Background noise tekstürü | Cheap-flat hissi yok eder |
| Beyaz boşluk (negative space) | Premium fitness uygulamalarının ortak imzası |
| Brand glyph (her screenshot'ta küçük logo) | Marka hatırlatma |
| Aynı font ailesi (4 screenshot'ta tutarlılık) | Profesyonellik sinyali |

### 5.16 İndirmeyi Maximize Etme — Son Liste

1. ✅ İlk screenshot'a **30 saniye düşün, 30 dakika tasarla** — geri kalan 7'nin yarısı kadar değerli
2. ✅ Headline'lar **3-5 kelime** ile sınırla
3. ✅ Mockup'lar **Pixel 8 / iPhone 15** modern modeller olsun (eski telefon = eski ürün hissi)
4. ✅ Türkçe + İngilizce versiyonları **ayrı çek** (translate edilmiş bir ekran ucuz görünür)
5. ✅ Her screenshot kendi başına anlamlı olsun (kullanıcı sadece birini görse bile yüklemek istesin)
6. ✅ A/B testle screenshot 1'i 14 gün test et — %30+ conversion farkı normal

---

## 6. FEATURE GRAPHIC STRATEJİSİ

> Feature graphic = **1024x500 px** Play Store hero banner. Çoğu kurucunun unuttuğu, ama Play Store'da listing'in en üstünde duran bilboard.

### 6.1 Premium Branding

Feature graphic ürünün **hero shot**'ıdır. İlk 1 saniye:
- Marka adı görünmeli
- Bir vaat görünmeli
- Tek bir ana visual element (kalabalık olmamalı)

### 6.2 Kompozisyon — Üç Direksiyon

#### **A — Ürün-merkezli**
- Sol: Telefon mockup (ürünün ana ekranı)
- Sağ: Brand + tagline + CTA
- Background: Brand gradient

#### **B — Tipografi-merkezli (önerilen)**
- Merkez: Devasa **"FORMAI"** wordmark
- Altında ince tagline: "Karın kası AI koçun."
- Background: Minimal, tek aksan rengi
- *Bu yön Notion, Linear, Cal.com'un kullandığı premium SaaS yaklaşımı*

#### **C — Lifestyle-merkezli**
- Lifestyle fotoğraf + üzerinde brand
- Risk: Ucuz stock photo hissi
- Sadece özel çekim varsa kullan

### 6.3 Görsel Hiyerarşi

```
[1] Marka adı (en büyük, en güçlü)
   ↓
[2] Tek vaat cümlesi (orta)
   ↓
[3] Ürün/visual support (alt)
```

### 6.4 CTR Psikolojisi

Feature graphic **autoplay videoyla rotation**'a girer (eğer promo video yoksa). Bu yüzden:
- **2 saniyede** anlatmalı
- Hareket veya sürpriz unsuru yok (statik)
- Brand recognition odaklı

### 6.5 Background Stratejisi

| Yaklaşım | Etki |
|---|---|
| Gradient (lacivert → mor) | Modern AI premium |
| Saf siyah + neon aksan | Performance / gym |
| Beyaz + ince çizgi | Apple-clean, beyaz boşluk lüksü |
| **Önerilen:** Lacivert → derin mor gradient + noise | FormAI brand hissi |

### 6.6 Tipografi Yönü

- **Wordmark:** Inter Black / Satoshi Black / Sora Bold (modern, sans-serif, ekstra bold)
- **Tagline:** Inter Medium, italic değil
- **Letter-spacing:** -2 ile -4 arası (tight, modern)

> **Kaçınılacak:** Comic Sans, Bebas Neue (overused), kıvrımlı stylized fontlar

---

## 7. PLAY STORE PSİKOLOJİSİ

### 7.1 Trust Signals (Güven Sinyalleri)

Kullanıcı listing'de saniyelerle karar verir. Güven mekanizmaları:

| Sinyal | Yer | Etki |
|---|---|---|
| Yıldız puanı (4,5+) | Üst | %80 conversion etkisi |
| Yorum sayısı (1.000+) | Üst | Sosyal kanıt |
| Editör seçimi rozeti | Üst | Otorite transferi |
| "Ücretsiz başla" rozeti | Bottom | Risk azaltma |
| Düzenli güncellemeler (her 2 hafta) | What's New | Aktiflik sinyali |
| Net gizlilik politikası | Data safety | Güven |
| Geliştirici profilinde 1+ uygulama | Profil | Profesyonellik |

### 7.2 Credibility Triggers

- "AI" kelimesi 2025-2026'da hala **otorite çağrışımı** taşıyor — ama sadece görünür/gösterilebilirse
- "Dr. tarafından onaylandı" gibi *gerçek* otoriteler (eğer varsa kullan, yoksa **asla uydurma**)
- "30 günde sonuç" — *quantified promise* her zaman vague claim'den güçlü
- Üniversite / araştırma referansları (eğer varsa)

### 7.3 FOMO (Fear of Missing Out)

- "Bu ay 5.000 kişi başladı" tarzı sayılar
- Trial expiry timer (paywall'da, listing'de değil)
- "Limited launch price" — ilk lansman fiyat indirimi
- "Erken kayıt avantajı" rozeti

> **Uyarı:** Listing'de FOMO **abartılırsa** sahte gelir. Sadece gerçek sayılar kullan.

### 7.4 Consistency Psychology

Kullanıcı küçük taahhütlerden büyüğüne ilerlemeye yatkındır:
- Onboarding'de "günde 7 dakika ayırabilir misin?" → Evet
- Sonra "ilk antrenmanı yap" → Evet
- Sonra "trial başlat" → Evet
- Sonra "satın al" → Evet

Listing'de bu zincirin başlangıcı **risksiz adım** vurgusudur ("ücretsiz dene").

### 7.5 Streak Psychology

Streak (üst üste gün sayısı) — fitness uygulamalarının en güçlü retention silahı:
- İlk streak gün 1'de **görsel olarak başlamalı**
- 3, 7, 14, 30, 60, 100 gün **dönüm noktası animasyonları**
- Streak kırıldığında bir kez **"streak freeze"** affı (Duolingo prensibi)
- Streak sayısını paylaşma butonu

### 7.6 Identity-Based Marketing

İnsanlar özellik almaz, **olmak istedikleri kişiyi** alır.

- Ürün konuşması yerine: **"Disiplinli birinin yaptığı şey..."**
- Özellik vurgusu yerine: **"Form, görünüm değil kimliktir."**
- Fonksiyon yerine: **"Bırakmayan biri olduğunu kanıtla."**

### 7.7 Transformation Messaging

- **Önce / sonra** çerçevesi (gerçek kullanıcı, izinli)
- **30 gün** çerçevesi (somut süre)
- **"Sen 30 gün önce başlayan birisin"** geriden bakış çerçevesi
- **"Bir versiyon yukarı"** gelecek-sen çerçevesi

### 7.8 Discipline Branding

FormAI'nın brand çekirdek mesajı **disiplin**:
- "Motivasyon başlangıcı, disiplin bitirir." (slogan adayı)
- "Bırakmayanlar değişir." (slogan adayı)
- "Form, sabırla kazanılır." (slogan adayı)

> Disiplin brand'i **zayıf-iradeli kullanıcıyı dışlamaz** — onu **iradeli olduğuna inandırır**. Bu psikolojik ters çeviri brand sadakatinin temelidir.

---

## 8. RAKİPLERDEN SIYRILMA STRATEJİSİ

### 8.1 Tipik Fitness Uygulaması Zayıflıkları

Sektör analizinde rakiplerin (Fitify, Workout for Men, Home Workout, Six Pack in 30 Days, JEFIT) ortak zayıflıkları:

| Zayıflık | Kullanıcı algısı | FormAI fırsat |
|---|---|---|
| Generic "youtube videosu" formatı | "Bunu youtube'da bedava izlerim" | AI form detection ile interaktivite |
| Form geri bildirimi yok | "Doğru mu yapıyorum bilmiyorum" | Pose detection ile çözüm |
| Kişiselleştirme yüzeysel | "Plan herkes için aynı" | Adaptif AI plan |
| Paywall agresif (1. ekran) | "Sömürülüyorum" | Onboarding sonrası kademeli |
| Türkçe lokalizasyon kötü | "Çeviri ucuz" | Native Türkçe içerik |
| Streak yok / zayıf | Habit oluşmuyor | Güçlü streak sistemi |
| Topluluk hissi yok | Yalnız antrenman | Discord / leaderboard |

### 8.2 FormAI'nın Diferansiyasyon Stratejisi

#### **A — AI Form Detection (Ana ayrışma)**
> "Bu, video izleten bir uygulama değil. **Gözleri olan bir uygulamadır.**"

Pose detection diğerlerinde ya yok ya da gizli. FormAI'da **her screenshot'ta, her conversion noktasında** vurgulanmalı.

#### **B — 30 Gün Specific Promise**
> "Generic fitness değil. **Spesifik 30 günlük altı paket programı.**"

Specificity Apple Fitness'tan, MyFitnessPal'den, Strava'dan ayrıştırır. Generic uygulamalar genel kalır; FormAI bir **lazer odakla** başlar (sonra genişler).

#### **C — Türkçe-First**
> "Türkçe rakipler çeviri uygulamalardır. **FormAI Türkiye için doğdu.**"

Native Türkçe ses-üstü, motivasyon mesajları, kültürel kontekst (Türk yemek alışkanlıkları, Ramazan modu, vb.).

#### **D — Disiplin Brand'i**
> "Hızlı sonuç vaat eden değil. **Sabrı ödüllendiren brand.**"

Bu pozisyonlama Headspace'in mindfulness'ı sahiplenmesi gibi long-term marka değeri yaratır.

### 8.3 AI Pozisyonlama Stratejisi

AI vurgusu 2026'da **commodity'leşti** — "AI" kelimesi tek başına ayrışma yaratmaz. FormAI **özellik AI'sı** değil **kullanım AI'sı** olarak pozisyon almalı:

| Generic AI sloganı (kötü) | FormAI AI sloganı (iyi) |
|---|---|
| "AI destekli antrenman" | "Hareketini gören AI" |
| "Akıllı koç" | "Form düzelten gözler" |
| "Yapay zeka fitness" | "Her tekrarın sayılır — ML Kit ile" |

### 8.4 Duygusal Pozisyonlama

Rakipler **performans** satıyor. FormAI **identity** satmalı:

- Performans satışı: "Daha güçlü ol"
- Identity satışı: "**Bırakmayan biri** ol"

İkincisi 10x duygusal yapışkanlık yaratır.

### 8.5 Retention Pozisyonlama

> "Çoğu fitness app **30 gün sonra siliniyor.** FormAI 30 günde **başlatıyor.**"

Bu çerçeve, kullanıcıya "uzun vadeli yatırım" hissi verir. Onboarding mesajlarında, paywall'da, ASO'da kullanılabilir.

### 8.6 Premium-Feel Stratejisi

Premium algı **fiyat değil, deneyim sinyallerinden** doğar:

| Premium sinyali | FormAI'da uygulama |
|---|---|
| Tipografi (modern sans, tight letter-spacing) | Tüm UI Inter/Sora |
| Mikro-animasyonlar (60fps) | Spring animations |
| Sessiz UI (boşluk, sadelik) | 16-24px padding kuralı |
| Yüksek kontrast | Dark mode öncelikli |
| Premium ses tasarımı (haptic + ses) | UI feedback haptic |
| "Bekleme yok" hissi (instant load) | Prefetch + skeleton |

> **Kural:** Premium **fiyat etiketinden önce** UI'da gösterilmeli. Yoksa "bu kadar mı?" tepkisi gelir.

---

## 9. ABONELİK & PAYWALL STRATEJİSİ

### 9.1 Fiyatlandırma Psikolojisi

#### **Mevcut SKU yapısı (Phase 93):**
- `formai_pro_monthly` — Aylık
- `formai_pro_3month` — 3 aylık
- `formai_pro_annual` — Yıllık

#### **Önerilen Türkiye fiyatlandırması (TL):**

| Plan | Fiyat (TL) | Aylık eşdeğer | Anchor strateji |
|---|---|---|---|
| Aylık | ₺149 | ₺149/ay | "kaçık fiyat" anchor |
| 3 Aylık | ₺299 | ~₺99/ay | "%33 indirim" |
| Yıllık | ₺799 | ~₺67/ay | **"En çok seçilen" / -%55** |

> **Ana taktik:** Yıllık plan **ortada** ve **vurgulu** dursun. Aylık plan görece **pahalı** görünsün. 3 aylık **kompromi** seçeneği (ne yıllık taahhüdü ne aylık savruk).

#### **Önerilen Global fiyatlandırma (USD/EUR):**

| Plan | USD | EUR | Aylık eşdeğer |
|---|---|---|---|
| Aylık | $11,99 | €11,99 | $11,99 |
| 3 Aylık | $24,99 | €24,99 | ~$8,33 |
| Yıllık | $59,99 | €59,99 | ~$5,00 |

### 9.2 Trial Stratejisi

#### **Önerilen: 7 gün ücretsiz deneme**

**Neden 7 gün, 3 değil?**
- 3 gün: Kullanıcı app'i daha **alışkanlığa** dönüştüremeden trial biter — düşük conversion
- 7 gün: Streak başlar, habit'in ilk halkası kurulur, **kayıp acısı** doğar
- 14 gün: Çok uzun — fiyatlandırma ciddiyetini kırar

**Trial yönetimi:**
- Trial başlangıcında Türkiye için **kart almadan** trial dene (Google Play izin verir, conversion düşüktür ama yarı-niyetli kullanıcı daha çok denenir)
- Veya **kart-only** trial → conversion daha yüksek, indirme daha düşük
- A/B test gerekli; başlangıçta **kart-only** öneririm (kalite > kantite)

### 9.3 Onboarding-to-Paywall Akışı

Optimal akış (12-15 ekran):

```
1. Selamlama (brand + soft promise)
2. Hedef seçimi (kilo verme / kas yapma / form)
3. Cinsiyet + yaş
4. Deneyim seviyesi
5. Boy + kilo
6. Hedef vücut (görsel)
7. Engeller / sorunlar (motivasyon, zaman, vb.)
8. Spor geçmişi
9. Quick-win moment ("Sen artık programındasın")
10. AI plan oluşturma animasyonu (8-12 sn drama)
11. Plan özeti + sosyal kanıt
12. Paywall (3 plan + trial)
13. (Trial al) → "Welcome, hemen ilk antrenman"
```

> **Kritik:** 9-10. adım **dramatic moment** olmalı. AI plan oluşturma animasyonu **anchoring** etkisi yapar — kullanıcı **emek verildiği** algısı kazanır, paywall'da reddetmesi zorlaşır (sunk cost).

### 9.4 Premium Trigger Timing

Paywall'ı tetiklemenin doğru anları:

| Trigger | Conversion etkisi | Risk |
|---|---|---|
| Onboarding sonu (default) | Yüksek hacim, orta kalite | Trial-only kullanıcı |
| 3. antrenman sonrası | Düşük hacim, yüksek kalite | İlk 3 ücretsiz tutmak gerekir |
| Streak 3 gün milestone | Çok yüksek kalite | Çok az kullanıcı buraya ulaşır |
| Premium feature lock | Orta | Friction noktası |

**Önerilen:** Onboarding **+ ikinci antrenmanda hard trigger** (hibrit model). Kullanıcı yarı-niyetli ise onboarding'de yakalar; tam-niyetli ise 2. antrenmanda. İkili kapan.

### 9.5 Habit-Lock Stratejisi

> Kullanıcı paywall'a değil, **habit'e bağlı kalır.** Habit ne kadar güçlüyse fiyat hassasiyeti o kadar düşer.

Habit-lock mekanizmaları:
- **Streak görselleştirmesi** (kayıp endişesi)
- **Progress dashboard** (yatırım hissi)
- **Önceki antrenman geri bildirimi** ("Dün 14 squat yaptın, bugün 16 hedefin")
- **Kişiselleştirilmiş plan** (yeniden başlama maliyeti)
- **AI öğrenmesi** ("AI seni 14 günde öğrendi, tekrar başlamak istemezsin")

### 9.6 AI Premium Pozisyonlama

AI'yı premium feature olarak sat — **ücretsiz tier'da AI form detection olmamalı veya sınırlı olmalı.**

- Ücretsiz: Plan + temel takip
- Premium: AI form detection + adaptif plan + advanced analytics
- **Bu ayrım upgrade trigger'ının ana motoru olur**

> **Uyarı:** AI'yı **tamamen** ücretsiz tier'dan kaldırma — kullanıcı diferansiyasyonu denemeden gitmez. *Sınırlı tat* en iyi strateji (örn: ilk 3 antrenmanda AI form check ücretsiz).

---

## 10. İLK 1000 KULLANICI STRATEJİSİ

### 10.1 Felsefe — "Quality Acquisition"

İlk 1000 kullanıcı **algoritmik temel attığınız kişilerdir.** Bu kullanıcılar yüksek niyetli olmalı; aksi halde D1 retention çöker, Play Store sizi cezalandırır.

### 10.2 Reddit Stratejisi

Reddit hedef sub'lar:
- **r/turkey** (genel — yumuşak post)
- **r/Tekirdag, r/istanbul, r/ankara** (yerel)
- **r/Turkishfitness, r/TurkeyFitness** (niche)
- **r/sixpack, r/abs, r/bodyweightfitness** (EN)
- **r/SideProject, r/InternetIsBeautiful** (lansman)

**Post tipleri:**
1. **Build-in-public:** "30 günde Flutter ile fitness app yazdım — feedback istiyorum"
2. **Story-driven:** "AI ile karın kası uygulaması yaptım — hikaye"
3. **Direct help-seek:** "Beta testçileri arıyorum — Türkiye"

> **Kural:** Asla doğrudan *"şu uygulamayı indir"* yazma — Reddit bunu spam görür ve banlar. Hikaye + utility + meşru istek.

### 10.3 TikTok / Reels Stratejisi

Fitness + AI **TikTok için altın kombinasyon.** İçerik direksiyonları:

#### **Format A — Day-in-life with FormAI (POV)**
- 15 saniye, akşam antrenman
- "30. günümde — fark bakın" voice-over
- AI form correction'ı **görsel olarak** göster
- CTA: "Profilde link"

#### **Format B — AI calls out my form**
- AI'nın yanlış form tespit ettiği komik moment
- "Güya squat yapıyordum, AI 'oturuyorsun' dedi" tarzı
- Yüksek viral potansiyel

#### **Format C — 30-day transformation**
- 30 gün önce / sonra (gerçek kullanıcı, izinli)
- Saniyede 1 gün geçen hızlandırılmış footage
- Voice-over: "AI bana 30 gün boyunca her gün ne yapacağımı söyledi"

**Hashtag stratejisi:**
- #FormAI #karinKasi #30Gun #aiCoach #sporTurkiye #fitnessTr #abs2026

> **Dağıtım taktiği:** Aynı video Instagram Reels + YouTube Shorts'a *birebir* paslanır. Tek prodüksiyon, üç platform.

### 10.4 Twitter/X Stratejisi

X bir build-in-public + indie maker platformu — fitness app için doğrudan değil ama **founder hesabı** üzerinden değerli:

- Lansman thread: "10 ay geliştirdim, bugün lansman — şu öğrendiklerim"
- Metrik thread: "İlk 100 kullanıcı sonrası gördüklerim"
- AI thread: "AI form detection nasıl çalışıyor — teknik"

Hedef: **Founder community** içinde görünürlük → indie maker'lar deneme → review

### 10.5 Organik Virality Mekanizmaları

App içine **organik virality kancaları** kur:

#### **Streak share**
- 7 gün dolduğunda "Paylaş" butonu
- Otomatik branded image: "12 gün üst üste — FormAI"
- Instagram story-ready boyutlandırma

#### **Before/After**
- 30 gün sonunda paylaşılabilir progress kartı
- Watermark: "FormAI ile"

#### **Challenge daveti**
- Arkadaş davet et → ikiniz de bir hafta extra premium
- Düşük friction referral

### 10.6 Creator Outreach

**Hedef profiller:**
- Türkiye fitness micro-influencer'ları (10K-100K)
- AI / tech YouTuber'lar (lifestyle ile kesişim)
- "30 gün challenge" formatı yapan içerik üreticileri

**Outreach scripti (Türkçe):**
```
Selam [İsim],

FormAI adında AI destekli karın kası uygulaması yaptım — pose detection
ile form düzeltiyor. Sen [şu içeriğinde] benzer şeyi gözlemledim ve
ilgini çekebileceğini düşündüm.

Sana 1 yıllık premium hediye etmek isterim — beğenirsen organik
mention yeterli, kesinlikle reklam değil. İlk 50 creator'a açıyorum.

30 saniyede bakar mısın?

[Link]

İyi günler.
```

### 10.7 Discord / Topluluk Stratejisi

Türkiye fitness Discord sunucuları + global fitness community:
- Pasif bekleme yerine **gerçek değer ver** (form check Q&A, motivasyon)
- Yardım ettiğin yerlerde imzanda app linki
- Kendi sunucunu kurmak → 50-100 üye gelene kadar prematüre

### 10.8 Review Acquisition (İlk 100 Review)

İlk 100 review **algoritma için en kritik** sosyal kanıt:

#### **Strateji:**
1. **Kişisel ağ** (50 review): Aile, arkadaş, kolej, eski iş arkadaşları → manuel rica + ekran kaydı talimatı
2. **Beta testçi conversion** (30 review): Closed test'ten gelenlere indirme sonrası 7. günde push notification
3. **Reddit/Discord help'i** (20 review): Yardım ettiğin topluluklardan rica

> **YAPMA:** Review for review takası, sahte review, incentive for review. Google Play **kalıcı ban** verir.

### 10.9 Beta-User Harvesting

Closed testing → production geçişinde **beta kullanıcıyı kaybetmemek için:**
- Closed testing kullanıcılarına özel **3 ay ücretsiz premium** (sadık tabaka)
- Ürünün ilk official launch e-postası → "You were here from day 1"
- App içi rozet: "Founding user"

---

## 11. YORUM & PUAN STRATEJİSİ

### 11.1 Review Ask Felsefesi

Yorum istemenin tek doğru anı: **kullanıcı pozitif duygu hissettiği an.**

Yanlış an: Onboarding sonu, paywall sonrası, hata sonrası.
Doğru an: Streak milestone, antrenman tamamlama, hedef ulaşma.

### 11.2 İdeal Review Ask Akışı

```
1. Kullanıcı 3. antrenmanı tamamlar
2. Antrenman sonu ekranı: "Harikasın! 3 antrenman, 3 streak."
3. Bekle 2 saniye
4. Soft pop-up: "FormAI'yı seviyor musun?"
   - "Evet" → Native review prompt
   - "Hayır" → "Neyi düzeltebiliriz?" feedback formu (review değil)
   - "Sonra" → 14 gün sessiz mod
```

> **Bu ikili çatal kritik:** Negatif kullanıcı **review yazmıyor, feedback veriyor.** Negatif review'lar app içi feedback formuna yönlendirilerek Play Store'da görünmüyor.

### 11.3 Review Timing Psikolojisi

| Timing | Conversion oranı | Review kalitesi |
|---|---|---|
| 1. açılış sonrası | %1 | Düşük (kullanıcı tanımıyor) |
| Onboarding sonu | %3 | Düşük |
| 1. antrenman sonu | %8 | Orta |
| **3. antrenman + streak** | **%18** | **Yüksek** |
| 7 gün milestone | %25 | Çok yüksek |
| 30 gün completion | %35 | Çok yüksek (ama az kullanıcı buraya ulaşır) |

### 11.4 Negatif Review Önleme

Negatif review'ların %80'i şu sorunlardan gelir:
- Paywall surprise (kullanıcı ücretsiz sandı)
- Login sorunu
- App crash
- Trial bitince beklenmedik charge
- Yanıt verilmemiş support talebi

#### **Önlemler:**
1. **Paywall transparency:** "7 gün ücretsiz, sonra X TL — istediğin an iptal" cümlesi **paywall'da** ve **trial başlangıç ekranında**
2. **Trial expiry uyarısı:** Bitmeden 24 saat önce push notification
3. **Crash response:** Sentry crash + "üzgünüz, düzeltiyoruz" e-posta otomatik (eğer e-posta varsa)
4. **In-app support:** Review prompt'undan önce "Sorun mu var? Yazışalım" linki
5. **Hızlı support yanıtı:** İlk 24 saat içinde her support e-postasına yanıt → review'a dönüşmez

### 11.5 Satisfaction Checkpoint'leri

Kullanıcı yolculuğunda 4 checkpoint:

| Checkpoint | Eylem |
|---|---|
| Antrenman 1 sonu | "Nasıldı?" emoji feedback |
| Antrenman 3 sonu | Review ask (ilk kez) |
| Streak 7 gün | Streak rozet + share + review ask (eğer ilk seferde alınmadıysa) |
| Streak 30 gün | Transformation review + paylaşım kampanyası |

### 11.6 Mevcut Yorumları Yönetme

- Her review'a **48 saat içinde yanıt** ver (Play Console'dan)
- Negatif review'da **sürtüşmeden çözüm** sun ("üzgünüz, support@formai.app yaz, çözelim")
- Pozitif review'a teşekkür et (Google bunu engagement sinyali okur)
- 1-2 yıldız review'larında **savunmacı olma** — soğukkanlı çözüm öner

### 11.7 Hedef Rating ve Yorum Hacmi (90 gün)

| Hafta | Toplam review | Ortalama rating |
|---|---|---|
| W1 | 30 | 4,7+ |
| W2 | 80 | 4,6+ |
| W4 | 200 | 4,5+ |
| W8 | 500 | 4,5+ |
| W12 | 1.000 | 4,5+ |

> 4,5 altına düşerse algoritma görünürlüğü cezalandırır. Acil paywall + onboarding iterasyonu gerekir.

---

## 12. GOOGLE PLAY CONSOLE ADIM ADIM

> Bu bölüm bir **founder lansman rehberidir.** Console'da **sırayla** ne yapılacağı, hangi butona neden basılacağı.

### 12.1 Hesap & Geliştirici Profili

1. **Google Play Console hesabı aç** ($25 tek seferlik)
2. Geliştirici **gerçek adı** veya **şirket adı** — Play Store'da görünür, sonradan değişmez kolay
3. **D-U-N-S numarası** (şirket olarak yayınlıyorsan zorunlu, individual ise gerekmez)
4. **İletişim e-postası:** support@formai.app gibi profesyonel bir adres (Gmail amatör algısı)
5. **2FA mutlaka aç**
6. **Geliştirici doğrulaması:** Pasaport/kimlik upload — Google 2024+ tüm yeni hesaplarda zorunlu kıldı, **48 saat sürebilir**

### 12.2 Yeni Uygulama Oluşturma

`Create app` butonu:
- **App name:** "FormAI" (30 karakter)
- **Default language:** Turkish (Turkey) — birinci pazar olduğu için
- **App or game:** App
- **Free or paid:** Free (in-app subscription)
- **Declarations:** Developer Program Policies ✓ + US export laws ✓

### 12.3 Store Listing Setup

#### **Main store listing → Türkçe**

| Alan | İçerik (taslak) |
|---|---|
| App name | FormAI: Karın Kası AI Koçu |
| Short description | AI form düzelten, 30 günde karın kası getiren akıllı fitness koçun. |
| Full description | (Bölüm 2.6'daki katmanlı yapı) |
| App icon | 512x512 PNG — Bölüm 4 |
| Feature graphic | 1024x500 PNG — Bölüm 6 |
| Phone screenshots | 8 screenshot — Bölüm 5 |
| 7-inch tablet | İsteğe bağlı (önerilmez ilk lansman) |
| 10-inch tablet | İsteğe bağlı |
| Promo video (YouTube) | İsteğe bağlı ama **CTR'yi %10-25 artırır** |

> **Pro ipucu:** İlk 14 gün **video koymadan** lansman yap. Video conversion'ı bazen düşürür (autoplay rahatsız eder). Video'yu day 30'da test et.

#### **Locale eklemek**

İkinci dil olarak **English (United States)** ekle:
- Aynı listing → İngilizce çeviri (sadece çeviri değil, **kültürel adaptasyon**)
- Screenshots İngilizce versiyonu **ayrı çekilmeli**

### 12.4 Release Tracks

Play Console'da 4 ana track:

#### **A — Internal Testing**
- 100 kişiye kadar
- E-posta listesi ile davet
- Anında dağıtım, review yok
- **Ne için:** Geliştirme + dev test

#### **B — Closed Testing**
- E-posta listesi VEYA Google Group
- Test track yarat: "FormAI Beta TR"
- **Ne için:** Soft launch, kontrollü kalabalık (Faz 1)

#### **C — Open Testing**
- Herkes Play Store'da "Erken Erişim" linkinden katılır
- **Ne için:** Faz 2, ASO ısınması

#### **D — Production**
- Live, herkese açık
- Staged rollout aktive et
- **Ne için:** Faz 3 ve sonrası

### 12.5 Internal Testing Adımları

1. `Testing` → `Internal testing` → `Create new release`
2. **App bundle (.aab) yükle** — APK değil
3. **Release notes:** Türkçe + İngilizce (her dil için ayrı)
4. **Save → Review → Roll out**
5. **Tester e-postaları ekle** (kendi liste veya Google Group)
6. **Opt-in URL** kullanıcılara gönder

> **Sık hata:** App önceden Production'da değilse Internal testing kullanıcı **olmayan kullanıcı için bile listelenmez** — opt-in URL üzerinden gitmek zorunda.

### 12.6 Closed Testing Adımları

1. `Closed testing` → `Create track` → "Beta TR"
2. Aynı bundle veya farklı bundle yükle
3. **Tester listesi:**
   - Google Group oluştur (en pratik)
   - Reddit/Discord'dan toplanan e-postalar
4. **Feedback channel:** support e-postası veya Discord linki
5. Roll out

### 12.7 Production Rollout

1. `Production` → `Create new release`
2. **Bundle yükle**
3. **What's new:** Hem Türkçe hem İngilizce, **kullanıcı odaklı dil** ("yenilikler") — teknik dilden kaç
4. **Staged rollout:** %1 ile başla
5. **Roll out** → Google review (ilk lansman 1-7 gün, güncellemeler genelde 2-12 saat)

### 12.8 Content Rating

`Policy → App content → Content rating questionnaire`:

- Kategori: Fitness
- **Şiddet:** Yok
- **Cinsellik:** Yok
- **Bahis:** Yok
- **İlaç/uyuşturucu:** Yok (eğer içerikte yoksa)
- **Korkutucu içerik:** Yok
- **Kullanıcı içeriği:** Yok (eğer kullanıcı UGC paylaşmıyorsa)
- **Kullanıcı verisi paylaşımı:** Evet (Supabase/RevenueCat)

Sonuç: **Everyone** veya **Everyone 10+**.

### 12.9 Data Safety

`Policy → App content → Data safety` — **2026'da en sıkı bölüm:**

#### **Toplanan veriler:**
- E-posta (account)
- Kişisel ID (UUID)
- Yaş, cinsiyet (profile)
- Kilo, boy, hedef (fitness data)
- Antrenman geçmişi (app activity)
- IP adresi (analytics)
- Crash logs (Sentry)

#### **Her veri için:**
- Toplanıyor mu? Evet/Hayır
- Paylaşılıyor mu? (Supabase → backend, RevenueCat → ödeme, PostHog → analytics, Sentry → crash)
- Şifrelenmiş mi? (Evet — TLS in-transit, AES at-rest)
- Kullanıcı sileebilir mi? (Evet — hesap silme akışı zorunlu)

> **Önemli:** "Data safety" formu yanlış doldurulursa **Play Store kaldırma sebebi.** Her data point Privacy Policy ile **birebir tutarlı** olmalı.

### 12.10 App Access

`App access`:
- App'e giriş için login gerekiyor mu? **Evet**
- Demo hesap: review@formai.app / [demo-password] — Google reviewer'ları için
- Test hesap'ın **abonelik durumu:** Premium aktive (paywall ardını görmek için)

> Demo hesabı eksik veya çalışmazsa **lansman 5-14 gün gecikir.**

### 12.11 Ads

`Ads`: **No** (uygulamada reklam yok)

### 12.12 Target Audience

- **Yaş aralığı:** 18+
- **Çocuklara yönelik mi:** Hayır

### 12.13 Privacy Policy

Mutlaka **canlı bir URL** olmalı (Notion sayfası bile olur):
- `https://formai.app/privacy` (öneri)
- KVKK + GDPR + Apple/Google policy uyumlu
- Türkçe + İngilizce versiyon

### 12.14 App Signing

- **Play App Signing** kullan (zorunlu yeni uygulamalarda)
- Upload key + signing key ayrı tut
- **Keystore yedeği** birden fazla yerde sakla (kayıp = uygulama yenileme imkansız)

### 12.15 Release Management

#### **Internal app sharing:**
- QR kod ile hızlı bundle paylaşımı (review öncesi test için)
- Ekibe / closed test'çilere aynı saniye dağıtım

#### **Pre-launch report:**
- Google bundle yüklediğinde **otomatik 5 gerçek cihazda 30 dakika çalıştırır**
- Crash, ANR, deprecated API, performance raporları gelir
- **Bu raporu lansmanmadan ÖNCE oku** — production'a kötü bundle gitmesin

#### **App bundle explorer:**
- APK'lar device-specific (Pixel'e ne gidiyor, Samsung'a ne) — debug için

### 12.16 Subscription Setup (RevenueCat ile)

1. `Monetize → Products → Subscriptions`
2. Subscription oluştur:
   - **Product ID:** `formai_pro_monthly` (kod tarafında zaten kullanılan)
   - **Subscription period:** 1 ay
   - **Price:** ₺149,00 (TR) — Auto-translate other countries
   - **Free trial:** 7 days
   - **Grace period:** 16 days
3. Aynısını `formai_pro_3month` ve `formai_pro_annual` için tekrar et
4. RevenueCat dashboard'da entitlement'a bağla
5. Sandbox account ile **gerçek satın alma akışı** test et

> **Phase 94'te öğrenildi:** Anonymous kullanıcı RevenueCat satın alımı kırıyordu — `auth gate` zorunlu. Test akışında **mutlaka login + purchase** yolu denenmeli.

### 12.17 Policy Risk Areas

Fitness app'lerinin Play Store'da en sık takıldığı yerler:

| Risk | Açıklama | Önlem |
|---|---|---|
| Misleading health claims | "Garanti karın kası" tarzı | Dilini "destek olur, garanti vermez" yumuşat |
| Sensitive data without consent | Sağlık verisi → consent | Her data point için açık consent |
| Trial dark patterns | İptal zorlaştırma | İptal akışı **3 tıklama** içinde olmalı |
| Misrepresentation in screenshots | App'te olmayan UI | Sadece **gerçek** UI screenshot'ı |
| Keyword stuffing in title | "ai ai ai fitness fitness" | Doğal dil, max 1 kez tekrar |
| Copycat icon/branding | Bilinen marka taklit | Özgün brand |

### 12.18 Lansman Sonrası Console İzleme

`Statistics`:
- Daily installs / uninstalls
- Conversion (store listing visitors → installs)
- ASO arama keyword'leri (acquisition reports)
- Country breakdown
- Crash rate
- ANR rate
- Rating ortalaması

> Bunları **günlük 5 dakika** check etme habit'i ilk 90 gün için zorunlu.

---

## 13. YAYIN ÖNCESİ CHECKLIST

> Production'a basmadan önce **HEPSI** ✓ olmalı.

### 13.1 Crash Testing

- [ ] Sentry entegrasyonu canlı + DSN doğru
- [ ] Pre-launch report'ta 0 crash
- [ ] Manuel: airplane mode → app aç → crash yok (offline graceful)
- [ ] Manuel: hızlı 10 navigasyon → memory leak yok
- [ ] Release build'de **Phase 94 4-layer error guard** çalışıyor
- [ ] `SentryFlutter.init` etrafında try/catch
- [ ] `_envSafe` ile environment yüklenmesi
- [ ] Supabase 8s, PostHog 5s timeout'ları aktif

### 13.2 Device Testing

| Cihaz tipi | Test edildi mi? |
|---|---|
| Pixel 6/7/8 (modern Android) | [ ] |
| Samsung Galaxy S20+ | [ ] |
| Samsung Galaxy A serisi (mid-tier) | [ ] |
| Xiaomi Redmi (entry-level, TR'de yaygın) | [ ] |
| Huawei (GMS-siz) — opsiyonel | [ ] |
| Tablet 10" | [ ] |
| Foldable (Galaxy Fold) | [ ] |
| Android 7 (minimum SDK) | [ ] |
| Android 14/15 (latest) | [ ] |

> **Önemli:** Google'ın **Firebase Test Lab** üzerinden 20+ cihazda otomatik test ucuzdur ($1-5) ve cihaz sahibi olmadan test imkanı verir.

### 13.3 Screenshot Checklist

- [ ] 8 Türkçe screenshot final
- [ ] 8 İngilizce screenshot final (ayrı çekim)
- [ ] Her screenshot 1080x1920 (portrait) — Play Store standardı
- [ ] Status bar gerçek (saat, pil — fake değil)
- [ ] Hiçbir mockup'ta yazım hatası yok
- [ ] Renk paleti birebir tutarlı
- [ ] Telefon mockup modeli **2024+ cihaz**

### 13.4 Policy Checklist

- [ ] Privacy policy canlı URL (Türkçe + İngilizce)
- [ ] Terms of service URL
- [ ] Data safety formu **birebir** privacy policy ile uyumlu
- [ ] Subscription disclosure: Trial, fiyat, iptal — paywall'da net
- [ ] KVKK consent ekranı onboarding'de
- [ ] Hesap silme akışı (3 tıklamadan kısa) **zorunlu**
- [ ] Misleading health claim yok ("kesin garanti" gibi)

### 13.5 Analytics Checklist

- [ ] PostHog event'leri test edildi (onboarding flow, paywall view, purchase)
- [ ] Custom event'ler: `onboarding_complete`, `paywall_view`, `trial_start`, `subscription_active`
- [ ] PostHog 5s timeout aktif (Phase 94)
- [ ] Funnel'lar dashboard'da kurulu
- [ ] PII (kişisel veri) PostHog'a **gönderilmiyor**
- [ ] User ID hashing (Supabase UUID raw değil, hash)

### 13.6 RevenueCat Checklist

- [ ] 3 SKU production'da: `formai_pro_monthly`, `formai_pro_3month`, `formai_pro_annual`
- [ ] Sandbox'ta tüm 3 SKU satın alma test edildi
- [ ] Trial → paid geçişi test edildi
- [ ] Refund handling (RevenueCat webhook)
- [ ] Restore purchases butonu çalışıyor
- [ ] Auth gate aktif — anonim kullanıcı satın alamaz (Phase 94)
- [ ] Store-localized fiyatlar paywall'da görünüyor (Phase 95)
- [ ] Skeleton loading state aktif (Phase 95)

### 13.7 Notification Checklist

- [ ] FCM (Firebase Cloud Messaging) ya da OneSignal kurulu
- [ ] Push permission Android 13+ runtime istek
- [ ] Streak hatırlatması 20:00 yerel saat
- [ ] Antrenman bildirimi (planlandıysa)
- [ ] Trial bitiş 24 saat önce uyarı
- [ ] Notification deep-link (push'a tıklayınca doğru ekran)
- [ ] Notification opt-out (Settings ekranında)

### 13.8 Deep-Link Checklist

- [ ] `formai://workout/today` → bugünkü antrenman
- [ ] `formai://paywall` → paywall ekranı
- [ ] `formai://profile` → profil
- [ ] App Links (https://formai.app/...) doğrulandı (assetlinks.json)
- [ ] Push notification → deep link → doğru ekran açılıyor
- [ ] Cold start deep link çalışıyor

### 13.9 Onboarding Checklist

- [ ] Onboarding 12-15 ekran arasında
- [ ] Quick-win moment (Adım 9) etkili
- [ ] AI plan generate animasyonu 8-12 saniye
- [ ] Skip butonu yok (linear akış)
- [ ] Geri butonu hep aktif
- [ ] Onboarding tamamlama oranı %70+ (closed test'te)
- [ ] Onboarding sırasında crash yok
- [ ] KVKK consent ekranı entegre

---

## 14. YAYIN SONRASI İLK 30 GÜN STRATEJİSİ

### 14.1 Felsefe — "İlk 30 gün sermaye-yoğun, son 60 gün ölçek"

İlk 30 gün **datayı toplama** ve **iterasyon** günleridir. Pazarlama burada büyük ölçek değil, **kalite optimizasyonu** demektir.

### 14.2 Hafta 1 — Kritik İlk Hafta

#### **Günlük rutin (her sabah 15 dk):**
1. Crash & ANR rate kontrol (eşik aştıysa **rollback**)
2. Yeni review'lara yanıt
3. Support e-postalarına yanıt
4. PostHog funnel: önceki günün conversion'ı
5. Play Console: organic vs paid breakdown

#### **Acil yangın söndürme:**
- Bir bug %20+ kullanıcıyı etkiliyorsa **24 saat içinde fix release**
- Crash spike → staged rollout durdur
- Negatif review wave → **kaynak araştır**, yanıt ver

### 14.3 Hafta 2 — İlk Iterasyon

#### **Veri analizi (PostHog):**
- En çok drop-off olan onboarding adımı?
- Paywall'da hangi planı seçiyor (mostly aylık → fiyat algısı sorunu)
- Trial-to-paid yüzdesi
- D1 retention

#### **Hipotez test başlat:**
- Bir hipotez seç (örn: "screenshot 1'i değiştirirsem CTR %20 artar")
- Play Console **Store listing experiments** ile A/B test (14 gün)

### 14.4 Hafta 3 — ASO İterasyonu

#### **Play Console acquisition reports:**
- Hangi keyword'lerden ziyaret?
- Hangi keyword'lerden install?
- En yüksek install/visit oranlı keyword → **başlığa veya açıklamaya tırmandır**
- En düşük → kaldır

#### **Subtitle test:**
- Yeni subtitle versiyonu yaz
- 7 gün deploy → conversion ölç

### 14.5 Hafta 4 — Screenshot İterasyonu

İlk 14 günün verisi geldi:
- En düşük scroll-through oranlı screenshot → değiştir
- En yüksek conversion'lı screenshot pozisyonunu **#1**'e taşı (zaten oradaysa, mesajını **header'a** çıkar)
- A/B test mesaj varyantı

### 14.6 Paywall İterasyonu

#### **PostHog paywall funnel'ı:**
- Paywall view → trial start: hedef %15+
- Trial start → paid: hedef %50+
- Paid → renewal (sonraki ay): hedef %75+

#### **Test edilebilir varyantlar:**
- 3 plan vs 2 plan (3-monthly çıkar)
- Trial 7 gün vs 14 gün
- Yıllık vurgu vs aylık vurgu
- Sosyal kanıt eklenmesi

### 14.7 Retention Optimization

#### **D1 düşükse:**
- Onboarding completion düşük → kısalt
- Quick win moment yok → ekle (ilk antrenman ekranı **çok kolay**)

#### **D7 düşükse:**
- Streak görselleştirmesi zayıf
- Push notification timing yanlış
- App boring (yeni içerik gelmiyor)

#### **D30 düşükse:**
- Ürün **özünden** dar — ekstra hedefler ekle (kol, sırt, full-body)
- Topluluk yok → Discord aç

### 14.8 Notification Optimization

PostHog'da analiz et:
- Push CTR (open rate): hedef %12+ (sektör %5-8)
- Hangi push mesajı en yüksek?
- Hangi saat?
- Optimal frequency: **günde 1**, **maksimum**

#### **Test edilecek varyantlar:**
- "Bugünkü antrenman bekliyor 💪" vs "Streak'ini kaybetme — 18:00'a kadar" (loss aversion daha güçlü)
- Sabah vs akşam push
- Personalized name vs generic

### 14.9 Review Monitoring

#### **Günlük:**
- Yeni review'lar oku (tüm dillerde)
- Negatif review'a 24 saat içinde yanıt
- Pozitif review'a teşekkür (maks 2 gün)
- Pattern ara: 3+ kişi aynı bug'ı söylüyor → bug

#### **Haftalık:**
- Rating ortalaması trendi
- Review hacmi trendi
- Negatif review yüzdesi (target <%15)

### 14.10 Rakip İzleme

- 3-5 ana rakibi App Annie / Sensor Tower / SimilarWeb (ücretli) veya manuel haftada bir kez izle
- Yeni screenshot? Yeni başlık? Yeni özellik?
- **Onlardan kopya çekme** — onların yaptığı **olmayanı** yap

### 14.11 Day 30 Retrospective

30 günün sonunda:
- Genel retention numaraları sektör benchmark'ına vs?
- Trial-to-paid conversion?
- LTV / CAC oranı (eğer paid acquisition yapıldıysa)
- Hangi keyword'ler değerli?
- Hangi screenshot kazandı?
- Hangi paywall versiyonu kazandı?

→ **Day 31-90 stratejisi** bu retrospective ile yazılır. Generic plan ile değil, **gerçek veriyle.**

---

## SON SÖZ — STRATEJİK DEĞERLENDİRME

FormAI / SixPack AI **iyi konumlanmış bir lansmana hazır:**
- Kategoride niş bir vaat (30 gün karın kası)
- Diferansiyatör (AI form detection)
- Türkçe-first avantajı
- Modern stack (Flutter, Supabase, RevenueCat)

**Lansman başarısı için 3 risk:**
1. **İsim krizi:** "SixPack AI" generic — production öncesi **FormAI'ya** geçiş kritik
2. **Premium algı:** UI premium hissetmiyorsa fiyat itirazı doğar
3. **Onboarding:** Quick-win moment yoksa retention çöker

**3 risk çözüldüğünde:**
- 30 günde 5.000+ install ulaşılabilir
- 90 günde $10K MRR mümkün
- 12 ayda Türkiye fitness kategorisinde ilk 10

> Bu doküman bir **launch playbook**'tur, ezberlenmek için değil — **referans olarak kullanılmak için** yazıldı. Her sprint sonunda ilgili bölümü tekrar oku, gerçek veriyle güncelle.

---

**Hazırlayan:** FormAI Launch Strategy Team
**Versiyon:** 1.0 — Production Launch Edition
**Son güncelleme:** 2026-05-08
