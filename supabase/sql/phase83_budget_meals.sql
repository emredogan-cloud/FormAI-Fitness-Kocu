-- =============================================================================
-- Phase 83 · Pratik & Ekonomik (Budget) meal pilot — 10 recipes.
-- =============================================================================
-- Pilot batch (NOT the full 100). Generated as a validation slice so the
-- end-to-end pipeline (schema fit → SQL apply → tag filter in
-- _MealCategoriesSection → /nutrition/category/budget route → recipe
-- list render) is verified before scaling up.
--
-- Schema decisions (signed off by PM in Phase 83):
--   • Re-uses the existing `recipes` columns. NO new column for
--     `is_budget` / `subcategory` / etc. The "Pratik & Ekonomik" bucket
--     is a tag, joining the existing five (Yüksek Protein, Düşük
--     Kalori, Hacim, Sıkılaşma, Vegan).
--   • `meal_type` uses the same five tokens already in the seed
--     (`breakfast` / `lunch` / `dinner` / `snack`). No `dessert` rows
--     in this pilot since none of the existing seed uses that token
--     either.
--   • Macro values are MY ESTIMATES, not dietitian-curated. They
--     follow the same magnitude as the Phase 24 seed but should be
--     reviewed before the larger 90-meal expansion lands.
--   • `image_url` paths point at `photos/meals/<snake_case>.webp`
--     files that DO NOT YET EXIST. The Phase 83
--     `docs/MEAL_IMAGE_PROMPTS.md` section appended in this commit
--     gives the PM the Midjourney prompts; until those generate, the
--     `_Thumb` fallback in `category_recipes_screen.dart` shows the
--     restaurant icon on a `surfaceContainerHighest` background. No
--     crash, just a placeholder.
--
-- Idempotency: `ON CONFLICT (title) DO NOTHING` — relies on the
-- `recipes_title_unique` constraint installed by `seed_recipes.sql`.
-- Re-running this file is safe.
-- =============================================================================

INSERT INTO public.recipes (
  title, meal_type, calories, protein, carbs, fat,
  prep_time_minutes, image_url, instructions, tags
) VALUES
-- ============================ Kahvaltı (2) ============================
(
  'Yumurtalı Sucuklu Tava',
  'breakfast',
  490, 30, 16, 32,
  10,
  'photos/meals/yumurtali_sucuklu_tava.webp',
  $$MALZEMELER:
- 3 yumurta
- 50g sucuk dilimleri
- 1 dilim tam buğday ekmeği
- 1 tutam tuz
- 1 tutam karabiber
- 5 ml sıvı yağ

HAZIRLANIŞI:
1. Sucuk dilimlerini orta ateşte tavada 1 dakika kavurun.
2. Yumurtaları kırıp üzerine ekleyin, tuz ve karabiberi serpin.
3. Karıştırmadan 3-4 dakika pişirin.
4. Tam buğday ekmeği ile servis edin.$$,
  ARRAY['Pratik & Ekonomik', 'Yüksek Protein']
),
(
  'Beyaz Peynirli Tam Buğday Tost',
  'breakfast',
  455, 22, 35, 21,
  7,
  'photos/meals/beyaz_peynirli_tam_bugday_tost.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 60g beyaz peynir
- 1 domates
- 5 zeytin
- 1 tatlı kaşığı zeytinyağı
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Ekmek dilimlerinin bir yüzünü zeytinyağıyla yağlayın.
2. Peyniri ezerek dilimlerin iç yüzeyine eşit dağıtın.
3. Çift taraflı tost makinesinde 3-4 dakika kızartın.
4. Domates dilimleri, zeytin ve nane ile servis edin.$$,
  ARRAY['Pratik & Ekonomik']
),
-- ============================ Öğle Yemeği (2) ============================
(
  'Yoğurtlu Bulgur Pilavı',
  'lunch',
  550, 24, 77, 15,
  15,
  'photos/meals/yogurtlu_bulgur_pilavi.webp',
  $$MALZEMELER:
- 80g pilavlık bulgur
- 1 küçük kuru soğan
- 200g süzme yoğurt
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı kuru nane
- 1 tutam tuz

HAZIRLANIŞI:
1. Soğanı küçük doğrayıp tereyağında 2 dakika kavurun.
2. Bulguru ekleyip 1 dakika daha kavurun, üzerine 200 ml sıcak su ve tuzu ekleyin.
3. Kapağı kapatıp kısık ateşte 12 dakika pişirin, ocaktan alıp 5 dakika demlendirin.
4. Pilavı tabağa alın, yanına yoğurdu koyup üzerine kuru nane serpin.$$,
  ARRAY['Pratik & Ekonomik']
),
(
  'Hızlı Mercimek Köftesi',
  'lunch',
  405, 24, 75, 7,
  15,
  'photos/meals/hizli_mercimek_koftesi.webp',
  $$MALZEMELER:
- 200g haşlanmış kırmızı mercimek (suyu süzülmüş)
- 30g ince bulgur
- 1 küçük kuru soğan
- 1 çay kaşığı zeytinyağı
- Bir tutam taze maydanoz
- 1/2 limon

HAZIRLANIŞI:
1. Soğanı çok küçük doğrayıp zeytinyağıyla 2 dakika sote edin.
2. Sıcak mercimeği ve bulguru bir kaba alın, sote soğanı ekleyip yoğurun.
3. Karışımı 5 dakika dinlendirip ele kadar küçük köfte şekli verin.
4. Maydanoz serpip limonla servis edin.$$,
  ARRAY['Pratik & Ekonomik', 'Vegan']
),
-- ============================ Akşam Yemeği (3) ============================
(
  'Tencerede Tavuk Sote',
  'dinner',
  515, 60, 24, 11,
  15,
  'photos/meals/tencerede_tavuk_sote.webp',
  $$MALZEMELER:
- 200g tavuk göğsü kuşbaşı
- 1 küçük kuru soğan
- 1 yeşil sivri biber
- 2 yemek kaşığı domates salçası
- 10 ml zeytinyağı
- Tuz, karabiber, pul biber

HAZIRLANIŞI:
1. Soğan ve biberi küçük doğrayıp zeytinyağında 2 dakika sote edin.
2. Tavuk küplerini ekleyip her tarafı kapanana kadar 4 dakika kavurun.
3. Salçayı, baharatları ve 100 ml sıcak suyu ekleyip karıştırın.
4. Kapağı kapatıp kısık ateşte 8 dakika pişirin.$$,
  ARRAY['Pratik & Ekonomik', 'Yüksek Protein']
),
(
  'Sucuklu Yumurtalı Bulgur',
  'dinner',
  620, 30, 55, 30,
  15,
  'photos/meals/sucuklu_yumurtali_bulgur.webp',
  $$MALZEMELER:
- 60g pilavlık bulgur
- 50g sucuk
- 2 yumurta
- 1 küçük kuru soğan
- 5 ml zeytinyağı
- Tuz, karabiber

HAZIRLANIŞI:
1. Soğanı doğrayıp zeytinyağında kavurun, sucuk dilimlerini ekleyip 1 dakika daha kavurun.
2. Bulguru ekleyip karıştırın, üzerine 180 ml sıcak su ve tuzu koyun.
3. Kapağı kapatıp 12 dakika pişirin, ocaktan alıp 5 dakika demlendirin.
4. Bir kenarda hızlıca pişirilen sahanda yumurtaları üzerine koyup karabiberle servis edin.$$,
  ARRAY['Pratik & Ekonomik']
),
(
  'Hızlı Yumurtalı Mercimek Çorbası',
  'dinner',
  420, 22, 45, 16,
  12,
  'photos/meals/hizli_yumurtali_mercimek_corbasi.webp',
  $$MALZEMELER:
- 1 küçük kavanoz haşlanmış kırmızı mercimek (suyu ile, ~400g)
- 1 yumurta
- 1/2 limon
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı pul biber
- 1 tutam tuz

HAZIRLANIŞI:
1. Mercimeği suyuyla birlikte tencereye alıp kaynatın.
2. Yumurtayı çırpıp tencereye ince bir akıntıyla, sürekli karıştırarak ekleyin.
3. Tuzu ekleyip 2 dakika daha kaynatın.
4. Tereyağını eritip pul biberle yakın, çorbanın üzerine gezdirip limonla servis edin.$$,
  ARRAY['Pratik & Ekonomik']
),
-- ============================ Ara Öğün (3) ============================
(
  'Yoğurtlu Salatalık Atıştırması',
  'snack',
  200, 14, 14, 8,
  5,
  'photos/meals/yogurtlu_salatalik_atistirmasi.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 salatalık
- 1 diş sarımsak
- 5 ml zeytinyağı
- 1 çay kaşığı kuru nane
- 1 tutam tuz

HAZIRLANIŞI:
1. Salatalığı rendeleyip suyunu hafifçe süzün.
2. Yoğurda ezilmiş sarımsağı, tuzu ve naneyi ekleyip karıştırın.
3. Salatalığı yoğurda katın.
4. Üzerine zeytinyağı gezdirip servis edin.$$,
  ARRAY['Pratik & Ekonomik', 'Düşük Kalori']
),
(
  'Haşlanmış Yumurta ve Domates',
  'snack',
  195, 13, 8, 13,
  12,
  'photos/meals/haslanmis_yumurta_ve_domates.webp',
  $$MALZEMELER:
- 2 yumurta
- 1 domates
- 5 zeytin
- 1 tutam karabiber
- 1 tutam tuz
- Birkaç dal taze maydanoz

HAZIRLANIŞI:
1. Yumurtaları soğuk suya koyup kaynamaya bırakın, kaynamadan sonra 8 dakika daha pişirin.
2. Soğuk suya alıp kabuklarını soyun, ortadan ikiye kesin.
3. Domatesi dilimleyip zeytinleri tabağa dizin.
4. Yumurtaları yerleştirip tuz, karabiber ve maydanoz serpin.$$,
  ARRAY['Pratik & Ekonomik', 'Düşük Kalori']
),
(
  'Tahin Pekmez Ekmek',
  'snack',
  390, 14, 47, 16,
  3,
  'photos/meals/tahin_pekmez_ekmek.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 2 yemek kaşığı tahin
- 1 yemek kaşığı pekmez
- 1 tutam tarçın

HAZIRLANIŞI:
1. Ekmek dilimlerini hafifçe ısıtın.
2. Bir kasede tahin ve pekmezi pürüzsüz olana kadar karıştırın.
3. Karışımı ekmek dilimlerine sürün.
4. Üzerine tarçın serpip hemen servis edin.$$,
  ARRAY['Pratik & Ekonomik']
)
ON CONFLICT (title) DO NOTHING;

-- =============================================================================
-- Sanity check — should return 10 rows tagged with 'Pratik & Ekonomik'
-- after a fresh run.
-- =============================================================================
-- SELECT title, meal_type, calories, protein, tags
--   FROM public.recipes
--   WHERE 'Pratik & Ekonomik' = ANY(tags)
--   ORDER BY meal_type, title;
