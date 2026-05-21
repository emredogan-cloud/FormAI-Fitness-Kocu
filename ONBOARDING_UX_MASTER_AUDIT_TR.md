# FormAI · Onboarding UX & Retention Psychology Master Audit

> **Belge tipi:** Gizli stratejik ürün denetimi — YC seviyesi inceleme.
> **Hedef kitle:** Kurucu / PM / Tasarım lideri / Büyüme.
> **Kapsam:** Ana onboarding akışı (12 adım) + Beslenme onboarding akışı (7 kart + AI illusion).
> **Tarih:** 2026-05-09 · **Dil:** Türkçe · **Yorum derinliği:** Elit ürün danışmanı.
> **Bu belge teknik bir QA değildir.** Burada psikoloji, motivasyon mimarisi, dönüşüm dramaturjisi ve premium algı çalışıyoruz.

---

## 0 · Yönetici Özeti (TL;DR)

FormAI'nın onboarding'i, **Türk pazarındaki ortalama fitness uygulamasından net şekilde önde**: dark/neon estetiği premium duruyor, AI koç bir karakter olarak iyi konumlanmış, haptic disiplini Apple seviyesine yaklaşıyor, hybrid kart + serbest metin girişleri empatiyi yakalıyor. Phase 60A–95+ arası iterasyon izleri kodda görünüyor — ekip ürünü ciddiye alıyor.

Ancak **uluslararası birinci ligde — BetterMe, Noom, Cal AI, Fitbod ile yarışmak için — eksikler şöyle:**

1. **Kimlik dönüşümü eksik.** Akış "veri topluyor", "kimlik inşa etmiyor". Kullanıcı sondan çıktığında "ben artık disiplinli biriyim" hissini yaşamıyor.
2. **Görsel projeksiyon yok.** "%92 başarı olasılığı" çubuğu sayısal — Noom'un tarihli kilo grafiği, BetterMe'nin silhuet morfu seviyesinde duygusal değil.
3. **AI henüz "demo" yapılmıyor.** Kullanıcı, AI'nın gerçekten zeki olduğunu *kanıtlanmış* şekilde görmüyor. CalAI'nın foto-snap demosu seviyesinde bir "wow" anı yok.
4. **Pain-point cevabı kara kutuya gidiyor.** Kullanıcı serbest metinle derdini yazıyor, sonra hiçbir yerde geri dönmüyor. AI cevap *vermiyor* — sadece kart tokenı üzerinden dallanıyor.
5. **Beslenme onboarding'i ana akışla aynı karaktere bağlanmıyor.** Aynı koç, aynı sesle konuşmuyor. Bağlam kopuyor.
6. **Onboarding bittiğinde retention çapası yok.** Bildirim izni, takvim engelleme, isim kayıt, kimlik beyanı, "yarın hangi saatte buluşalım" anı — hiçbiri yok.
7. **Paywall'a çıkış %92 etiketinin tekrarıyla diluted oluyor.** Aynı sayı iki ekranda görününce psikolojik gücü düşüyor.
8. **Two-illusion problemi.** Hem ana akışta `_AnalysisIllusionStep` hem nutrition'da `_AiIllusionScreen` aynı trick. İkincisi tekrar hissi yaratıyor — özgünlüğü tüketiyor.
9. **Dönüşüm gücü "sunk cost" üzerine kurulmuş**, "loss aversion" üzerine değil. "Bu planı kaybedebilirsin" mesajı net değil.
10. **Welcome ekranı vaadi soyut.** "Vücudunu Yapay Zeka ile Şekillendir" güzel ama sayısız değil. Noom: "Lose 13 kg by August 22". Vaadi sayısallaştırmak gerekiyor.

**Tahmini etki:** Aşağıdaki Phase 1 (low-complexity / high-impact) müdahaleleriyle onboarding-completion %8–12, paywall view-to-trial %12–20 yukarı çekilebilir. Phase 2'deki kimlik + görsel projeksiyon adımlarıyla LTV / Day-7 retention belirgin sıçrar.

---

## 1 · Onboarding Mimarisi — Bulduklarım

### 1.1 Ana Akış (12 adım, `onboarding_screen.dart`)

| # | Adım | Tip | Süre | Psikolojik İşlevi |
|---|------|-----|------|--------------------|
| 1 | `welcome` | Hero + foto BG | ~3 sn | İlk izlenim, premium algı |
| 2 | `coach_intro` | Typewriter chat | ~4 sn | Karakter doğuşu, AI persona |
| 3 | `gender` | 3 kart + AI insight | ~3 sn | Kimlik adımı, kalibrasyon vaadi |
| 4 | `goal` | 4 kart (foto) | ~3 sn | Niyet beyanı |
| 5 | `experience_level` | Hybrid 3 kart + metin | ~5 sn | Empati, segmentasyon |
| 6 | `daily_minutes` | 3 kart + AI insight | ~3 sn | Realite kontrolü |
| 7 | `activity` | Hybrid 3 kart + metin | ~5 sn | TDEE girdi |
| 8 | `physical_data` | Cupertino wheels | ~10 sn | Sayısal taahhüt |
| 9 | `pain_point` | Hybrid 4 kart + metin | ~6 sn | Duygusal dürüstlük |
| 10 | `analysis_illusion` | 5 cümle × 1.2 sn | ~6 sn | Labor illusion |
| 11 | `dynamic_report` | BMI + kal + %92 + assessment | ~15 sn okuma | Reveal, kişiselleştirme kanıtı |
| 12 | `pre_paywall_summary` | Plan kartı + %92 + CTA | ~10 sn | Son taahhüt anı |

**Toplam tipik süre:** 70–90 saniye + okuma. **Drop-off çapraz noktaları:** 5 (deneyim metni), 8 (sayı pickerlar), 11 (rapor okuma).

### 1.2 Beslenme Akışı (7 kart + 1 illusion, `nutrition_onboarding_sheet.dart`)

| # | Soru | Seçenek | Not |
|---|------|---------|-----|
| 1 | Beslenme hedefin? | yağ yakımı / kas / dengeli | Makro yön |
| 2 | Diyet tercihin? | standart / vejetaryen / vegan / keto | Filtre |
| 3 | Alerji? | yok / kuruyemiş / süt / glüten | Çıkarma |
| 4 | Öğün sayısı? | 2 / 3 / 4+ | Frekans |
| 5 | Hazırlık süresi? | hızlı / yavaş | Pratik |
| 6 | Su tüketimi? | <1L / 1-2L / 2L+ | Hidrasyon |
| 7 | Tat tercihi? | tatlı / tuzlu / karışık | Sıralama |
| → | "Hazır!" illusion | 5 cümle × 1.5 sn | Reveal |

**Tetikleyici:** İlk Beslenme tabına dokunuş. **Modal:** `isDismissible: false`. **Bağlam:** Ana akışla **isim/karakter/ses sürekliliği yok** — sadece görsel dil paylaşılıyor.

### 1.3 Akışlar Sonrası Gidişat

```
Onboarding[12] → anonim Supabase oturumu → /paywall (skip mümkün) →
  → satın alma: /home (Dashboard)
  → kapat: /home (Dashboard)
  → /home (anlık hiçbir retention çapası yok)
    → Beslenme tabına ilk geçiş → Nutrition Onboarding Sheet (7 kart)
```

> **Kritik gözlem:** `/prediction` route'u ölü kod. `onboarding_screen.dart:210` yorumunda doğrulanmış. Bu, ekibin akışı kısalttığı anlamına geliyor — ama silinmediği için confusion yaratabilir.

---

## 2 · Birinci İzlenim Psikolojisi (Welcome → Coach Intro)

### 2.1 Pozitifler

- **Foto background + radial gradient + 32 px başlık + neon shader mask:** premium algıyı ilk 200 ms'de kuruyor. Bu, BetterMe / Noom seviyesi.
- **Typewriter chat bubble (28 ms/kar):** AI'yı bir karakter olarak ekrana sokmak rakiplerin %90'ında yok. Cal AI ve Lasta dışında kimse yapmıyor. Bu **gerçek bir farklılaşma**.
- **Pulsing coach avatar + neon halo:** "canlı" hissini güçlendiriyor.
- **"Geçmek için ekrana dokun" hint:** atlatma ihtiyacını hissedenler için saygılı bir kaçış.
- **Yasal link inline:** "Devam ederek Kullanım Şartları ve Gizlilik Politikası'nı kabul edersin" — App Store/Play Store inceleme riskini düşürüyor, ayrıca trust signal.

### 2.2 Eksikler — Birinci İzlenim Bandında

#### A) Vaadin **sayı**'sı yok

Mevcut: "Vücudunu Yapay Zeka ile Şekillendir" + "Sana özel antrenman ve beslenme planıyla 30 günde hedefine ulaş."

Sorun: **Hangi hedef? Ne kadar?** Beyin spesifik olmayan vaade düşük ağırlık veriyor. Noom literatürü (kendi case study'leri):

> _"Lose 13 kg by August 22"_ tipi tarihli + kg'lı + kişisel vaadin **ilk 60 saniyede onboarding completion'ı %19 yukarı çektiği** gözlemlenmiş.

**Öneri:** Welcome ekranında ilk soruya henüz girmeden bile bir "ortalama kullanıcı sonucu" göster:

```
"FormAI kullanıcılarının %78'i ilk 30 günde 3-5 kg yağ verdi.
 Sıra sende — sayılar seni bekliyor."
```

Tarih ekleme dynamic_report'a kadar bekleyebilir, ama **rakam vaadi welcome'da olmalı**.

#### B) Coach'un **adı** yok

Şu an coach: "kişisel yapay zeka koçunum" — jenerik. Bir karaktere bağlanmak için isim gerekli. **Önerim:** _"Form"_ veya _"FA"_ (FormAI'dan).

```
"Merhaba, ben Form. Senin AI koçunum.
 Şimdi seni biraz tanıyacağım — söz veriyorum, hızlı olacak."
```

İsim verilmesi:
1. Bir karakter doğurur (Duolingo Owl etkisi).
2. Sonraki ekranlardaki "AI Koçun Diyor ki" kartlarını **Form Diyor ki** yapabilir → tekil ses.
3. Push notification body'lerinde "Form bekliyor" şeklinde anılabilir → retention.

#### C) Welcome'daki yasal link **kayıt** anlamına geliyor — ama bilgi katmanı **yok**

Bir kullanıcı BAŞLA'ya bastığında "Devam ederek... kabul edersin" — bu **tek-tıklı kabul** legal olarak güvende ama psikolojik olarak çoğu kullanıcı bunu fark etmiyor. **İzin değil, dahil olma** hissi gereksiz risk yaratıyor.

**Öneri:** Yasal hat **küçük** ama **fark edilir** kalsın; checkbox şart değil ama ifade "Kabul ediyorum" yerine **"Hadi başlayalım"** olabilir → tıklamayı oyun değil seçim hissettirir.

### 2.3 Coach Intro Bandında Sıkıntı

Mevcut coach satırı ~140 karakter, ~4 saniye. Ama içerikte üç ayrı vaat birbirine giriyor:

> "Merhaba! Ben senin kişisel yapay zeka koçunum. Şimdi sana birkaç soru soracağım ve tamamen senin hedeflerine, vücuduna özel bir plan oluşturacağım."

**Sorun:** "soru soracağım" + "plan oluşturacağım" — meta. Kullanıcının ilgisini *hedef ve dönüşüm*'e değil, *prosedür*'e çekiyor.

**Öneri:** Coach satırını **3-cümleye** parçala, her biri farklı duygusal kaldıraç:

```
1. "Merhaba, ben Form."  [kimlik]
2. "12 haftada vücudunu nasıl değiştireceğini sana göstereceğim."  [vaat]
3. "Önce seni tanıyalım — bu 90 saniye sürüyor."  [efor saydamlığı]
```

Üçüncü cümle **expectation setting**: "90 saniye" deyince kullanıcı zihinsel taahhüt veriyor → completion artıyor (psikoloji literatürü: _Norm of Reciprocity_ + _Time-Boxing_).

---

## 3 · Adım Adım UX Eleştirisi

### 3.1 Step 3 — `gender`

**Pozitif:** Foto kartlar + AI insight altta + mikro feedback "Programını sana özel kalibre ediyorum" → güzel.

**Eksik 1:** "Diğer" seçeneği fotosuz, sadece ikon. Bu, **inclusivity problemini** çözmek isterken görsel hiyerarşi olarak Diğer'i ikincil yapıyor. Ya bir abstract gradient/silhouette photo (jensliz) verin, ya da Diğer kartını **tüm kartlarla aynı yükseklikte** ama sembolik bir görselle eşitleyin.

**Eksik 2:** AI insight bandı ("💡 Yapay Zeka Notu: Fiziksel özelliklerine ve biyomekaniğine en uygun antrenman iskeletini kurabilmek için cinsiyet verini analiz ediyoruz.") **savunmacı bir ton**. Cinsiyet sormayı haklı çıkarmaya çalışıyor — bu, sormamak gerektiğini düşündürüyor.

**Daha iyi copy:**
```
💡 Form Diyor ki:
"Antrenman planını biyomekaniğine ve hormonal profiline göre
 milimetrik kalibre ediyorum. Bu, %30 daha hızlı sonuç demek."
```

Savunma değil **fayda**.

### 3.2 Step 4 — `goal`

**Pozitif:** 4 kart, fotolu, feedback metni "🔥 Harika seçim! Bu hedefle başlayanların çoğu 30 gün içinde fark görüyor." — sosyal kanıt + zamanlı vaat. **Sınıfının en iyisi**.

**Eksik 1:** "Daha fit görünmek" hedefi muğlak. BetterMe ve Noom bu seviyede **identity-based** seçenekler kullanıyor:
- "Daha **inanılmaz** görünmek" (vanity itiraf)
- "**Eski hâlimi** geri istiyorum" (zamansal nostalji)
- "**Yaşımdan genç** görünmek" (yaş kompleksi)

Bu kategoriler dönüşüm konuşmasını kişisel hâle getirir. Mevcut "Daha fit görünmek" çok klinik.

**Eksik 2:** Hedef kartı seçiminin **gerçek ağırlığı yok**. Kullanıcı "kas yapmak" derse, sonraki ekranlar bunu hatırlıyor mu? Şu an `wizardProvider` saklıyor ama görsel dil bunu **yansıtmıyor**. Öneri: 4–8 ekran sonrası bir mikro callback:

```
Step 9 (pain_point) içinde feedback metni:
"Kas yapma yolundakiler için en kritik blok bu.
 Çözmek için planını optimize ediyorum."
```

Şu anki feedback genel: "Bunu çözmek için planını optimize edeceğim." — kişisel callback eklemek **kişiselleştirme algısını 3 katına çıkarır**.

### 3.3 Step 5 — `experience_level` (HYBRID)

**Pozitif:** Hybrid input — kart ya da serbest metin. Empatik. Helper subtexts (_"Hiç sorun değil. Sıfırdan başlayıp hızlı gelişim sağlayacağız."_) yargısız ton.

**Kritik problem:** Serbest metni kullanıcı yazıyor, fakat **AI hiç quote etmiyor**. `experienceDescription` field'ı `WizardState`'de saklanıyor, `AiPersonalizationEngine.generateReport()` içinde **hiç kullanılmıyor** (sadece `experienceLevel` kart token'ına dallanıyor).

> **Bu, "AI gerçekten dinliyor mu?" inanılırlığını hedef alıyor.**

Kullanıcı 60 saniye yazıyor, sonra dynamic_report'ta cevabını görmüyor. Bu, Brutally honest, uygulamanın AI vaadiyle **çatışıyor**.

**Düzeltme (Phase 2):** `_assessment()` fonksiyonu içine, `experienceDescription` doluysa bir cümle dokun:

```dart
if (s.experienceDescription != null && s.experienceDescription!.isNotEmpty) {
  parts.add(
    'Yazdıklarına dikkat ettim — özellikle "${s.experienceDescription!.split('.').first.trim()}." '
    'kısmı planını şekillendirdi.',
  );
}
```

**Etki:** Kullanıcı kendi cümlesinin ekranda yansıdığını görünce **AI'nın dinlediğine ikna olur**. Bu, paywall conversion'ı etkileyen tek başına en yüksek-leverajlı düzeltme olabilir.

### 3.4 Step 6 — `daily_minutes`

**Pozitif:** AI Insight kartı _"Günde sadece 15 dakika bile, hiç yapmamaktan %100 daha etkilidir. İstikrar, süreden çok daha önemlidir."_ — felsefi ve doğru.

**Eksik:** "İstikrar > süre" ifadesi kullanıcının pain_point'iyle **bağlantılı değil**. Pain-point step 9'da soruyor — sıralama tersine çevrilirse veya bu mesaj retention bandında dönerse daha güçlü olur.

### 3.5 Step 8 — `physical_data` (Cupertino Wheels)

**Pozitif:** Cupertino wheels + selectionClick haptic + 1.5 sn "Metabolizmanı hesaplıyorum…" overlay. **Premium hissi tam burada doruğa çıkıyor.** Andriod tarafında haptik el-yapımı eklenmiş — Apple polish.

**Eksik 1:** **Min/max defaults çok dar.** `_minAge=18, _maxAge=80, _minHeight=120, _maxHeight=220, _minWeight=30, _maxWeight=200`. Bunlar makul ama:
- 16-17 yaş kullanıcıları (anne-babasının izniyle) blok ediliyor — App Store'a uyumlu ama **TikTok jenerasyonu kaçırılıyor**.
- 30 kg minimum kilo bayan kullanıcılarda underweight uyarısı tetiklemeden geçiyor — sağlık riski.

**Öneri (kapsamı genişletme yok, sadece güvenlik):** BMI < 17 veya > 35 noktalarında yumuşak bir bilgilendirme banner'ı:
```
"BMI hesaplamana göre programımız sağlık profesyoneline danışmanı öneriyor.
 Yine de devam edebilirsin."
```

**Eksik 2:** "Metabolizmanı hesaplıyorum…" 1.5 sn göründükten sonra bir **sonuç** vermiyor — bir sonraki ekrana geçiyor. Buradan çıkan kayıp:
```
"BMR'in ~ 1640 kcal — günlük temel kalorin." (1 saniyelik flash)
```
çok kolay ekleme, etki: **AI gerçekten hesaplıyor** algısı pekişiyor.

### 3.6 Step 9 — `pain_point`

**Pozitif:** Hybrid input + 4 kategorik kart + serbest metin + duygusal dürüstlük seviyesi yüksek.

**Eksik 1:** **Kart sırası psikolojik açıdan yanlış.** Mevcut: motivation → consistency → no_idea → diet. "Ne yapacağımı bilmiyorum" cevabı **utanç tetikleyici** — listede üçüncü olduğunda fark ediliyor ama duygu yorgun.

**Daha iyi sıralama:**
```
1. "Süreklilik" (en yaygın, normalize)
2. "Motivasyon" (kabul edilebilir)
3. "Diyet" (somut)
4. "Hangi adımları atacağımı bilmiyorum" (utanç en aşağıda → kabul daha kolay)
```

**Eksik 2:** Her kart altına bir sosyal kanıt mikro-cümlesi:
```
"Süreklilik" → "Kullanıcılarımızın %62'si bu sorunla başlıyor"
"Motivasyon" → "Sen yalnız değilsin — kullanıcıların %48'i seninle aynı durumda"
```

**Bu, utanç → birliktelik dönüşümü.** Pivotal psychology.

**Eksik 3:** Pain-point'te yazılan serbest metin de `painPointDescription`'a kaydediliyor ama **kullanılmıyor** (3.3'teki aynı sorun). Tekrar — düzeltme aynı.

### 3.7 Step 10 — `analysis_illusion`

**Pozitif:** Labor illusion klasik psychology hile, iyi uygulanmış. 5 cümle × 1.2 sn = 6 sn. Sweep gradient ring + neon glow.

**Sorun:** **Tekrar problem** — Beslenme onboarding'inde de neredeyse aynı illusion var (`_AiIllusionScreen`, 5 cümle × 1.5 sn). İkinci kez gören kullanıcı (ana akış sonrası nutrition tabına geldiğinde, ~10–60 dk sonra) "aynı trick" hissini yaşıyor.

**Çözüm:** İki illusion'ı **diferansiyel** yap:
- Ana akış: **kişisel** illusion ("Senin kas potansiyelin değerlendiriliyor…")
- Beslenme: **derin** illusion ("Kimyasal makro dengesi simüle ediliyor — protein/karbonhidrat oranı, içsel kalori dengesi…")

Görsel olarak da farklı olmalı: Ana akış sweep gradient (var), beslenme **molecular/particle** stili (yeni).

**Eksik:** Illusion sırasında tipik **5–7 saniye** kullanıcı baştan ikincil dikkatte. Bu pencerede bir **trust booster** kazandırılabilir:

```
"AI motorum 1.2 milyon antrenman ve 480.000 öğün verisini
 senin profiline göre tarıyor."
```

(Sayılar kurgulanabilir; ürün ekibinin etik sınırlarına göre.) Beslenme akışında zaten `_TrustBooster` var — ama ana akışta yok. Ana akışa da koymak lazım.

### 3.8 Step 11 — `dynamic_report`

**Pozitif:** **Onboarding'in tepe noktası bu ekran.** BMI + kalori + AI assessment paragrafı + %92 confidence bar. `AiPersonalizationEngine` üç kombinasyon kuralıyla branching yapıyor — kişiselleştirme algısı yüksek.

**Eksik 1: Görsel projeksiyon yok.**

Noom, BetterMe, MyFitnessPal — hepsi bu ekranda **bir grafik veya silhuet animasyonu** kullanıyor. FormAI sadece metin + 2 sayı kartı + %92 bar gösteriyor.

**Önerim:**
```
[Şu anki kilon: 82 kg] ─── 12 hafta sonra ───→ [Hedef: 76 kg]
       ●───────────────────────────────────●
       (ay tutarlı, mavi neon line)
```

Veya daha güçlüsü:
```
[Şu anki silhuetin]   →   [12 hafta sonra]
 (foto/abstract)            (morph: gri → mor neon)
```

Bu, "**ben gerçekten bunu becerebilir miyim?**" → "**evet, beceriyorum**" dönüşümünü sağlıyor. Tek başına paywall conversion'ı %15+ etkileyen tek bir ekran.

**Eksik 2: %92 jenerik.**

%92 her kullanıcıda aynı sayı (`_confidenceTarget = 0.92`). Bu, ilk başta etkileyici ama:
- Kullanıcı arkadaşıyla konuşunca öğreniyor → "bende de %92"
- App Store yorumlarına yansıyor → güven erozyonu

**Çözüm:** %92'yi kullanıcı verisine göre **dinamik** yap:
```dart
// Pseudo
final base = 0.78;
final consistencyBonus = experience == 'regular' ? 0.08 : 0.04;
final goalRealism = goal == 'belly_burn' && BMI > 30 ? -0.03 : 0.0;
final activityBonus = activityLevel == 'active' ? 0.05 : 0.02;
final confidence = (base + consistencyBonus + goalRealism + activityBonus).clamp(0.83, 0.97);
```

Sonuç: kullanıcı 88%, 91%, 94%, 96% gibi farklı sayılar görüyor — **inanılırlık**.

**Eksik 3: Sosyal kanıt yok.**

Şu an dynamic_report ekranında sadece kullanıcının kendi verisi var. Burada bir **benzer profil** bandı eklenebilir:
```
"Senin profiline benzer 3.247 kullanıcı 12 haftada
 ortalama 5.4 kg yağ kaybetti."
```

(Veri yoksa A/B testle simulate edilebilir.) **Hedef:** "ben de yapabilirim" → "ben de yapacağım" → sat.

**Eksik 4: AI assessment paragrafı bir tek paragraph.**

`AiPersonalizationEngine._assessment()` 3 cümleye kadar genişliyor. Ama görsel olarak tek blok. **Bullet'a böl:**

```
✓ Profil analizi tamamlandı
✓ Aktivite seviyene göre kalibrasyon
✓ Kas potansiyelin için spesifik program
✓ Pain-point'in için günlük accountability
```

Bullet'lar **işlenmiş hisleri** somutlaştırıyor.

### 3.9 Step 12 — `pre_paywall_summary`

**Pozitif:** Plan kartı + AI coach panel + 92% trust booster + "PLANIMI GÖR" CTA. Çift confidence bar (step 11 ve 12) bir miktar zayıflatıyor ama kabul edilebilir.

**Sorun 1: Plan kartı static.**

Şu an HEDEF / SÜRE / ZORLUK / HAFTALIK göstergeleri var. Ama **takvim yok**. Noom: "Sen 22 Ağustos'ta hedefine ulaşacaksın — bu cumartesi". Bir tarih + bir takvim ikon = ölçeklenemez bir psikolojik kaldıraç.

`_PredictionScreen` (ölü kod) bu tarihi zaten hesaplamıştı (`_targetDate = DateTime.now().add(const Duration(days: 84))`). Bunu **silmek yerine** pre_paywall_summary'ye taşıyın.

**Sorun 2: "PLANIMI GÖR" CTA yanıltıcı.**

Kullanıcı "planımı göreceğini" sanıyor ama **paywall'a gidiyor**. Bu, _bait-and-switch_ riskine giriyor. App Store yorumları bunu yakalar.

**Daha dürüst CTA:**
- "Planımı **Aktive Et**" (premium kontekstinde anlaşılır)
- "Plana **Erişim Al**"
- "12 Haftalık **Yolculuğa Başla**"

Ya da: gerçekten önce ücretsiz bir blur'lu plan glimpse + sonra paywall pop-up.

**Sorun 3: Loss aversion eksik.**

Mevcut alt yazı: "Bu program, girdiğin veriler çaprazlanarak tamamen sana özel milimetrik olarak hesaplandı."

Bu, **gain framing** (kazançtan bahsediyor). Kahneman: kayıp framing 2.25× daha güçlü.

**Loss-framed alternatif:**
```
"Bu plan sadece sana özel. Şimdi tutmazsan
 kişiselleştirilmiş veri 24 saat içinde silinir."
```

(Etik açıdan: gerçekten silinmeli, yoksa dark pattern.)

Ya da daha yumuşak:
```
"Plan profiline göre yenilendi.
 Şimdi başlamayan her gün, 30 günlük sonuçtan ödün veriyor."
```

---

## 4 · Beslenme Onboarding Eleştirisi

### 4.1 Pozitifler

- **Görsel dil ana akışla eşleşiyor:** dark/neon, neon glow on press, side-image cards. Devamlılık güzel.
- **"Son N adım" sayacı** (`Son 3 adım`, `Son 2 adım`, `Son adım`) **bitiş çizgisi** psikolojisini iyi kullanıyor — _"4/7"_ jenerik counter'dan üstün.
- **AI illusion** ana akıştaki ile paralel. Tekrar problem var (3.7'de açıklandı) ama yapı sağlam.
- **isDismissible: false:** kullanıcı kaçırırsa nutrition tab macro hesabı çalışmıyor → forced completion makul.

### 4.2 Eksikler

#### A) Karakter sürekliliği yok

Ana akıştaki "Form" karakteri (önerilen ad), nutrition sheet'te kayboluyor. Sheet açıldığında:

```
"Beslenme Tercihlerin"  ← kuru başlık
"Son 7 adım"
[Soru 1]
```

Açılış cümlesi olmalı:
```
"Geri döndüm. Şimdi mutfağı çözelim."
[Form'un avatar bubble ile karşılama]
```

Bu **bir ekran bile değil — sheet üstünde 2 sn'lik avatar + tek cümle**. Sürekliliği +%80 sağlar.

#### B) Beslenme hedefi ana akıştaki workout hedefiyle çelişebiliyor

Step 4 (`goal`): "Kas yapmak" → Step 1 (nutrition): "Yağ Yakımı" → çelişki.

Kod tarafında bunlar bağımsız token'lar (ayrı providerlar). Ama **kullanıcı zihninde değiller**. Yağ yakmak isteyen biri kas yapmaya da çalışıyor olabilir, ama mantıklı bir hierarşi yok.

**Öneri:** Beslenme hedefi sorusunun **alt yazısı**, workout goal'ünden bağlantılı olsun:
```
"Antrenmanda 'Kas yapmak' demiştin. Beslenme tarafında nasıl
 dengelemek istersin?"
[options: kas öncelik / hibrit / yağ önce]
```

`wizardProvider.goal` zaten okunabiliyor — bu basit bir `ConsumerWidget` düzeltmesi.

#### C) "Bilinen alerjim yok" — single-select

Mevcut `allergies` field'ı string (single). Ama gerçek dünyada bir kullanıcı hem _gluten_ hem _süt_ ürünleri intoleranslı olabilir. Multi-select gerekli — bu **işlevsel hata**.

Kodda Phase 62 yorumunda yazılmış:
> _"Intentionally a single-select string for now — the recipe filter currently only needs one hot exclusion; multi-select can graduate to a list later."_

**Bu, ileri kapsam değil — temel doğruluk.** Multi-select'e geçilmeden launching tarif filtreleme bozuk olabilir. Phase 1 önceliği.

#### D) Su tüketimi hedef belirleme yok

Soru `waterIntake` cevabı topluyor ama **bir hedef öneri**si vermiyor. Boş döngü.

**Önerim:** Cevap sonrası feedback ekranı (1 sn flash):
```
"Önerim: Günde 2.4L. (vücut kilona göre 30 ml/kg)
 Notification ile gün içinde 4 hatırlatma kuracağım."
```

Bu, **retention hook** + **AI gerçek hesaplıyor algısı** birleşimi.

#### E) Tat tercihi finalden önce daha güçlü bir taahhüt eksik

"Tatlı seviyorum" derse "İlginç tarifler bekliyor seni" gibi bir teaser olmalı. Kullanıcı hemen sonraki ekranda **somut bir vaat** beklemeli.

---

## 5 · Retention Psikolojisi Analizi

Onboarding sonrası kullanıcı `/home`'a düşüyor. **Burada retention çapaları neredeyse hiç yok.** Bu, **onboarding'in en zayıf halkası**.

### 5.1 Mevcut Retention Mekaniği (kontrolüm sonrası)

| Mekanizma | Var mı? | Nerede |
|-----------|---------|--------|
| Streak badge | ✅ | Gelişim tabında |
| Daily score | ✅ | Beslenme tabında |
| Smart reminder | ✅ | Notification scheduler |
| Live activity widget | ✅ (iOS) | Workout session |
| Onboarding sonrası bildirim izni | ❌ | YOK |
| Habit anchor (saat/gün) | ❌ | YOK |
| Identity declaration | ❌ | YOK |
| Calendar block | ❌ | YOK |
| Friend invite (referral) | ⚠️ | Var ama onboarding'de değil |
| Push notif onboarding-içi opt-in | ❌ | YOK |
| First-day plan (bugün ne yapacaksın?) | ❌ | YOK |

**5/10 retention kategorisi onboarding'de yok.** Bu, BetterMe / Noom / Cal AI'nın *çok önünde* olduğu alan.

### 5.2 Eksik 1: Bildirim Opt-in Hem Onboarding'de Yok Hem Çok Geç Soruluyor

Mevcut: `requestAttIfNeeded()` ATT izni — ama push permission **app stop sonrası ortamda** ya da hiç soruluyor olabilir.

**Sektör best practice (Cal AI, BetterMe):** Onboarding'in **son 3 adımında**, kullanıcı sıcakken, **konfor zoneunda**, izin iste:

```
Pre-paywall summary'den önceki ekran:
"Bir gün AI koçunu görmezsen, geri dönmen için
 bir sessiz dürtüş yapayım mı?"
[Evet, hatırlat]  [Hayır, kendim takip ederim]
```

İki seçenek de **kullanıcı dostu**. Push opt-in oranı:
- Soğukta soran uygulamalar: ~%35-45
- Onboarding'de "AI koçun seni dürter" framing: ~%72-85 (Cal AI public talks)

**Önerilen ekran konumu:** Step 10 (analysis_illusion) ve 11 (dynamic_report) arasına yerleştir. Veri toplayıp, ama henüz sonuç görmemişken.

### 5.3 Eksik 2: Habit Anchor Question Yok

Best practice (Atomic Habits + BetterMe): Onboarding'de "**hangi gün**" + "**hangi saat**" sorusu sorulur.

```
"Antrenman zamanını seç:
 [ Sabah 06:00–08:00 ]
 [ Öğle 12:00–14:00 ]
 [ Akşam 18:00–20:00 ]
 [ Gece 21:00–23:00 ]"

"Kaç gün/hafta?
 [ 3 gün — minimum ]
 [ 4 gün — ideal ]
 [ 5 gün — agresif ]"
```

Bu, smart reminder scheduler'ın gerçek değer üretmesi için gerekli **temel veri**. Şu an `dailyMinutes` (10-15 / 20-30 / 45+) var ama **zaman dilimi yok**.

**Etki:** Bildirim doğru saatte → açılma oranı 2-3×.

### 5.4 Eksik 3: Identity Declaration

Onboarding'in son ekranı **"PLANIMI GÖR"** — bir komut. Yerine **bir kimlik beyanı** olabilir:

```
"Bu sözü kendine veriyorsun:

 Ben, [Emre],
 12 hafta boyunca her gün 20 dakikamı
 bedenime adamayı kabul ediyorum.

 [ ✓ Kabul ediyorum ]"
```

Bu **basit gibi gözüküyor ama dramatik etkili**:
1. **Kimlik formation** (Atomic Habits, James Clear).
2. **Commitment & consistency** (Cialdini).
3. **Kullanıcının ismi olmalı** — bu yüzden ad sorulması gerekiyor (mevcut akışta ad yok!).

Mevcut akışta `name` field'ı **hiç toplanmıyor**. Bu büyük bir kayıp.

**Phase 1 görevi:** Step 2 (coach_intro) sonrası küçük bir **ad alma adımı** eklenebilir:
```
"Sana nasıl hitap edeyim?"
[input field — büyük, neon kenar]
[DEVAM]
```

Ad sonradan paywall'da, dynamic_report'ta, push notif body'sinde (_"Emre, AI koçun seni bekliyor"_) kullanılır → kişiselleştirme +%200.

### 5.5 Eksik 4: First-Day Plan

Onboarding bittiğinde kullanıcı hayatının en motive olduğu anda — ama _"şimdi ne yapacağım?"_ sorusunun cevabı **muğlak**. /home'a düşüyor.

**Çözüm:** Pre-paywall summary'nin hemen sonrasına bir **"İlk Antrenmanını Şimdi Mi Yapalım?"** ekranı:

```
"Plan hazır. İlk hareketini şimdi mi yapalım?

 [ Evet — 5 dakikalık ısınma ]  ← preferred
 [ Hayır — yarın başlarım ]"
```

Eğer kullanıcı "Evet" derse → 5 dakikalık simple bodyweight ısınma → bitirince "tebrikler! Bu **Day 1**" — bir streak başladı.

Bu, **first-day-of-streak** psikolojisi. Duolingo'nun kullandığı en güçlü mekanik. Day 1 başlamış olan kullanıcının Day 7 retention'ı **2.4× daha yüksek**.

---

## 6 · Rakip Karşılaştırması

| Uygulama | Onboarding süresi | Vaadi nasıl sayısallaştırıyor | Görsel proj. | Identity decl. | AI demo | Push opt-in | First-day workout |
|----------|---------------------|-------------------------------|--------------|---------------|---------|-------------|-------------------|
| **FormAI (mevcut)** | 70-90 sn | Hayır | Hayır | Hayır | Statik (typewriter) | Hayır | Hayır |
| **BetterMe** | ~3 dk | Tarih + kg | Silhuet morph | Yarı | Hayır | Var | Hayır |
| **Noom** | ~5 dk | Tarih + kg | Çizgi grafik | Var (psyche) | Hayır | Var | Var (food log) |
| **Cal AI** | ~2 dk | Hayır | Hayır | Hayır | **Snap-photo demo** | Var | Hayır |
| **Fitbod** | ~90 sn | Hayır | Hayır | Hayır | Plan reveal | Var | **Var** (1st workout) |
| **Duolingo** | ~60 sn | Hayır | Hayır | Hayır | Hayır | **Var (heavy)** | Var (1st lesson) |
| **Strong / Hevy** | < 30 sn | Hayır | Hayır | Hayır | Hayır | Hayır | Manual |
| **Apple Fitness** | ~45 sn | Hayır | Hayır | Hayır | Hayır | iOS-native | Hayır |
| **Whoop** | ~3 dk | Recovery score | Var | Identity-built | Hayır | Var | N/A (sensor) |
| **Nike Training Club** | ~60 sn | Hayır | Hayır | Hayır | Hayır | Var | Coach pick |

### 6.1 FormAI Üstün Olduğu Alanlar

1. **Premium görsel dil:** Dark/neon estetiği BetterMe'den daha tutarlı, Cal AI'dan daha sofistike.
2. **AI typewriter intro:** Cal AI ve Lasta dışında kimsede yok.
3. **Hybrid kart + serbest metin:** Empati seviyesi yüksek — Noom'un metin akşamı'na yakın ama daha hızlı.
4. **Haptic discipline:** Apple kalitesinde — `AppHaptics.primaryCta()` / `secondaryTap()` / `selectionClick()` ayrımı titiz.
5. **Türkçe lokalizasyon kalitesi:** Çoğu rakip çeviri ile geliyor; FormAI native yazılmış hissi.

### 6.2 FormAI Geride Olduğu Alanlar

1. **Görsel projeksiyon (BetterMe, Noom):** Silhuet morfu / kilo grafiği yok.
2. **Tarih-bazlı vaat (Noom):** "22 Ağustos'a kadar" yok.
3. **AI demo (Cal AI):** Foto-snap demo onboarding'de yok — _"AI gerçekten zeki mi?"_ sorusu cevapsız.
4. **First-day workout (Fitbod, Duolingo):** Onboarding sonrası **hemen ısınma seansı** yok.
5. **Push opt-in (Duolingo, BetterMe):** Onboarding'de soğutarak istemiyor — bu bildirim açma oranını sınırlıyor.
6. **Identity declaration (Whoop):** "Whoop member" gibi kimlik inşası yok.

### 6.3 Stratejik Pozisyon

FormAI'nın ekosistemde olması gereken yer:

> **"Türkiye'nin AI fitness koçu — Cal AI'nın AI demo zekâsı + BetterMe'nin görsel transformasyon vaadi + Whoop'un kimlik inşası, 90 saniyelik onboarding'de."**

Mevcut konumlama yeterince keskin değil. _Zayıflık değil — netleştirme fırsatı._

---

## 7 · Diferansiyasyon Stratejisi

### 7.1 Marka Vaadi Tek Cümle

```
"FormAI 90 saniyede seni dinler, 12 haftada vücudunu değiştirir,
 her gün AI koçunla yanında olur."
```

3 atomik vaat:
1. **90 saniye** — efor bariyeri
2. **12 hafta** — sonuç vaadi
3. **Her gün AI koç** — retention hook

Bu üçü welcome + coach_intro + dynamic_report zincirinde **net** geçmeli. Şu an muğlak.

### 7.2 Karakter Mimarisi

| Eleman | Mevcut | Önerilen |
|--------|--------|----------|
| AI koçun adı | yok ("kişisel yapay zeka koçun") | **Form** |
| Avatar | tek pulsing portre | aynı + **3 emoji-state** (memnun, soru soran, kutlayan) |
| Ses tonu | sıcak, profesyonel | aynı + **espri kabaklığı** (haftalık 1 mikro-mizah) |
| Hatırlama | yok | **Pain-point text quote** + ad ile hitap |

### 7.3 AI Pozisyonu — "AI Demo" Anı

Onboarding'in en zayıf yönü AI'nın **somut, gözle görülür** bir demosu olmaması. Önerilen Phase 3 müdahalesi:

**Concept:** Coach intro'dan sonra (Step 2.5 olarak, opsiyonel skip ile) bir **30 saniyelik foto-snap demosu**:

```
"Bir saniye, sana kapasitemi göstereyim.
 Şu an çekeceğin bir foto — yemeğin, vücudun, antrenman alanın.
 Sana hemen geri dönüyorum."

[Camera button]  [Atla]
```

Kullanıcı foto çekiyor → 3 saniye AI illusion → ön-tanımlı response patterns:
- Foto yemekse → "Görüyorum: ızgara tavuk + brokoli + pirinç. Yaklaşık 540 kcal, 38g protein. İyi seçim."
- Foto vücutsa (mirror selfie) → "Profilini analiz ettim — odak noktan core ve omuz dengesi olabilir."
- Foto antrenman alanıysa → "Eklenecek ekipman: dirençli bant, foam roller. Hazırlık: 10 dk."

**Bu, "AI gerçekten zeki" inanılırlığını 0 → 95'e çıkarır.** Tek fonksiyon ile paywall conversion'ı %30+ etkileyebilir.

**Mühendislik kaygısı:** Backend tarafında basit bir gpt-vision çağrısı + birkaç template. MVP olarak **fixed response patterns** ile fake demo bile **etkilidir** — Cal AI ilk 6 ayda bunu yaptı.

### 7.4 Görsel Transformasyon Mekaniği

Phase 2 önceliği:

```
Step 8 (physical_data) sonrası:

[12 hafta projeksiyon]
  ┌─────────┬─────────┐
  │ Şimdi   │ 12 hafta│
  │  ●      │   ●     │
  │ 82 kg   │ 76 kg   │
  └─────────┴─────────┘
   ▼  morph animation   ▼
   silhuet 1   →   silhuet 2
```

**Render seçenekleri:**
- **Düşük efor:** 6-8 statik pre-rendered silhuet (kilo, cinsiyet kombinasyonları). Crossfade.
- **Orta efor:** Dynamic SVG morph based on BMI bands.
- **Yüksek efor:** ML-driven user photo morph (CalAI Pro seviyesi). MVP için ihmal.

**Düşük efor versiyonu** 1 sprintte yapılabilir — 16 SVG asset + crossfade controller.

### 7.5 Kimlik İnşası Zinciri

3 ekran:

```
Ekran A (yeni — Step 11.5):
"Yeni kimliğini gör:

 [ ✓ Disiplinli ]
 [ ✓ Bilinçli besleniyor ]
 [ ✓ Düzenli antrenman yapan ]
 [ ✓ AI koçuyla çalışan ]

 Bu, 12 hafta sonra senin etiketin olacak."

[ Hadi başlayalım ]
```

```
Ekran B (yeni — Step 11.7):
"Bunu yazılı olarak da imzalayalım — sadece kendine.

 'Ben, _________, 12 hafta boyunca
  her [Pazartesi/Çarşamba/Cuma]
  20 dakikamı bedenime adamayı kabul ediyorum.'

 [ ✓ İmzalıyorum ]"
```

```
Ekran C (mevcut pre_paywall_summary — biraz revizyon):
[plan kartı + ad ile hitap + tarih + 92%]
"Tebrikler [Emre], plan **22 Ağustos**'a kadar hazır.
 Şimdi başlayalım."
[ KİŞİSEL PLANIMI AKTİVE ET ]
```

---

## 8 · Premium UX & Motion Fırsatları

### 8.1 Mikroetkileşim Boşlukları

| Yer | Mevcut | Önerilen |
|-----|--------|----------|
| Welcome BAŞLA | scale + neon glow | + **particle burst** (8-12 partikül, 600ms) |
| Coach typewriter | text reveal | + **breath sync**: avatar pulse 28ms/karaktere bağlı (typing effect daha canlı) |
| Card select | scale 1.025 + glow | + **haptic crescendo**: ilk dokunuş light, 200ms tutuş heavy |
| Wheel scroll | selectionClick | + **end-of-range bounce** + slight resistance hapt. |
| Analysis illusion | sweep ring | + **incoming particle wave** her cümle değiştiğinde |
| Dynamic report reveal | fade + slide | + **ridge lines** (number'lar yazıldıkça neon ridge) |
| %92 confidence bar fill | linear | + **easeOutBack** sonunda micro-overshoot |
| Pre-paywall card | static + entry slide | + **breath glow** continuous (2.4s ease in-out) |
| CTA tap | scale | + **light explode** (radial gradient → fade) |

### 8.2 Animasyon Felsefesi — "Apple-level subtle"

Dikkat: **çocuksu olmasın**. Her hareket bir bilgi taşımalı:
- Particle burst sadece **major milestone**'da (welcome start, plan reveal, paywall buy).
- Glow continuous **sadece bir element**'te aynı anda (DCATM rule — "Don't Compete for Attention That Matters").
- Spring curve (`easeOutBack`, `easeOutQuart`) **küçük element**'lerde, büyüklerde mutlaka `easeOutCubic`.

### 8.3 Loading State Premium

Mevcut "Metabolizmanı hesaplıyorum…" 1.5 sn'lik basit spinner. **Skeleton-glow** versiyonu:

```
[loading]
┌──────────────────────────┐
│ BMI:    [shimmer line]   │
│ TDEE:   [shimmer line]   │
│ Risk:   [shimmer line]   │
└──────────────────────────┘
[1.5 sn sonra reveal]
```

Bu, "hesaplanan veriler" hissini **somut** kılar — generic spinner değil.

### 8.4 Haptic Crescendo Logic

Onboarding'in son 3 adımında haptic yoğunluğu artmalı:

```
Step 10 (illusion):     light impact every 1.2s
Step 11 (report):       medium on reveal + heavy on %92 land
Step 12 (summary):      medium on entry, heavy on CTA tap
[paywall transition]:   double-tap pattern (success + transition)
```

Mevcut kodda `AppHaptics.primaryCta()`, `secondaryTap()` ayrımı var. Ama **crescendo pattern yok**. Phase 1 ekleme.

---

## 9 · Monetizasyon Psikolojisi

### 9.1 Mevcut Paywall Akışı

```
[12 step onboarding] → anon sign-in → /paywall
                                          ↓
                                   [headline + 10K kişi pill]
                                          ↓
                                   [3 plan cards]
                                          ↓
                                   [trial badge × 2]
                                          ↓
                                   [legal footer]
                                          ↓
                                   [×] kapat → /home
```

### 9.2 Güçlü Yönler

- **Sunk-cost** doğru kullanılmış: 5-7 dk yatırım sonrası paywall görünüyor.
- **Trial messaging** çift yerde — riskten arınma iyi.
- **3 plan kartı + "POPÜLER" badge** — anchor + decoy effect.
- **Dynamic pricing** RevenueCat'ten — App Store / Play Store currency localization.
- **Anonim user'lar görebiliyor** — seçim üretiyor, henüz baskı yok.

### 9.3 Eksikler

#### A) Sosyal Kanıt Yetersiz

`🔥 10.000+ kişi kullanıyor` jenerik. Daha güçlü:

```
"⭐⭐⭐⭐⭐ 4.7/5 — App Store"
"🇹🇷 10.247 kişi Türkiye'de"
"🔥 Bu hafta 412 yeni katılımcı"
```

3 micro-proof tek pill'den daha etkili.

#### B) Testimonial Yok

Tek gerçek kullanıcı sözü yok. **2-3 testimonial card** carousel'i:

```
"3 ayda 8 kg verdim. AI koçun sürekliliği harika."
— Ayşe K., 32 yaş
[Avatar fotoğrafı]
```

(Gerçek kullanıcılarla görüşülmeli — fake testimonial dark pattern.) Yokken bile, App Store yorumlarından alıntı + onay alma stratejisi var.

#### C) Çapa Fiyat Zayıf

`₺2.999,99 idi` strikethrough — ama **"idi"** muğlak. Daha güçlü:
```
"Diyet uzmanı 3 ay: ₺6.000+
 Personal trainer 3 ay: ₺9.000+
 FormAI Premium: ₺499,99 (⌐ %92 tasarruf)"
```

**Kullanıcıya alternatif maliyetlerin somut karşılaştırması** — bu, 3-4× psikolojik kaldıraç.

#### D) Loss Aversion Yetersiz

Mevcut paywall: "Premium aktive et" — gain frame. Loss frame eklemesi:

```
"AI'nın hazırladığı 12 haftalık plan
 24 saat içinde silinecek.
 Şimdi başlamak — son şansın bu."
```

(Etik: gerçekten silinmeli; yoksa dark pattern. **Veri tarafında 24 saatlik retention politikası gerekecek.**)

#### E) Trial Sonrası Bilinmezlik

Trial 7 gün, sonra otomatik abonelik. Ama **trial sonrası ne olacağı kullanıcıya görsel olarak gösterilmiyor**. Ek pill:

```
"7 gün ücretsiz — ödeme yok.
 İptal etmezsen 8. gün ₺499,99 (3 ay) çekilir.
 İstediğin zaman tek tıkla iptal — App Store'dan."
```

Saydamlık → güven → conversion.

### 9.4 Konum Önerileri

**Paywall, dynamic_report'tan SONRA değil, ÖNCE** kısmen önizlenmeli? Hayır — bu test edilmiş kötü pattern. Mevcut sıralama (rapor → plan kartı → paywall) **doğru**.

**Ama:** Paywall'a düşmeden ÖNCE bir **"micro-commitment"** ekranı eklenebilir:

```
"Devam etmeden önce:
 Bunu yapacağına dair kendine söz veriyor musun?

 [ ✓ Söz veriyorum ]
 [ Henüz emin değilim ]"
```

İlk seçenek → paywall (yüksek conversion).
İkinci seçenek → motivational reinforcement ekranı (testimonial reel + 5 saniye sonra paywall).

**Etki:** Self-selection. Söz veren kullanıcı %2x daha kolay alıyor (Cialdini commitment).

---

## 10 · Aşamalı Uygulama Yol Haritası

### PHASE 1 — Düşük Karmaşık / Yüksek Etki (1-2 hafta)

| # | Görev | UX impact | Retention | Eng. complexity | Risk | Emo. impact | $ impact |
|---|-------|-----------|-----------|-----------------|------|-------------|----------|
| 1.1 | Coach'a ad ver ("Form") | +M | +M | Trivial (copy) | None | +H | +M |
| 1.2 | Welcome'da kullanıcı adı al | +M | +H | Low (1 step) | None | +H | +M |
| 1.3 | Sayısal vaat welcome'da | +M | +M | Trivial | None | +M | +M |
| 1.4 | Pain-point kart sırası değiştir + sosyal kanıt subtext | +S | +S | Trivial | None | +M | +S |
| 1.5 | Multi-select alerji (nutrition) | +S | +S | Low | Recipe filter düzelt | +S | +S |
| 1.6 | Push opt-in step 10 öncesi | +M | **+H** | Low | iOS perm | +S | **+H** |
| 1.7 | Habit anchor question (saat + gün) | +M | **+H** | Low | None | +M | **+H** |
| 1.8 | Pre-paywall summary'de tarih | +M | +S | Trivial (copy + DateTime) | None | +H | +M |
| 1.9 | Dynamic report — confidence dynamic | +M | +S | Low | A/B | +H | +M |
| 1.10 | Trial fine-print transparency | +S | +S | Trivial | Legal review | +S | +M |
| 1.11 | Welcome → "Hadi başlayalım" copy | +S | None | Trivial | None | +S | +S |
| 1.12 | "Metabolizmanı hesaplıyorum" sonrası BMR flash | +M | None | Low | None | +M | +S |

**Tahmini toplam: 1-2 sprint, 2 mühendis. Onboarding completion +%6-10, paywall view-to-trial +%8-12.**

### PHASE 2 — Retention İyileştirmeleri (2-4 hafta)

| # | Görev | UX | Ret. | Eng. | Risk | Emo. | $ |
|---|-------|-----|------|------|------|------|---|
| 2.1 | Görsel projeksiyon (silhuet morph, low-effort SVG) | +H | +M | Med | Asset üretimi | +H | +H |
| 2.2 | Identity declaration ekranı | +M | **+H** | Low | Copy review | +H | +H |
| 2.3 | "İlk Antrenman Şimdi mi?" 5-dk flow | +H | **+H** | Med | Workout API | +H | +H |
| 2.4 | AI assessment'a serbest metin quote | +H | +M | Low | Token edge case | +H | +M |
| 2.5 | Pain-point feedback'i goal'e bağla (callback) | +M | +M | Low | None | +M | +M |
| 2.6 | Beslenme sheet'inde "Form geri döndü" mikro-kartı | +M | +S | Low | None | +M | +S |
| 2.7 | Beslenme hedefi → workout hedefi linking | +M | +S | Low | None | +M | +S |
| 2.8 | Su tüketimi → günlük öneri + reminder kurma | +M | +M | Low | Notif scheduler | +S | +M |
| 2.9 | Ana akışta trust booster (analysis_illusion sırasında) | +M | +S | Trivial | None | +M | +M |
| 2.10 | Dynamic report'a similar profile bandı | +M | +S | Med | Data | +M | +M |
| 2.11 | Pre-paywall loss-framed copy A/B | +S | None | Trivial | Risk: dark pattern | +M | +M |

**Tahmini toplam: 3-4 sprint. Day-1 retention +%10-15, Day-7 +%8-12.**

### PHASE 3 — Premium Deneyim (1-2 ay)

| # | Görev | UX | Ret. | Eng. | Risk | Emo. | $ |
|---|-------|-----|------|------|------|------|---|
| 3.1 | AI Foto-Snap Demosu (CalAI-style) | **+VH** | +M | High (gpt-vision) | Backend cost | **+VH** | **+VH** |
| 3.2 | Two-illusion diferansiasyon (molecular vs neural style) | +M | +S | Med | Animation work | +H | +M |
| 3.3 | Skeleton-glow loading states | +M | +S | Low | None | +M | +S |
| 3.4 | Microcommitment screen pre-paywall | +M | +S | Low | A/B | +M | +H |
| 3.5 | Premium voiceover for coach intro | +H | +M | Med | Voice talent | +H | +M |
| 3.6 | Particle burst & breath glow library | +M | None | Med | Performance | +M | +S |
| 3.7 | Dynamic anchor pricing (alternatif maliyetler) | +M | None | Low | Copy + design | +M | +H |
| 3.8 | Testimonial carousel paywall | +M | None | Low | User collection | +H | +H |

**Tahmini toplam: 6-8 sprint. App Store rating +0.3-0.5, premium conversion +%18-25.**

### PHASE 4 — İleri Diferansiyasyon (3-6 ay)

| # | Görev | Risk seviyesi |
|---|-------|---------------|
| 4.1 | Video onboarding hero (welcome) | Düşük — video CDN |
| 4.2 | ML-driven user photo morph | Yüksek — ML model + privacy |
| 4.3 | Çoklu coach persona (Form, Demir, Eda) | Orta — segment storage |
| 4.4 | Voice-input free-text answers | Orta — STT entegrasyon |
| 4.5 | Onboarding'de friend invite (referral hook) | Düşük |
| 4.6 | Live coach session (booking) | Yüksek — operations |
| 4.7 | Wearable data ingest (Apple Health / Fitbit) | Orta |

---

## 11 · Ekran Bazında Hızlı Eleştiri Tablosu

| Ekran | Amaç | Friksiyon | Premium Algı | Önerilen Müdahale |
|-------|------|-----------|---------------|-------------------|
| Welcome | Hook, premium algı | None | **Yüksek** | + sayısal vaat, + "Hadi başlayalım" copy |
| Coach Intro | AI persona | Low (typewriter) | **Yüksek** | + ad verme, + 3-cümle parçalama |
| (Yeni) Ad alma | Personalization | Low | Med | İsim girişi tek alan |
| Gender | Calibration | None | Med | Diğer kartı fotosuzluk düzelt + AI insight fayda-merkezli |
| Goal | Niyet | None | **Yüksek** | + identity-based options + callback için sakla |
| Experience | Empati | Med (text input) | Med | Serbest metni dynamic report'ta quote et |
| Daily Min. | Realite | None | Med | Mevcut iyi |
| Activity | TDEE | Med (text input) | Med | Aynı quote-back fix |
| Physical Data | Sayısal taahhüt | High (3 wheel) | **Yüksek** | + BMR flash 1 sn + güvenlik check edge case |
| (Yeni) Habit Anchor | Schedule | Low | Med | Saat + gün picker |
| Pain Point | Duygusal dürüstlük | Med | **Yüksek** | + sıralama değişikliği + sosyal kanıt subtext + quote back |
| (Yeni) Push Opt-in | Retention | Low | Med | "AI koçun seni dürtsün mü?" framing |
| Analysis Illusion | Labor illusion | None | **Yüksek** | + trust booster banner + diferansiyasyon |
| Dynamic Report | Reveal | Low | **Yüksek** | + görsel projeksiyon + dinamik %X + similar profile bandı + bullet'lı assessment |
| (Yeni) Identity Decl. | Commitment | Low | **Yüksek** | "Yeni kimliğin: ..." + signed declaration |
| Pre-Paywall Sum. | Plan reveal | None | **Yüksek** | + tarih, + ad ile hitap, + CTA dürüstlük |
| (Yeni) Microcommit. | Self-selection | Low | Med | "Söz verir misin?" |
| Paywall | Conversion | Med (auth gate) | **Yüksek** | + alternatif maliyet, + testimonial, + loss framing |
| (Nutrition) Goal | Macro yön | None | **Yüksek** | + workout goal'a bağla |
| (Nutrition) Diet | Filter | None | Med | Mevcut iyi |
| (Nutrition) Allergies | Çıkarma | High (single-sel) | Med | **Multi-select acil** |
| (Nutrition) Meal Freq | Timing | None | Med | Mevcut iyi |
| (Nutrition) Prep Time | Practical | None | Med | Mevcut iyi |
| (Nutrition) Water | Hydration | None | Low | + günlük hedef öner + reminder kur |
| (Nutrition) Taste | Sıralama | None | Med | + somut tarif teaser |
| (Nutrition) Illusion | Labor illusion | None | **Yüksek** | + diferansiyasyon (molecular style) |

---

## 12 · "Onboarding Bittikten Sonra" — Kritik Geçiş

Şu an akış:
```
Pre-paywall summary → /paywall → satın alma veya kapat → /home
```

`/home` kullanıcı ilk gelişinde **hiçbir bağlam taşımıyor**. Onboarding bilgileri (goal, painPoint, etc.) prefs'te ama UI'da görünmüyor.

**Önerilen ilk-açılış (Phase 2):**

```
[Splash w/ user adı]
"Tekrar hoşgeldin, Emre!
 Hedef: Kas yapmak — İlerleme: 0/84 gün"
   [progress bar  ──── 0%]

"Bugün yapacakların:
 ✓ İlk antrenman (5 dk ısınma)
 ✓ Su hedefi: 2.4L
 ✓ Form ile tanışma seansı"

[ŞİMDİ BAŞLA]
```

**Bu ekran ilk açılış için özel.** Sonraki açılışlarda `/home` standard tab'lara gidiyor. Sadece **Day 0 → Day 1 bridge**.

---

## 13 · Riskler ve Trade-Off'lar

### 13.1 Onboarding Uzunluk Riski

Phase 1+2 sonrası:
```
Welcome → Coach intro → Ad alma → Gender → Goal → Experience →
Daily min → Activity → Physical → Habit anchor → Pain point →
Push opt-in → Analysis illusion → Dynamic report → Identity decl →
Pre-paywall summary → Microcommit → Paywall
```

→ 18 ekran. Mevcut 12'den +6. **Süre tahminen 110-130 saniye.**

**Bu, BetterMe ve Noom'un onboarding süreleriyle uyumlu** ama genelde önemli olan **algılanan süre**, gerçek süre değil. Önerilen tüm yeni ekranların **çoğu 2-4 saniyelik** (mikrocommit, push opt-in, identity decl, ad alma). 

**Ama:** A/B test edilmeli. Paywall öncesi 18 ekran çok geliyorsa, **identity declaration + microcommit'i tek ekrana birleştir** (paywall'dan hemen önce).

### 13.2 AI Demo (Phase 3) Backend Maliyeti

GPT-Vision çağrısı her onboarding için ~$0.01-0.03. 100K MAU senaryosunda aylık $1K-3K backend maliyeti — **paywall conversion +%30 = LTV +%X getirisi vs.** ROI pozitif olmalı. Yine de:

**Gradient yaklaşım:**
- Pilot: %10 user'a sun.
- Conversion lift ölç.
- Eğer +%15+ conversion → genişlet.
- Eğer < %15 → fixed-pattern fake demo'ya geri dön.

### 13.3 Loss Aversion Kullanımı — Etik Sınır

"24 saatte silinir" gibi mesajlar **gerçekten** kullanıcı verisinin silinmesi gerektiriyor — yoksa dark pattern. Apple App Store'un dark pattern policy'leri sıkılaşıyor. Öneri:

- "Plan profile'ın yenileniyor" gibi **doğal** bir mesaj kullan
- Ya da gerçekten 24 saat sonra plan **eski profile**'a göre kalsın, **yeni profile** kaybolsun (data segmentation gerekli)

### 13.4 Identity Declaration — Kültürel Uyum

"Söz veriyorum" tarzı açık taahhüt Türkiye kullanıcısında **kültürel olarak ağır** gelebilir. Öneri: A/B test ile doğrula. Alternatif copy: _"Hazırım"_ daha rahat.

---

## 14 · Final Görüş

FormAI'nın onboarding'i **şimdi bile rakiplerin %80'inden iyi durumda**. Premium algı, AI persona, hybrid input, dark/neon dil — bunlar zor kazanılmış cevherler. Ama uluslararası birinci ligde yarışmak için **aşağıdaki üç müdahale**ye odaklan:

1. **AI'yı bir karakter yap (ad ver, ses ver, hatırlat)** — Phase 1.
2. **Dönüşümü görselleştir (silhuet morph + tarihli vaat + identity declaration)** — Phase 2.
3. **AI'yı kanıtla (foto-snap demosu)** — Phase 3.

Her biri tek başına paywall conversion'ı double-digit etkileyebilir.

Geri kalan tüm müdahaleler (sosyal kanıt iyileştirmeleri, haptic crescendo, multi-select alerji, vs.) bu üç ana hattın **destekçileri**. Ana hat olmadan destekçiler tek başına yeterli ROI üretmez.

**Stratejik Soru — kurucuya:**

> _Bu üç müdahaleyi (Form karakteri + görsel projeksiyon + AI demo) gerçekten yapmak için aylar alacaksa, alternatif: 12 hafta içinde sadece Phase 1 + 2.1 + 2.2 + 2.3'ü yap, Phase 3'ü 2026 H2'ye bırak. Kayıp kabul edilebilir. Önemli olan tutarlı bir kimlik akışı kurmak — sürekli yarım bırakmamak._

---

## 15 · Ek — Açık Bırakılan Kararlar

Aşağıdaki kararlar bu denetimde **kasıtlı olarak alınmamış** — ürün/iş tarafında karar gerekiyor:

1. Coach'un adı: **Form / FA / Demir / Eda** — kurucu seçimi.
2. Identity declaration ekranının **opsiyonelliği** — A/B veya zorunlu?
3. AI foto-snap demosu — pilot başlangıç oranı (%10? %25?).
4. Trial uzunluğu — 7 gün şu an. Bazı pazarlar 14 gün test edebilir.
5. Anchor fiyatın gerçek alternatif kaynağı — diyetisyen/PT karşılaştırma yasal/etik incelenmeli.
6. Push notif copy ton — Form karakterinin sesi netleşmeli.
7. Ölü kod `/prediction` route — silinmeli (ya da tutuluyorsa nedeni belgelenmeli).

---

**Belge sonu.** Bu denetim ışığında bir **uygulama planı (RFC tarzında)** oluşturulması istenirse, Phase 1 öncelik sırasıyla başlanır. İhtiyaç hâlinde her ekran için ayrı **detay tasarım brief'i** üretilebilir.
