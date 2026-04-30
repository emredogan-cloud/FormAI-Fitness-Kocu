# IMAGE_PROMPTS.md

**Phase 63B · Master prompt guide for AI-generated onboarding visuals.**

Bu dokümandaki promptlar, hem Ana Onboarding hem de Beslenme Onboarding akışlarındaki tüm seçim kartları için kullanılacak görselleri üretmek üzere Midjourney v6 / DALL-E 3'e verilmek üzere hazırlanmıştır. Üretim yaparken şu evrensel kuralları her promptun sonuna eklediğimizden emin oluyoruz; tek tek tekrar etmek yerine bir kere okuyup uygulamak daha güvenli.

---

## Universal Constraints (Apply to Every Prompt)

Her prompt aşağıdaki sabit kuralları içermelidir. Promptlarda kısaltılmış formla geçecek; tam liste burada referans olsun:

- **Right-aligned composition** — the main subject MUST occupy the right 40-50 % of the frame. The left 50-60 % must be a soft, dark, low-detail negative space (deep purple-black gradient or out-of-focus shadow). This is non-negotiable: the Flutter UI overlays a `Colors.black → Colors.transparent` gradient and ~16 px of padded text on the left side. Subjects centred or left-aligned will be partially hidden.
- **Clean dark background** — deep matte black or very dark navy (`#05030D`-ish) with subtle purple/blue accent light. Avoid bright skies, daylight outdoor scenes, and white backgrounds. The asset must blend into the app's `#1A0B3D → #000000` onboarding gradient.
- **Cinematic lighting** — rim lighting from behind/right, soft volumetric haze, hint of neon purple (`#8E5BFF`) or blue (`#4DA6FF`) reflected on the subject's edge. Treat every shot as a premium product photo, not a stock image.
- **No text, no logos, no watermarks** — append `--no text, no letters, no logos, no watermark, no UI elements`.
- **Photorealistic style** — append `hyper-realistic, photographic, 8K, sharp focus on subject, shallow depth of field, 50mm lens`.
- **Aspect ratio** — `--ar 3:2` for the standard option-card image area (~165 × 110 dp on a 360 dp screen). For the rare full-bleed hero (plan card on the pre-paywall summary), use `--ar 4:5`.
- **Negative space promise** — explicitly add `with deep negative space and soft shadow on the left side of the frame for text overlay`.
- **Color palette** — neutral skin tones, deep blacks, with single-accent neon purple (`#8E5BFF`) or blue (`#4DA6FF`) highlights. Avoid orange, red, or yellow primary lighting except where the food/scene demands it (e.g. fire-burn imagery for "yağ yakımı").

When you see `[CORE]` in a prompt below, treat it as shorthand for these constraints — Midjourney has token limits and repeating the universals every time hits them quickly. The recommended Midjourney macro is:

```
[scene description], right-aligned subject in the right 40 % of the frame,
deep negative space on the left for text overlay, dark cinematic background,
hyper-realistic, premium fitness app aesthetic, neon purple rim light,
8K, sharp, shallow DoF, 50mm lens --ar 3:2 --no text, logos, watermark, UI
```

---

# 1. MAIN ONBOARDING

## 1.1 Cinsiyet (Gender)

### 1.1.1 Cinsiyet — Kadın

- **Rationale (Turkish):** Kadın kullanıcının kendini hemen "burası benim için" diye konumlandırabilmesi için atletik, sağlıklı bir kadın silüetini sıcak ama disiplinli bir şekilde göstermeliyiz. Çıplaklık değil, formda ve güçlü bir hava aranıyor; agresif kasları olmayan, "ulaşılabilir" bir vücut. Sağda profil pozu, sol tarafta koyu vinyet → metin overlay'iyle çakışmayacak.
- **Target Filename:** `photos/cinsiyetseçimikadın.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Athletic young woman, side-profile silhouette, fit and toned body, sportswear
  (black sports bra and leggings), looking forward with calm confidence,
  cinematic studio rim light from the right, deep matte black background,
  subtle neon purple glow on her shoulder edge, premium fitness app aesthetic,
  right-aligned composition with subject in the right 45 % of the frame,
  deep negative space and soft shadow on the left for text overlay,
  hyper-realistic, photographic, 8K, sharp focus, shallow depth of field,
  50mm lens --ar 3:2 --no text, letters, logos, watermark, UI elements
  ```

### 1.1.2 Cinsiyet — Erkek

- **Rationale (Turkish):** Erkek kullanıcı için "hedef vücut" değil "bugünün motive erkeği" havasını veriyoruz — hafif ışıklı, defined ama abartısız, yüksek-kontrast siluet. Ulaşılabilirlik kritik; kullanıcı kendini değil bir Greek god görmemeli yoksa "ben yapamam" hissi tetikler.
- **Target Filename:** `photos/cinsiyetseçimierkek.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Athletic young man, side-profile silhouette, lean and defined torso, plain
  black athletic shorts, calm focused expression, cinematic studio rim light
  from the right, deep matte black background, subtle neon blue glow on his
  shoulder and bicep edge, premium fitness app aesthetic, right-aligned
  composition with subject in the right 45 % of the frame, deep negative
  space and soft shadow on the left for text overlay, hyper-realistic,
  photographic, 8K, sharp focus, shallow depth of field, 50mm lens
  --ar 3:2 --no text, letters, logos, watermark, UI elements
  ```

### 1.1.3 Cinsiyet — Diğer

- **Rationale (Turkish):** Şu an kodda görsel asset'i yok (sadece `Icons.transgender_rounded` ikonu kullanılıyor). PM isterse şu prompt'la inkluzif bir görsel ekleyebilir; eklemediği sürece text-only card kalmaya devam eder. Cinsiyet-belirsiz bir silüet, ışık ve form üzerinden konuşmalı, herhangi bir cinsiyet işaretine yaslanmamalı.
- **Target Filename:** `photos/cinsiyet_diger.webp` *(YENİ; PM eklemek istemezse mevcut text-only kart davranışı korunur)*
- **AI Generation Prompt (English):**
  ```
  Abstract gender-neutral human silhouette, athletic build, ambiguous body
  shape, lit only by a single neon purple rim light from the right side,
  facing forward, head turned three-quarter, dark matte background,
  cinematic minimal style, premium fitness app aesthetic, right-aligned
  composition with subject in the right 45 % of the frame, deep negative
  space on the left for text overlay, hyper-realistic, 8K, shallow DoF,
  50mm lens --ar 3:2 --no text, letters, logos, watermark, UI elements,
  no gender-specific clothing, no makeup, no facial hair
  ```

## 1.2 Hedef (Goal)

### 1.2.1 Hedef — Göbek eritmek (belly_burn)

- **Rationale (Turkish):** Kullanıcının kafasındaki "yağ yakımı" görseli sıkı, yağsız bir karın bölgesi → "hedef hissi" verir. Egzersiz aksiyonu yerine sonuç pozu seçiyoruz çünkü bu seçenek bir HEDEF, yani ulaşılmak istenen durum.
- **Target Filename:** `photos/hedefinneSıkılaşmak.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Close-up of a fit lean torso with toned defined abs, side-profile, athletic
  black sportswear, single warm rim light from the right with subtle ember
  orange glow suggesting fat burn, otherwise dark cinematic background,
  premium fitness app aesthetic, right-aligned composition with the abdomen
  occupying the right 45 % of the frame, deep negative space on the left for
  text overlay, hyper-realistic, photographic, 8K, sharp focus, shallow DoF,
  50mm lens --ar 3:2 --no text, letters, logos, watermark, UI elements,
  no gym equipment, no face
  ```

### 1.2.2 Hedef — Kas yapmak (muscle_gain)

- **Rationale (Turkish):** Hacim/kas hedefi seçen kullanıcılar için "gain" enerjisi gerek — kalın, dolgun kas hatları, geniş omuz/sırt. Ama yağsız değil, "hacim kazanmış" havasında. Demir/dumbbell metaforuyla destekleyebilir ama zorunlu değil — vücut yeterli.
- **Target Filename:** `photos/hedefinneHacimKazanmak.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Close-up of a muscular athlete's broad shoulder and bicep, side-profile,
  full developed musculature with visible definition, dark sleeveless tank,
  single dramatic rim light from the right with neon purple highlight on
  the deltoid, dark moody background with hint of dumbbell silhouette
  blurred in the far background, premium fitness app aesthetic, right-
  aligned composition with the muscle group in the right 45 % of the
  frame, deep negative space on the left for text overlay, hyper-realistic,
  photographic, 8K, sharp focus, shallow DoF, 50mm lens --ar 3:2
  --no text, letters, logos, watermark, UI elements, no face
  ```

### 1.2.3 Hedef — Daha fit görünmek (fitness_look)

- **Rationale (Turkish):** "Estetik" hedefi seçen kullanıcı, dergi kapağı tarzı altı paket / V-cut hattı görmek ister. Aşırı bulky değil, çekici-aspirational bir vücut. Aydınlatma drama yüksek; yüz değil, gövde anlatıyor.
- **Target Filename:** `photos/hedefinneSadeceSix-Pack.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Aesthetic photoshoot of a fit athletic torso with chiseled six-pack abs
  and V-cut, side-three-quarter angle, oiled skin glistening under
  cinematic rim light from the right with neon blue accent, dark moody
  background, magazine cover aesthetic, premium fitness app style, right-
  aligned composition with subject in the right 45 % of the frame, deep
  negative space on the left for text overlay, hyper-realistic,
  photographic, 8K, sharp focus, shallow depth of field, 50mm lens
  --ar 3:2 --no text, letters, logos, watermark, UI elements, no face,
  no swimwear branding
  ```

### 1.2.4 Hedef — Güçlenmek (strength)

- **Rationale (Turkish):** Şu an kodda görsel asset'i yok. PM eklemek isterse "ham güç" enerjisi: ağır deadlift kavrayışı, halter, tebeşirli el. Sadece güç hareketi → "estetik" değil "kapasite" hedefi anlatılır.
- **Target Filename:** `photos/hedef_guclenmek.webp` *(YENİ; eklenmezse mevcut ikon-only kart davranışı korunur)*
- **AI Generation Prompt (English):**
  ```
  Close-up of a chalked hand gripping a heavy barbell, knurled steel
  texture visible, dramatic side-light from the right with subtle warm
  rim glow, dark moody gym atmosphere, dust particles in the air,
  premium fitness app aesthetic, right-aligned composition with the hand
  and barbell in the right 45 % of the frame, deep negative space on the
  left for text overlay, hyper-realistic, photographic, 8K, sharp focus,
  shallow DoF, 50mm lens --ar 3:2 --no text, letters, logos, watermark,
  UI elements, no face
  ```

## 1.3 Günlük Aktivite (Activity Level)

### 1.3.1 Aktivite — Masa başı (sedentary)

- **Rationale (Turkish):** Kullanıcı kendini "evet, ben de masada oturuyorum" diye eşleyebilmeli. Ama kasvetli görünmemeli, sadece tarafsız-modern bir ofis sahnesi olmalı; suçluluk hissi vermek yerine "anlaşıldım" hissi yaratmalı.
- **Target Filename:** `photos/günlükaktivitenmasabaşı.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Modern minimalist home office desk seen from a low side-angle, laptop
  screen glow, ergonomic chair partially visible, mug and notebook on the
  right side of the desk, soft cool ambient lighting, dark muted color
  palette with hint of cool blue from the screen, premium fitness app
  aesthetic, right-aligned composition with the desk and laptop in the
  right 50 % of the frame, deep negative space on the left for text
  overlay, hyper-realistic, photographic, 8K, sharp focus, shallow DoF,
  50mm lens --ar 3:2 --no text on screen, no letters, logos, watermark,
  UI elements, no person
  ```

### 1.3.2 Aktivite — Hafif hareketli (light)

- **Rationale (Turkish):** "Yürüyorum, hareket ediyorum ama sporcu değilim" segmenti. Şehir/park yürüyüşü, casual giysiler, doğal aydınlatma ama yine de cinematic. Ne aşırı sportif ne tembel.
- **Target Filename:** `photos/günlükaktivitenhafifhareketli.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Side-profile shot of a casually dressed person walking through a dim
  urban evening setting, hoodie and jeans, hands relaxed, motion blur
  hint on the legs, ambient street light from the right side casting a
  cool blue rim, dark moody background, premium fitness app aesthetic,
  right-aligned composition with subject in the right 45 % of the frame,
  deep negative space on the left for text overlay, hyper-realistic,
  photographic, 8K, sharp focus, shallow DoF, 50mm lens --ar 3:2
  --no text, letters, logos, watermark, UI elements, no face detail
  ```

### 1.3.3 Aktivite — Çok aktif (active)

- **Rationale (Turkish):** Aktif segment için patlayıcı enerji: koşan bir sporcu, dinamik kompozisyon, hareket bulanıklığı. Gece koşusu havasında olmasına dikkat — koyu sahne kuralımıza uysun.
- **Target Filename:** `photos/günlükaktivitenneÇokAktif.webp` *(mevcut dosyayı güncelle, isim aynı kalsın)*
- **AI Generation Prompt (English):**
  ```
  Athletic runner mid-stride at night on a dark track, side-profile,
  dynamic motion blur on the back leg, sweat droplets catching the light,
  dramatic neon purple rim light from the right, dark moody atmosphere
  with light haze, premium fitness app aesthetic, right-aligned
  composition with subject in the right 45 % of the frame, deep negative
  space on the left for text overlay, hyper-realistic, photographic, 8K,
  sharp focus on the runner, shallow DoF, 50mm lens, freeze-frame
  feeling --ar 3:2 --no text, letters, logos, watermark, UI elements,
  no face detail
  ```

---

# 2. NUTRITION ONBOARDING

## 2.1 Beslenme Hedefi (Nutrition Goal)

### 2.1.1 Beslenme Hedefi — Yağ Yakımı (yag_yakimi)

- **Rationale (Turkish):** Kullanıcı yağ yakımı hedefliyorsa görsel "yanma" / "ısı" / "metabolizma" metaforu üzerinden konuşmalı. Gerçek bir alev yerine ısı dalgası / glow tercih ediliyor; biraz fitness, biraz beslenme havası.
- **Target Filename:** `photos/nutrition_goal_fat_loss.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Stylized close-up of a lean grilled chicken breast and fresh greens on
  a dark slate plate, subtle ember warm glow underneath suggesting fat-
  burning energy, steam rising, dramatic side-light from the right with
  warm orange-red accent fading into a dark moody background, premium
  fitness app aesthetic, right-aligned composition with the plate in the
  right 50 % of the frame, deep negative space on the left for text
  overlay, hyper-realistic, food photography, 8K, sharp focus, shallow
  DoF, 50mm lens --ar 3:2 --no text, letters, logos, watermark, UI
  elements, no hands, no cutlery
  ```

### 2.1.2 Beslenme Hedefi — Kas Kazanımı (kas_kazanimi)

- **Rationale (Turkish):** Yüksek-protein "bulk" tabağı — biftek, somon, yumurta gibi. Yanına bir dumbbell veya shaker bırakmak protein-yapı ilişkisini güçlendirir.
- **Target Filename:** `photos/nutrition_goal_muscle.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Premium protein-rich plate with a thick grilled steak, sliced eggs,
  quinoa, and steamed broccoli, dark slate plate, dumbbell partially
  visible blurred in the right background, dramatic neon blue rim light
  from the right, dark moody background, premium fitness app aesthetic,
  right-aligned composition with the plate occupying the right 50 % of
  the frame, deep negative space on the left for text overlay, hyper-
  realistic, food photography, 8K, sharp focus on the steak, shallow
  DoF, 50mm lens --ar 3:2 --no text, letters, logos, watermark, UI
  elements, no hands, no cutlery
  ```

### 2.1.3 Beslenme Hedefi — Dengeli Beslenme (dengeli)

- **Rationale (Turkish):** "Sürdürülebilir" mesajı vermek için Buddha-bowl tarzı renkli, dengeli bir tabak — protein + karb + sebze + yağ ayrı kompartmanlarda. Renk paleti çok parlak değil; cinematic tutmak şart.
- **Target Filename:** `photos/nutrition_goal_balanced.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Beautifully composed Buddha bowl with grilled salmon, brown rice,
  roasted sweet potato, avocado slices, and leafy greens, arranged in
  harmonious sections on a dark wooden surface, soft cinematic lighting
  from the right, neon purple subtle accent on the avocado edge, dark
  moody background, premium fitness app aesthetic, right-aligned
  composition with the bowl in the right 50 % of the frame, deep
  negative space on the left for text overlay, hyper-realistic, food
  photography, 8K, sharp focus, shallow DoF, 50mm lens --ar 3:2
  --no text, letters, logos, watermark, UI elements, no hands,
  no cutlery
  ```

## 2.2 Diyet Tercihi (Diet Preference)

### 2.2.1 Diyet — Standart

- **Rationale (Turkish):** "Her şeyi yiyebilirim" diyen kullanıcı → karışık, çok-bileşenli, klasik "Türk evi"-vari değil ama modern bir tabak. Et + sebze + tahıl üçlemesi.
- **Target Filename:** `photos/diet_standard.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Classic balanced dinner plate with grilled chicken thigh, mashed
  potato, and roasted seasonal vegetables, on a dark ceramic plate,
  warm cinematic side-light from the right, dark moody restaurant
  background, premium fitness app aesthetic, right-aligned composition
  with the plate in the right 50 % of the frame, deep negative space
  on the left for text overlay, hyper-realistic, editorial food
  photography, 8K, sharp focus, shallow DoF, 50mm lens --ar 3:2
  --no text, letters, logos, watermark, UI elements, no hands,
  no cutlery
  ```

### 2.2.2 Diyet — Vejetaryen

- **Rationale (Turkish):** Vejetaryen → yumurta, peynir, baklagil gibi hayvansal ama et-dışı bileşenleri öne çıkaran tabak. Yeşil ağırlıklı ama "et yemiyor" değil "değişik yiyor" tonunda.
- **Target Filename:** `photos/diet_vegetarian.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Rustic vegetarian plate with poached eggs over creamy lentil stew,
  sliced halloumi cheese, fresh herbs, and roasted tomatoes, dark stone
  surface, soft warm side-light from the right, dark moody background,
  premium fitness app aesthetic, right-aligned composition with the
  plate in the right 50 % of the frame, deep negative space on the left
  for text overlay, hyper-realistic, editorial food photography, 8K,
  sharp focus, shallow DoF, 50mm lens --ar 3:2 --no text, letters,
  logos, watermark, UI elements, no hands, no cutlery
  ```

### 2.2.3 Diyet — Vegan

- **Rationale (Turkish):** Tamamen bitkisel — renkli ama yine cinematic; ne kuru salata ne hipster bowl → modern bir "complete plant" tabağı.
- **Target Filename:** `photos/diet_vegan.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Vibrant vegan plate with grilled tofu, quinoa, roasted chickpeas,
  avocado, kale, and tahini drizzle, dark slate plate, soft cool side-
  light from the right with neon green subtle accent on the kale edge,
  dark moody background, premium fitness app aesthetic, right-aligned
  composition with the plate in the right 50 % of the frame, deep
  negative space on the left for text overlay, hyper-realistic, editorial
  food photography, 8K, sharp focus, shallow DoF, 50mm lens --ar 3:2
  --no text, letters, logos, watermark, UI elements, no hands,
  no cutlery, no animal products
  ```

### 2.2.4 Diyet — Ketojenik

- **Rationale (Turkish):** Yüksek yağ + düşük karb. Avokado, somon, tereyağı, yumurta klasik keto vizüali. Yağlı parıltı görselin DNA'sı.
- **Target Filename:** `photos/diet_keto.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Keto-style plate with seared salmon fillet glistening with butter,
  avocado halves, soft-boiled eggs cut open with runny yolk, and crispy
  bacon, on a dark slate plate, dramatic side-light from the right
  catching the oily sheen, dark moody background, premium fitness app
  aesthetic, right-aligned composition with the plate in the right
  50 % of the frame, deep negative space on the left for text overlay,
  hyper-realistic, editorial food photography, 8K, sharp focus, shallow
  DoF, 50mm lens --ar 3:2 --no text, letters, logos, watermark, UI
  elements, no bread, no rice, no pasta, no hands, no cutlery
  ```

## 2.3 Alerji (Allergies)

> Not: Alerji görsellerinde çıkartmak istediğimiz/uzak duracağımız ürünü güzel ve appetizing göstermek istemiyoruz — kullanıcının "aha bunu yiyemiyorum" diye anlaması yeterli. Tanım amaçlı, dramatik değil.

### 2.3.1 Alerji — Yok

- **Rationale (Turkish):** "Hiçbir kısıtım yok" → onaylı, güvenli, açık-büfe vibe. Üzerinde hafif yeşil "tick" parıltısı olabilir ama text yok.
- **Target Filename:** `photos/allergy_none.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Abundant variety of fresh whole foods spread across a dark wooden
  surface — colorful vegetables, fruit, nuts, dairy, eggs, meat, and
  bread, all visible but softly out-of-focus toward the back, soft
  warm cinematic light from the right with subtle neon green accent,
  dark moody background, premium fitness app aesthetic, right-aligned
  composition with the spread in the right 55 % of the frame, deep
  negative space on the left for text overlay, hyper-realistic, food
  photography, 8K, sharp focus on the foreground items, shallow DoF,
  50mm lens --ar 3:2 --no text, letters, logos, watermark, UI elements,
  no hands
  ```

### 2.3.2 Alerji — Kuruyemiş

- **Rationale (Turkish):** Bademler, fındıklar, cevizler — net ve tanınabilir. "Bunlardan kaçınılacak" mesajı kart üzerinden iletilir, görsel sadece kategori bildiriyor.
- **Target Filename:** `photos/allergy_nuts.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Close-up still life of mixed nuts — almonds, walnuts, hazelnuts,
  pistachios — scattered across a dark slate surface, dramatic side-
  light from the right, dark moody background, premium fitness app
  aesthetic, right-aligned composition with the nuts piled in the right
  50 % of the frame, deep negative space on the left for text overlay,
  hyper-realistic, macro food photography, 8K, sharp focus, shallow
  DoF, 50mm lens --ar 3:2 --no text, letters, logos, watermark, UI
  elements, no hands, no bowls
  ```

### 2.3.3 Alerji — Süt Ürünleri

- **Rationale (Turkish):** Süt, peynir, yoğurt — temsili "süt ürünleri" sahne. Renk paleti açık olduğu için kompozisyonun arka planı koyu, ön plan beyaz olmalı; tezat şart.
- **Target Filename:** `photos/allergy_dairy.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Still life arrangement of dairy products — a glass of milk, a wedge
  of aged cheese, a bowl of plain yogurt, butter on a dark slate
  surface, dramatic side-light from the right, dark moody background,
  premium fitness app aesthetic, right-aligned composition with the
  dairy items in the right 55 % of the frame, deep negative space on
  the left for text overlay, hyper-realistic, food photography, 8K,
  sharp focus, shallow DoF, 50mm lens --ar 3:2 --no text, letters,
  logos, watermark, UI elements, no hands
  ```

### 2.3.4 Alerji — Glüten

- **Rationale (Turkish):** Buğday tahılları, ekmek, makarna. Klasik glüten metaforu — buğday başağı + ekmek dilimi yeterli.
- **Target Filename:** `photos/allergy_gluten.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Rustic still life of golden wheat stalks lying across a sliced
  artisan sourdough loaf and uncooked pasta on a dark wooden surface,
  warm side-light from the right, dark moody background, premium
  fitness app aesthetic, right-aligned composition with the wheat and
  bread in the right 55 % of the frame, deep negative space on the
  left for text overlay, hyper-realistic, food photography, 8K, sharp
  focus, shallow DoF, 50mm lens --ar 3:2 --no text, letters, logos,
  watermark, UI elements, no hands
  ```

## 2.4 Öğün Sayısı (Meal Frequency)

### 2.4.1 Öğün — 2 Öğün (IF)

- **Rationale (Turkish):** Aralıklı oruç tarzı → iki büyük, doyurucu tabak. Yan yana iki tabak / bir tabak + bir bowl pozu. "Yoğun" hissi vermesi için porsiyon büyük görünmeli.
- **Target Filename:** `photos/meals_2.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Two large hearty plates side by side — one with grilled chicken,
  rice, and vegetables, another with a generous protein bowl — on a
  dark wooden table, dramatic warm side-light from the right, dark
  moody background, premium fitness app aesthetic, right-aligned
  composition with both plates occupying the right 55 % of the frame,
  deep negative space on the left for text overlay, hyper-realistic,
  food photography, 8K, sharp focus, shallow DoF, 50mm lens --ar 3:2
  --no text, letters, logos, watermark, UI elements, no hands,
  no cutlery
  ```

### 2.4.2 Öğün — 3 Öğün

- **Rationale (Turkish):** Klasik kahvaltı + öğle + akşam üçlemesi. Üç farklı dish, üç farklı zaman. Düzen ve istikrar mesajı.
- **Target Filename:** `photos/meals_3.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Three plates arranged in a row — a healthy breakfast plate (eggs,
  avocado toast), a balanced lunch plate (grilled fish, salad), and a
  hearty dinner plate (steak, vegetables) — on a dark wooden table,
  cinematic warm side-light from the right, dark moody background,
  premium fitness app aesthetic, right-aligned composition with the
  plates in the right 55 % of the frame, deep negative space on the
  left for text overlay, hyper-realistic, food photography, 8K, sharp
  focus, shallow DoF, 50mm lens --ar 3:2 --no text, letters, logos,
  watermark, UI elements, no hands, no cutlery
  ```

### 2.4.3 Öğün — 4+ Öğün

- **Rationale (Turkish):** Atıştırmalık severim → küçük porsiyon × çok sayıda. Tapas / mini bowl spread'i. Çoğullu hissi için yan yana ≥4 element.
- **Target Filename:** `photos/meals_4.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Tapas-style spread of multiple small bowls and ramekins on a dark
  slate board — almonds, sliced fruit, Greek yogurt, hummus with
  veggies, hard-boiled egg, dark chocolate squares — at least five
  distinct items visible, soft cinematic side-light from the right,
  dark moody background, premium fitness app aesthetic, right-aligned
  composition with the spread in the right 55 % of the frame, deep
  negative space on the left for text overlay, hyper-realistic, food
  photography, 8K, sharp focus, shallow DoF, 50mm lens --ar 3:2
  --no text, letters, logos, watermark, UI elements, no hands
  ```

## 2.5 Hazırlama Süresi (Prep Time)

### 2.5.1 Prep — Hızlı & Pratik (10-15 dk)

- **Rationale (Turkish):** "Hızlı" → çiğ ya da minimum pişirme: smoothie bowl, salad, overnight oats. Renkli ve davetkâr; "10 dakikada bu olur" hissi.
- **Target Filename:** `photos/prep_quick.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Vibrant smoothie bowl topped with fresh berries, banana slices, chia
  seeds, and granola, beside a small glass of overnight oats, on a dark
  marble counter, soft cool morning light from the right with subtle
  neon purple accent, dark moody background, premium fitness app
  aesthetic, right-aligned composition with the bowls in the right
  50 % of the frame, deep negative space on the left for text overlay,
  hyper-realistic, food photography, 8K, sharp focus, shallow DoF,
  50mm lens --ar 3:2 --no text, letters, logos, watermark, UI elements,
  no hands, no cutlery
  ```

### 2.5.2 Prep — Mutfakta Vakit (30+ dk)

- **Rationale (Turkish):** Yavaş, sıcak, "yemekten hoşlanan" hissiyat. Fırından çıkan bir et / fırın eldiveni / tencere buharı → sahnede aksiyon var.
- **Target Filename:** `photos/prep_slow.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Roasted whole chicken with rosemary and lemon fresh out of the oven
  in a dark cast-iron pan, steam rising, golden crispy skin glistening,
  dramatic warm side-light from the right with hint of orange ember
  glow, dark moody kitchen background, premium fitness app aesthetic,
  right-aligned composition with the pan in the right 55 % of the
  frame, deep negative space on the left for text overlay, hyper-
  realistic, food photography, 8K, sharp focus, shallow DoF, 50mm lens
  --ar 3:2 --no text, letters, logos, watermark, UI elements, no
  hands, no oven mitts
  ```

## 2.6 Su Tüketimi (Water Intake)

### 2.6.1 Su — Çok az (0-1L)

- **Rationale (Turkish):** "Yetersiz" mesajı için yarı-boş, dibi görünen bir bardak. Suç hissi yaratmadan, "buradayız ama daha fazla içmen lazım" tonu.
- **Target Filename:** `photos/water_low.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  A nearly empty glass of water with just a small amount of liquid
  remaining at the bottom, on a dark slate surface, dramatic side-
  light from the right with subtle cool blue refraction through the
  glass, dark moody background, premium fitness app aesthetic,
  right-aligned composition with the glass in the right 45 % of the
  frame, deep negative space on the left for text overlay, hyper-
  realistic, product photography, 8K, sharp focus on the glass,
  shallow DoF, 50mm lens --ar 3:2 --no text, letters, logos,
  watermark, UI elements, no hands, no condensation droplets that
  read as full
  ```

### 2.6.2 Su — Orta (1-2L)

- **Rationale (Turkish):** Yarım dolu cam şişe. Düzenli ama tam değil hissini doğal olarak iletir.
- **Target Filename:** `photos/water_medium.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  A reusable glass water bottle filled to about 60 % with crystal-clear
  water, sitting upright on a dark slate surface, soft cool side-light
  from the right catching subtle highlights on the glass, dark moody
  background, premium fitness app aesthetic, right-aligned composition
  with the bottle in the right 45 % of the frame, deep negative space
  on the left for text overlay, hyper-realistic, product photography,
  8K, sharp focus, shallow DoF, 50mm lens --ar 3:2 --no text, letters,
  logos, watermark, UI elements, no hands, no labels
  ```

### 2.6.3 Su — İyi (2L+)

- **Rationale (Turkish):** Aşırı dolu, neredeyse taşan bir bardak veya damlacıklarla kaplı bir şişe. "Hidrasyon kralı" hissi.
- **Target Filename:** `photos/water_high.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Tall glass overflowing with crystal-clear water, droplets cascading
  down the sides, dynamic splash captured mid-motion, dramatic side-
  light from the right with vivid neon blue accent on the water,
  dark moody background, premium fitness app aesthetic, right-aligned
  composition with the glass in the right 45 % of the frame, deep
  negative space on the left for text overlay, hyper-realistic,
  high-speed product photography, 8K, sharp focus on the splash,
  shallow DoF, 50mm lens --ar 3:2 --no text, letters, logos,
  watermark, UI elements, no hands
  ```

## 2.7 Tat Tercihi (Taste Preference)

### 2.7.1 Tat — Tatlı

- **Rationale (Turkish):** Doğal tatlılık → meyveler, bal, tatlı ama sağlıklı bowl. Şekerli kek değil çünkü mesaj "sağlıklı tatlı tarifler" üzerine.
- **Target Filename:** `photos/taste_sweet.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Beautiful close-up of a Greek yogurt bowl topped with fresh berries,
  honey drizzle catching the light, sliced banana, and crushed nuts,
  on a dark wooden surface, soft warm side-light from the right
  highlighting the honey, dark moody background, premium fitness app
  aesthetic, right-aligned composition with the bowl in the right
  50 % of the frame, deep negative space on the left for text overlay,
  hyper-realistic, food photography, 8K, sharp focus, shallow DoF,
  50mm lens --ar 3:2 --no text, letters, logos, watermark, UI
  elements, no hands, no cutlery
  ```

### 2.7.2 Tat — Tuzlu

- **Rationale (Turkish):** Izgara et, baharatlı sebze, kekik dalı. Doyurucu, tuzlu tarafa eğilen klasik fitness plate'i.
- **Target Filename:** `photos/taste_savory.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Sizzling grilled steak slices with rosemary, sea salt flakes, and
  cracked black pepper on top, beside roasted herb potatoes and
  caramelized onions, on a dark cast-iron skillet, dramatic warm side-
  light from the right with smoke rising, dark moody background,
  premium fitness app aesthetic, right-aligned composition with the
  skillet in the right 55 % of the frame, deep negative space on the
  left for text overlay, hyper-realistic, food photography, 8K, sharp
  focus, shallow DoF, 50mm lens --ar 3:2 --no text, letters, logos,
  watermark, UI elements, no hands, no cutlery
  ```

### 2.7.3 Tat — Karışık

- **Rationale (Turkish):** "İkisi de olur" → ortada kombinli bir tabak. Tatlı bir element + tuzlu bir element birlikte (mesela tarçınlı tatlı patates + ızgara somon).
- **Target Filename:** `photos/taste_mixed.webp` *(YENİ asset)*
- **AI Generation Prompt (English):**
  ```
  Modern brunch plate combining sweet and savoury — grilled salmon
  fillet next to glazed sweet potato wedges with cinnamon, alongside
  fresh blueberries and a small drizzle of honey on the rim, dark
  ceramic plate, soft cinematic side-light from the right with mixed
  warm and cool accents, dark moody background, premium fitness app
  aesthetic, right-aligned composition with the plate in the right
  55 % of the frame, deep negative space on the left for text overlay,
  hyper-realistic, food photography, 8K, sharp focus, shallow DoF,
  50mm lens --ar 3:2 --no text, letters, logos, watermark, UI
  elements, no hands, no cutlery
  ```

---

# 3. Workflow

1. **Üretim sırası önerilir:** önce mevcut asset'lerin (cinsiyet, hedef, aktivite) yenilenmiş sürümünü üretmek; çünkü o görseller en sık görünüyor (her kullanıcı 1. taramada bunlardan geçiyor). Sonra Beslenme Onboarding (Faz 62'de yeni eklenen kartlar).
2. **Test akışı:** Her görseli `photos/` altına `<TargetFilename>` adıyla koyduktan sonra Flutter çalıştır → ilgili karta gir → soldaki gradient ile sağdaki resim arasındaki blend doğal mı kontrol et. Subject çok merkezdeyse text overlay'in altında kalır → prompt'a `subject in the right 30 %` diye sıkıştırarak yeniden üret.
3. **Format:** Üretilen PNG/JPG'leri `cwebp -q 85` ile webp'ye çevir, dosya boyutunu 70-150 KB aralığında tut. `OnboardingImage`'ın yerleşik `frameBuilder`'ı 240 ms fade-in zaten yapıyor, ekstra optimizasyon gerekmez.
4. **Asset kaybolursa:** `OnboardingImage`'ın gradient + ikon fallback'i devreye girer — yani yanlış asset adı koymak ekranı boşaltmaz, sadece eski generic kartı gösterir. PR açmadan kart tek tek doğrulanmalı.

---

**Maintainer note:** Bu doküman üretim için canlı kalır. Yeni bir option card eklenirse (örn. yeni bir hedef tipi), bu dosyaya hem rationale hem de prompt eklenmeli ki PM tek bir yerden tüm seti yönetebilsin.
