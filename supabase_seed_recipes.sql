-- =============================================================================
-- Phase 24: Nutrition seed data
-- =============================================================================
-- 25 dietitian-curated recipes, 5 per category tag:
--   • Yüksek Protein  — protein-heavy, post-training staples (>= 40 g protein)
--   • Düşük Kalori    — light, satiating cuts (<= 350 kcal)
--   • Hacim           — calorie-dense for gaining phases (>= 600 kcal)
--   • Sıkılaşma       — balanced, lower-fat recomp meals
--   • Vegan           — plant-only, no animal products
--
-- Copy this entire file into Supabase's SQL Editor and run it once.
-- Phase 43: the file is now idempotent — re-running is safe. The
-- preamble dedupes any existing duplicate titles (keeping the earliest
-- ctid), installs a UNIQUE constraint on `title`, and the INSERT at
-- the bottom uses `ON CONFLICT (title) DO NOTHING` so a second run
-- becomes a no-op on seeded rows.
--
-- Image URLs point to Unsplash photos that match the meal type. If any
-- URL 404s, the Flutter client's cached-network-image fallback renders
-- a neon-gradient placeholder, so broken images never crash the UI.
-- =============================================================================

-- 1. Schema: add the `tags` column if it isn't already there.
ALTER TABLE public.recipes
  ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';

-- 2. Idempotency primer — dedupe existing duplicates, then add the
--    UNIQUE constraint the `ON CONFLICT` clause below relies on.
DELETE FROM public.recipes r1
USING public.recipes r2
WHERE r1.ctid < r2.ctid
  AND r1.title = r2.title;

DO $guard$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'recipes_title_unique'
  ) THEN
    ALTER TABLE public.recipes
      ADD CONSTRAINT recipes_title_unique UNIQUE (title);
  END IF;
END
$guard$;

-- 3. Bulk insert of the 25 recipes. Dollar-quoted strings ($$...$$) let
--    the instructions hold literal newlines and Turkish apostrophes
--    without escaping.
INSERT INTO public.recipes (
  title, meal_type, calories, protein, carbs, fat,
  prep_time_minutes, image_url, instructions, tags
) VALUES
-- ============================ Yüksek Protein (5) ============================
(
  'Izgara Tavuk ve Kinoa Kasesi',
  'main',
  520, 52, 35, 18,
  25,
  'photos/meals/izgara_tavuk_kinoa_kasesi.webp',
  $$MALZEMELER:
- 180g tavuk göğsü fileto
- 60g kinoa (kuru ölçü)
- 1 avuç taze ıspanak yaprağı
- 1/2 avokado
- 10 ml zeytinyağı
- 1 tatlı kaşığı limon suyu
- Tuz, karabiber, kimyon

HAZIRLANIŞI:
1. Kinoayı üç katı suyla 15 dakika haşlayıp süzün.
2. Tavuğu tuz, karabiber ve kimyonla marine edip kızgın ızgarada her yüzünü 3 dakika pişirin.
3. Kaseye sırasıyla kinoa, ıspanak ve dilimlenmiş avokadoyu yerleştirin.
4. Tavuğu dilimleyip üzerine koyun, zeytinyağı-limon sosuyla gezdirip servis edin.$$,
  ARRAY['Yüksek Protein']
),
(
  'Fırında Somon ve Tatlı Patates',
  'dinner',
  580, 45, 42, 25,
  30,
  'photos/meals/firinda_somon_tatli_patates.webp',
  $$MALZEMELER:
- 170g somon fileto
- 200g tatlı patates (küp doğranmış)
- 100g brokoli
- 15 ml zeytinyağı
- 1 diş sarımsak
- Taze dereotu, tuz, karabiber

HAZIRLANIŞI:
1. Tatlı patatesleri zeytinyağı, tuz ve karabiberle karıştırıp 200 derecede 25 dakika fırınlayın.
2. Somonu dereotu ve ezilmiş sarımsakla ovun, pişmenin son 12 dakikasında tepsiye ekleyin.
3. Brokoliyi 4 dakika buharda haşlayın.
4. Tabakta somonun yanına patates ve brokoliyi yerleştirip servis edin.$$,
  ARRAY['Yüksek Protein']
),
(
  'Yumurta Akı Omleti ve Hindi Eti',
  'breakfast',
  320, 45, 10, 10,
  10,
  'photos/meals/yumurta_aki_omleti_hindi_eti.webp',
  $$MALZEMELER:
- 5 adet yumurta akı
- 1 bütün yumurta
- 60g dilimli hindi göğsü
- 1/2 kırmızı biber (küp)
- 1 avuç maydanoz (doğranmış)
- Tuz, karabiber

HAZIRLANIŞI:
1. Yumurta akları ile bütün yumurtayı çırpın, tuz ve karabiber ekleyin.
2. Yapışmaz tavada hindi etini 1 dakika soteleyin.
3. Yumurta karışımını ekleyin, kenarlardan tutana kadar orta ateşte pişirin.
4. Biber ve maydanozu serpip omleti ikiye katlayın ve servis edin.$$,
  ARRAY['Yüksek Protein']
),
(
  'Süzme Yoğurtlu Protein Kasesi',
  'breakfast',
  380, 42, 32, 8,
  5,
  'photos/meals/suzme_yogurtlu_protein_kasesi.webp',
  $$MALZEMELER:
- 250g süzme yoğurt (yağsız)
- 30g vanilyalı whey protein tozu
- 80g çilek
- 20g yaban mersini
- 15g badem (iri doğranmış)
- 10g chia tohumu
- 5g bal

HAZIRLANIŞI:
1. Süzme yoğurdu protein tozuyla pürüzsüz olana kadar karıştırın.
2. Karışımı geniş bir kasenin tabanına yayın.
3. Üzerine meyveleri, bademi ve chia tohumunu sıralayın.
4. En son balı ince bir şerit halinde gezdirip hemen servis edin.$$,
  ARRAY['Yüksek Protein']
),
(
  'Izgara Bonfile ve Brokoli',
  'dinner',
  560, 55, 18, 28,
  20,
  'photos/meals/izgara_bonfile_brokoli.webp',
  $$MALZEMELER:
- 200g sığır bonfile
- 200g brokoli
- 15g tereyağı
- 2 diş sarımsak
- 10 ml zeytinyağı
- 1 dal taze biberiye
- Tuz, karabiber

HAZIRLANIŞI:
1. Bonfileyi pişirmeden 30 dakika önce buzdolabından çıkarıp oda sıcaklığına getirin.
2. Dökme demir tavada yüksek ateşte her yüzünü 3 dakika mühürleyin.
3. Ateşi kısın; tereyağı, sarımsak ve biberiyeyi ekleyip eti yağla kaşıklayın.
4. Brokoliyi ayrı tavada zeytinyağında 4 dakika soteleyin.
5. Bonfileyi 5 dakika dinlendirip dilimleyin, brokoliyle servis edin.$$,
  ARRAY['Yüksek Protein']
),
-- ============================ Düşük Kalori (5) ==============================
(
  'Izgara Sebzeli Ton Balığı Salatası',
  'lunch',
  290, 28, 22, 10,
  15,
  'photos/meals/izgara_sebzeli_ton_baligi_salatasi.webp',
  $$MALZEMELER:
- 120g suyu süzülmüş ton balığı konservesi
- 1 avuç marul yaprağı
- 1/2 salatalık
- 1 domates
- 50g ızgara kabak
- 30g ızgara kırmızı biber
- 10 ml zeytinyağı
- 1 tatlı kaşığı limon suyu

HAZIRLANIŞI:
1. Marulu, salatalığı ve domatesi iri iri doğrayıp geniş bir kaseye alın.
2. Izgara sebzeleri dilimleyip üzerine ekleyin.
3. Ton balığını salatanın üzerine yayın.
4. Zeytinyağı ve limon suyunu karıştırıp salatanın üzerine gezdirip servis edin.$$,
  ARRAY['Düşük Kalori']
),
(
  'Sebzeli Ev Çorbası',
  'lunch',
  180, 8, 28, 4,
  25,
  'photos/meals/sebzeli_ev_corbasi.webp',
  $$MALZEMELER:
- 1 havuç (küp)
- 1 kabak (küp)
- 100g kereviz sapı
- 1/2 kuru soğan
- 1 diş sarımsak
- 800 ml sebze suyu
- 10 ml zeytinyağı
- Tuz, karabiber, kekik

HAZIRLANIŞI:
1. Soğan ve sarımsağı zeytinyağında 2 dakika pembeleşene kadar soteleyin.
2. Küp doğranmış havuç, kabak ve kerevizi ekleyip 3 dakika daha kavurun.
3. Sebze suyunu ekleyip kısık ateşte 20 dakika pişirin.
4. Kekik, tuz ve karabiberi ilave edip sıcak servis edin.$$,
  ARRAY['Düşük Kalori']
),
(
  'Tavuk Göğsü Marul Sarma',
  'lunch',
  310, 32, 18, 12,
  15,
  'photos/meals/tavuk_gogsu_marul_sarma.webp',
  $$MALZEMELER:
- 120g haşlanmış tavuk göğsü (didiklenmiş)
- 6 iri marul yaprağı
- 1/2 havuç (rende)
- 1/4 kırmızı soğan (ince)
- 1 yemek kaşığı tahin
- 1 tatlı kaşığı soya sosu
- 5 ml limon suyu

HAZIRLANIŞI:
1. Tahin, soya sosu ve limon suyunu bir kasede iyice çırpın.
2. Tavuk, havuç ve soğanı bu sosla karıştırın.
3. Her marul yaprağına 2 yemek kaşığı karışım yerleştirin.
4. Yaprakları rulo şeklinde sarıp hemen servis edin.$$,
  ARRAY['Düşük Kalori']
),
(
  'Izgara Karides ve Roka Salatası',
  'dinner',
  280, 30, 12, 11,
  15,
  'photos/meals/izgara_karides_roka_salatasi.webp',
  $$MALZEMELER:
- 150g temizlenmiş karides
- 50g roka
- 1/2 avokado
- 10 cherry domates
- 10 ml zeytinyağı
- 2 diş sarımsak (ezilmiş)
- 1 limonun kabuğu rendesi
- Pul biber

HAZIRLANIŞI:
1. Karidesleri sarımsak, limon kabuğu ve pul biberle 10 dakika marine edin.
2. Yapışmaz tavada yağsız 3 dakika çevirerek pişirin.
3. Tabağa roka, dilimlenmiş avokado ve cherry domatesi yerleştirin.
4. Karidesleri üzerine dizin, zeytinyağını gezdirip servis edin.$$,
  ARRAY['Düşük Kalori']
),
(
  'Meyveli Süzme Yoğurt',
  'breakfast',
  240, 20, 30, 3,
  5,
  'photos/meals/meyveli_suzme_yogurt.webp',
  $$MALZEMELER:
- 200g süzme yoğurt (yağsız)
- 100g taze böğürtlen
- 50g kivi (dilimlenmiş)
- 10g bal
- 5g yulaf ezmesi

HAZIRLANIŞI:
1. Yoğurdu geniş bir kasenin tabanına yayın.
2. Meyveleri yoğurdun üzerine sıralayın.
3. Balı ince bir şerit halinde gezdirin.
4. Yulaf ezmesini serpip hemen servis edin.$$,
  ARRAY['Düşük Kalori']
),
-- ================================ Hacim (5) =================================
(
  'Tavuklu Yulaflı Wrap',
  'lunch',
  720, 45, 85, 20,
  20,
  'photos/meals/tavuklu_yulafli_wrap.webp',
  $$MALZEMELER:
- 2 büyük tam buğday lavaş
- 180g ızgara tavuk göğsü
- 60g yulaf ezmesi
- 1/2 avokado
- 30g çedar peyniri
- 1 yemek kaşığı humus
- Marul, domates ve salatalık

HAZIRLANIŞI:
1. Yulafı az suyla lapa kıvamına getirin ve soğutun.
2. Lavaşları tavada hafifçe ısıtın.
3. Humus, yulaf lapası, tavuk, avokado ve peyniri sırayla yerleştirin.
4. Sebzeleri ekleyip sıkıca sarın, ortadan iki parçaya bölüp servis edin.$$,
  ARRAY['Hacim']
),
(
  'Kıymalı Yüksek Protein Makarna',
  'dinner',
  820, 55, 95, 22,
  30,
  'photos/meals/kiymali_yuksek_protein_makarna.webp',
  $$MALZEMELER:
- 120g tam buğday makarna
- 150g yağsız dana kıyma
- 200g şekersiz domates sosu
- 1/2 soğan
- 2 diş sarımsak
- 30g parmesan peyniri
- 10 ml zeytinyağı
- Fesleğen, tuz, karabiber

HAZIRLANIŞI:
1. Makarnayı paket talimatına göre haşlayın.
2. Soğan ve sarımsağı zeytinyağında kavurun.
3. Kıymayı ekleyip rengi değişene kadar pişirin.
4. Domates sosunu ekleyip 10 dakika kısık ateşte kaynatın.
5. Makarnayı sosla buluşturun, üzerine parmesan ve fesleğen serpip servis edin.$$,
  ARRAY['Hacim']
),
(
  'Fıstık Ezmeli Muzlu Yulaf Ezmesi',
  'breakfast',
  680, 32, 90, 22,
  10,
  'photos/meals/fistik_ezmeli_muzlu_yulaf_ezmesi.webp',
  $$MALZEMELER:
- 80g yulaf ezmesi
- 250 ml süt
- 1 adet muz
- 30g doğal fıstık ezmesi
- 20g chia tohumu
- 15g bal
- Tarçın

HAZIRLANIŞI:
1. Yulafı sütle kısık ateşte 6-8 dakika kıvamını alana kadar lapalaştırın.
2. Kaseye aktarıp üzerine dilimlenmiş muz yerleştirin.
3. Fıstık ezmesini kaşıkla dolaştırarak gezdirin.
4. Chia tohumu, bal ve tarçınla bitirip sıcak servis edin.$$,
  ARRAY['Hacim']
),
(
  'Bonfileli Burrito',
  'lunch',
  780, 50, 78, 28,
  25,
  'photos/meals/bonfileli_burrito.webp',
  $$MALZEMELER:
- 1 büyük tam buğday tortilla
- 160g ızgara bonfile (dilimli)
- 80g esmer pirinç (pişmiş)
- 80g kırmızı barbunya (haşlanmış)
- 30g çedar peyniri
- 1/2 avokado
- 2 yemek kaşığı salsa sos

HAZIRLANIŞI:
1. Pirinç ile barbunyayı bir kasede karıştırın.
2. Tortillayı tavada hafifçe ısıtın.
3. Pirinç-barbunya karışımı, bonfile, peynir, avokado ve salsayı ortaya yerleştirin.
4. Önce kenarları içe katlayıp sıkıca sarın.
5. Sıcak tavada her yüzünü 1 dakika altın rengi alana kadar kızartın.$$,
  ARRAY['Hacim']
),
(
  'Protein Pankek Yığını',
  'breakfast',
  650, 40, 75, 18,
  15,
  'photos/meals/protein_pankek_yigini.webp',
  $$MALZEMELER:
- 60g yulaf unu
- 30g vanilyalı whey protein tozu
- 1 bütün yumurta
- 2 yumurta akı
- 1 muz (püre)
- 200 ml yağsız süt
- 1 tatlı kaşığı kabartma tozu
- 20g bal
- 80g yaban mersini

HAZIRLANIŞI:
1. Tüm malzemeleri blenderda pürüzsüz bir karışım olana kadar çekin.
2. Yapışmaz tavada orta ateşte her pankeki iki tarafta 2 dakika pişirin.
3. Pankekleri üst üste koyarak yığın oluşturun.
4. Üzerine yaban mersini ve balı ekleyip servis edin.$$,
  ARRAY['Hacim']
),
-- ============================= Sıkılaşma (5) ================================
(
  'Akdeniz Kinoa Salatası',
  'lunch',
  420, 22, 58, 10,
  20,
  'photos/meals/akdeniz_kinoa_salatasi.webp',
  $$MALZEMELER:
- 100g kinoa (kuru ölçü)
- 100g haşlanmış nohut
- 1/2 salatalık
- 10 cherry domates
- 30g az yağlı beyaz peynir
- 10 adet zeytin
- 1 avuç maydanoz
- 15 ml zeytinyağı
- 1 limonun suyu

HAZIRLANIŞI:
1. Kinoayı bolca suda 15 dakika haşlayıp soğumaya bırakın.
2. Tüm sebzeleri küçük küp doğrayın.
3. Kinoa, nohut, sebzeler ve peyniri karıştırın.
4. Zeytinyağı ile limon suyunu gezdirip maydanozla servis edin.$$,
  ARRAY['Sıkılaşma']
),
(
  'Izgara Hindi ve Pirinç Kasesi',
  'lunch',
  450, 42, 48, 8,
  25,
  'photos/meals/izgara_hindi_pirinc_kasesi.webp',
  $$MALZEMELER:
- 160g hindi göğsü fileto
- 70g esmer pirinç (kuru ölçü)
- 100g ızgara kabak
- 100g ızgara kırmızı biber
- 5 ml zeytinyağı
- 1 diş sarımsak
- Kekik, tuz, karabiber

HAZIRLANIŞI:
1. Pirinci bolca suyla 25 dakika pişirin.
2. Hindiyi sarımsak, kekik ve baharatlarla marine edip ızgarada her yüzü 3 dakika pişirin.
3. Kabak ve biberi ızgarada 4 dakika kızartın.
4. Kasede pirinç, sebzeler ve dilimlenmiş hindiyi birleştirip servis edin.$$,
  ARRAY['Sıkılaşma']
),
(
  'Sebzeli Mercimek Çorbası',
  'lunch',
  380, 22, 55, 6,
  30,
  'photos/meals/sebzeli_mercimek_corbasi.webp',
  $$MALZEMELER:
- 120g kırmızı mercimek
- 1 soğan
- 1 havuç
- 1 kabak
- 2 diş sarımsak
- 1.2 L sebze suyu
- 10 ml zeytinyağı
- Kimyon, tuz, karabiber

HAZIRLANIŞI:
1. Soğan ve sarımsağı zeytinyağında 2 dakika kavurun.
2. Küp doğranmış havuç ve kabağı ekleyip 3 dakika pişirin.
3. Mercimeği ve sebze suyunu ekleyip 25 dakika kısık ateşte kaynatın.
4. Blenderdan geçirin, kimyon ve tuzla tatlandırıp sıcak servis edin.$$,
  ARRAY['Sıkılaşma']
),
(
  'Fırında Levrek ve Kuskus',
  'dinner',
  440, 38, 42, 9,
  25,
  'photos/meals/firinda_levrek_kuskus.webp',
  $$MALZEMELER:
- 180g levrek fileto
- 80g kuskus (kuru ölçü)
- 1 limon (dilimlenmiş)
- 1 diş sarımsak
- 10 ml zeytinyağı
- Taze dereotu
- Tuz, karabiber

HAZIRLANIŞI:
1. Levreği pişirme kâğıdına yerleştirin.
2. Üzerine sarımsak, dereotu, limon dilimleri ve az zeytinyağı koyun.
3. Önceden ısıtılmış 180 derece fırında 15 dakika pişirin.
4. Kuskusu sıcak suyla 5 dakika dinlendirip çatalla kabartın.
5. Tabakta kuskus ve levreği birleştirip servis edin.$$,
  ARRAY['Sıkılaşma']
),
(
  'Süzme Yoğurtlu Meyve Parfe',
  'breakfast',
  320, 24, 42, 4,
  5,
  'photos/meals/suzme_yogurtlu_meyve_parfe.webp',
  $$MALZEMELER:
- 250g süzme yoğurt (yağsız)
- 60g şekersiz granola
- 80g taze çilek
- 30g ahududu
- 10g bal

HAZIRLANIŞI:
1. Uzun bir bardağın tabanına bir kat süzme yoğurt koyun.
2. Üzerine bir kat granola ekleyin.
3. Çilek ve ahududuyu serpiştirin.
4. Katmanları tekrarlayın, en üste bir şerit bal gezdirip servis edin.$$,
  ARRAY['Sıkılaşma']
),
-- ================================ Vegan (5) =================================
(
  'Nohutlu Kinoa Buddha Kasesi',
  'lunch',
  480, 22, 65, 14,
  20,
  'photos/meals/nohutlu_kinoa_buddha_kasesi.webp',
  $$MALZEMELER:
- 80g kinoa (kuru ölçü)
- 150g haşlanmış nohut
- 1 havuç (rende)
- 50g mor lahana (ince kıyılmış)
- 1/2 avokado
- 15 ml tahin
- 1 limonun suyu
- Tuz, karabiber

HAZIRLANIŞI:
1. Kinoayı haşlayıp soğutun.
2. Tahin, limon suyu ve 2 yemek kaşığı su ile sos hazırlayın.
3. Kaseye kinoa, nohut, havuç, lahana ve avokadoyu yerleştirin.
4. Tahin sosunu gezdirip servis edin.$$,
  ARRAY['Vegan']
),
(
  'Tofu Soteli Kahverengi Pirinç',
  'dinner',
  520, 28, 60, 16,
  25,
  'photos/meals/tofu_soteli_kahverengi_pirinc.webp',
  $$MALZEMELER:
- 180g katı tofu
- 70g esmer pirinç (kuru ölçü)
- 1 küçük brokoli
- 1 kırmızı biber
- 1 havuç
- 2 yemek kaşığı az tuzlu soya sosu
- 10 ml susam yağı
- 1 diş sarımsak
- Zencefil rende

HAZIRLANIŞI:
1. Esmer pirinci 25 dakika pişirin.
2. Tofuyu küp doğrayıp susam yağında her yüzü altın rengi alana kadar kızartın.
3. Sebzeleri ve sarımsağı tavaya ekleyip 4 dakika yüksek ateşte çevirin.
4. Soya sosu ve zencefili ekleyip 2 dakika daha pişirin.
5. Pirincin üzerine sosuyla dökerek servis edin.$$,
  ARRAY['Vegan']
),
(
  'Chia Tohumu Pudingi',
  'breakfast',
  340, 12, 42, 14,
  5,
  'photos/meals/chia_tohumu_pudingi.webp',
  $$MALZEMELER:
- 40g chia tohumu
- 300 ml şekersiz badem sütü
- 15g akçaağaç şurubu
- 1 tatlı kaşığı vanilya özütü
- 80g taze çilek
- 20g badem

HAZIRLANIŞI:
1. Chia tohumu, badem sütü, akçaağaç şurubu ve vanilyayı bir kavanozda karıştırın.
2. Buzdolabında en az 4 saat (tercihen gece boyu) bekletin.
3. Sabah çatalla hafifçe çalkalayıp kaseye aktarın.
4. Üzerine çilek ve bademi serpip servis edin.$$,
  ARRAY['Vegan']
),
(
  'Mercimek Köftesi Wrap',
  'lunch',
  450, 18, 62, 12,
  15,
  'photos/meals/mercimek_koftesi_wrap.webp',
  $$MALZEMELER:
- 2 tam buğday lavaş
- 150g ev yapımı mercimek köftesi
- 1 avuç marul yaprağı
- 1 domates
- 1/4 kırmızı soğan
- 1 yemek kaşığı humus
- Taze maydanoz, limon suyu

HAZIRLANIŞI:
1. Lavaşları tavada hafifçe ısıtın.
2. Her lavaşın yüzeyine bir kat humus sürün.
3. Marul, domates, soğan ve mercimek köftelerini yerleştirin.
4. Maydanoz ve limon suyuyla tamamlayıp sıkıca sarıp servis edin.$$,
  ARRAY['Vegan']
),
(
  'Fıstık Ezmeli Muzlu Vegan Smoothie',
  'snack',
  380, 15, 52, 14,
  5,
  'photos/meals/fistik_ezmeli_muzlu_vegan_smoothie.webp',
  $$MALZEMELER:
- 1 dondurulmuş muz
- 300 ml yulaf sütü
- 20g doğal fıstık ezmesi
- 15g şekersiz kakao tozu
- 10g bitkisel protein tozu
- 5g hurma şurubu
- 100g buz

HAZIRLANIŞI:
1. Tüm malzemeleri blendera alın.
2. Pürüzsüz bir içecek olana kadar 60 saniye yüksek hızda çekin.
3. Uzun bir bardağa aktarın.
4. Üzerine dilerseniz biraz kakao tozu serpip hemen için.$$,
  ARRAY['Vegan']
)
ON CONFLICT (title) DO NOTHING;

-- =============================================================================
-- Phase 69 · idempotent image_url upgrade for the 25 seed recipes
-- =============================================================================
-- The INSERT block above ships the new local-asset paths for fresh DB
-- seeds. Existing installs (where rows already exist with the old
-- Unsplash URLs) won't pick those up because of the ON CONFLICT
-- DO NOTHING clause. The UPDATE below covers that upgrade path —
-- safe to re-run because it's keyed on the unique title.
-- =============================================================================
UPDATE public.recipes SET image_url = 'photos/meals/izgara_tavuk_kinoa_kasesi.webp'         WHERE title = 'Izgara Tavuk ve Kinoa Kasesi';
UPDATE public.recipes SET image_url = 'photos/meals/firinda_somon_tatli_patates.webp'       WHERE title = 'Fırında Somon ve Tatlı Patates';
UPDATE public.recipes SET image_url = 'photos/meals/yumurta_aki_omleti_hindi_eti.webp'      WHERE title = 'Yumurta Akı Omleti ve Hindi Eti';
UPDATE public.recipes SET image_url = 'photos/meals/suzme_yogurtlu_protein_kasesi.webp'     WHERE title = 'Süzme Yoğurtlu Protein Kasesi';
UPDATE public.recipes SET image_url = 'photos/meals/izgara_bonfile_brokoli.webp'            WHERE title = 'Izgara Bonfile ve Brokoli';
UPDATE public.recipes SET image_url = 'photos/meals/izgara_sebzeli_ton_baligi_salatasi.webp' WHERE title = 'Izgara Sebzeli Ton Balığı Salatası';
UPDATE public.recipes SET image_url = 'photos/meals/sebzeli_ev_corbasi.webp'                WHERE title = 'Sebzeli Ev Çorbası';
UPDATE public.recipes SET image_url = 'photos/meals/tavuk_gogsu_marul_sarma.webp'           WHERE title = 'Tavuk Göğsü Marul Sarma';
UPDATE public.recipes SET image_url = 'photos/meals/izgara_karides_roka_salatasi.webp'      WHERE title = 'Izgara Karides ve Roka Salatası';
UPDATE public.recipes SET image_url = 'photos/meals/meyveli_suzme_yogurt.webp'              WHERE title = 'Meyveli Süzme Yoğurt';
UPDATE public.recipes SET image_url = 'photos/meals/tavuklu_yulafli_wrap.webp'              WHERE title = 'Tavuklu Yulaflı Wrap';
UPDATE public.recipes SET image_url = 'photos/meals/kiymali_yuksek_protein_makarna.webp'    WHERE title = 'Kıymalı Yüksek Protein Makarna';
UPDATE public.recipes SET image_url = 'photos/meals/fistik_ezmeli_muzlu_yulaf_ezmesi.webp'  WHERE title = 'Fıstık Ezmeli Muzlu Yulaf Ezmesi';
UPDATE public.recipes SET image_url = 'photos/meals/bonfileli_burrito.webp'                 WHERE title = 'Bonfileli Burrito';
UPDATE public.recipes SET image_url = 'photos/meals/protein_pankek_yigini.webp'             WHERE title = 'Protein Pankek Yığını';
UPDATE public.recipes SET image_url = 'photos/meals/akdeniz_kinoa_salatasi.webp'            WHERE title = 'Akdeniz Kinoa Salatası';
UPDATE public.recipes SET image_url = 'photos/meals/izgara_hindi_pirinc_kasesi.webp'        WHERE title = 'Izgara Hindi ve Pirinç Kasesi';
UPDATE public.recipes SET image_url = 'photos/meals/sebzeli_mercimek_corbasi.webp'          WHERE title = 'Sebzeli Mercimek Çorbası';
UPDATE public.recipes SET image_url = 'photos/meals/firinda_levrek_kuskus.webp'             WHERE title = 'Fırında Levrek ve Kuskus';
UPDATE public.recipes SET image_url = 'photos/meals/suzme_yogurtlu_meyve_parfe.webp'        WHERE title = 'Süzme Yoğurtlu Meyve Parfe';
UPDATE public.recipes SET image_url = 'photos/meals/nohutlu_kinoa_buddha_kasesi.webp'       WHERE title = 'Nohutlu Kinoa Buddha Kasesi';
UPDATE public.recipes SET image_url = 'photos/meals/tofu_soteli_kahverengi_pirinc.webp'     WHERE title = 'Tofu Soteli Kahverengi Pirinç';
UPDATE public.recipes SET image_url = 'photos/meals/chia_tohumu_pudingi.webp'               WHERE title = 'Chia Tohumu Pudingi';
UPDATE public.recipes SET image_url = 'photos/meals/mercimek_koftesi_wrap.webp'             WHERE title = 'Mercimek Köftesi Wrap';
UPDATE public.recipes SET image_url = 'photos/meals/fistik_ezmeli_muzlu_vegan_smoothie.webp' WHERE title = 'Fıstık Ezmeli Muzlu Vegan Smoothie';

-- =============================================================================
-- Sanity check — should return 25 rows after a fresh run.
-- =============================================================================
-- SELECT title, meal_type, calories, protein, tags FROM public.recipes
--   ORDER BY created_at DESC LIMIT 25;
