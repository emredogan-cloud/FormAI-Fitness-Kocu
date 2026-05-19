# New Exercise Library — Phase 96

**Status:** specification document. Source-of-truth for the SQL migration `supabase/sql/phase96_workout_library_expansion.sql` and the analyzer routing additions in `lib/features/workout/services/analyzer_factory.dart`.
**Generated:** 2026-05-09
**Total new exercises:** 87 across 7 categories (35 equipment, 52 bodyweight including 6 mobility/stretching).
**After Phase 96 the catalogue grows from 51 → 138 exercises.**

---

## Conventions

- **`category`** is one of the 7 enum values — no schema migration. Sub-groupings live in `target_muscles[]`.
- **`target_muscles[]` element [0]** stays one of `core | upper_body | lower_body | full_body | cardio` so `_firstTargetMuscle()` keeps producing the same generator-bucket value as today. Element [1+] are the new sub-tags (`biceps`, `triceps`, `forearms`, `glutes`, `quads`, `hamstrings`, `calves`, `obliques`, `abs`, `lats`, `rhomboids`, `traps`, `rear_delt`, `front_delt`, `side_delt`, `inner_chest`, `upper_chest`, `lower_chest`, `lower_back`, `hip_flexors`, `adductors`, `grip`, `hiit`, `mobility`, `stretching`).
- **`slug`** is snake_case; `StringCase.snakeToPascal` produces the `.mp4` filename (e.g. `diamond_push_up` → `DiamondPushUp.mp4`).
- **`thumbnail_url`** column is populated for completeness; the player does not yet read it.
- **Analyzer:** when "reused", the slug is added to the matching `case` in `analyzer_factory.dart`. When "SilentHold", no factory edit is needed (default fallback).
- **Calorie estimates** are per set (lower bound, ~75 kg adult) and intentionally conservative.
- **Animation duration** is the recommended Kling clip length for a clean loop.

---

## CORE — 11 additions (5 equipment + 6 bodyweight)

### `decline_crunch` — Eğimli Mekik
- Category: `core` · Difficulty: `intermediate` · Type: `repBased` · is_cardio: false
- target_muscles: `['core', 'abs']`
- Reps: 15 · Sets: 3 · Rest: 35 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: decline bench
- Analyzer: **CrunchAnalyzer** (reused — torso angle preserved)
- Landmarks: shoulder, hip, knee, ear (form)
- Description: `'Decline bench üzerine sırt üstü uzan, ayaklarını sabitle ve omuzlarını karnını kasarak kontrollü olarak yukarı kaldır.'`
- shortTip: `'Karın gergin, boyun nötr.'`
- contextualCue: `'Düşerken nefes ver.'`
- Form correction (auto): neck angle < 120° → "Boynunu düz tut!"
- Common mistakes: boynu çekiştirme · ivmeli sallanma · ayak sabitlemesi gevşek
- Asset: `DeclineCrunch.mp4` · Thumb: `decline_crunch_thumb.webp`
- Tags: `['core','abs','equipment','intermediate']`

### `weighted_sit_up` — Ağırlıklı Sit-up
- Category: `core` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['core', 'abs']`
- Reps: 10 · Sets: 3 · Rest: 40 s · Calories: ~6/set · Animation: 3.8 s
- Equipment: dumbbell or plate
- Analyzer: **CrunchAnalyzer** (reused)
- Landmarks: shoulder, hip, knee, ear
- Description: `'Sırt üstü uzan, plate veya dambılı göğsüne yapıştır ve gövdeni dizlerine kadar tam olarak kontrollü kaldır.'`
- shortTip: `'Karnınla çek, ivmeden kaçın.'`
- Form correction: neck < 120° warning
- Common mistakes: ağırlığı boyna yaklaştırma · sırtı yuvarlama · sallanma
- Asset: `WeightedSitUp.mp4` · Thumb: `weighted_sit_up_thumb.webp`
- Tags: `['core','abs','equipment','intermediate']`

### `weighted_leg_raise` — Ağırlıklı Bacak Kaldırma
- Category: `core` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['core', 'abs', 'lower_abs']`
- Reps: 12 · Sets: 3 · Rest: 35 s · Calories: ~5/set · Animation: 3.6 s
- Equipment: ankle weight or dumbbell between feet
- Analyzer: **LegRaiseAnalyzer** (reused — hip angle)
- Landmarks: shoulder, hip, ankle
- Description: `'Sırt üstü uzan, ayak bileklerine ağırlık tak veya dambılı ayakların arasına sıkıştır ve bacaklarını kontrollü olarak yukarı kaldır.'`
- shortTip: `'Bel yere yapışık.'`
- Common mistakes: bel köprüsü · sallanma · hızlı iniş
- Asset: `WeightedLegRaise.mp4` · Thumb: `weighted_leg_raise_thumb.webp`
- Tags: `['core','abs','lower_abs','equipment','intermediate']`

### `dragon_flag` — Dragon Flag
- Category: `core` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['core', 'abs', 'obliques']`
- Reps: 6 · Sets: 3 · Rest: 75 s · Calories: ~8/set · Animation: 4.5 s
- Equipment: bench (grip behind head)
- Analyzer: **LegRaiseAnalyzer** (reused — hip angle still cycles 90→180)
- Landmarks: shoulder, hip, ankle
- Description: `'Bench üzerine sırt üstü uzan, ellerinle başının arkasındaki kenara sıkıca tutun, vücudunu omuzlarınla bench üzerinde olacak şekilde dik tut ve kontrollü olarak indir.'`
- shortTip: `'Vücut tek parça düz.'`
- Form correction: torso angle warning
- Common mistakes: kalçayı bükmek · iniş kontrolü kaybı · omuz sabitlemesi gevşek
- Asset: `DragonFlag.mp4` · Thumb: `dragon_flag_thumb.webp`
- Tags: `['core','abs','obliques','equipment','advanced']`

### `medicine_ball_russian_twist` — Sağlık Topuyla Rus Dönüşü
- Category: `core` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['core', 'obliques']`
- Reps: 20 · Sets: 3 · Rest: 35 s · Calories: ~5/set · Animation: 3.4 s
- Equipment: medicine ball or dumbbell
- Analyzer: **RussianTwistAnalyzer** (reused — shoulder/hip mid offset)
- Landmarks: shoulders, hips
- Description: `'Otur, dizleri bük, sağlık topunu göğüs önünde tut, hafifçe geri yaslan ve gövdeni sağdan sola tempolu biçimde döndür.'`
- shortTip: `'Karnını sıkı tut, sırt yuvarlanmasın.'`
- Common mistakes: sırt yere düşme · top kollarla salınma · ayak yere düşme
- Asset: `MedicineBallRussianTwist.mp4` · Thumb: `medicine_ball_russian_twist_thumb.webp`
- Tags: `['core','obliques','equipment','intermediate']`

### `reverse_crunch` — Ters Mekik
- Category: `core` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['core', 'abs', 'lower_abs']`
- Reps: 15 · Sets: 3 · Rest: 30 s · Calories: ~4/set · Animation: 3.2 s
- Equipment: bodyweight
- Analyzer: **LegRaiseAnalyzer** (reused — hips/legs lift = hip angle)
- Landmarks: shoulder, hip, ankle
- Description: `'Sırt üstü uzan, dizlerini 90 dereceye bük ve kalçanı yerden kaldırarak dizlerini göğsüne doğru çek.'`
- shortTip: `'Karnınla çek, ayağı sallama.'`
- Common mistakes: ivmeli sallanma · bel köprüsü · diz açısı bozulması
- Asset: `ReverseCrunch.mp4` · Thumb: `reverse_crunch_thumb.webp`
- Tags: `['core','abs','lower_abs','bodyweight','beginner']`

### `toe_touch` — V-Up Toe Touch
- Category: `core` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['core', 'abs']`
- Reps: 12 · Sets: 3 · Rest: 30 s · Calories: ~4/set · Animation: 3.2 s
- Equipment: bodyweight
- Analyzer: **CrunchAnalyzer** (reused — torso flex)
- Landmarks: shoulder, hip, knee, ear
- Description: `'Sırt üstü uzan, bacaklarını dik kaldır ve ellerini ayak parmaklarına dokundurmaya çalış.'`
- shortTip: `'Tepe noktada bir saniye dur.'`
- Common mistakes: bacakları çok eğme · boyun çekiştirme · sallanma
- Asset: `ToeTouch.mp4` · Thumb: `toe_touch_thumb.webp`
- Tags: `['core','abs','bodyweight','beginner']`

### `hollow_hold` — Hollow Body Hold
- Category: `core` · Difficulty: `intermediate` · Type: `timeBased`
- target_muscles: `['core', 'abs']`
- Duration: 25 s · Sets: 3 · Rest: 35 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer** (default — static hold; no rep counting)
- Landmarks: n/a
- Description: `'Sırt üstü uzan, kollarını başının üzerinde uzat, omuzlarını ve bacaklarını yerden bir miktar kaldır ve karnını kasarak hollow pozisyonunu koru.'`
- shortTip: `'Bel yere yapışık.'`
- Common mistakes: bel boşluğu · omuz çökmesi · nefes tutma
- Asset: `HollowHold.mp4` · Thumb: `hollow_hold_thumb.webp`
- Tags: `['core','abs','bodyweight','intermediate']`

### `side_plank` — Yan Plank
- Category: `core` · Difficulty: `intermediate` · Type: `timeBased`
- target_muscles: `['core', 'obliques']`
- Duration: 30 s · Sets: 3 · Rest: 30 s · Calories: ~5/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer** (PlankAnalyzer's vertical-line check would misfire on rotated geometry)
- Landmarks: n/a
- Description: `'Yan yat, dirseğini omuz altına yerleştir ve kalçanı yukarı kaldırarak vücudunu omuzdan ayağa düz bir çizgi oluştur.'`
- shortTip: `'Kalçanı düşürme.'`
- Common mistakes: kalça düşmesi · omuz çökmesi · baş düşmesi
- Asset: `SidePlank.mp4` · Thumb: `side_plank_thumb.webp`
- Tags: `['core','obliques','bodyweight','intermediate']`

### `bird_dog` — Bird Dog
- Category: `core` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['core', 'lower_back']`
- Reps: 12 (per side) · Sets: 3 · Rest: 30 s · Calories: ~3/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer** (single-side balance hold)
- Landmarks: n/a
- Description: `'Dört ayak duruşunda elin omuz altında, dizin kalça altında olacak şekilde başla; karşıt kol ve bacağı vücutla aynı çizgide uzat ve geri dön.'`
- shortTip: `'Sırtın düz, salınma.'`
- Common mistakes: bel sarkması · omuz dönmesi · bacak çok yukarı
- Asset: `BirdDog.mp4` · Thumb: `bird_dog_thumb.webp`
- Tags: `['core','lower_back','bodyweight','beginner','mobility']`

### `dead_bug` — Dead Bug
- Category: `core` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['core', 'abs']`
- Reps: 12 · Sets: 3 · Rest: 30 s · Calories: ~3/set · Animation: 3.4 s
- Equipment: bodyweight
- Analyzer: **FlutterKickAnalyzer** (reused — alternating ankle-y delta side-flips)
- Landmarks: ankles
- Description: `'Sırt üstü uzan, kolları yukarı uzat ve dizleri 90 derece bükülü tut; karşıt kol ve bacağı yere değdirmeden indir ve geri çek.'`
- shortTip: `'Bel yere yapışık.'`
- Common mistakes: bel köprüsü · hızlı hareket · kollar gevşek
- Asset: `DeadBug.mp4` · Thumb: `dead_bug_thumb.webp`
- Tags: `['core','abs','bodyweight','beginner']`

---

## CHEST — 11 additions (5 equipment + 6 bodyweight)

### `decline_bench_press` — Decline DB Bench Press
- Category: `chest` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'chest', 'lower_chest']`
- Reps: 10 · Sets: 3 · Rest: 60 s · Calories: ~7/set · Animation: 3.8 s
- Equipment: decline bench + dumbbells
- Analyzer: **BenchPressAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Decline bench üzerine sırt üstü uzan, ayaklarını sabitle, dambılları göğsüne göğsünden kollarını tam açana kadar yukarı it.'`
- shortTip: `'Bilek nötr, dirsek 45°.'`
- Common mistakes: dirsek dışa açılması · alt sırt köprüsü · bilek bükülmesi
- Asset: `DeclineBenchPress.mp4` · Thumb: `decline_bench_press_thumb.webp`
- Tags: `['chest','lower_chest','equipment','intermediate']`

### `cable_crossover` — Cable Crossover
- Category: `chest` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'chest', 'inner_chest']`
- Reps: 12 · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.6 s
- Equipment: cable machine
- Analyzer: **ChestFlyAnalyzer** (reused — wrist gap vs shoulder width)
- Landmarks: shoulders, wrists
- Description: `'Cable makinesinin ortasında dur, kollarını yana aç ve kabloları göğsünün önünde kontrollü olarak çapraz şekilde birleştir.'`
- shortTip: `'Dirseğin hafif bükülü kalsın.'`
- Common mistakes: omuz öne kaymak · gövde dönmesi · ağırlık çok fazla
- Asset: `CableCrossover.mp4` · Thumb: `cable_crossover_thumb.webp`
- Tags: `['chest','inner_chest','equipment','intermediate']`

### `dumbbell_pullover` — Dambıl Pullover
- Category: `chest` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'chest', 'lats']`
- Reps: 12 · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.6 s
- Equipment: bench + single dumbbell
- Analyzer: **SilentHoldAnalyzer** (overhead arc not modeled by existing analyzers)
- Landmarks: n/a
- Description: `'Bench üzerine omuzların değecek şekilde dik açıyla yat, dambılı iki elinle göğsünün üzerinde tut ve kontrollü olarak başının arkasına indir.'`
- shortTip: `'Dirsekleri hafif bükülü tut.'`
- Common mistakes: aşırı esneme · kalça düşmesi · dirsek tam açılması
- Asset: `DumbbellPullover.mp4` · Thumb: `dumbbell_pullover_thumb.webp`
- Tags: `['chest','lats','equipment','intermediate']`

### `incline_chest_fly` — Yokuş Yukarı Chest Fly
- Category: `chest` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'chest', 'upper_chest']`
- Reps: 12 · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.6 s
- Equipment: incline bench + dumbbells
- Analyzer: **ChestFlyAnalyzer** (reused)
- Landmarks: shoulders, wrists
- Description: `'Eğimli bench üzerine sırt üstü uzan, dambılları göğsünün üstünde tut ve kollarını yana doğru kontrollü olarak aç ve kapat.'`
- shortTip: `'Dirsekleri hafif bükülü tut.'`
- Common mistakes: omuzdan değil dirsekten yük · aşırı açılma · hızlı tempo
- Asset: `InclineChestFly.mp4` · Thumb: `incline_chest_fly_thumb.webp`
- Tags: `['chest','upper_chest','equipment','intermediate']`

### `machine_chest_press` — Makine Chest Press
- Category: `chest` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'chest']`
- Reps: 12 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: chest press machine
- Analyzer: **BenchPressAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Makineye otur, sırtını yasla, kollarını omuz hizasında tut ve tutamakları kontrollü olarak öne doğru it.'`
- shortTip: `'Omuzları yastığa bastır.'`
- Common mistakes: dirsek kilitleme · omuz öne kayma · hızlı geri dönüş
- Asset: `MachineChestPress.mp4` · Thumb: `machine_chest_press_thumb.webp`
- Tags: `['chest','equipment','beginner']`

### `diamond_push_up` — Diamond Şınav
- Category: `chest` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'chest', 'triceps', 'inner_chest']`
- Reps: 10 · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **PushUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Avuç içlerini iki başparmak ve iki işaret parmağıyla elmas oluşturacak şekilde yere koy ve kontrollü olarak şınav hareketini uygula.'`
- shortTip: `'Dirseği gövdene yapıştır.'`
- Common mistakes: dirsek dışa kaçar · kalça düşmesi · boyun gerilmesi
- Asset: `DiamondPushUp.mp4` · Thumb: `diamond_push_up_thumb.webp`
- Tags: `['chest','triceps','inner_chest','bodyweight','intermediate']`

### `wide_push_up` — Geniş Tutuş Şınav
- Category: `chest` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'chest']`
- Reps: 12 · Sets: 3 · Rest: 45 s · Calories: ~6/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **PushUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Ellerini omuz genişliğinden 1.5 kat dışarıda yere koy, dirseklerini yana doğru bükerek şınav hareketini uygula.'`
- shortTip: `'Göğsü iki elin arasına indir.'`
- Common mistakes: kalça düşmesi · omuz öne çökme · hızlı tempo
- Asset: `WidePushUp.mp4` · Thumb: `wide_push_up_thumb.webp`
- Tags: `['chest','bodyweight','intermediate']`

### `archer_push_up` — Archer Şınav
- Category: `chest` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['upper_body', 'chest']`
- Reps: 6 (per side) · Sets: 3 · Rest: 60 s · Calories: ~7/set · Animation: 4.0 s
- Equipment: bodyweight
- Analyzer: **PushUpAnalyzer** (reused — single-arm dominant elbow flexion)
- Landmarks: shoulder, elbow, wrist
- Description: `'Geniş bir şınav pozisyonu al, vücudunu bir tarafa kaydırarak ağırlığını tek kola al ve kontrollü olarak in ve çık.'`
- shortTip: `'Karşı kolu düz tut.'`
- Common mistakes: kalça düşmesi · gövde dönmesi · diğer kol bükülmesi
- Asset: `ArcherPushUp.mp4` · Thumb: `archer_push_up_thumb.webp`
- Tags: `['chest','bodyweight','advanced']`

### `pseudo_planche_push_up` — Pseudo Planche Şınav
- Category: `chest` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['upper_body', 'chest', 'shoulders', 'triceps']`
- Reps: 8 · Sets: 3 · Rest: 60 s · Calories: ~7/set · Animation: 3.8 s
- Equipment: bodyweight
- Analyzer: **PushUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Ellerini bel hizasına yerleştir, parmakların geriye baksın, ağırlığını öne aktararak kontrollü şınav uygula.'`
- shortTip: `'Omuzu öne, dirseği geri.'`
- Common mistakes: kalça yukarı kaçma · omuz çökmesi · parmak gerilmesi
- Asset: `PseudoPlanchePushUp.mp4` · Thumb: `pseudo_planche_push_up_thumb.webp`
- Tags: `['chest','shoulders','triceps','bodyweight','advanced']`

### `clap_push_up` — Alkışlı Şınav
- Category: `chest` · Difficulty: `advanced` · Type: `repBased` · is_cardio: true
- target_muscles: `['upper_body', 'chest']`
- Reps: 8 · Sets: 3 · Rest: 60 s · Calories: ~9/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **PushUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Standart şınav pozisyonundan patlayıcı şekilde yukarı it, havadayken bir kez alkışla ve yumuşak iniş yap.'`
- shortTip: `'Sessiz iniş, dirsek yumuşak.'`
- Common mistakes: sert iniş · alkışsız tek el · dengesiz iniş
- Asset: `ClapPushUp.mp4` · Thumb: `clap_push_up_thumb.webp`
- Tags: `['chest','plyometric','bodyweight','advanced','cardio']`

### `knee_push_up` — Diz Üstü Şınav
- Category: `chest` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'chest']`
- Reps: 12 · Sets: 3 · Rest: 40 s · Calories: ~4/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **PushUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Dizlerini yere koy, ellerini omuz hizasında yere yerleştir ve kontrollü olarak şınav hareketini uygula.'`
- shortTip: `'Dizden başa düz çizgi.'`
- Common mistakes: kalça yukarı · omuz çökmesi · ROM kısa
- Asset: `KneePushUp.mp4` · Thumb: `knee_push_up_thumb.webp`
- Tags: `['chest','bodyweight','beginner']`

---

## BACK — 11 additions (6 equipment + 5 bodyweight)

### `dumbbell_row` — Tek Kol Dambıl Row
- Category: `back` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'back', 'lats']`
- Reps: 12 (per side) · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.6 s
- Equipment: bench + dumbbell
- Analyzer: **PullUpAnalyzer** (reused — loaded elbow flexion)
- Landmarks: shoulder, elbow, wrist
- Description: `'Bench üzerine bir el ve bir dizini yasla, sırtını düz tut, dambılı kalçana doğru kontrollü olarak çek.'`
- shortTip: `'Dirsek gövdeye yakın.'`
- Common mistakes: gövde dönmesi · sırt yuvarlanması · ağırlık çok fazla
- Asset: `DumbbellRow.mp4` · Thumb: `dumbbell_row_thumb.webp`
- Tags: `['back','lats','equipment','intermediate']`

### `t_bar_row` — T-Bar Row
- Category: `back` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'back', 'rhomboids']`
- Reps: 10 · Sets: 3 · Rest: 60 s · Calories: ~7/set · Animation: 3.8 s
- Equipment: T-bar attachment
- Analyzer: **PullUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Barı omuz hizanda tutarak öne eğil, sırtın nötr, barı göbek hizana kontrollü olarak çek ve indir.'`
- shortTip: `'Kürekleri sıkıştır.'`
- Common mistakes: sırt yuvarlanması · ivmeli salınım · dirseği dışa açma
- Asset: `TBarRow.mp4` · Thumb: `t_bar_row_thumb.webp`
- Tags: `['back','rhomboids','equipment','intermediate']`

### `face_pull` — Kablo Face Pull
- Category: `back` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'back', 'rear_delt']`
- Reps: 15 · Sets: 3 · Rest: 40 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: cable machine + rope
- Analyzer: **PullUpAnalyzer** (reused — elbow flexion to head height)
- Landmarks: shoulder, elbow, wrist
- Description: `'Kablo makinesinin önünde dur, halatı yüz hizanda tut ve dirseklerini dışa doğru bükerek halatı kulak hizasına çek.'`
- shortTip: `'Dirsek omuz hizasında.'`
- Common mistakes: dirseğin düşmesi · gövde geriye yaslanması · ağırlık fazla
- Asset: `FacePull.mp4` · Thumb: `face_pull_thumb.webp`
- Tags: `['back','rear_delt','equipment','beginner']`

### `seated_cable_row` — Oturarak Kablo Row
- Category: `back` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'back', 'rhomboids']`
- Reps: 12 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.6 s
- Equipment: cable row machine
- Analyzer: **PullUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Otur, ayakları platforma yerleştir, halatı göbek hizana kontrollü olarak çek ve sırtı düz tut.'`
- shortTip: `'Önce kürekten çek.'`
- Common mistakes: gövde sallanması · sırt yuvarlanması · dirsek dışa açma
- Asset: `SeatedCableRow.mp4` · Thumb: `seated_cable_row_thumb.webp`
- Tags: `['back','rhomboids','equipment','beginner']`

### `deadlift` — Deadlift
- Category: `back` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['lower_body', 'back', 'lower_back', 'hamstrings', 'glutes']`
- Reps: 6 · Sets: 4 · Rest: 90 s · Calories: ~12/set · Animation: 4.5 s
- Equipment: barbell
- Analyzer: **SquatAnalyzer** (reused — knee bend at start; geometry partial-fit)
- Landmarks: hip, knee, ankle
- Description: `'Bar ayaklarının orta hizasında, ayaklar omuz genişliğinde; sırt nötr, göğüs yukarı, dizlerini ve kalçanı aynı anda açarak barı kontrollü olarak yukarı kaldır.'`
- shortTip: `'Sırt nötr, kalça hinge.'`
- Common mistakes: sırt yuvarlanması · bar gövdeden uzakta · diz öne kayması
- Asset: `Deadlift.mp4` · Thumb: `deadlift_thumb.webp`
- Tags: `['back','lower_back','hamstrings','glutes','equipment','advanced']`

### `hyperextension` — Hyperextension
- Category: `back` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['back', 'lower_back', 'glutes']`
- Reps: 12 · Sets: 3 · Rest: 45 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: hyperextension bench
- Analyzer: **SilentHoldAnalyzer** (back extension geometry not modeled)
- Landmarks: n/a
- Description: `'Hyperextension bench üzerine yüzükoyun yerleş, ayaklarını sabitle ve gövdeni 90 dereceden başlayarak kontrollü olarak yukarı kaldır.'`
- shortTip: `'Tepe noktada hiperekstansiyon yapma.'`
- Common mistakes: aşırı uzatma · ivmeli sallanma · diz tam kilitleme
- Asset: `Hyperextension.mp4` · Thumb: `hyperextension_thumb.webp`
- Tags: `['back','lower_back','glutes','equipment','beginner']`

### `inverted_row` — Inverted Row
- Category: `back` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'back', 'lats']`
- Reps: 10 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.6 s
- Equipment: low bar or sturdy table
- Analyzer: **PullUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Düşük bir barın altına sırt üstü uzan, vücudunu düz tutarak göğsünü bara doğru kontrollü olarak çek.'`
- shortTip: `'Göğüs bara temas etsin.'`
- Common mistakes: kalça düşmesi · ROM kısa · dirsek dışa açma
- Asset: `InvertedRow.mp4` · Thumb: `inverted_row_thumb.webp`
- Tags: `['back','lats','bodyweight','intermediate']`

### `prone_y_raise` — Yüzükoyun Y Kaldırma
- Category: `back` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'back', 'traps', 'rear_delt']`
- Reps: 12 · Sets: 3 · Rest: 35 s · Calories: ~3/set · Animation: 3.2 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer** (small ROM, prone geometry)
- Landmarks: n/a
- Description: `'Yüzükoyun uzan, kollarını başının üzerinde Y şekli oluşturacak biçimde uzat ve kollarını kontrollü olarak yerden kaldır.'`
- shortTip: `'Kürekleri sıkıştır.'`
- Common mistakes: boyun aşağı sarkma · ivmeli sallanma · ROM kısa
- Asset: `ProneYRaise.mp4` · Thumb: `prone_y_raise_thumb.webp`
- Tags: `['back','traps','rear_delt','bodyweight','beginner']`

### `prone_t_raise` — Yüzükoyun T Kaldırma
- Category: `back` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'back', 'rhomboids']`
- Reps: 12 · Sets: 3 · Rest: 35 s · Calories: ~3/set · Animation: 3.2 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Yüzükoyun uzan, kollarını yana doğru T şekli oluşturacak biçimde aç ve kontrollü olarak yerden kaldır.'`
- shortTip: `'Baş parmak yukarı.'`
- Common mistakes: boyun çökmesi · omuz çekme · ROM kısa
- Asset: `ProneTRaise.mp4` · Thumb: `prone_t_raise_thumb.webp`
- Tags: `['back','rhomboids','bodyweight','beginner']`

### `swimmer` — Swimmer
- Category: `back` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['upper_body', 'back', 'lower_back']`
- Duration: 30 s · Sets: 3 · Rest: 30 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Yüzükoyun uzan, kolları başın üzerinde uzat; karşıt kol ve bacağı yerden eş zamanlı kaldır ve değişimle yüzme hareketi yap.'`
- shortTip: `'Tempolu, ritimli.'`
- Common mistakes: bel köprüsü · boyun çökmesi · hızlı tempo
- Asset: `Swimmer.mp4` · Thumb: `swimmer_thumb.webp`
- Tags: `['back','lower_back','bodyweight','beginner']`

### `scapular_pull_up` — Skapular Pull-up
- Category: `back` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['back', 'lats', 'traps']`
- Reps: 10 · Sets: 3 · Rest: 45 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: pull-up bar
- Analyzer: **PullUpAnalyzer** (reused — small ROM but elbow geometry)
- Landmarks: shoulder, elbow, wrist
- Description: `'Bara avuç içleri dışa dönük asıl, dirseklerini düz tut ve omuzlarını aşağı çekerek kürek kemiklerini sıkıştır.'`
- shortTip: `'Sadece omuzdan çek.'`
- Common mistakes: dirsek bükmesi · sallanma · ROM çok kısa
- Asset: `ScapularPullUp.mp4` · Thumb: `scapular_pull_up_thumb.webp`
- Tags: `['back','lats','traps','equipment','intermediate']`

---

## SHOULDERS — 10 additions (5 equipment + 5 bodyweight)

### `rear_delt_fly` — Rear Delt Fly
- Category: `shoulders` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'rear_delt']`
- Reps: 12 · Sets: 3 · Rest: 40 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: dumbbells
- Analyzer: **LateralRaiseAnalyzer** (reused — same shoulder vertex angle)
- Landmarks: shoulder, elbow, hip
- Description: `'Hafifçe öne eğil, sırtını düz tut, dambılları yana doğru omuz hizasına kontrollü olarak kaldır.'`
- shortTip: `'Kürekleri sıkıştır.'`
- Common mistakes: gövdeyi dikleştirme · ivmeli sallanma · ağırlık fazla
- Asset: `RearDeltFly.mp4` · Thumb: `rear_delt_fly_thumb.webp`
- Tags: `['shoulders','rear_delt','equipment','beginner']`

### `upright_row` — Upright Row
- Category: `shoulders` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'traps']`
- Reps: 10 · Sets: 3 · Rest: 45 s · Calories: ~5/set · Animation: 3.4 s
- Equipment: dumbbells or barbell
- Analyzer: **ShoulderPressAnalyzer** (reused — vertical wrist-Y delta)
- Landmarks: shoulders, wrists
- Description: `'Dambılları kalça önünde tut, dirseklerini yukarı doğru göğüs hizasına kontrollü olarak çek.'`
- shortTip: `'Dirseği bilekten yüksek tut.'`
- Common mistakes: dirseğin bilekten alçak kalması · ivmeli salınım · omuz öne kayma
- Asset: `UprightRow.mp4` · Thumb: `upright_row_thumb.webp`
- Tags: `['shoulders','traps','equipment','intermediate']`

### `cuban_press` — Cuban Press
- Category: `shoulders` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'rear_delt']`
- Reps: 8 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 4.0 s
- Equipment: dumbbells
- Analyzer: **ShoulderPressAnalyzer** (reused — final phase is overhead press)
- Landmarks: shoulders, wrists
- Description: `'Dambılları kalça önünde tut, dirseklerini yukarı çek, sonra avuçlarını yukarı çevir ve son olarak baş üstüne kontrollü olarak it.'`
- shortTip: `'Üç fazlı: çek, çevir, it.'`
- Common mistakes: faz atlama · gövde geri yaslanma · dirsek tam kilitleme
- Asset: `CubanPress.mp4` · Thumb: `cuban_press_thumb.webp`
- Tags: `['shoulders','rear_delt','rotator_cuff','equipment','intermediate']`

### `landmine_press` — Landmine Press
- Category: `shoulders` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'core']`
- Reps: 10 (per side) · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.6 s
- Equipment: landmine attachment + barbell
- Analyzer: **ShoulderPressAnalyzer** (reused)
- Landmarks: shoulders, wrists
- Description: `'Tek elinle barı omuz hizasında tut, ayaklarını omuz genişliğinde yerleştir ve barı kontrollü olarak öne ve yukarı doğru it.'`
- shortTip: `'Karın gergin, gövde sabit.'`
- Common mistakes: gövde dönmesi · dirsek tam kilitleme · alt sırt köprüsü
- Asset: `LandminePress.mp4` · Thumb: `landmine_press_thumb.webp`
- Tags: `['shoulders','core','equipment','intermediate']`

### `machine_shoulder_press` — Makine Shoulder Press
- Category: `shoulders` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders']`
- Reps: 12 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: shoulder press machine
- Analyzer: **ShoulderPressAnalyzer** (reused)
- Landmarks: shoulders, wrists
- Description: `'Makineye otur, sırtını yasla, tutamakları omuz hizasında tut ve baş üstüne doğru kontrollü olarak it.'`
- shortTip: `'Sırtı yastığa bastır.'`
- Common mistakes: dirsek tam kilitleme · ROM kısa · gövde öne çökme
- Asset: `MachineShoulderPress.mp4` · Thumb: `machine_shoulder_press_thumb.webp`
- Tags: `['shoulders','equipment','beginner']`

### `handstand_hold` — Duvarda Handstand
- Category: `shoulders` · Difficulty: `advanced` · Type: `timeBased`
- target_muscles: `['upper_body', 'shoulders', 'core']`
- Duration: 20 s · Sets: 3 · Rest: 60 s · Calories: ~6/set · Animation: 3.5 s
- Equipment: bodyweight + wall
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Ellerini duvardan 30 cm uzakta yere koy, ayaklarını duvara doğru yürüt ve duvardan destek alarak baş aşağı pozisyonu koru.'`
- shortTip: `'Karnı sıkı, omuzu it.'`
- Common mistakes: bel köprüsü · omuz çökmesi · nefes tutma
- Asset: `HandstandHold.mp4` · Thumb: `handstand_hold_thumb.webp`
- Tags: `['shoulders','core','bodyweight','advanced']`

### `pike_walk` — Pike Walk
- Category: `shoulders` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'hamstrings']`
- Reps: 10 · Sets: 3 · Rest: 40 s · Calories: ~4/set · Animation: 3.8 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer** (multi-step movement)
- Landmarks: n/a
- Description: `'Şınav pozisyonunda başla, ayaklarını ellerine doğru küçük adımlarla yaklaştırarak pike pozisyonu al ve geri dön.'`
- shortTip: `'Diz hafif bükülü olabilir.'`
- Common mistakes: dizleri tam kilitleme · sırt yuvarlanması · hızlı tempo
- Asset: `PikeWalk.mp4` · Thumb: `pike_walk_thumb.webp`
- Tags: `['shoulders','hamstrings','mobility','bodyweight','beginner']`

### `wall_walk` — Wall Walk
- Category: `shoulders` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'core']`
- Reps: 5 · Sets: 3 · Rest: 60 s · Calories: ~7/set · Animation: 4.5 s
- Equipment: bodyweight + wall
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Ayaklarını duvara dayalı şınav pozisyonundan başla, ellerini ve ayaklarını sırayla duvara doğru yürüt ve geri dön.'`
- shortTip: `'Yavaş ve kontrollü.'`
- Common mistakes: bel köprüsü · hızlı yürüme · denge kaybı
- Asset: `WallWalk.mp4` · Thumb: `wall_walk_thumb.webp`
- Tags: `['shoulders','core','bodyweight','advanced']`

### `scapular_wall_slide` — Skapular Duvar Slayd
- Category: `shoulders` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['shoulders', 'back', 'rear_delt']`
- Reps: 12 · Sets: 3 · Rest: 30 s · Calories: ~3/set · Animation: 3.4 s
- Equipment: bodyweight + wall
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Sırtını duvara yasla, kollarını W şeklinde duvara dayalı tut ve kollarını kontrollü olarak yukarı ve aşağı kaydır.'`
- shortTip: `'Dirsek duvardan ayrılmasın.'`
- Common mistakes: dirseğin duvardan ayrılması · sırt eğilmesi · hızlı tempo
- Asset: `ScapularWallSlide.mp4` · Thumb: `scapular_wall_slide_thumb.webp`
- Tags: `['shoulders','rear_delt','mobility','bodyweight','beginner']`

### `handstand_push_up` — Duvarda Handstand Şınav
- Category: `shoulders` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'triceps']`
- Reps: 5 · Sets: 3 · Rest: 75 s · Calories: ~8/set · Animation: 4.0 s
- Equipment: bodyweight + wall
- Analyzer: **PushUpAnalyzer** (reused — inverted but elbow geometry preserved)
- Landmarks: shoulder, elbow, wrist
- Description: `'Duvarda handstand pozisyonu al, dirseklerini bükerek başını yere doğru kontrollü olarak indir ve kollarını yukarı it.'`
- shortTip: `'Üç noktada denge.'`
- Common mistakes: omuz çökmesi · dirsek dışa açma · denge kaybı
- Asset: `HandstandPushUp.mp4` · Thumb: `handstand_push_up_thumb.webp`
- Tags: `['shoulders','triceps','bodyweight','advanced']`

---

## ARMS — 12 additions (7 equipment + 5 bodyweight)

### `preacher_curl` — Preacher Curl
- Category: `arms` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'biceps']`
- Reps: 10 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: preacher bench + dumbbell or EZ bar
- Analyzer: **BicepsCurlAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Preacher bench üzerine kollarını yasla, dambılı veya EZ barı kontrollü olarak omuza doğru çek ve indir.'`
- shortTip: `'Sadece ön kol oynasın.'`
- Common mistakes: dirseğin yasladan kalkması · ROM kısa · ivmeli salınım
- Asset: `PreacherCurl.mp4` · Thumb: `preacher_curl_thumb.webp`
- Tags: `['biceps','equipment','intermediate']`

### `incline_dumbbell_curl` — Yokuş Yukarı Dambıl Curl
- Category: `arms` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'biceps']`
- Reps: 10 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: incline bench + dumbbells
- Analyzer: **BicepsCurlAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Eğimli bench üzerine sırt üstü uzan, kolları aşağı sarkıt ve dambılları kontrollü olarak omuza doğru çek.'`
- shortTip: `'Dirsek geri kaymasın.'`
- Common mistakes: dirseğin öne kayması · sırtı kaldırma · ROM kısa
- Asset: `InclineDumbbellCurl.mp4` · Thumb: `incline_dumbbell_curl_thumb.webp`
- Tags: `['biceps','equipment','intermediate']`

### `cable_curl` — Kablo Curl
- Category: `arms` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'biceps']`
- Reps: 12 · Sets: 3 · Rest: 45 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: cable machine + bar
- Analyzer: **BicepsCurlAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Cable makinesinin önünde dur, barı belin önünde tut ve dirseklerini sabitleyerek omuza doğru kontrollü olarak çek.'`
- shortTip: `'Dirsek gövdene yapışık.'`
- Common mistakes: gövde sallanması · dirseğin öne kayması · ROM kısa
- Asset: `CableCurl.mp4` · Thumb: `cable_curl_thumb.webp`
- Tags: `['biceps','equipment','beginner']`

### `overhead_triceps_extension` — Baş Üstü Triceps Extension
- Category: `arms` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'triceps']`
- Reps: 10 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.6 s
- Equipment: dumbbell
- Analyzer: **BicepsCurlAnalyzer** (reused — elbow flexion behind head)
- Landmarks: shoulder, elbow, wrist
- Description: `'Otur veya ayakta dur, dambılı iki elinle baş üstünde tut, dirseklerini sabitleyerek başının arkasına kontrollü olarak indir.'`
- shortTip: `'Üst kol sabit, sadece ön kol oynar.'`
- Common mistakes: dirseğin dışa açılması · sırt köprüsü · ROM kısa
- Asset: `OverheadTricepsExtension.mp4` · Thumb: `overhead_triceps_extension_thumb.webp`
- Tags: `['triceps','equipment','intermediate']`

### `rope_triceps_pushdown` — Halat Triceps Pushdown
- Category: `arms` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'triceps']`
- Reps: 12 · Sets: 3 · Rest: 45 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: cable machine + rope
- Analyzer: **BicepsCurlAnalyzer** (reused — elbow extension cycle)
- Landmarks: shoulder, elbow, wrist
- Description: `'Cable makinesinin önünde dur, halatı göğüs hizanda tut ve dirseklerini sabitleyerek halatı kontrollü olarak aşağı it ve dışarı doğru aç.'`
- shortTip: `'Tepe noktada halatı aç.'`
- Common mistakes: gövde öne çökme · dirseğin öne kayması · ROM kısa
- Asset: `RopeTricepsPushdown.mp4` · Thumb: `rope_triceps_pushdown_thumb.webp`
- Tags: `['triceps','equipment','beginner']`

### `dumbbell_kickback` — Dambıl Kickback
- Category: `arms` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'triceps']`
- Reps: 12 (per side) · Sets: 3 · Rest: 40 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: dumbbell + bench
- Analyzer: **BicepsCurlAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Bench üzerine bir el ve dizini yasla, dambılı tutan kolu üst kolun gövdene paralel olacak şekilde kaldır ve ön kolu kontrollü olarak geriye doğru aç.'`
- shortTip: `'Üst kol sabit kalsın.'`
- Common mistakes: üst kolun düşmesi · gövde dönmesi · ivmeli salınım
- Asset: `DumbbellKickback.mp4` · Thumb: `dumbbell_kickback_thumb.webp`
- Tags: `['triceps','equipment','beginner']`

### `farmer_carry` — Farmer's Carry
- Category: `arms` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['upper_body', 'forearms', 'core', 'grip']`
- Duration: 30 s · Sets: 3 · Rest: 45 s · Calories: ~6/set · Animation: 3.5 s
- Equipment: heavy dumbbells or kettlebells
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Iki ağır dambılı yan tarafına al, omuzlarını geride tut ve karnı sıkı şekilde dik yürüyüşle taşı.'`
- shortTip: `'Omuzlar geride, karın sıkı.'`
- Common mistakes: omuz öne çökmesi · adımları çok uzun atma · sırt yuvarlanması
- Asset: `FarmerCarry.mp4` · Thumb: `farmer_carry_thumb.webp`
- Tags: `['forearms','core','grip','equipment','beginner']`

### `chin_up_negative` — Chin-up Negatif
- Category: `arms` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'biceps', 'back']`
- Reps: 5 · Sets: 3 · Rest: 60 s · Calories: ~5/set · Animation: 5.0 s
- Equipment: pull-up bar
- Analyzer: **PullUpAnalyzer** (reused — eccentric phase)
- Landmarks: shoulder, elbow, wrist
- Description: `'Bara çene seviyesinde başla, vücudunu çok yavaş şekilde 4-6 saniyede aşağı indir, sonra zıplayarak başlangıç pozisyonuna geri dön.'`
- shortTip: `'Yavaş, kontrollü iniş.'`
- Common mistakes: hızlı iniş · sallanma · omuz çökmesi
- Asset: `ChinUpNegative.mp4` · Thumb: `chin_up_negative_thumb.webp`
- Tags: `['biceps','back','bodyweight','intermediate']`

### `bench_dip` — Bench Dip
- Category: `arms` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['upper_body', 'triceps']`
- Reps: 12 · Sets: 3 · Rest: 45 s · Calories: ~5/set · Animation: 3.5 s
- Equipment: bench or sturdy chair
- Analyzer: **PushUpAnalyzer** (reused — elbow flexion)
- Landmarks: shoulder, elbow, wrist
- Description: `'Sırtın bench arkasına gelecek şekilde otur, ellerinle bench kenarını tut, kalçanı bench önüne kaydır ve dirseklerini bükerek aşağı in ve geri kalk.'`
- shortTip: `'Dirsek geriye, dışarı değil.'`
- Common mistakes: omuz çökmesi · dirseğin dışa açılması · ROM kısa
- Asset: `BenchDip.mp4` · Thumb: `bench_dip_thumb.webp`
- Tags: `['triceps','bodyweight','beginner']`

### `tricep_extension_floor` — Yer Üstü Triceps Extension
- Category: `arms` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['upper_body', 'triceps']`
- Reps: 8 · Sets: 3 · Rest: 50 s · Calories: ~5/set · Animation: 3.6 s
- Equipment: bodyweight (no equipment variant of skull crusher)
- Analyzer: **BicepsCurlAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Yere şınav pozisyonunda başla, dirseklerini bükerek ön kollarını yere indir ve sadece tricepsleri kullanarak gövdeni geri yukarı it.'`
- shortTip: `'Üst kol sabit, ön kol oynar.'`
- Common mistakes: kalça düşmesi · omuz çökmesi · gövdeyi şınavla itme
- Asset: `TricepExtensionFloor.mp4` · Thumb: `tricep_extension_floor_thumb.webp`
- Tags: `['triceps','bodyweight','intermediate']`

### `pike_push_up_close` — Yakın Tutuş Pike Şınav
- Category: `arms` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['upper_body', 'shoulders', 'triceps']`
- Reps: 8 · Sets: 3 · Rest: 60 s · Calories: ~7/set · Animation: 3.8 s
- Equipment: bodyweight
- Analyzer: **PushUpAnalyzer** (reused)
- Landmarks: shoulder, elbow, wrist
- Description: `'Pike pozisyonunda kalçanı yukarı kaldır, ellerini omuz genişliğinden dar yere koy ve başını ellerin arasına kontrollü olarak indir.'`
- shortTip: `'Dirsek gövdene yakın.'`
- Common mistakes: kalça çökmesi · dirseğin dışa açılması · ROM kısa
- Asset: `PikePushUpClose.mp4` · Thumb: `pike_push_up_close_thumb.webp`
- Tags: `['shoulders','triceps','bodyweight','advanced']`

### `dead_hang` — Dead Hang
- Category: `arms` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['upper_body', 'forearms', 'grip', 'back']`
- Duration: 30 s · Sets: 3 · Rest: 45 s · Calories: ~3/set · Animation: 3.0 s
- Equipment: pull-up bar
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Bara avuç içleri dışa dönük asıl, omuzlarını aktif tut ve vücudunu rahat bir şekilde sarkıt.'`
- shortTip: `'Omuz aktif, sarkma.'`
- Common mistakes: omuz çökmesi · ayağı yere değdirme · sallanma
- Asset: `DeadHang.mp4` · Thumb: `dead_hang_thumb.webp`
- Tags: `['forearms','grip','back','equipment','beginner']`

---

## LEGS — 15 additions (6 equipment + 9 bodyweight)

### `front_squat` — Front Squat
- Category: `legs` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['lower_body', 'quads', 'core']`
- Reps: 8 · Sets: 4 · Rest: 75 s · Calories: ~10/set · Animation: 4.0 s
- Equipment: barbell + rack
- Analyzer: **SquatAnalyzer** (reused)
- Landmarks: hip, knee, ankle
- Description: `'Bar omuz önünde, dirsekler yukarı, ayakların omuz genişliğinde, kalçandan oturarak çök ve topuktan iterek kalk.'`
- shortTip: `'Göğüs yukarı, dirsek yukarı.'`
- Common mistakes: dirseğin düşmesi · gövde öne eğilmesi · diz içe düşmesi
- Asset: `FrontSquat.mp4` · Thumb: `front_squat_thumb.webp`
- Tags: `['quads','core','equipment','advanced']`

### `goblet_squat` — Goblet Squat
- Category: `legs` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['lower_body', 'quads', 'glutes']`
- Reps: 12 · Sets: 3 · Rest: 50 s · Calories: ~7/set · Animation: 3.6 s
- Equipment: dumbbell or kettlebell
- Analyzer: **SquatAnalyzer** (reused)
- Landmarks: hip, knee, ankle
- Description: `'Dambılı veya KB göğüs önünde dik tut, ayaklarını omuz genişliğinde yerleştir ve kalçandan oturarak kontrollü olarak çök ve kalk.'`
- shortTip: `'Dirsek dizin içine.'`
- Common mistakes: dizin içe düşmesi · topukların kalkması · sırt yuvarlanması
- Asset: `GobletSquat.mp4` · Thumb: `goblet_squat_thumb.webp`
- Tags: `['quads','glutes','equipment','beginner']`

### `hip_thrust` — Hip Thrust
- Category: `legs` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['lower_body', 'glutes', 'hamstrings']`
- Reps: 10 · Sets: 3 · Rest: 60 s · Calories: ~7/set · Animation: 3.8 s
- Equipment: barbell + bench
- Analyzer: **SilentHoldAnalyzer** (knee angle stays ~90°; hip extension is primary)
- Landmarks: n/a
- Description: `'Sırtın bench kenarına yaslı, ayaklar omuz genişliğinde ve dizler 90 derece, barı kalça hizasında tut ve kalçanı kontrollü olarak yukarı kaldır.'`
- shortTip: `'Tepe noktada kalçanı sıkıştır.'`
- Common mistakes: belin aşırı uzaması · ayakların çok uzakta · ROM kısa
- Asset: `HipThrust.mp4` · Thumb: `hip_thrust_thumb.webp`
- Tags: `['glutes','hamstrings','equipment','intermediate']`

### `dumbbell_step_up` — Dambıl Step-up
- Category: `legs` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['lower_body', 'quads', 'glutes']`
- Reps: 10 (per leg) · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.8 s
- Equipment: bench or box + dumbbells
- Analyzer: **SquatAnalyzer** (reused — knee angle still cycles)
- Landmarks: hip, knee, ankle
- Description: `'Dambılları yan tarafına al, ayağını bench üzerine koy ve topuktan iterek kontrollü olarak yukarı çık ve in.'`
- shortTip: `'Topuktan it, sıçrama.'`
- Common mistakes: topuktan değil parmak ucundan itme · gövde öne çökme · denge kaybı
- Asset: `DumbbellStepUp.mp4` · Thumb: `dumbbell_step_up_thumb.webp`
- Tags: `['quads','glutes','equipment','beginner']`

### `walking_lunge_dumbbell` — Dambıl Yürüyüş Lunge
- Category: `legs` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['lower_body', 'quads', 'glutes']`
- Reps: 12 (per leg) · Sets: 3 · Rest: 50 s · Calories: ~7/set · Animation: 3.8 s
- Equipment: dumbbells
- Analyzer: **SquatAnalyzer** (reused)
- Landmarks: hip, knee, ankle
- Description: `'Dambılları yan tarafına al, geniş bir adım at, ön dizini 90 dereceye kadar büküp arka diz yere yaklaşacak şekilde çök ve diğer adımı at.'`
- shortTip: `'Ön diz parmak ucu hizasında.'`
- Common mistakes: ön dizin parmak ucunu geçmesi · gövde öne eğilme · dengesiz adım
- Asset: `WalkingLungeDumbbell.mp4` · Thumb: `walking_lunge_dumbbell_thumb.webp`
- Tags: `['quads','glutes','equipment','intermediate']`

### `seated_calf_raise` — Oturarak Calf Raise
- Category: `legs` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['lower_body', 'calves']`
- Duration: 35 s · Sets: 3 · Rest: 35 s · Calories: ~3/set · Animation: 3.0 s
- Equipment: seated calf raise machine
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Makineye otur, ayak parmak uçlarını platforma yerleştir ve baldırlarını kasarak topukları kontrollü olarak yukarı ve aşağı hareket ettir.'`
- shortTip: `'Tepe noktada bir saniye sık.'`
- Common mistakes: ROM kısa · hızlı tempo · ağırlık fazla
- Asset: `SeatedCalfRaise.mp4` · Thumb: `seated_calf_raise_thumb.webp`
- Tags: `['calves','equipment','beginner']`

### `glute_bridge` — Glute Bridge
- Category: `legs` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['lower_body', 'glutes']`
- Reps: 15 · Sets: 3 · Rest: 35 s · Calories: ~4/set · Animation: 3.4 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer** (hip extension; knee stays ~90°)
- Landmarks: n/a
- Description: `'Sırt üstü uzan, dizleri 90 derece bük, ayaklarını yere yapıştır ve kalçanı yukarı kaldırarak omuzdan dize düz çizgi oluştur.'`
- shortTip: `'Tepe noktada kalçanı sıkıştır.'`
- Common mistakes: belin aşırı uzaması · diz içe düşmesi · ROM kısa
- Asset: `GluteBridge.mp4` · Thumb: `glute_bridge_thumb.webp`
- Tags: `['glutes','bodyweight','beginner']`

### `single_leg_glute_bridge` — Tek Bacak Glute Bridge
- Category: `legs` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['lower_body', 'glutes', 'hamstrings']`
- Reps: 10 (per side) · Sets: 3 · Rest: 45 s · Calories: ~5/set · Animation: 3.6 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Sırt üstü uzan, bir bacağını dik kaldır, diğer ayağını yere yapıştır ve tek bacak desteğiyle kalçanı kontrollü olarak yukarı kaldır.'`
- shortTip: `'Karın sıkı, denge tut.'`
- Common mistakes: kalçanın yan dönmesi · belin aşırı uzaması · denge kaybı
- Asset: `SingleLegGluteBridge.mp4` · Thumb: `single_leg_glute_bridge_thumb.webp`
- Tags: `['glutes','hamstrings','bodyweight','intermediate']`

### `pistol_squat` — Pistol Squat
- Category: `legs` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['lower_body', 'quads', 'glutes']`
- Reps: 6 (per leg) · Sets: 3 · Rest: 75 s · Calories: ~8/set · Animation: 4.5 s
- Equipment: bodyweight
- Analyzer: **SquatAnalyzer** (reused)
- Landmarks: hip, knee, ankle
- Description: `'Bir bacağını öne uzat, diğer bacağında dengele ve tek ayak üzerinde kontrollü olarak çök ve kalk.'`
- shortTip: `'Topuktan it, denge tut.'`
- Common mistakes: dizin içe düşmesi · topukların kalkması · denge kaybı
- Asset: `PistolSquat.mp4` · Thumb: `pistol_squat_thumb.webp`
- Tags: `['quads','glutes','bodyweight','advanced']`

### `sumo_squat` — Sumo Squat
- Category: `legs` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['lower_body', 'glutes', 'adductors']`
- Reps: 15 · Sets: 3 · Rest: 45 s · Calories: ~6/set · Animation: 3.6 s
- Equipment: bodyweight (or dumbbell variant)
- Analyzer: **SquatAnalyzer** (reused)
- Landmarks: hip, knee, ankle
- Description: `'Ayaklarını omuz genişliğinden iki kat dışarıda yerleştir, ayak parmaklarını dışa çevir ve kalçandan kontrollü olarak çök ve kalk.'`
- shortTip: `'Diz parmak ucu hizasında.'`
- Common mistakes: dizin içe düşmesi · topukların kalkması · sırt yuvarlanması
- Asset: `SumoSquat.mp4` · Thumb: `sumo_squat_thumb.webp`
- Tags: `['glutes','adductors','bodyweight','beginner']`

### `box_jump` — Box Jump
- Category: `legs` · Difficulty: `intermediate` · Type: `repBased` · is_cardio: true
- target_muscles: `['lower_body', 'quads', 'glutes']`
- Reps: 10 · Sets: 3 · Rest: 60 s · Calories: ~9/set · Animation: 3.8 s
- Equipment: plyo box
- Analyzer: **SquatAnalyzer** (reused — knee flexion cycle)
- Landmarks: hip, knee, ankle
- Description: `'Boxun önünde dur, kalçandan hafifçe çök, kollarını sallayarak patlayıcı şekilde boxa zıpla ve yumuşak iniş yap.'`
- shortTip: `'Topukta in, sessiz iniş.'`
- Common mistakes: parmak ucunda iniş · diz içe düşmesi · denge kaybı
- Asset: `BoxJump.mp4` · Thumb: `box_jump_thumb.webp`
- Tags: `['quads','glutes','plyometric','equipment','intermediate','cardio']`

### `single_leg_calf_raise` — Tek Bacak Calf Raise
- Category: `legs` · Difficulty: `intermediate` · Type: `timeBased`
- target_muscles: `['lower_body', 'calves']`
- Duration: 30 s · Sets: 3 · Rest: 35 s · Calories: ~3/set · Animation: 3.2 s
- Equipment: bodyweight (optional step)
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Tek ayak üzerinde dengele, parmak uçlarında yüksel ve baldırını sıkıştırarak topuğunu kontrollü olarak indir.'`
- shortTip: `'Tepede bir saniye sık.'`
- Common mistakes: denge kaybı · ROM kısa · hızlı tempo
- Asset: `SingleLegCalfRaise.mp4` · Thumb: `single_leg_calf_raise_thumb.webp`
- Tags: `['calves','bodyweight','intermediate']`

### `single_leg_rdl` — Tek Bacak Romen Deadlift
- Category: `legs` · Difficulty: `intermediate` · Type: `repBased`
- target_muscles: `['lower_body', 'hamstrings', 'glutes']`
- Reps: 10 (per leg) · Sets: 3 · Rest: 50 s · Calories: ~6/set · Animation: 3.8 s
- Equipment: bodyweight (optional dumbbell)
- Analyzer: **SilentHoldAnalyzer** (single-leg balance + hip hinge not modeled)
- Landmarks: n/a
- Description: `'Tek ayak üzerinde dengele, kalçandan menteşe gibi öne eğil, arka bacağını gövdenle aynı çizgide geri uzat ve geri dön.'`
- shortTip: `'Sırt nötr, diz hafif bükülü.'`
- Common mistakes: sırt yuvarlanması · diz tam kilitleme · denge kaybı
- Asset: `SingleLegRdl.mp4` · Thumb: `single_leg_rdl_thumb.webp`
- Tags: `['hamstrings','glutes','bodyweight','intermediate']`

### `frog_pump` — Frog Pump
- Category: `legs` · Difficulty: `beginner` · Type: `repBased`
- target_muscles: `['lower_body', 'glutes']`
- Reps: 20 · Sets: 3 · Rest: 30 s · Calories: ~3/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Sırt üstü uzan, ayak tabanlarını birleştir, dizleri yana açıp kurbağa pozisyonu al ve kalçanı kontrollü olarak yukarı kaldır.'`
- shortTip: `'Tepede sıkıştır.'`
- Common mistakes: ROM kısa · belin aşırı uzaması · hızlı tempo
- Asset: `FrogPump.mp4` · Thumb: `frog_pump_thumb.webp`
- Tags: `['glutes','bodyweight','beginner']`

### `nordic_curl` — Nordic Hamstring Curl
- Category: `legs` · Difficulty: `advanced` · Type: `repBased`
- target_muscles: `['lower_body', 'hamstrings']`
- Reps: 6 · Sets: 3 · Rest: 75 s · Calories: ~7/set · Animation: 4.5 s
- Equipment: bodyweight (partner or sturdy support to anchor ankles)
- Analyzer: **SilentHoldAnalyzer** (specialized eccentric, knee hinge not standard)
- Landmarks: n/a
- Description: `'Diz çök, ayak bileklerini sabitlet, vücudunu omuzdan dize düz tut ve hamstringleri kullanarak çok yavaş şekilde öne doğru indir.'`
- shortTip: `'Yavaş, kontrollü iniş.'`
- Common mistakes: kalça bükülmesi · sırt yuvarlanması · iniş hızı yüksek
- Asset: `NordicCurl.mp4` · Thumb: `nordic_curl_thumb.webp`
- Tags: `['hamstrings','bodyweight','advanced']`

---

## FULL BODY — 17 additions (3 equipment + 8 bodyweight HIIT/cardio + 6 mobility/stretching)

### `kettlebell_swing` — Kettlebell Swing
- Category: `fullBody` · Difficulty: `intermediate` · Type: `repBased` · is_cardio: true
- target_muscles: `['full_body', 'glutes', 'hamstrings', 'hiit']`
- Reps: 15 · Sets: 3 · Rest: 50 s · Calories: ~10/set · Animation: 3.6 s
- Equipment: kettlebell
- Analyzer: **SilentHoldAnalyzer** (hip hinge + arm swing pattern)
- Landmarks: n/a
- Description: `'Kettlebellı iki elinle tut, kalçandan menteşe gibi öne eğil, kalçanı patlayıcı şekilde öne iterek kettlebelli omuz hizasına savur ve geri kontrol et.'`
- shortTip: `'Hareket kalçadan, kollardan değil.'`
- Common mistakes: çekiş kollardan · sırt yuvarlanması · diz çok bükülmesi
- Asset: `KettlebellSwing.mp4` · Thumb: `kettlebell_swing_thumb.webp`
- Tags: `['full_body','glutes','hamstrings','hiit','equipment','intermediate','cardio']`

### `thruster` — Dambıl Thruster
- Category: `fullBody` · Difficulty: `intermediate` · Type: `repBased` · is_cardio: true
- target_muscles: `['full_body', 'quads', 'shoulders', 'hiit']`
- Reps: 10 · Sets: 3 · Rest: 60 s · Calories: ~10/set · Animation: 3.8 s
- Equipment: dumbbells
- Analyzer: **SquatAnalyzer** (reused — knee cycle dominant)
- Landmarks: hip, knee, ankle
- Description: `'Dambılları omuz hizasında tut, squat pozisyonuna in, kalkış patlamasıyla aynı anda dambılları baş üstüne kontrollü olarak it.'`
- shortTip: `'Squat ve press tek hareket.'`
- Common mistakes: faz ayrılması · dirseğin tam kilitlenmemesi · sırt yuvarlanması
- Asset: `Thruster.mp4` · Thumb: `thruster_thumb.webp`
- Tags: `['full_body','quads','shoulders','hiit','equipment','intermediate','cardio']`

### `dumbbell_clean` — Dambıl Hang Clean
- Category: `fullBody` · Difficulty: `intermediate` · Type: `repBased` · is_cardio: true
- target_muscles: `['full_body', 'hiit']`
- Reps: 8 · Sets: 3 · Rest: 60 s · Calories: ~9/set · Animation: 3.8 s
- Equipment: dumbbells
- Analyzer: **SilentHoldAnalyzer** (complex multi-phase movement)
- Landmarks: n/a
- Description: `'Dambılları kalça önünde tut, kalçanı geriye it, patlayıcı şekilde kalçayı öne iterek dambılları omuz hizasına çek.'`
- shortTip: `'Kalça itimi ile fırlat.'`
- Common mistakes: çekiş kollardan · sırt yuvarlanması · ayaktan kuvvet alma yetersiz
- Asset: `DumbbellClean.mp4` · Thumb: `dumbbell_clean_thumb.webp`
- Tags: `['full_body','hiit','equipment','intermediate','cardio']`

### `squat_thrust` — Squat Thrust
- Category: `fullBody` · Difficulty: `beginner` · Type: `repBased` · is_cardio: true
- target_muscles: `['full_body', 'cardio']`
- Reps: 15 · Sets: 3 · Rest: 40 s · Calories: ~7/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **BurpeeAnalyzer** (reused — STANDING→DOWN→STANDING phase machine)
- Landmarks: shoulder
- Description: `'Aşağı in, ellerin yere değdiğinde ayaklarını geri at ve plank pozisyonu al, ayaklarını öne çekip ayağa kalk (zıplama yok).'`
- shortTip: `'Sürekli ritim.'`
- Common mistakes: kalça yukarı · denge kaybı · faz atlama
- Asset: `SquatThrust.mp4` · Thumb: `squat_thrust_thumb.webp`
- Tags: `['full_body','cardio','bodyweight','beginner']`

### `half_burpee` — Half Burpee
- Category: `fullBody` · Difficulty: `intermediate` · Type: `repBased` · is_cardio: true
- target_muscles: `['full_body', 'cardio', 'hiit']`
- Reps: 12 · Sets: 3 · Rest: 45 s · Calories: ~8/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **BurpeeAnalyzer** (reused)
- Landmarks: shoulder
- Description: `'Aşağı in, ellerin yere değdiğinde ayaklarını geri at ve plank pozisyonu al, ayaklarını öne çekip patlayıcı şekilde zıpla.'`
- shortTip: `'Şınav yok, sürekli tempo.'`
- Common mistakes: kalça yukarı · şınav ekleme · iniş sert
- Asset: `HalfBurpee.mp4` · Thumb: `half_burpee_thumb.webp`
- Tags: `['full_body','cardio','hiit','bodyweight','intermediate']`

### `plank_jack` — Plank Jack
- Category: `fullBody` · Difficulty: `intermediate` · Type: `timeBased` · is_cardio: true
- target_muscles: `['core', 'cardio', 'hiit']`
- Duration: 30 s · Sets: 3 · Rest: 35 s · Calories: ~6/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer** (legs lateral spread in plank; not covered)
- Landmarks: n/a
- Description: `'Plank pozisyonunda başla, ayaklarını yana doğru aç ve birleştir, sürekli ritimle hareket et.'`
- shortTip: `'Kalçayı sabit tut.'`
- Common mistakes: kalça yukarı · kalça düşmesi · omuz çökmesi
- Asset: `PlankJack.mp4` · Thumb: `plank_jack_thumb.webp`
- Tags: `['core','cardio','hiit','bodyweight','intermediate']`

### `bear_crawl` — Bear Crawl
- Category: `fullBody` · Difficulty: `intermediate` · Type: `timeBased`
- target_muscles: `['full_body', 'core', 'hiit']`
- Duration: 30 s · Sets: 3 · Rest: 40 s · Calories: ~7/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Dört ayak duruşunda dizlerini yerden hafifçe kaldır ve karşıt el-bacak ritmi ile öne ve geri yürü.'`
- shortTip: `'Diz yere değmesin.'`
- Common mistakes: kalça yukarı · sırt yuvarlanması · hızlı tempo
- Asset: `BearCrawl.mp4` · Thumb: `bear_crawl_thumb.webp`
- Tags: `['full_body','core','hiit','bodyweight','intermediate']`

### `lateral_shuffle` — Lateral Shuffle
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased` · is_cardio: true
- target_muscles: `['cardio', 'lower_body', 'hiit']`
- Duration: 30 s · Sets: 3 · Rest: 30 s · Calories: ~6/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Hafifçe çök, ayaklarını omuz genişliğinde tut ve yana doğru hızlı adımlarla sürekli kaymaya devam et.'`
- shortTip: `'Diz hafif bükülü.'`
- Common mistakes: gövde dikleşmesi · ayakların çapraz kalması · ROM kısa
- Asset: `LateralShuffle.mp4` · Thumb: `lateral_shuffle_thumb.webp`
- Tags: `['cardio','lower_body','hiit','bodyweight','beginner']`

### `squat_jump_pulse` — Squat Pulse Jump
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased` · is_cardio: true
- target_muscles: `['cardio', 'lower_body', 'quads']`
- Duration: 30 s · Sets: 3 · Rest: 35 s · Calories: ~7/set · Animation: 3.2 s
- Equipment: bodyweight
- Analyzer: **SquatAnalyzer** (reused)
- Landmarks: hip, knee, ankle
- Description: `'Squat pozisyonuna in ve aralıksız kısa zıplamalarla pozisyonu koruyarak ritmik şekilde sıçra.'`
- shortTip: `'Diz parmak ucu hizasında.'`
- Common mistakes: dizin içe düşmesi · sırt yuvarlanması · ayağı kalkık tutma
- Asset: `SquatJumpPulse.mp4` · Thumb: `squat_jump_pulse_thumb.webp`
- Tags: `['cardio','lower_body','quads','bodyweight','beginner']`

### `shadow_boxing` — Shadow Boxing
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased` · is_cardio: true
- target_muscles: `['cardio', 'shoulders', 'hiit']`
- Duration: 45 s · Sets: 3 · Rest: 30 s · Calories: ~8/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Boks duruşu al, ayaklarını omuz genişliğinde yerleştir ve sürekli tempolu yumruklarla shadow boxing yap.'`
- shortTip: `'Karın sıkı, ritim koru.'`
- Common mistakes: ayakların çakılı kalması · gövdeyi sabit tutmama · nefes tutma
- Asset: `ShadowBoxing.mp4` · Thumb: `shadow_boxing_thumb.webp`
- Tags: `['cardio','shoulders','hiit','bodyweight','beginner']`

### `tuck_jump` — Tuck Jump
- Category: `fullBody` · Difficulty: `advanced` · Type: `repBased` · is_cardio: true
- target_muscles: `['lower_body', 'quads', 'hiit']`
- Reps: 10 · Sets: 3 · Rest: 60 s · Calories: ~10/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **SquatAnalyzer** (reused — knee cycle preserved)
- Landmarks: hip, knee, ankle
- Description: `'Kalçandan hafifçe çök, kollarını sallayarak patlayıcı şekilde zıpla ve dizlerini göğsüne kontrollü olarak çek.'`
- shortTip: `'Sessiz, yumuşak iniş.'`
- Common mistakes: iniş sert · diz içe düşmesi · denge kaybı
- Asset: `TuckJump.mp4` · Thumb: `tuck_jump_thumb.webp`
- Tags: `['lower_body','quads','hiit','plyometric','bodyweight','advanced','cardio']`

### `cat_cow` — Kedi-İnek Stretch
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['mobility', 'lower_back', 'core']`
- Duration: 30 s · Sets: 2 · Rest: 30 s · Calories: ~2/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Dört ayak duruşunda başla; nefes alarak sırtını içeri çukurlaştır (inek), nefes vererek sırtını yukarı kavisle (kedi) ve ritmik geçişler yap.'`
- shortTip: `'Nefesle hareket eşleşsin.'`
- Common mistakes: hızlı tempo · ROM kısa · nefes-hareket uyumsuzluğu
- Asset: `CatCow.mp4` · Thumb: `cat_cow_thumb.webp`
- Tags: `['mobility','lower_back','core','stretching','bodyweight','beginner']`

### `child_pose` — Çocuk Pozu
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['stretching', 'lower_back']`
- Duration: 30 s · Sets: 2 · Rest: 20 s · Calories: ~1/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Diz üstünde otur, kalçanı topuklarına yaklaştır, gövdeni öne eğ ve kollarını öne uzatarak rahatça bekle.'`
- shortTip: `'Derin nefes al.'`
- Common mistakes: kalça topuklara değmemesi · alın yere değmemesi · omuz gerilmesi
- Asset: `ChildPose.mp4` · Thumb: `child_pose_thumb.webp`
- Tags: `['stretching','lower_back','mobility','bodyweight','beginner']`

### `downward_dog` — Aşağı Bakan Köpek
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['mobility', 'shoulders', 'hamstrings']`
- Duration: 30 s · Sets: 2 · Rest: 25 s · Calories: ~2/set · Animation: 3.5 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Plank pozisyonundan kalçanı yukarı kaldır, vücudunla ters V şekli oluştur, topuklarını yere doğru bastır ve nefesle pozisyonu derinleştir.'`
- shortTip: `'Topuğu yere doğru bastır.'`
- Common mistakes: sırt yuvarlanması · omuz çökmesi · diz tam kilitleme
- Asset: `DownwardDog.mp4` · Thumb: `downward_dog_thumb.webp`
- Tags: `['mobility','shoulders','hamstrings','stretching','bodyweight','beginner']`

### `cobra_stretch` — Kobra Stretch
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['stretching', 'core', 'chest']`
- Duration: 25 s · Sets: 2 · Rest: 20 s · Calories: ~1/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Yüzükoyun uzan, ellerini omuz altına yerleştir ve kollarını uzatarak göğsünü yerden kaldırarak kobra pozisyonu al.'`
- shortTip: `'Kalça yere yapışık.'`
- Common mistakes: omuz çökmesi · kalça kalkması · boyun çekiştirmesi
- Asset: `CobraStretch.mp4` · Thumb: `cobra_stretch_thumb.webp`
- Tags: `['stretching','core','chest','mobility','bodyweight','beginner']`

### `hip_flexor_stretch` — Diz Çökerek Hip Flexor Stretch
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['stretching', 'hip_flexors']`
- Duration: 30 s · Sets: 2 · Rest: 20 s · Calories: ~1/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Bir dizini yere koy, diğer ayağını öne 90 derece bük; kalçanı kontrollü olarak öne it ve hip flexor gerilimini hisset.'`
- shortTip: `'Karın sıkı, kalça öne.'`
- Common mistakes: bel köprüsü · ön diz parmak ucunu geçer · gerilim hissetmeme
- Asset: `HipFlexorStretch.mp4` · Thumb: `hip_flexor_stretch_thumb.webp`
- Tags: `['stretching','hip_flexors','mobility','bodyweight','beginner']`

### `standing_hamstring_stretch` — Ayakta Hamstring Stretch
- Category: `fullBody` · Difficulty: `beginner` · Type: `timeBased`
- target_muscles: `['stretching', 'hamstrings']`
- Duration: 25 s · Sets: 2 · Rest: 20 s · Calories: ~1/set · Animation: 3.0 s
- Equipment: bodyweight
- Analyzer: **SilentHoldAnalyzer**
- Landmarks: n/a
- Description: `'Bir bacağını öne uzat, topuğunu yere yapıştır ve gövdeni kontrollü olarak öne eğerek hamstring gerilimini hisset.'`
- shortTip: `'Sırt nötr, dizi tam kilitleme.'`
- Common mistakes: sırt yuvarlanması · bacağı tam kilitleme · ROM yetersiz
- Asset: `StandingHamstringStretch.mp4` · Thumb: `standing_hamstring_stretch_thumb.webp`
- Tags: `['stretching','hamstrings','mobility','bodyweight','beginner']`

---

## Summary Table — Analyzer routing additions for `analyzer_factory.dart`

| Slug | Routes to |
|---|---|
| `decline_crunch`, `weighted_sit_up`, `toe_touch` | `CrunchAnalyzer` |
| `weighted_leg_raise`, `dragon_flag`, `reverse_crunch` | `LegRaiseAnalyzer` |
| `medicine_ball_russian_twist` | `RussianTwistAnalyzer` |
| `dead_bug` | `FlutterKickAnalyzer` |
| `decline_bench_press`, `machine_chest_press` | `BenchPressAnalyzer` |
| `cable_crossover`, `incline_chest_fly` | `ChestFlyAnalyzer` |
| `diamond_push_up`, `wide_push_up`, `archer_push_up`, `pseudo_planche_push_up`, `clap_push_up`, `knee_push_up`, `bench_dip`, `pike_push_up_close`, `handstand_push_up` | `PushUpAnalyzer` |
| `dumbbell_row`, `t_bar_row`, `face_pull`, `seated_cable_row`, `inverted_row`, `scapular_pull_up`, `chin_up_negative` | `PullUpAnalyzer` |
| `deadlift`, `front_squat`, `goblet_squat`, `dumbbell_step_up`, `walking_lunge_dumbbell`, `pistol_squat`, `sumo_squat`, `box_jump`, `thruster`, `squat_jump_pulse`, `tuck_jump` | `SquatAnalyzer` |
| `preacher_curl`, `incline_dumbbell_curl`, `cable_curl`, `overhead_triceps_extension`, `rope_triceps_pushdown`, `dumbbell_kickback`, `tricep_extension_floor` | `BicepsCurlAnalyzer` |
| `rear_delt_fly` | `LateralRaiseAnalyzer` |
| `upright_row`, `cuban_press`, `landmine_press`, `machine_shoulder_press` | `ShoulderPressAnalyzer` |
| `squat_thrust`, `half_burpee` | `BurpeeAnalyzer` |
| All others (mobility, stretching, balance holds, complex multi-phase) | `SilentHoldAnalyzer` (default fallback) |

**No new analyzer classes needed for Phase 96.** Every new exercise either reuses an existing analyzer or routes to `SilentHoldAnalyzer` (with the explicit understanding that those exercises do not have rep counting or form correction).

---

End of new exercise library specification.
