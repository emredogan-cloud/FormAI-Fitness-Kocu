-- =============================================================================
-- Phase 84 · Full Meal Expansion — 125 recipes (25 per meal_type)
-- =============================================================================
-- Distribution: 25 each across breakfast / lunch / dinner / snack / dessert.
-- (Path A scoped target was 150 (5 × 30); per the PM's "quality control"
-- guidance the actual ship is 125 to avoid stretched-uniqueness "Sade
-- X / Hızlı X" filler against the ~165 already-seeded recipes.
-- The 25-per-category cut preserves diversity AND deliberately fills tag
-- gaps the existing catalogue under-served:
--   • Yüksek Protein — fitness-app primary tag, expanded heavily
--   • Düşük Kalori   — cut sparse before; this batch adds ~25 entries
--   • Hacim          — bulk/gain meals were thin (~5); now ~15 added
--   • Sıkılaşma      — recomp/toning recipes added selectively
--   • Pratik & Ekonomik — budget overlay where natural, NOT blanket
--
-- Schema unchanged. This file populates the same column set Phase 83
-- batch 2 did: title, meal_type, calories, protein, carbs, fat,
-- prep_time_minutes, image_url, instructions (dollar-quoted),
-- ingredients (text[]), tags (text[]).
--
-- All 125 titles cross-checked against the ~165 existing seeded titles
-- (Phase 24 + 28 + 35 + seed_categories + Phase 83 pilot + Phase 83
-- batch 2) — no collisions. All max 6 ingredients, max 4 prep steps,
-- prep_time_minutes ≤ 20.
--
-- Caveats unchanged from Phase 83:
--   • Macro values are estimates, not dietitian-verified. The original
--     Phase 24 seed is "dietitian-curated"; consider a real nutrition
--     pass before treating these as authoritative.
--   • All 125 image_url paths point at webp files that do not yet exist.
--     Until the PM generates them via Midjourney (prompts in
--     docs/MEAL_IMAGE_PROMPTS.md under "Phase 84 — Full Expansion"),
--     the recipe list shows the existing _Thumb fallback restaurant
--     icon — no crash, just placeholder.
--
-- Idempotency: `ON CONFLICT (title) DO NOTHING` — relies on
-- `recipes_title_unique` constraint installed by seed_recipes.sql.
-- Re-running this file is safe.
-- =============================================================================

INSERT INTO public.recipes (
  title, meal_type, calories, protein, carbs, fat,
  prep_time_minutes, image_url, instructions, ingredients, tags
) VALUES
-- ============================ Kahvaltı (25) ============================
(
  'Çılbır',
  'breakfast',
  380, 22, 18, 24,
  12,
  'photos/meals/cilbir.webp',
  $$MALZEMELER:
- 2 yumurta
- 200g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 15g tereyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Yoğurda ezilmiş sarımsağı ve tuzu karıştırıp tabağa yayın.
2. Yumurtaları kaynar suya kırıp 3 dakika poşe edin, süzün.
3. Yumurtaları yoğurdun üzerine yerleştirin.
4. Tereyağını eritip pul biberle yakın, üzerine gezdirip servis edin.$$,
  ARRAY['2 yumurta', '200g süzme yoğurt', '1 diş sarımsak', '15g tereyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Sade Mıhlama',
  'breakfast',
  480, 18, 30, 30,
  15,
  'photos/meals/sade_mihlama.webp',
  $$MALZEMELER:
- 100g kaşar peyniri (rendelenmiş)
- 30g mısır unu
- 30g tereyağı
- 200 ml su
- Tuz

HAZIRLANIŞI:
1. Tereyağını tavada eritin, mısır ununu ekleyip 2 dakika kavurun.
2. Suyu yavaşça ekleyin, sürekli karıştırın.
3. Peyniri ekleyip eriyene kadar 3 dakika daha pişirin.
4. Sıcak servis edin.$$,
  ARRAY['100g kaşar peyniri', '30g mısır unu', '30g tereyağı', '200 ml su', 'Tuz'],
  ARRAY['Pratik & Ekonomik', 'Hacim']
),
(
  'Yumurtalı Tarhana Çorbası',
  'breakfast',
  280, 14, 30, 12,
  15,
  'photos/meals/yumurtali_tarhana_corbasi.webp',
  $$MALZEMELER:
- 30g tarhana
- 1 yumurta
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı pul biber
- 500 ml su
- Tuz

HAZIRLANIŞI:
1. Tarhanayı 100 ml soğuk suyla açın, kalan suyu kaynatın.
2. Açılan tarhanayı kaynar suya ekleyip 8 dakika kaynatın.
3. Yumurtayı çırpıp çorbaya ince akıtarak ekleyin, sürekli karıştırın.
4. Tereyağını pul biberle yakıp üzerine gezdirin.$$,
  ARRAY['30g tarhana', '1 yumurta', '1 yemek kaşığı tereyağı', '1 çay kaşığı pul biber', '500 ml su', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Hellim Peyniri Tava',
  'breakfast',
  380, 25, 20, 22,
  10,
  'photos/meals/hellim_peyniri_tava.webp',
  $$MALZEMELER:
- 100g hellim peyniri (dilimlenmiş)
- 5 ml zeytinyağı
- 1 dilim tam buğday ekmeği
- 5 zeytin
- Birkaç yaprak taze nane
- 1/2 limon

HAZIRLANIŞI:
1. Tavayı zeytinyağıyla ısıtın.
2. Hellim dilimlerini her yüzü altın olana kadar 2 dakika kızartın.
3. Tabağa alıp ekmek, zeytin ve naneyle eşliğinde yerleştirin.
4. Limonu sıkıp servis edin.$$,
  ARRAY['100g hellim peyniri', '5 ml zeytinyağı', '1 dilim tam buğday ekmeği', '5 zeytin', 'Taze nane', '1/2 limon'],
  ARRAY['Yüksek Protein']
),
(
  'Tarçınlı Yumurta Tostu',
  'breakfast',
  360, 14, 50, 12,
  12,
  'photos/meals/tarcinli_yumurta_tostu.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 1 yumurta
- 60 ml süt
- 1 çay kaşığı tarçın
- 10g tereyağı
- 1 yemek kaşığı bal

HAZIRLANIŞI:
1. Yumurta, süt ve tarçını çırpın.
2. Ekmek dilimlerini karışıma batırın.
3. Tereyağında her iki yüzü altın olana kadar 2 dakika kızartın.
4. Üzerine balı gezdirip servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '1 yumurta', '60 ml süt', '1 çay kaşığı tarçın', '10g tereyağı', '1 yemek kaşığı bal'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Kuru Kayısı Yulaflı Süt',
  'breakfast',
  320, 12, 55, 7,
  8,
  'photos/meals/kuru_kayisi_yulafli_sut.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 250 ml süt
- 4 kuru kayısı (doğranmış)
- 1 tatlı kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yulaf ve sütü tencerede orta ateşte kaynatın.
2. Kayısıları ekleyip 4 dakika daha pişirin.
3. Kaseye aktarın, balı gezdirin.
4. Tarçınla süsleyip sıcak servis edin.$$,
  ARRAY['50g yulaf ezmesi', '250 ml süt', '4 kuru kayısı', '1 tatlı kaşığı bal', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Karadeniz Kuymak',
  'breakfast',
  580, 20, 35, 38,
  15,
  'photos/meals/karadeniz_kuymak.webp',
  $$MALZEMELER:
- 100g mısır unu
- 80g taze peynir (ezilmiş)
- 30g tereyağı
- 250 ml su
- Tuz

HAZIRLANIŞI:
1. Tereyağını tavada eritin.
2. Mısır ununu ekleyip 3 dakika kavurun.
3. Suyu azar azar ekleyin, kıvam alana kadar karıştırın.
4. Peyniri ekleyip uzayan kıvama gelince servis edin.$$,
  ARRAY['100g mısır unu', '80g taze peynir', '30g tereyağı', '250 ml su', 'Tuz'],
  ARRAY['Hacim', 'Pratik & Ekonomik']
),
(
  'Beyaz Peynirli Krep',
  'breakfast',
  340, 18, 35, 14,
  12,
  'photos/meals/beyaz_peynirli_krep.webp',
  $$MALZEMELER:
- 1 yumurta
- 60g un
- 150 ml süt
- 60g beyaz peynir (ezilmiş)
- 5g tereyağı
- 1 yemek kaşığı kıyılmış maydanoz

HAZIRLANIŞI:
1. Yumurta, un ve sütü pürüzsüz olana kadar çırpın.
2. Yağlı tavada ince krep pişirin.
3. Krepin yarısına peynir ve maydanozu yayın.
4. İkiye katlayıp 1 dakika daha ısıtın ve servis edin.$$,
  ARRAY['1 yumurta', '60g un', '150 ml süt', '60g beyaz peynir', '5g tereyağı', '1 yemek kaşığı kıyılmış maydanoz'],
  ARRAY['Yüksek Protein', 'Pratik & Ekonomik']
),
(
  'Limonlu Bal Sıcak Süt',
  'breakfast',
  200, 8, 32, 5,
  5,
  'photos/meals/limonlu_bal_sicak_sut.webp',
  $$MALZEMELER:
- 250 ml süt
- 1 yemek kaşığı bal
- 1/2 limon (suyu)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Sütü orta ateşte ısıtın, kaynatmayın.
2. Bal ve limon suyunu ekleyin.
3. Karıştırıp bardağa aktarın.
4. Tarçınla süsleyip sıcak servis edin.$$,
  ARRAY['250 ml süt', '1 yemek kaşığı bal', '1/2 limon', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Süzme Yoğurtlu Çilek Kasesi',
  'breakfast',
  230, 13, 28, 7,
  4,
  'photos/meals/suzme_yogurtlu_cilek_kasesi.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 100g taze çilek (dilimlenmiş)
- 1 tatlı kaşığı bal
- 15g granola

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Çilekleri üzerine yerleştirin.
3. Granolayı serpin.
4. Balı gezdirip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '100g taze çilek', '1 tatlı kaşığı bal', '15g granola'],
  ARRAY['Düşük Kalori']
),
(
  'Tavuk Göğsülü Sade Sandviç',
  'breakfast',
  380, 35, 35, 10,
  8,
  'photos/meals/tavuk_gogsulu_sade_sandvic.webp',
  $$MALZEMELER:
- 100g pişmiş tavuk göğsü (dilimlenmiş)
- 2 dilim tam buğday ekmeği
- 1 yaprak marul
- 1 dilim domates
- 1 yemek kaşığı süzme yoğurt
- Tuz

HAZIRLANIŞI:
1. Ekmek dilimlerinin iç yüzeyine yoğurdu sürün.
2. Marul, domates ve tavuğu yerleştirin.
3. Tuz serpip kapatın.
4. İkiye keserek servis edin.$$,
  ARRAY['100g pişmiş tavuk göğsü', '2 dilim tam buğday ekmeği', '1 yaprak marul', '1 dilim domates', '1 yemek kaşığı süzme yoğurt', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Süzme Yoğurtlu Protein Smoothie',
  'breakfast',
  280, 22, 30, 8,
  5,
  'photos/meals/suzme_yogurtlu_protein_smoothie.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 muz
- 200 ml süt
- 15g vanilyalı protein tozu
- 1 yemek kaşığı bal

HAZIRLANIŞI:
1. Tüm malzemeleri blendera alın.
2. Pürüzsüz olana kadar 60 saniye yüksek hızda çekin.
3. Uzun bardağa aktarın.
4. Hemen için.$$,
  ARRAY['200g süzme yoğurt', '1 muz', '200 ml süt', '15g vanilyalı protein tozu', '1 yemek kaşığı bal'],
  ARRAY['Yüksek Protein']
),
(
  'Çırpılmış Yumurta ve Pastırma',
  'breakfast',
  380, 28, 4, 28,
  10,
  'photos/meals/cirpilmis_yumurta_ve_pastirma.webp',
  $$MALZEMELER:
- 3 yumurta
- 30g pastırma (dilimlenmiş)
- 5 ml tereyağı
- 1 yemek kaşığı süt
- Tuz ve karabiber

HAZIRLANIŞI:
1. Pastırmayı tavada 1 dakika kavurun.
2. Yumurtaları sütle çırpın, baharatları ekleyin.
3. Pastırmanın üzerine dökün, çırparak 3 dakika pişirin.
4. Tabağa alıp tereyağıyla servis edin.$$,
  ARRAY['3 yumurta', '30g pastırma', '5 ml tereyağı', '1 yemek kaşığı süt', 'Tuz ve karabiber'],
  ARRAY['Yüksek Protein']
),
(
  'Yumurta Akı ve Sebze Tabağı',
  'breakfast',
  180, 22, 14, 4,
  12,
  'photos/meals/yumurta_aki_ve_sebze_tabagi.webp',
  $$MALZEMELER:
- 4 yumurta akı
- 1 domates (dilimlenmiş)
- 1 salatalık (dilimlenmiş)
- 5 ml zeytinyağı
- Birkaç yaprak taze nane
- Tuz

HAZIRLANIŞI:
1. Yumurta aklarını yapışmaz tavada 4 dakika orta ateşte pişirin.
2. Tabağa alın, kenara domates ve salatalığı dizin.
3. Tuz ve naneyi serpin.
4. Üzerine zeytinyağı gezdirip servis edin.$$,
  ARRAY['4 yumurta akı', '1 domates', '1 salatalık', '5 ml zeytinyağı', 'Taze nane', 'Tuz'],
  ARRAY['Düşük Kalori', 'Yüksek Protein']
),
(
  'Tarçınlı Süzme Yoğurt',
  'breakfast',
  180, 14, 16, 6,
  3,
  'photos/meals/tarcinli_suzme_yogurt.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 tatlı kaşığı bal
- 1 çay kaşığı tarçın
- 10g ceviz (kırılmış)

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Bal ve cevizi üzerine ekleyin.
3. Tarçınla süsleyip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '1 tatlı kaşığı bal', '1 çay kaşığı tarçın', '10g ceviz'],
  ARRAY['Düşük Kalori']
),
(
  'Yulaflı Süt Çorbası',
  'breakfast',
  280, 12, 45, 6,
  10,
  'photos/meals/yulafli_sut_corbasi.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 300 ml süt
- 1 yemek kaşığı bal
- 1 tutam tarçın
- 5g tereyağı

HAZIRLANIŞI:
1. Süt ve yulafı tencerede kaynatın.
2. Tereyağını ekleyip 4 dakika daha pişirin.
3. Kaseye aktarın, balı gezdirin.
4. Tarçınla süsleyip sıcak servis edin.$$,
  ARRAY['50g yulaf ezmesi', '300 ml süt', '1 yemek kaşığı bal', '1 tutam tarçın', '5g tereyağı'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Üzümlü Yulaf',
  'breakfast',
  320, 11, 60, 6,
  8,
  'photos/meals/uzumlu_yulaf.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 250 ml süt
- 30g kuru üzüm
- 1 tatlı kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yulaf, süt ve kuru üzümü tencerede kaynatın.
2. 4 dakika kıvam alana kadar pişirin.
3. Kaseye aktarın.
4. Bal ve tarçınla süsleyip servis edin.$$,
  ARRAY['50g yulaf ezmesi', '250 ml süt', '30g kuru üzüm', '1 tatlı kaşığı bal', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Çıtır Yumurtalı Sandviç',
  'breakfast',
  320, 16, 32, 14,
  8,
  'photos/meals/citir_yumurtali_sandvic.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 2 yumurta
- 5 ml tereyağı
- 1 yaprak marul
- 1 dilim domates
- Tuz

HAZIRLANIŞI:
1. Yumurtaları tereyağında 3 dakika sahanda pişirin.
2. Ekmek dilimlerini hafifçe kızartın.
3. Bir dilim üzerine yumurta, marul ve domatesi yerleştirin.
4. Tuzlayıp diğer dilimle kapatıp servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '2 yumurta', '5 ml tereyağı', '1 yaprak marul', '1 dilim domates', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Süzme Yoğurtlu Yer Fıstığı',
  'breakfast',
  320, 18, 18, 18,
  3,
  'photos/meals/suzme_yogurtlu_yer_fistigi.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 30g kavrulmuş yer fıstığı
- 1 tatlı kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Yer fıstıklarını üzerine yerleştirin.
3. Balı gezdirin.
4. Tarçın serpip servis edin.$$,
  ARRAY['200g süzme yoğurt', '30g kavrulmuş yer fıstığı', '1 tatlı kaşığı bal', '1 tutam tarçın'],
  ARRAY['Yüksek Protein', 'Pratik & Ekonomik']
),
(
  'Sade Sucuklu Krep',
  'breakfast',
  420, 22, 30, 22,
  12,
  'photos/meals/sade_sucuklu_krep.webp',
  $$MALZEMELER:
- 1 yumurta
- 60g un
- 150 ml süt
- 50g sucuk (dilimlenmiş)
- 5g tereyağı
- Tuz

HAZIRLANIŞI:
1. Yumurta, un, süt ve tuzu çırpın.
2. Sucuk dilimlerini tavada 1 dakika kavurup çıkarın.
3. Yağlı tavada krep pişirin, üzerine sucukları yerleştirin.
4. Krepi rulo yapıp servis edin.$$,
  ARRAY['1 yumurta', '60g un', '150 ml süt', '50g sucuk', '5g tereyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Yulaflı Tarçınlı Smoothie',
  'breakfast',
  290, 14, 50, 6,
  5,
  'photos/meals/yulafli_tarcinli_smoothie.webp',
  $$MALZEMELER:
- 30g yulaf ezmesi
- 250 ml süt
- 1 muz
- 1 tatlı kaşığı bal
- 1 çay kaşığı tarçın

HAZIRLANIŞI:
1. Tüm malzemeleri blendera alın.
2. Pürüzsüz olana kadar 60 saniye çekin.
3. Bardağa aktarın.
4. Üzerine biraz tarçın serpip için.$$,
  ARRAY['30g yulaf ezmesi', '250 ml süt', '1 muz', '1 tatlı kaşığı bal', '1 çay kaşığı tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Süzme Peynirli Tost',
  'breakfast',
  380, 22, 35, 16,
  8,
  'photos/meals/suzme_peynirli_tost.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 80g süzme peynir
- 5g tereyağı
- 1 dilim domates
- Birkaç yaprak taze nane
- Tuz

HAZIRLANIŞI:
1. Süzme peyniri ekmek dilimlerinin iç yüzeyine yayın.
2. Domates ve naneyi yerleştirin, tuzlayın.
3. Tavayı tereyağıyla yağlayın.
4. Tostu kapalı tavada 3 dakika her iki yüzü altın olana kadar pişirin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '80g süzme peynir', '5g tereyağı', '1 dilim domates', 'Taze nane', 'Tuz'],
  ARRAY['Yüksek Protein', 'Pratik & Ekonomik']
),
(
  'Mantarlı Sade Omlet',
  'breakfast',
  280, 18, 6, 20,
  10,
  'photos/meals/mantarli_sade_omlet.webp',
  $$MALZEMELER:
- 3 yumurta
- 80g mantar (dilimlenmiş)
- 5 ml tereyağı
- 1 yemek kaşığı süt
- Tuz ve karabiber

HAZIRLANIŞI:
1. Mantarları tereyağında 3 dakika sote edin.
2. Yumurtaları sütle çırpın, baharatları ekleyin.
3. Karışımı mantarların üzerine dökün.
4. Yumurtalar tutana kadar 3 dakika pişirin.$$,
  ARRAY['3 yumurta', '80g mantar', '5 ml tereyağı', '1 yemek kaşığı süt', 'Tuz ve karabiber'],
  ARRAY['Yüksek Protein']
),
(
  'Hindi Salam ve Yumurta',
  'breakfast',
  320, 26, 8, 20,
  10,
  'photos/meals/hindi_salam_ve_yumurta.webp',
  $$MALZEMELER:
- 2 yumurta
- 60g hindi salam (dilimlenmiş)
- 5 ml zeytinyağı
- 1 dilim tam buğday ekmeği
- Birkaç dal taze maydanoz
- Tuz

HAZIRLANIŞI:
1. Salam dilimlerini tavada 1 dakika kavurun.
2. Yumurtaları üzerine kırın, tuzu serpin.
3. Yumurtalar tuttuğunda ocaktan alın.
4. Ekmek ve maydanozla servis edin.$$,
  ARRAY['2 yumurta', '60g hindi salam', '5 ml zeytinyağı', '1 dilim tam buğday ekmeği', 'Taze maydanoz', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Kıymalı Yumurta Tava',
  'breakfast',
  480, 32, 8, 36,
  14,
  'photos/meals/kiymali_yumurta_tava.webp',
  $$MALZEMELER:
- 100g dana kıyma
- 2 yumurta
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- Tuz

HAZIRLANIŞI:
1. Soğanı zeytinyağında 2 dakika kavurun.
2. Kıymayı ekleyip rengi dönene kadar 4 dakika pişirin, salçayı ekleyin.
3. Yumurtaları üzerine kırıp tuzlayın.
4. Yumurtalar tutana kadar 4 dakika daha pişirin.$$,
  ARRAY['100g dana kıyma', '2 yumurta', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 yemek kaşığı domates salçası', 'Tuz'],
  ARRAY['Yüksek Protein', 'Hacim']
),
-- ============================ Öğle Yemeği (25) ============================
(
  'Acılı Domates Çorbası',
  'lunch',
  220, 6, 28, 10,
  14,
  'photos/meals/acili_domates_corbasi.webp',
  $$MALZEMELER:
- 4 olgun domates (rendelenmiş)
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- 1 çay kaşığı pul biber
- 1 yemek kaşığı tereyağı
- Tuz

HAZIRLANIŞI:
1. Soğanı zeytinyağında 2 dakika kavurun.
2. Domatesleri ekleyip 6 dakika kaynatın.
3. Tuz, pul biber ve 200 ml suyu ekleyin, 4 dakika daha pişirin.
4. Tereyağını çorbanın üzerine ekleyip servis edin.$$,
  ARRAY['4 olgun domates', '1 küçük kuru soğan', '10 ml zeytinyağı', '1 çay kaşığı pul biber', '1 yemek kaşığı tereyağı', 'Tuz'],
  ARRAY['Düşük Kalori']
),
(
  'Yoğurtlu Mercimek Çorbası',
  'lunch',
  320, 20, 38, 8,
  14,
  'photos/meals/yogurtlu_mercimek_corbasi.webp',
  $$MALZEMELER:
- 100g haşlanmış kırmızı mercimek
- 200g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Mercimeği 400 ml suda 6 dakika kaynatın, blendırla pürüzsüzleştirin.
2. Yoğurda sarımsağı ve tuzu karıştırın.
3. Çorbayı kaselere paylaştırıp yoğurdu ortalayın.
4. Tereyağını pul biberle yakıp üzerine gezdirin.$$,
  ARRAY['100g haşlanmış kırmızı mercimek', '200g süzme yoğurt', '1 diş sarımsak', '1 yemek kaşığı tereyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Bahçıvan Salatası',
  'lunch',
  220, 8, 22, 12,
  8,
  'photos/meals/bahcivan_salatasi.webp',
  $$MALZEMELER:
- 2 avuç marul
- 1 domates (doğranmış)
- 1 salatalık (doğranmış)
- 1 küçük yeşil biber (doğranmış)
- 1 küçük havuç (rendelenmiş)
- 10 ml zeytinyağı

HAZIRLANIŞI:
1. Tüm sebzeleri kasede karıştırın.
2. Zeytinyağını ekleyin.
3. Tuz ile tatlandırıp hafifçe karıştırın.
4. Soğuk servis edin.$$,
  ARRAY['2 avuç marul', '1 domates', '1 salatalık', '1 küçük yeşil biber', '1 küçük havuç', '10 ml zeytinyağı'],
  ARRAY['Düşük Kalori']
),
(
  'Tavuklu Erişte Çorbası',
  'lunch',
  380, 28, 35, 12,
  15,
  'photos/meals/tavuklu_eriste_corbasi.webp',
  $$MALZEMELER:
- 80g erişte
- 100g pişmiş tavuk göğsü (didilmiş)
- 500 ml tavuk suyu
- 1 küçük havuç (küp)
- 5g tereyağı
- Tuz

HAZIRLANIŞI:
1. Tavuk suyunu tencereye alıp havucu ekleyin, 4 dakika kaynatın.
2. Erişteyi ekleyip 6 dakika daha pişirin.
3. Tavuk parçalarını ekleyip 2 dakika ısıtın.
4. Tereyağı ve tuzla tatlandırıp servis edin.$$,
  ARRAY['80g erişte', '100g pişmiş tavuk göğsü', '500 ml tavuk suyu', '1 küçük havuç', '5g tereyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Etli Tarhana Çorbası',
  'lunch',
  420, 28, 35, 18,
  15,
  'photos/meals/etli_tarhana_corbasi.webp',
  $$MALZEMELER:
- 30g tarhana
- 100g dana kıyma
- 1 yemek kaşığı domates salçası
- 1 yemek kaşığı tereyağı
- 500 ml su
- Tuz

HAZIRLANIŞI:
1. Kıymayı tereyağında 4 dakika kavurun, salçayı ekleyin.
2. Tarhanayı 100 ml soğuk suyla açın, kalan 400 ml suyu ekleyip kaynatın.
3. Açılan tarhanayı kıymalı tencereye ekleyin.
4. 6 dakika daha pişirip tuzlayın ve servis edin.$$,
  ARRAY['30g tarhana', '100g dana kıyma', '1 yemek kaşığı domates salçası', '1 yemek kaşığı tereyağı', '500 ml su', 'Tuz'],
  ARRAY['Yüksek Protein', 'Hacim']
),
(
  'Hindi Soslu Makarna',
  'lunch',
  520, 30, 65, 14,
  14,
  'photos/meals/hindi_soslu_makarna.webp',
  $$MALZEMELER:
- 100g makarna
- 100g hindi göğsü (kıyılmış)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Makarnayı tuzlu suda haşlayıp süzün.
2. Soğanı zeytinyağında 2 dakika kavurun.
3. Hindiyi ekleyip 4 dakika pişirin, salçayı ekleyip 100 ml suyla 2 dakika kaynatın.
4. Makarnayı sosa katıp servis edin.$$,
  ARRAY['100g makarna', '100g hindi göğsü', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Beyaz Pilav ve Etli Sote',
  'lunch',
  580, 35, 65, 16,
  15,
  'photos/meals/beyaz_pilav_ve_etli_sote.webp',
  $$MALZEMELER:
- 60g pirinç
- 120g dana kuşbaşı
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- Tuz

HAZIRLANIŞI:
1. Pirinci tuzlu suda 12 dakika pişirip süzün.
2. Eti zeytinyağında 4 dakika kavurun.
3. Soğan ve salçayı ekleyip 100 ml suyla 6 dakika daha pişirin.
4. Pilavı tabağa alıp eti üzerine yerleştirin.$$,
  ARRAY['60g pirinç', '120g dana kuşbaşı', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 yemek kaşığı domates salçası', 'Tuz'],
  ARRAY['Yüksek Protein', 'Hacim']
),
(
  'Yoğurtlu Pirinç Çorbası',
  'lunch',
  280, 12, 38, 9,
  15,
  'photos/meals/yogurtlu_pirinc_corbasi.webp',
  $$MALZEMELER:
- 60g pirinç
- 200g yoğurt
- 1 yumurta
- 500 ml su
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı kuru nane

HAZIRLANIŞI:
1. Pirinci suya ekleyip 12 dakika kaynatın.
2. Yumurtayı yoğurda yedirin, çorbaya ince akıtarak ekleyin.
3. Tereyağını eritip naneyle yakın.
4. Çorbanın üzerine gezdirip servis edin.$$,
  ARRAY['60g pirinç', '200g yoğurt', '1 yumurta', '500 ml su', '1 yemek kaşığı tereyağı', '1 çay kaşığı kuru nane'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Ezogelin Çorbası',
  'lunch',
  290, 16, 42, 6,
  15,
  'photos/meals/ezogelin_corbasi.webp',
  $$MALZEMELER:
- 60g kırmızı mercimek
- 30g ince bulgur
- 1 yemek kaşığı domates salçası
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı kuru nane

HAZIRLANIŞI:
1. Soğanı tereyağında 2 dakika kavurun, salçayı ekleyin.
2. Mercimek, bulgur ve 600 ml suyu ekleyip kaynatın.
3. 10 dakika kısık ateşte pişirin.
4. Naneyle baharatlandırıp servis edin.$$,
  ARRAY['60g kırmızı mercimek', '30g ince bulgur', '1 yemek kaşığı domates salçası', '1 küçük kuru soğan', '1 yemek kaşığı tereyağı', '1 çay kaşığı kuru nane'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Mercimekli Erişte',
  'lunch',
  380, 18, 60, 8,
  15,
  'photos/meals/mercimekli_eriste.webp',
  $$MALZEMELER:
- 80g erişte
- 100g haşlanmış kırmızı mercimek
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1 yemek kaşığı kuru nane
- Tuz

HAZIRLANIŞI:
1. Erişteyi tuzlu suda haşlayıp süzün.
2. Soğanı zeytinyağında 2 dakika kavurun.
3. Mercimeği ekleyip 2 dakika ısıtın, sonra erişteyi katın.
4. Naneyle baharatlandırıp servis edin.$$,
  ARRAY['80g erişte', '100g haşlanmış kırmızı mercimek', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 yemek kaşığı kuru nane', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuklu Karnabahar Sote',
  'lunch',
  320, 38, 14, 10,
  15,
  'photos/meals/tavuklu_karnabahar_sote.webp',
  $$MALZEMELER:
- 150g tavuk göğsü (kuşbaşı)
- 200g karnabahar (parçalanmış)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- Tuz

HAZIRLANIŞI:
1. Tavuğu zeytinyağında 4 dakika kavurun.
2. Soğan ve karnabaharı ekleyip 4 dakika sote edin.
3. Salçayı ve 100 ml suyu ekleyin.
4. Kapağı kapatıp 6 dakika pişirin, tuzlayıp servis edin.$$,
  ARRAY['150g tavuk göğsü', '200g karnabahar', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 yemek kaşığı domates salçası', 'Tuz'],
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Hindi Etli Yoğurtlu Köfte',
  'lunch',
  420, 30, 18, 22,
  15,
  'photos/meals/hindi_etli_yogurtlu_kofte.webp',
  $$MALZEMELER:
- 150g hindi kıyma
- 30g galeta unu
- 200g süzme yoğurt
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Hindi kıyma, galeta unu, soğan ve tuzu yoğurun.
2. Topaklar şekillendirip zeytinyağında 6 dakika pişirin.
3. Çevirip 4 dakika daha pişirin.
4. Yoğurdun üzerine yerleştirip servis edin.$$,
  ARRAY['150g hindi kıyma', '30g galeta unu', '200g süzme yoğurt', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Hindi Yoğurtlu Wrap',
  'lunch',
  420, 32, 35, 16,
  8,
  'photos/meals/hindi_yogurtlu_wrap.webp',
  $$MALZEMELER:
- 1 lavaş
- 100g pişmiş hindi göğsü (dilimlenmiş)
- 100g süzme yoğurt
- 2 yaprak marul
- 1 dilim domates
- Tuz

HAZIRLANIŞI:
1. Lavaşı düz bir zemine açın.
2. Yoğurdu yayıp tuzlayın.
3. Marul, domates ve hindiyi yerleştirin.
4. Sıkıca rulo yapıp ikiye keserek servis edin.$$,
  ARRAY['1 lavaş', '100g pişmiş hindi göğsü', '100g süzme yoğurt', '2 yaprak marul', '1 dilim domates', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Tavuklu Patates Salatası',
  'lunch',
  380, 25, 35, 14,
  15,
  'photos/meals/tavuklu_patates_salatasi.webp',
  $$MALZEMELER:
- 2 haşlanmış patates (küp)
- 100g pişmiş tavuk göğsü (kuşbaşı)
- 100g süzme yoğurt
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı kıyılmış maydanoz
- Tuz

HAZIRLANIŞI:
1. Patates, tavuk ve soğanı kasede toplayın.
2. Yoğurt ve tuzu ekleyip karıştırın.
3. Maydanozla süsleyin.
4. Soğuk servis edin.$$,
  ARRAY['2 haşlanmış patates', '100g pişmiş tavuk göğsü', '100g süzme yoğurt', '1 küçük kuru soğan', '1 yemek kaşığı kıyılmış maydanoz', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Roka Salatası ve Izgara Tavuk',
  'lunch',
  320, 35, 8, 16,
  15,
  'photos/meals/roka_salatasi_ve_izgara_tavuk.webp',
  $$MALZEMELER:
- 150g tavuk göğsü
- 2 avuç roka
- 1 domates (dilimlenmiş)
- 10 ml zeytinyağı
- 1/2 limon (suyu)
- Tuz

HAZIRLANIŞI:
1. Tavuğu tuz ve karabiberle baharatlayın.
2. Kızgın ızgara tavada her yüzünü 4 dakika pişirin.
3. Roka ve domatesi tabağa dizin.
4. Tavuğu dilimleyip üzerine koyun, zeytinyağı-limon ile servis edin.$$,
  ARRAY['150g tavuk göğsü', '2 avuç roka', '1 domates', '10 ml zeytinyağı', '1/2 limon', 'Tuz'],
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Tavada Karnabahar Köftesi',
  'lunch',
  280, 14, 35, 10,
  15,
  'photos/meals/tavada_karnabahar_koftesi.webp',
  $$MALZEMELER:
- 200g pişmiş karnabahar (ezilmiş)
- 50g un
- 1 yumurta
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Karnabahar, un, yumurta, soğan ve tuzu yoğurun.
2. Karışımdan ceviz büyüklüğünde köfteler şekillendirin.
3. Yağlı tavada her yüzünü 4 dakika pişirin.
4. Kağıt havluya alıp servis edin.$$,
  ARRAY['200g pişmiş karnabahar', '50g un', '1 yumurta', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Düşük Kalori']
),
(
  'Sade Hindi Etli Pilav',
  'lunch',
  520, 32, 60, 14,
  15,
  'photos/meals/sade_hindi_etli_pilav.webp',
  $$MALZEMELER:
- 80g pirinç
- 100g hindi göğsü (kıyılmış)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı tereyağı
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Hindiyi zeytinyağında 4 dakika kavurun, soğanı ekleyip 2 dakika daha pişirin.
2. Pirinci tereyağında 1 dakika kavurun.
3. 200 ml sıcak su ve tuzu ekleyin, kapağı kapatın.
4. Kısık ateşte 12 dakika pişirip dinlendirin.$$,
  ARRAY['80g pirinç', '100g hindi göğsü', '1 küçük kuru soğan', '1 yemek kaşığı tereyağı', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein', 'Hacim']
),
(
  'Hızlı Kuru Fasulye Yemeği',
  'lunch',
  380, 18, 50, 12,
  15,
  'photos/meals/hizli_kuru_fasulye_yemegi.webp',
  $$MALZEMELER:
- 200g haşlanmış kuru fasulye
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Soğanı zeytinyağında 2 dakika kavurun.
2. Salçayı ekleyip 1 dakika daha kavurun.
3. Fasulye ve 200 ml sıcak suyu ekleyin, 8 dakika kaynatın.
4. Pul biber ve tuzla tatlandırıp servis edin.$$,
  ARRAY['200g haşlanmış kuru fasulye', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Hacim', 'Pratik & Ekonomik']
),
(
  'Pratik Nohut Yemeği',
  'lunch',
  360, 16, 48, 10,
  15,
  'photos/meals/pratik_nohut_yemegi.webp',
  $$MALZEMELER:
- 200g haşlanmış nohut
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- 1 çay kaşığı kimyon
- Tuz

HAZIRLANIŞI:
1. Soğanı zeytinyağında 2 dakika kavurun.
2. Salçayı ekleyip 1 dakika kavurun.
3. Nohut ve 200 ml sıcak suyu ekleyin, 8 dakika kaynatın.
4. Kimyon ve tuzla tatlandırıp servis edin.$$,
  ARRAY['200g haşlanmış nohut', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', '1 çay kaşığı kimyon', 'Tuz'],
  ARRAY['Hacim', 'Pratik & Ekonomik']
),
(
  'Domatesli Pirinç Pilavı',
  'lunch',
  420, 8, 70, 12,
  15,
  'photos/meals/domatesli_pirinc_pilavi.webp',
  $$MALZEMELER:
- 80g pirinç
- 1 olgun domates (rendelenmiş)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı tereyağı
- 1 yemek kaşığı domates salçası
- Tuz

HAZIRLANIŞI:
1. Soğanı tereyağında 2 dakika kavurun.
2. Salça ve domatesi ekleyip 2 dakika daha pişirin.
3. Pirinci ekleyip 1 dakika kavurun.
4. 200 ml sıcak su ve tuzu ekleyin, kapağı kapatıp 12 dakika pişirin.$$,
  ARRAY['80g pirinç', '1 olgun domates', '1 küçük kuru soğan', '1 yemek kaşığı tereyağı', '1 yemek kaşığı domates salçası', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuklu Sebze Çorbası',
  'lunch',
  280, 25, 22, 8,
  15,
  'photos/meals/tavuklu_sebze_corbasi.webp',
  $$MALZEMELER:
- 100g pişmiş tavuk göğsü (didilmiş)
- 1 patates (küp)
- 1 havuç (küp)
- 1 küçük kuru soğan (doğranmış)
- 500 ml tavuk suyu
- Tuz

HAZIRLANIŞI:
1. Soğan, havuç ve patatesi tavuk suyuna ekleyip 8 dakika kaynatın.
2. Tavuğu ekleyip 4 dakika daha pişirin.
3. Tuzla tatlandırın.
4. Kaselere paylaştırıp servis edin.$$,
  ARRAY['100g pişmiş tavuk göğsü', '1 patates', '1 havuç', '1 küçük kuru soğan', '500 ml tavuk suyu', 'Tuz'],
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Soğanlı Etli Sote',
  'lunch',
  480, 35, 14, 30,
  15,
  'photos/meals/soganli_etli_sote.webp',
  $$MALZEMELER:
- 150g dana kuşbaşı
- 2 büyük kuru soğan (ince dilim)
- 1 yemek kaşığı domates salçası
- 10 ml zeytinyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Eti zeytinyağında 4 dakika kavurun.
2. Soğanları ekleyip karamelize olana kadar 5 dakika daha pişirin.
3. Salça, pul biber ve 50 ml suyu ekleyin.
4. Kapağı kapatıp 4 dakika pişirin, tuzlayıp servis edin.$$,
  ARRAY['150g dana kuşbaşı', '2 büyük kuru soğan', '1 yemek kaşığı domates salçası', '10 ml zeytinyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Yüksek Protein', 'Hacim']
),
(
  'Etli Sebzeli Çorba',
  'lunch',
  380, 25, 35, 14,
  15,
  'photos/meals/etli_sebzeli_corba.webp',
  $$MALZEMELER:
- 100g dana kuşbaşı
- 1 patates (küp)
- 1 havuç (küp)
- 1 küçük kuru soğan (doğranmış)
- 500 ml et suyu
- Tuz

HAZIRLANIŞI:
1. Eti tencereye alıp et suyuyla 8 dakika kaynatın.
2. Soğan, havuç ve patatesi ekleyip 5 dakika daha pişirin.
3. Tuzla tatlandırın.
4. Servis edin.$$,
  ARRAY['100g dana kuşbaşı', '1 patates', '1 havuç', '1 küçük kuru soğan', '500 ml et suyu', 'Tuz'],
  ARRAY['Hacim', 'Yüksek Protein']
),
(
  'Tavuklu Mantar Sote',
  'lunch',
  360, 38, 12, 16,
  14,
  'photos/meals/tavuklu_mantar_sote.webp',
  $$MALZEMELER:
- 150g tavuk göğsü (kuşbaşı)
- 150g mantar (dilimlenmiş)
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- Tuz

HAZIRLANIŞI:
1. Tavuğu zeytinyağında 4 dakika kavurun.
2. Soğan ve mantarı ekleyip 4 dakika sote edin.
3. Salça ve 50 ml suyu ekleyin.
4. Kapağı kapatıp 4 dakika pişirin, tuzlayıp servis edin.$$,
  ARRAY['150g tavuk göğsü', '150g mantar', '1 küçük kuru soğan', '10 ml zeytinyağı', '1 yemek kaşığı domates salçası', 'Tuz'],
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
(
  'Bonfileli Salata',
  'lunch',
  380, 38, 12, 18,
  15,
  'photos/meals/bonfileli_salata.webp',
  $$MALZEMELER:
- 150g pişmiş bonfile (dilimlenmiş)
- 2 avuç roka
- 1 domates (dilimlenmiş)
- 1 salatalık (küp)
- 10 ml zeytinyağı
- 1/2 limon (suyu)

HAZIRLANIŞI:
1. Roka, domates ve salatalığı kasede karıştırın.
2. Bonfileyi üzerine yerleştirin.
3. Zeytinyağı ve limon suyunu ekleyin.
4. Tuzla tatlandırıp servis edin.$$,
  ARRAY['150g pişmiş bonfile', '2 avuç roka', '1 domates', '1 salatalık', '10 ml zeytinyağı', '1/2 limon'],
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
-- ============================ Akşam Yemeği (25) ============================
(
  'Tavuk Şinitzel',
  'dinner',
  480, 38, 35, 18,
  15,
  'photos/meals/tavuk_sinitzel.webp',
  $$MALZEMELER:
- 150g tavuk fileto
- 1 yumurta
- 50g galeta unu
- 5 ml zeytinyağı
- Tuz
- Karabiber

HAZIRLANIŞI:
1. Tavuk filetoyu inceltip tuz ve karabiberle baharatlayın.
2. Yumurtaya, sonra galeta ununa bulayın.
3. Yağlı tavada her yüzünü 4 dakika kızartın.
4. Kağıt havluya alıp servis edin.$$,
  ARRAY['150g tavuk fileto', '1 yumurta', '50g galeta unu', '5 ml zeytinyağı', 'Tuz', 'Karabiber'],
  ARRAY['Yüksek Protein']
),
(
  'Levrek Tava',
  'dinner',
  380, 35, 6, 20,
  14,
  'photos/meals/levrek_tava.webp',
  $$MALZEMELER:
- 200g levrek fileto
- 30g un
- 10 ml zeytinyağı
- 1/2 limon
- Birkaç dal taze maydanoz
- Tuz

HAZIRLANIŞI:
1. Levreği tuzla baharatlayıp una bulayın.
2. Zeytinyağını tavada ısıtın.
3. Levreği her yüzü altın olana kadar 4 dakika kızartın.
4. Limon ve maydanozla servis edin.$$,
  ARRAY['200g levrek fileto', '30g un', '10 ml zeytinyağı', '1/2 limon', 'Taze maydanoz', 'Tuz'],
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
(
  'Hamsi Tava',
  'dinner',
  480, 28, 25, 28,
  14,
  'photos/meals/hamsi_tava.webp',
  $$MALZEMELER:
- 200g hamsi (temizlenmiş)
- 50g mısır unu
- 10 ml ayçiçek yağı
- 1/2 limon
- Tuz
- Karabiber

HAZIRLANIŞI:
1. Hamsileri tuz ve karabiberle baharatlayın.
2. Mısır ununa bulayın.
3. Kızgın yağda her iki yüzü altın olana kadar 4 dakika kızartın.
4. Limonla servis edin.$$,
  ARRAY['200g hamsi', '50g mısır unu', '10 ml ayçiçek yağı', '1/2 limon', 'Tuz', 'Karabiber'],
  ARRAY['Pratik & Ekonomik', 'Hacim']
),
(
  'Sade Bonfile Sote',
  'dinner',
  380, 40, 6, 22,
  14,
  'photos/meals/sade_bonfile_sote.webp',
  $$MALZEMELER:
- 150g dana bonfile (kuşbaşı)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- Tuz
- Karabiber

HAZIRLANIŞI:
1. Bonfileyi zeytinyağında 4 dakika kavurun.
2. Soğanı ekleyip 2 dakika daha pişirin.
3. Salçayı ekleyip 1 dakika kavurun.
4. Tuz ve karabiberle tatlandırıp servis edin.$$,
  ARRAY['150g dana bonfile', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 yemek kaşığı domates salçası', 'Tuz', 'Karabiber'],
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
(
  'Domates Salçalı Bonfile Yemeği',
  'dinner',
  480, 38, 18, 28,
  15,
  'photos/meals/domates_salcali_bonfile_yemegi.webp',
  $$MALZEMELER:
- 150g dana bonfile (kuşbaşı)
- 2 olgun domates (rendelenmiş)
- 1 yemek kaşığı domates salçası
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Bonfileyi zeytinyağında 4 dakika kavurun.
2. Soğanı ekleyip 2 dakika daha pişirin.
3. Salça ve domatesi ekleyip 5 dakika kaynatın.
4. Tuzla tatlandırıp servis edin.$$,
  ARRAY['150g dana bonfile', '2 olgun domates', '1 yemek kaşığı domates salçası', '1 küçük kuru soğan', '10 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Pratik Karnıyarık',
  'dinner',
  520, 25, 30, 32,
  15,
  'photos/meals/pratik_karniyarik.webp',
  $$MALZEMELER:
- 2 patlıcan (közlenmiş, ortadan kesilmiş)
- 100g dana kıyma
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Birkaç dal taze maydanoz

HAZIRLANIŞI:
1. Kıymayı zeytinyağında 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 3 dakika daha pişirin.
3. Patlıcanları açıp harcı doldurun.
4. 200 ml sıcak suda kapağı kapalı 5 dakika pişirip maydanozla servis edin.$$,
  ARRAY['2 patlıcan', '100g dana kıyma', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Taze maydanoz'],
  ARRAY['Yüksek Protein', 'Hacim']
),
(
  'Mücver Tava',
  'dinner',
  320, 12, 30, 18,
  14,
  'photos/meals/mucver_tava.webp',
  $$MALZEMELER:
- 1 büyük kabak (rendelenmiş)
- 50g un
- 2 yumurta
- 30g beyaz peynir (ezilmiş)
- 5 ml zeytinyağı
- Birkaç dal taze dereotu

HAZIRLANIŞI:
1. Rendelenmiş kabağın suyunu sıkın.
2. Un, yumurta, peynir ve dereotuyla yoğurun.
3. Yağlı tavaya kaşıkla harç dökerek mücverler şekillendirin.
4. Her yüzünü 3 dakika pişirip servis edin.$$,
  ARRAY['1 büyük kabak', '50g un', '2 yumurta', '30g beyaz peynir', '5 ml zeytinyağı', 'Taze dereotu'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuklu Karnıyarık',
  'dinner',
  480, 32, 28, 24,
  15,
  'photos/meals/tavuklu_karniyarik.webp',
  $$MALZEMELER:
- 2 patlıcan (közlenmiş, ortadan kesilmiş)
- 150g tavuk kıyma
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Tavuk kıymayı zeytinyağında 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 3 dakika daha pişirin.
3. Patlıcanları açıp harcı doldurun.
4. 200 ml sıcak suda kapağı kapalı 5 dakika pişirin.$$,
  ARRAY['2 patlıcan', '150g tavuk kıyma', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Etli Kuru Fasulye',
  'dinner',
  480, 28, 50, 16,
  15,
  'photos/meals/etli_kuru_fasulye.webp',
  $$MALZEMELER:
- 200g haşlanmış kuru fasulye
- 100g dana kuşbaşı
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Eti zeytinyağında 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 2 dakika daha pişirin.
3. Fasulye ve 200 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 8 dakika kaynatın, tuzlayıp servis edin.$$,
  ARRAY['200g haşlanmış kuru fasulye', '100g dana kuşbaşı', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Hacim', 'Yüksek Protein']
),
(
  'Etli Nohut',
  'dinner',
  460, 26, 48, 16,
  15,
  'photos/meals/etli_nohut.webp',
  $$MALZEMELER:
- 200g haşlanmış nohut
- 100g dana kuşbaşı
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Eti zeytinyağında 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 2 dakika daha pişirin.
3. Nohut ve 200 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 8 dakika kaynatın ve tuzlayıp servis edin.$$,
  ARRAY['200g haşlanmış nohut', '100g dana kuşbaşı', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Hacim', 'Yüksek Protein']
),
(
  'Tavuk Şiş',
  'dinner',
  380, 42, 6, 18,
  15,
  'photos/meals/tavuk_sis.webp',
  $$MALZEMELER:
- 200g tavuk göğsü (kuşbaşı)
- 1 yeşil biber (parçalanmış)
- 1 küçük kuru soğan (parçalanmış)
- 5 ml zeytinyağı
- 1 diş sarımsak (ezilmiş)
- Tuz

HAZIRLANIŞI:
1. Tavuğu zeytinyağı, sarımsak ve tuzla 5 dakika marine edin.
2. Şişlere tavuk, biber ve soğanı geçirin.
3. Kızgın ızgara tavada her yüzünü 3 dakika pişirin.
4. Sıcak servis edin.$$,
  ARRAY['200g tavuk göğsü', '1 yeşil biber', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 diş sarımsak', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Etli Pırasa Yemeği',
  'dinner',
  380, 22, 22, 22,
  15,
  'photos/meals/etli_pirasa_yemegi.webp',
  $$MALZEMELER:
- 1 büyük pırasa (dilimlenmiş)
- 100g dana kıyma
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı tereyağı
- 1 yemek kaşığı domates salçası
- Tuz

HAZIRLANIŞI:
1. Kıymayı tereyağında 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 2 dakika daha pişirin.
3. Pırasa ve 150 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 8 dakika kaynatın, tuzlayıp servis edin.$$,
  ARRAY['1 büyük pırasa', '100g dana kıyma', '1 küçük kuru soğan', '1 yemek kaşığı tereyağı', '1 yemek kaşığı domates salçası', 'Tuz'],
  ARRAY['Hacim']
),
(
  'Etli Kabak Yemeği',
  'dinner',
  320, 22, 18, 16,
  15,
  'photos/meals/etli_kabak_yemegi.webp',
  $$MALZEMELER:
- 2 kabak (küp)
- 100g dana kıyma
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Birkaç dal taze dereotu

HAZIRLANIŞI:
1. Kıymayı zeytinyağında 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 2 dakika daha pişirin.
3. Kabak ve 150 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 6 dakika pişirin, dereotuyla servis edin.$$,
  ARRAY['2 kabak', '100g dana kıyma', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Taze dereotu'],
  ARRAY['Hacim', 'Düşük Kalori']
),
(
  'Tavuk Göğsü Tava',
  'dinner',
  320, 42, 4, 14,
  12,
  'photos/meals/tavuk_gogsu_tava.webp',
  $$MALZEMELER:
- 200g tavuk göğsü
- 5 ml zeytinyağı
- 1 diş sarımsak (ezilmiş)
- 1/2 limon (suyu)
- Tuz
- Karabiber

HAZIRLANIŞI:
1. Tavuk göğsünü inceltip baharat, sarımsak ve limonla 5 dakika marine edin.
2. Kızgın tavada zeytinyağıyla her yüzünü 3 dakika pişirin.
3. Kapağı kapatıp 2 dakika dinlendirin.
4. Sıcak servis edin.$$,
  ARRAY['200g tavuk göğsü', '5 ml zeytinyağı', '1 diş sarımsak', '1/2 limon', 'Tuz', 'Karabiber'],
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
(
  'Sade Izgara Köfte',
  'dinner',
  380, 28, 4, 28,
  15,
  'photos/meals/sade_izgara_kofte.webp',
  $$MALZEMELER:
- 200g dana kıyma
- 1 küçük kuru soğan (rendelenmiş)
- 1 çay kaşığı kimyon
- 5 ml zeytinyağı
- Tuz
- Karabiber

HAZIRLANIŞI:
1. Kıyma, soğan ve baharatları yoğurun.
2. Köfteler şekillendirin.
3. Kızgın ızgara tavayı zeytinyağıyla yağlayın.
4. Köfteleri her yüzünü 4 dakika pişirip servis edin.$$,
  ARRAY['200g dana kıyma', '1 küçük kuru soğan', '1 çay kaşığı kimyon', '5 ml zeytinyağı', 'Tuz', 'Karabiber'],
  ARRAY['Yüksek Protein']
),
(
  'Pratik İmam Bayıldı',
  'dinner',
  280, 6, 22, 18,
  15,
  'photos/meals/pratik_imam_bayildi.webp',
  $$MALZEMELER:
- 2 patlıcan (uzun dilim)
- 1 büyük kuru soğan (yarım ay dilim)
- 2 olgun domates (rendelenmiş)
- 10 ml zeytinyağı
- 2 diş sarımsak (ezilmiş)
- Birkaç dal taze maydanoz

HAZIRLANIŞI:
1. Patlıcanları zeytinyağında 4 dakika kızartın, çıkarın.
2. Aynı tavada soğan ve sarımsağı 3 dakika sote edin, domatesi ekleyin.
3. Patlıcanları geri katıp 4 dakika daha pişirin.
4. Maydanozla süsleyip servis edin.$$,
  ARRAY['2 patlıcan', '1 büyük kuru soğan', '2 olgun domates', '10 ml zeytinyağı', '2 diş sarımsak', 'Taze maydanoz'],
  ARRAY['Pratik & Ekonomik', 'Düşük Kalori']
),
(
  'Taze Fasulye Etli',
  'dinner',
  380, 22, 25, 22,
  15,
  'photos/meals/taze_fasulye_etli.webp',
  $$MALZEMELER:
- 200g taze fasulye
- 100g dana kuşbaşı
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Eti zeytinyağında 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 2 dakika daha pişirin.
3. Fasulye ve 150 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 8 dakika pişirip tuzlayıp servis edin.$$,
  ARRAY['200g taze fasulye', '100g dana kuşbaşı', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Hacim', 'Yüksek Protein']
),
(
  'Türlü Sebze Etli',
  'dinner',
  420, 22, 30, 22,
  15,
  'photos/meals/turlu_sebze_etli.webp',
  $$MALZEMELER:
- 1 patlıcan (küp)
- 1 kabak (küp)
- 1 patates (küp)
- 100g dana kıyma
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı

HAZIRLANIŞI:
1. Kıymayı zeytinyağında 4 dakika kavurun.
2. Patatesi ekleyip 3 dakika daha pişirin, salçayı ekleyin.
3. Patlıcan ve kabak ile 150 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 6 dakika pişirin, tuzlayıp servis edin.$$,
  ARRAY['1 patlıcan', '1 kabak', '1 patates', '100g dana kıyma', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı'],
  ARRAY['Hacim']
),
(
  'Kıymalı Patates Yemeği',
  'dinner',
  480, 24, 35, 26,
  15,
  'photos/meals/kiymali_patates_yemegi.webp',
  $$MALZEMELER:
- 100g dana kıyma
- 2 patates (küp)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Kıymayı zeytinyağında 4 dakika kavurun.
2. Soğan ve patatesi ekleyip 4 dakika daha pişirin.
3. Salça ve 150 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 6 dakika pişirip tuzlayıp servis edin.$$,
  ARRAY['100g dana kıyma', '2 patates', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Hacim', 'Yüksek Protein']
),
(
  'Mantarlı Tavuk Sote',
  'dinner',
  360, 38, 14, 16,
  14,
  'photos/meals/mantarli_tavuk_sote.webp',
  $$MALZEMELER:
- 150g tavuk göğsü (kuşbaşı)
- 200g mantar (dilimlenmiş)
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- Tuz

HAZIRLANIŞI:
1. Tavuğu zeytinyağında 4 dakika kavurun.
2. Soğan ve mantarı ekleyip 4 dakika daha pişirin.
3. Salça ve 50 ml suyu ekleyin.
4. Kapağı kapatıp 4 dakika pişirin, tuzlayıp servis edin.$$,
  ARRAY['150g tavuk göğsü', '200g mantar', '1 küçük kuru soğan', '10 ml zeytinyağı', '1 yemek kaşığı domates salçası', 'Tuz'],
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
(
  'Bezelye Etli',
  'dinner',
  380, 24, 30, 16,
  15,
  'photos/meals/bezelye_etli.webp',
  $$MALZEMELER:
- 200g bezelye
- 100g dana kuşbaşı
- 1 havuç (küp)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Eti zeytinyağında 4 dakika kavurun.
2. Soğan ve havucu ekleyip 3 dakika daha pişirin.
3. Bezelye ve 150 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 6 dakika pişirip tuzlayıp servis edin.$$,
  ARRAY['200g bezelye', '100g dana kuşbaşı', '1 havuç', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Hacim']
),
(
  'Etli Nohutlu Pilav',
  'dinner',
  580, 30, 75, 16,
  15,
  'photos/meals/etli_nohutlu_pilav.webp',
  $$MALZEMELER:
- 80g pirinç
- 100g haşlanmış nohut
- 100g dana kuşbaşı
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı tereyağı
- Tuz

HAZIRLANIŞI:
1. Eti tereyağında 4 dakika kavurun.
2. Soğanı ekleyip 2 dakika daha pişirin.
3. Pirinç ve nohutu ekleyip 1 dakika kavurun.
4. 250 ml sıcak su ve tuzu ekleyip kapakla 12 dakika pişirin.$$,
  ARRAY['80g pirinç', '100g haşlanmış nohut', '100g dana kuşbaşı', '1 küçük kuru soğan', '1 yemek kaşığı tereyağı', 'Tuz'],
  ARRAY['Hacim', 'Yüksek Protein']
),
(
  'Soğanlı Köfte',
  'dinner',
  420, 28, 14, 26,
  15,
  'photos/meals/soganli_kofte.webp',
  $$MALZEMELER:
- 200g hazır köfte harcı
- 2 büyük kuru soğan (yarım ay dilim)
- 5 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- 1 çay kaşığı kimyon
- Tuz

HAZIRLANIŞI:
1. Köftelerden topaklar yapıp tavada 4 dakika kavurun.
2. Soğanları ekleyip karamelize olana kadar 4 dakika daha pişirin.
3. Salça ve 100 ml suyu ekleyip 4 dakika kaynatın.
4. Kimyon ve tuzla baharatlandırıp servis edin.$$,
  ARRAY['200g hazır köfte harcı', '2 büyük kuru soğan', '5 ml zeytinyağı', '1 yemek kaşığı domates salçası', '1 çay kaşığı kimyon', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Pırasalı Pilav',
  'dinner',
  420, 10, 70, 12,
  15,
  'photos/meals/pirasali_pilav.webp',
  $$MALZEMELER:
- 80g pirinç
- 1 büyük pırasa (dilimlenmiş)
- 1 yemek kaşığı tereyağı
- 5 ml zeytinyağı
- Tuz
- Karabiber

HAZIRLANIŞI:
1. Pırasayı tereyağında 4 dakika sote edin.
2. Pirinci zeytinyağıyla ekleyip 1 dakika kavurun.
3. 200 ml sıcak su ve tuzu ekleyin, kapağı kapatın.
4. Kısık ateşte 12 dakika pişirin, karabiberle servis edin.$$,
  ARRAY['80g pirinç', '1 büyük pırasa', '1 yemek kaşığı tereyağı', '5 ml zeytinyağı', 'Tuz', 'Karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pırasa Köftesi',
  'dinner',
  280, 12, 30, 12,
  15,
  'photos/meals/pirasa_koftesi.webp',
  $$MALZEMELER:
- 1 büyük pırasa (rendelenmiş)
- 50g un
- 1 yumurta
- 30g beyaz peynir (ezilmiş)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Pırasanın suyunu sıkın.
2. Un, yumurta, peynir ve tuzla yoğurun.
3. Yağlı tavaya kaşıkla harç dökerek köfteler şekillendirin.
4. Her yüzünü 3 dakika pişirip servis edin.$$,
  ARRAY['1 büyük pırasa', '50g un', '1 yumurta', '30g beyaz peynir', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik', 'Düşük Kalori']
),
-- ============================ Atıştırmalıklar (25) ============================
(
  'Soğuk Tavuk Göğsü Dilimleri',
  'snack',
  220, 30, 4, 8,
  5,
  'photos/meals/soguk_tavuk_gogsu_dilimleri.webp',
  $$MALZEMELER:
- 120g pişmiş tavuk göğsü (dilimlenmiş)
- 1 yeşil biber (dilim)
- 1/2 limon (suyu)
- 5 ml zeytinyağı
- Birkaç dal taze maydanoz
- Tuz

HAZIRLANIŞI:
1. Tavuk dilimlerini tabağa dizin.
2. Biberleri yan tarafa yerleştirin.
3. Üzerine zeytinyağı ve limon suyunu gezdirin.
4. Tuz ve maydanozla servis edin.$$,
  ARRAY['120g pişmiş tavuk göğsü', '1 yeşil biber', '1/2 limon', '5 ml zeytinyağı', 'Taze maydanoz', 'Tuz'],
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Yumurta-Avokado Tabağı',
  'snack',
  320, 18, 12, 22,
  8,
  'photos/meals/yumurta_avokado_tabagi.webp',
  $$MALZEMELER:
- 2 haşlanmış yumurta
- 1/2 avokado (dilimlenmiş)
- 5 zeytin
- 5 ml zeytinyağı
- 1 dilim ekmek
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Yumurtaları soyup ortadan ikiye kesin.
2. Avokado dilimlerini ve zeytinleri tabağa yerleştirin.
3. Yumurtaları ekleyin, zeytinyağıyla gezdirin.
4. Ekmek dilimi ve nane ile servis edin.$$,
  ARRAY['2 haşlanmış yumurta', '1/2 avokado', '5 zeytin', '5 ml zeytinyağı', '1 dilim ekmek', 'Taze nane'],
  ARRAY['Yüksek Protein']
),
(
  'Hardallı Tavuk Salatası',
  'snack',
  280, 28, 10, 14,
  8,
  'photos/meals/hardalli_tavuk_salatasi.webp',
  $$MALZEMELER:
- 120g pişmiş tavuk göğsü (kuşbaşı)
- 2 avuç marul
- 1 yemek kaşığı süzme yoğurt
- 1 çay kaşığı hardal
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Yoğurt, hardal, zeytinyağı ve tuzu çırpın.
2. Marulu kaseye alıp tavuğu üzerine yerleştirin.
3. Sosu gezdirin.
4. Hafifçe karıştırıp servis edin.$$,
  ARRAY['120g pişmiş tavuk göğsü', '2 avuç marul', '1 yemek kaşığı süzme yoğurt', '1 çay kaşığı hardal', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Lor Peynirli Domates Tabağı',
  'snack',
  220, 18, 8, 14,
  5,
  'photos/meals/lor_peynirli_domates_tabagi.webp',
  $$MALZEMELER:
- 100g lor peyniri
- 2 olgun domates (dilimlenmiş)
- 5 zeytin
- 5 ml zeytinyağı
- 1 çay kaşığı kuru kekik
- Tuz

HAZIRLANIŞI:
1. Domates dilimlerini tabağa dizin.
2. Lor peynirini ortaya yerleştirin.
3. Zeytinleri ekleyin, zeytinyağı gezdirin.
4. Kekik ve tuzla servis edin.$$,
  ARRAY['100g lor peyniri', '2 olgun domates', '5 zeytin', '5 ml zeytinyağı', '1 çay kaşığı kuru kekik', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Roka ve Ceviz Salatası',
  'snack',
  220, 8, 10, 18,
  5,
  'photos/meals/roka_ve_ceviz_salatasi.webp',
  $$MALZEMELER:
- 2 avuç roka
- 30g ceviz (kırılmış)
- 5 ml zeytinyağı
- 1/2 limon (suyu)
- 30g beyaz peynir (ezilmiş)
- Tuz

HAZIRLANIŞI:
1. Rokayı kaseye alın.
2. Cevizleri ve peyniri üzerine ekleyin.
3. Zeytinyağı ve limonu gezdirin.
4. Tuzla tatlandırıp servis edin.$$,
  ARRAY['2 avuç roka', '30g ceviz', '5 ml zeytinyağı', '1/2 limon', '30g beyaz peynir', 'Tuz'],
  ARRAY['Düşük Kalori']
),
(
  'Tahin Soslu Marul Salatası',
  'snack',
  230, 6, 14, 18,
  6,
  'photos/meals/tahin_soslu_marul_salatasi.webp',
  $$MALZEMELER:
- 2 avuç marul
- 1 yemek kaşığı tahin
- 1/2 limon (suyu)
- 1 yemek kaşığı su
- 1 diş sarımsak (ezilmiş)
- Tuz

HAZIRLANIŞI:
1. Tahin, limon, su, sarımsak ve tuzu çırpın.
2. Sos pürüzsüz olana kadar karıştırın.
3. Marulu kaseye alın.
4. Sosu gezdirip karıştırarak servis edin.$$,
  ARRAY['2 avuç marul', '1 yemek kaşığı tahin', '1/2 limon', '1 yemek kaşığı su', '1 diş sarımsak', 'Tuz'],
  ARRAY['Düşük Kalori']
),
(
  'Yoğurtlu Karnabahar Salatası',
  'snack',
  180, 14, 16, 6,
  8,
  'photos/meals/yogurtlu_karnabahar_salatasi.webp',
  $$MALZEMELER:
- 200g pişmiş karnabahar (parçalanmış)
- 100g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 5 ml zeytinyağı
- Birkaç dal taze maydanoz
- Tuz

HAZIRLANIŞI:
1. Karnabaharı ve yoğurdu kasede karıştırın.
2. Sarımsak ve tuzu ekleyip karıştırın.
3. Maydanozla süsleyin.
4. Zeytinyağı gezdirip soğuk servis edin.$$,
  ARRAY['200g pişmiş karnabahar', '100g süzme yoğurt', '1 diş sarımsak', '5 ml zeytinyağı', 'Taze maydanoz', 'Tuz'],
  ARRAY['Düşük Kalori', 'Yüksek Protein']
),
(
  'Pratik Yumurtalı Salata',
  'snack',
  220, 14, 8, 14,
  8,
  'photos/meals/pratik_yumurtali_salata.webp',
  $$MALZEMELER:
- 2 haşlanmış yumurta (dilim)
- 2 avuç marul
- 1 domates (dilim)
- 5 ml zeytinyağı
- 1/2 limon (suyu)
- Tuz

HAZIRLANIŞI:
1. Marul ve domatesi kaseye alın.
2. Yumurta dilimlerini üzerine yerleştirin.
3. Zeytinyağı, limon ve tuzu ekleyin.
4. Hafifçe karıştırıp servis edin.$$,
  ARRAY['2 haşlanmış yumurta', '2 avuç marul', '1 domates', '5 ml zeytinyağı', '1/2 limon', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Karpuzlu Beyaz Peynir',
  'snack',
  220, 10, 22, 10,
  4,
  'photos/meals/karpuzlu_beyaz_peynir.webp',
  $$MALZEMELER:
- 200g karpuz (küp)
- 60g beyaz peynir (küp)
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Karpuz küplerini tabağa dizin.
2. Beyaz peynir küplerini yan tarafa yerleştirin.
3. Naneyle süsleyip servis edin.$$,
  ARRAY['200g karpuz', '60g beyaz peynir', 'Taze nane'],
  ARRAY['Düşük Kalori', 'Pratik & Ekonomik']
),
(
  'Süzme Yoğurtlu Beyaz Peynir Tabağı',
  'snack',
  280, 22, 14, 16,
  4,
  'photos/meals/suzme_yogurtlu_beyaz_peynir_tabagi.webp',
  $$MALZEMELER:
- 100g süzme yoğurt
- 60g beyaz peynir
- 1 yemek kaşığı bal
- 15g ceviz (kırılmış)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Beyaz peyniri yan tarafa yerleştirin.
3. Cevizleri ve balı ekleyin.
4. Tarçınla süsleyip servis edin.$$,
  ARRAY['100g süzme yoğurt', '60g beyaz peynir', '1 yemek kaşığı bal', '15g ceviz', '1 tutam tarçın'],
  ARRAY['Yüksek Protein']
),
(
  'Hindi Salam Tabağı',
  'snack',
  240, 22, 10, 12,
  4,
  'photos/meals/hindi_salam_tabagi.webp',
  $$MALZEMELER:
- 80g hindi salam (dilimlenmiş)
- 1 dilim tam buğday ekmeği
- 1 dilim domates
- 5 zeytin
- 30g beyaz peynir
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Hindi salam dilimlerini tabağa dizin.
2. Beyaz peynir ve zeytinleri yan tarafa yerleştirin.
3. Domatesi ve ekmeği ekleyin.
4. Naneyle servis edin.$$,
  ARRAY['80g hindi salam', '1 dilim tam buğday ekmeği', '1 dilim domates', '5 zeytin', '30g beyaz peynir', 'Taze nane'],
  ARRAY['Yüksek Protein']
),
(
  'Tavada Sade Sebze Atıştırmalığı',
  'snack',
  180, 5, 18, 10,
  12,
  'photos/meals/tavada_sade_sebze_atistirmaligi.webp',
  $$MALZEMELER:
- 1 kabak (dilimlenmiş)
- 1 patlıcan (dilimlenmiş)
- 1 yeşil biber (dilimlenmiş)
- 5 ml zeytinyağı
- 1 çay kaşığı kuru kekik
- Tuz

HAZIRLANIŞI:
1. Patlıcan dilimlerini tavada zeytinyağıyla 4 dakika kızartın.
2. Kabak ve biberi ekleyip 4 dakika daha sote edin.
3. Tuz ve kekiği serpin.
4. Sıcak servis edin.$$,
  ARRAY['1 kabak', '1 patlıcan', '1 yeşil biber', '5 ml zeytinyağı', '1 çay kaşığı kuru kekik', 'Tuz'],
  ARRAY['Düşük Kalori']
),
(
  'Tahin Soslu Havuç Sticks',
  'snack',
  240, 6, 22, 14,
  5,
  'photos/meals/tahin_soslu_havuc_sticks.webp',
  $$MALZEMELER:
- 2 havuç (parmak)
- 1 yemek kaşığı tahin
- 1 yemek kaşığı pekmez
- 1 yemek kaşığı su

HAZIRLANIŞI:
1. Tahin, pekmez ve suyu pürüzsüz olana kadar karıştırın.
2. Havuçları parmak şeklinde doğrayın.
3. Tabağa dizin, sosu kase içinde yan tarafa koyun.
4. Hemen servis edin.$$,
  ARRAY['2 havuç', '1 yemek kaşığı tahin', '1 yemek kaşığı pekmez', '1 yemek kaşığı su'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Pancar Salatası',
  'snack',
  180, 8, 22, 6,
  6,
  'photos/meals/yogurtlu_pancar_salatasi.webp',
  $$MALZEMELER:
- 1 pişmiş pancar (rendelenmiş)
- 100g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 5 ml zeytinyağı
- 15g ceviz (kırılmış)
- Tuz

HAZIRLANIŞI:
1. Pancarı ve yoğurdu kasede karıştırın.
2. Sarımsak ve tuzu ekleyin.
3. Zeytinyağı gezdirin.
4. Cevizle süsleyip servis edin.$$,
  ARRAY['1 pişmiş pancar', '100g süzme yoğurt', '1 diş sarımsak', '5 ml zeytinyağı', '15g ceviz', 'Tuz'],
  ARRAY['Düşük Kalori']
),
(
  'Maydanozlu Yumurta Salatası',
  'snack',
  240, 16, 6, 16,
  12,
  'photos/meals/maydanozlu_yumurta_salatasi.webp',
  $$MALZEMELER:
- 3 haşlanmış yumurta (doğranmış)
- 100g süzme yoğurt
- 1 yemek kaşığı kıyılmış maydanoz
- 1 çay kaşığı sirke
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Yumurtaları kaseye alın.
2. Yoğurt, sirke, zeytinyağı ve tuzu ekleyip karıştırın.
3. Maydanozla harmanlayın.
4. Soğuk servis edin.$$,
  ARRAY['3 haşlanmış yumurta', '100g süzme yoğurt', '1 yemek kaşığı kıyılmış maydanoz', '1 çay kaşığı sirke', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Yumurtalı Peynirli Roll',
  'snack',
  280, 18, 22, 14,
  8,
  'photos/meals/yumurtali_peynirli_roll.webp',
  $$MALZEMELER:
- 1 lavaş
- 1 haşlanmış yumurta (dilimlenmiş)
- 60g beyaz peynir (ezilmiş)
- Birkaç dal taze maydanoz
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Lavaşı düz bir zemine açıp peyniri yayın.
2. Yumurta dilimlerini ve maydanozu yerleştirin.
3. Zeytinyağı ve tuzu ekleyin.
4. Sıkıca rulo yapıp ikiye keserek servis edin.$$,
  ARRAY['1 lavaş', '1 haşlanmış yumurta', '60g beyaz peynir', 'Taze maydanoz', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Sade Tahıl Bar',
  'snack',
  240, 6, 35, 10,
  14,
  'photos/meals/sade_tahil_bar.webp',
  $$MALZEMELER:
- 60g yulaf ezmesi
- 1 yemek kaşığı bal
- 1 yemek kaşığı tahin
- 15g kuru üzüm
- 15g ceviz (kırılmış)

HAZIRLANIŞI:
1. Tüm malzemeleri kasede karıştırın.
2. Karışımı düz tabağa yayıp 1 cm kalınlığında sıkıştırın.
3. Buzdolabında 5 dakika dinlendirin.
4. Bar şeklinde keserek servis edin.$$,
  ARRAY['60g yulaf ezmesi', '1 yemek kaşığı bal', '1 yemek kaşığı tahin', '15g kuru üzüm', '15g ceviz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Tavuk Sandviç',
  'snack',
  380, 32, 30, 14,
  8,
  'photos/meals/yogurtlu_tavuk_sandvic.webp',
  $$MALZEMELER:
- 100g pişmiş tavuk göğsü (dilim)
- 2 dilim tam buğday ekmeği
- 2 yemek kaşığı süzme yoğurt
- 1 yaprak marul
- 1 dilim domates
- Tuz

HAZIRLANIŞI:
1. Ekmek dilimlerinin iç yüzeyine yoğurdu sürün.
2. Marul, domates ve tavuğu yerleştirin.
3. Tuzlayıp kapatın.
4. İkiye keserek servis edin.$$,
  ARRAY['100g pişmiş tavuk göğsü', '2 dilim tam buğday ekmeği', '2 yemek kaşığı süzme yoğurt', '1 yaprak marul', '1 dilim domates', 'Tuz'],
  ARRAY['Yüksek Protein']
),
(
  'Limon Soslu Roka Salatası',
  'snack',
  180, 4, 8, 14,
  5,
  'photos/meals/limon_soslu_roka_salatasi.webp',
  $$MALZEMELER:
- 2 avuç roka
- 1/2 limon (suyu)
- 10 ml zeytinyağı
- 30g ceviz (kırılmış)
- Birkaç yaprak taze nane
- Tuz

HAZIRLANIŞI:
1. Rokayı kaseye alın.
2. Limon, zeytinyağı ve tuzu çırpın.
3. Sosu rokanın üzerine gezdirin.
4. Ceviz ve naneyle süsleyip servis edin.$$,
  ARRAY['2 avuç roka', '1/2 limon', '10 ml zeytinyağı', '30g ceviz', 'Taze nane', 'Tuz'],
  ARRAY['Düşük Kalori']
),
(
  'Bal-Cevizli Lor Peyniri',
  'snack',
  280, 16, 22, 14,
  4,
  'photos/meals/bal_cevizli_lor_peyniri.webp',
  $$MALZEMELER:
- 100g lor peyniri
- 1 yemek kaşığı bal
- 15g ceviz (kırılmış)
- 1 tutam tarçın
- 1 dilim tam buğday ekmeği

HAZIRLANIŞI:
1. Lor peynirini kaseye alın.
2. Cevizleri üzerine ekleyin.
3. Balı gezdirin.
4. Tarçınla süsleyip ekmek yanında servis edin.$$,
  ARRAY['100g lor peyniri', '1 yemek kaşığı bal', '15g ceviz', '1 tutam tarçın', '1 dilim tam buğday ekmeği'],
  ARRAY['Yüksek Protein']
),
(
  'Sade Pancar Salatası',
  'snack',
  140, 4, 18, 6,
  5,
  'photos/meals/sade_pancar_salatasi.webp',
  $$MALZEMELER:
- 1 pişmiş pancar (dilimlenmiş)
- 5 ml zeytinyağı
- 1/2 limon (suyu)
- 1 küçük kuru soğan (ince dilim)
- Birkaç dal taze maydanoz
- Tuz

HAZIRLANIŞI:
1. Pancar dilimlerini tabağa dizin.
2. Soğanları üzerine yerleştirin.
3. Zeytinyağı ve limonu gezdirin.
4. Maydanoz ve tuzla servis edin.$$,
  ARRAY['1 pişmiş pancar', '5 ml zeytinyağı', '1/2 limon', '1 küçük kuru soğan', 'Taze maydanoz', 'Tuz'],
  ARRAY['Düşük Kalori', 'Pratik & Ekonomik']
),
(
  'Yumurtalı Domates Sandviç',
  'snack',
  280, 14, 30, 12,
  7,
  'photos/meals/yumurtali_domates_sandvic.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 1 haşlanmış yumurta (dilim)
- 1 dilim domates
- 5 ml zeytinyağı
- Birkaç yaprak taze nane
- Tuz

HAZIRLANIŞI:
1. Ekmek dilimlerinin iç yüzeyini zeytinyağıyla yağlayın.
2. Yumurta ve domatesi yerleştirin.
3. Tuzlayın, naneyle süsleyin.
4. Kapatıp ikiye keserek servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '1 haşlanmış yumurta', '1 dilim domates', '5 ml zeytinyağı', 'Taze nane', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Süzme Peynirli Avokado',
  'snack',
  280, 16, 12, 22,
  5,
  'photos/meals/suzme_peynirli_avokado.webp',
  $$MALZEMELER:
- 1/2 avokado
- 80g süzme peynir
- 1/2 limon (suyu)
- 5 ml zeytinyağı
- Birkaç yaprak taze nane
- Tuz

HAZIRLANIŞI:
1. Avokadoyu çekirdeği etrafından oyun.
2. Süzme peyniri oyuğa doldurun.
3. Limon ve zeytinyağını gezdirin.
4. Tuz ve naneyle servis edin.$$,
  ARRAY['1/2 avokado', '80g süzme peynir', '1/2 limon', '5 ml zeytinyağı', 'Taze nane', 'Tuz'],
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Hindi Etli Marul Wrap',
  'snack',
  220, 28, 6, 10,
  5,
  'photos/meals/hindi_etli_marul_wrap.webp',
  $$MALZEMELER:
- 100g hindi göğsü (dilim)
- 4 büyük marul yaprağı
- 1 yemek kaşığı süzme yoğurt
- 1 çay kaşığı hardal
- 1/4 salatalık (parmak)
- Tuz

HAZIRLANIŞI:
1. Yoğurt ve hardalı karıştırın.
2. Marul yaprağına hindi, salatalık ve sosu yerleştirin.
3. Tuzlayın.
4. Marulu sıkıca rulo yapıp servis edin.$$,
  ARRAY['100g hindi göğsü', '4 büyük marul yaprağı', '1 yemek kaşığı süzme yoğurt', '1 çay kaşığı hardal', '1/4 salatalık', 'Tuz'],
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Yoğurtlu Pirinç Salatası',
  'snack',
  320, 12, 50, 8,
  12,
  'photos/meals/yogurtlu_pirinc_salatasi.webp',
  $$MALZEMELER:
- 80g pişmiş pirinç (soğutulmuş)
- 100g süzme yoğurt
- 1 salatalık (küp)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Birkaç dal taze maydanoz

HAZIRLANIŞI:
1. Pirinç, salatalık ve soğanı kasede karıştırın.
2. Yoğurt ve zeytinyağını ekleyin.
3. Tuzlayıp maydanozla harmanlayın.
4. Soğuk servis edin.$$,
  ARRAY['80g pişmiş pirinç', '100g süzme yoğurt', '1 salatalık', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Taze maydanoz'],
  ARRAY['Pratik & Ekonomik']
),
-- ============================ Tatlı Çeşitleri (25) ============================
(
  'Yüksek Proteinli Yoğurt Mousse',
  'dessert',
  240, 22, 14, 8,
  6,
  'photos/meals/yuksek_proteinli_yogurt_mousse.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 15g vanilyalı protein tozu
- 1 yemek kaşığı bal
- 15g granola
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurda protein tozunu çırparak ekleyin.
2. Balı yedirip kıvamlı bir mousse elde edin.
3. Kaseye aktarıp granolayı serpin.
4. Tarçınla süsleyip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '15g vanilyalı protein tozu', '1 yemek kaşığı bal', '15g granola', '1 tutam tarçın'],
  ARRAY['Yüksek Protein']
),
(
  'Kakaolu Hurma Topları',
  'dessert',
  280, 6, 38, 14,
  10,
  'photos/meals/kakaolu_hurma_toplari.webp',
  $$MALZEMELER:
- 8 hurma (çekirdeksiz)
- 30g badem
- 1 yemek kaşığı şekersiz kakao
- 15g hindistan cevizi rendesi
- 1 tutam tuz

HAZIRLANIŞI:
1. Hurma ve bademleri rondodan geçirin.
2. Tuz ekleyip yoğurun.
3. Ceviz büyüklüğünde toplar yapıp önce kakaoya, sonra hindistan cevizine bulayın.
4. Buzdolabında 5 dakika soğutup servis edin.$$,
  ARRAY['8 hurma', '30g badem', '1 yemek kaşığı şekersiz kakao', '15g hindistan cevizi rendesi', '1 tutam tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Süzme Yoğurtlu Frozen Bar',
  'dessert',
  180, 14, 22, 4,
  8,
  'photos/meals/suzme_yogurtlu_frozen_bar.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 100g taze çilek (ezilmiş)
- 1 yemek kaşığı bal
- 15g granola

HAZIRLANIŞI:
1. Yoğurt, çilek ve balı karıştırın.
2. Düz bir kaba yayıp 1 cm kalınlığında dağıtın.
3. Granolayı üzerine serpin.
4. Buzlukta 5 dakika dondurup bar şeklinde keserek servis edin.$$,
  ARRAY['200g süzme yoğurt', '100g taze çilek', '1 yemek kaşığı bal', '15g granola'],
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Yoğurtlu Çikolata Mousse',
  'dessert',
  280, 14, 30, 12,
  6,
  'photos/meals/yogurtlu_cikolata_mousse.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 yemek kaşığı şekersiz kakao
- 1 yemek kaşığı bal
- 15g bitter çikolata (rendelenmiş)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurda kakaoyu eleyerek çırpın.
2. Balı yedirin.
3. Kaseye aktarın, çikolatayı üzerine serpin.
4. Tarçınla süsleyip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '1 yemek kaşığı şekersiz kakao', '1 yemek kaşığı bal', '15g bitter çikolata', '1 tutam tarçın'],
  ARRAY['Yüksek Protein']
),
(
  'Bademli Süt Pudingi',
  'dessert',
  320, 12, 38, 14,
  14,
  'photos/meals/bademli_sut_pudingi.webp',
  $$MALZEMELER:
- 250 ml süt
- 25g pirinç unu
- 30g toz şeker
- 30g badem (kırılmış)
- 1 paket vanilya

HAZIRLANIŞI:
1. Pirinç ununu 50 ml soğuk sütle açın.
2. Kalan sütü kaynatın, şekeri ekleyin.
3. Pirinç unu karışımını ekleyip kıvam alana kadar 6 dakika karıştırın.
4. Kaselere paylaştırın, vanilya ve bademlerle süsleyin.$$,
  ARRAY['250 ml süt', '25g pirinç unu', '30g toz şeker', '30g badem', '1 paket vanilya'],
  ARRAY['Yüksek Protein']
),
(
  'Karamel Soslu Yoğurt',
  'dessert',
  280, 12, 38, 8,
  8,
  'photos/meals/karamel_soslu_yogurt.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 30g toz şeker
- 15g tereyağı
- 50 ml süt
- 1 tutam tuz

HAZIRLANIŞI:
1. Tencerede şekeri orta ateşte karamelize edin.
2. Tereyağı, süt ve tuzu ekleyip pürüzsüz olana kadar karıştırın.
3. Sosun soğumasını bekleyin.
4. Yoğurdun üzerine gezdirip servis edin.$$,
  ARRAY['200g süzme yoğurt', '30g toz şeker', '15g tereyağı', '50 ml süt', '1 tutam tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pekmezli Hurma Pudingi',
  'dessert',
  320, 8, 60, 6,
  12,
  'photos/meals/pekmezli_hurma_pudingi.webp',
  $$MALZEMELER:
- 250 ml süt
- 25g pirinç unu
- 4 hurma (çekirdeksiz, doğranmış)
- 2 yemek kaşığı pekmez
- 15g ceviz (kırılmış)

HAZIRLANIŞI:
1. Pirinç ununu 50 ml soğuk sütle açın.
2. Kalan sütü kaynatın, hurmaları ekleyin.
3. Pirinç unu karışımını ekleyip kıvam alana kadar 6 dakika karıştırın.
4. Kaselere paylaştırın, pekmez ve cevizle süsleyin.$$,
  ARRAY['250 ml süt', '25g pirinç unu', '4 hurma', '2 yemek kaşığı pekmez', '15g ceviz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Limonlu Yoğurt Bar',
  'dessert',
  180, 12, 22, 4,
  8,
  'photos/meals/limonlu_yogurt_bar.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1/2 limon (kabuk rendesi ve suyu)
- 1 yemek kaşığı bal
- 15g granola

HAZIRLANIŞI:
1. Yoğurda limon kabuğu, suyu ve balı yedirin.
2. Düz bir kaba yayın.
3. Granolayı üzerine serpin.
4. Buzlukta 5 dakika dondurup bar şeklinde servis edin.$$,
  ARRAY['200g süzme yoğurt', '1/2 limon', '1 yemek kaşığı bal', '15g granola'],
  ARRAY['Düşük Kalori']
),
(
  'Cevizli Karamelize Muz',
  'dessert',
  280, 4, 45, 12,
  8,
  'photos/meals/cevizli_karamelize_muz.webp',
  $$MALZEMELER:
- 2 muz (uzunlamasına ikiye)
- 15g tereyağı
- 1 yemek kaşığı bal
- 20g ceviz (kırılmış)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Tavada tereyağını eritip muz dilimlerini her yüzünü 2 dakika kızartın.
2. Balı tavanın kenarından gezdirin.
3. Muzları tabağa alın.
4. Ceviz ve tarçın serpip sıcak servis edin.$$,
  ARRAY['2 muz', '15g tereyağı', '1 yemek kaşığı bal', '20g ceviz', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Pirinç Sütü Tatlısı',
  'dessert',
  280, 8, 50, 6,
  14,
  'photos/meals/sade_pirinc_sutu_tatlisi.webp',
  $$MALZEMELER:
- 50g pişmiş pirinç
- 400 ml süt
- 30g toz şeker
- 1 paket vanilya
- 1 tutam tarçın

HAZIRLANIŞI:
1. Pirinç ve sütü tencerede orta ateşte kaynatın.
2. Şekeri ve vanilyayı ekleyin.
3. Kıvam alana kadar 8 dakika karıştırın.
4. Kaselere paylaştırın, tarçınla süsleyin.$$,
  ARRAY['50g pişmiş pirinç', '400 ml süt', '30g toz şeker', '1 paket vanilya', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Süt Helvası',
  'dessert',
  320, 8, 38, 14,
  14,
  'photos/meals/sade_sut_helvasi.webp',
  $$MALZEMELER:
- 80g un
- 30g tereyağı
- 40g toz şeker
- 200 ml süt
- 15g ceviz

HAZIRLANIŞI:
1. Tereyağında unu altın renge gelene kadar 5 dakika kavurun.
2. Süt ve şekeri ayrı tencerede ısıtıp un karışımına ekleyin.
3. Kıvam alana kadar 4 dakika karıştırın.
4. Kalıba alıp ceviz serpip servis edin.$$,
  ARRAY['80g un', '30g tereyağı', '40g toz şeker', '200 ml süt', '15g ceviz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Mikrodalgada Çikolatalı Kek',
  'dessert',
  360, 8, 50, 14,
  8,
  'photos/meals/mikrodalgada_cikolatali_kek.webp',
  $$MALZEMELER:
- 4 yemek kaşığı un
- 2 yemek kaşığı kakao
- 3 yemek kaşığı toz şeker
- 1 yumurta
- 60 ml süt
- 15g tereyağı

HAZIRLANIŞI:
1. Tüm malzemeleri kupada karıştırın.
2. Pürüzsüz bir karışım elde edin.
3. Mikrodalgada 800W güçte 2 dakika pişirin.
4. 1 dakika dinlendirip servis edin.$$,
  ARRAY['4 yemek kaşığı un', '2 yemek kaşığı kakao', '3 yemek kaşığı toz şeker', '1 yumurta', '60 ml süt', '15g tereyağı'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yulaflı Muzlu Cookie',
  'dessert',
  280, 8, 45, 8,
  14,
  'photos/meals/yulafli_muzlu_cookie.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 1 olgun muz (ezilmiş)
- 15g bitter çikolata (kırılmış)
- 15g ceviz (kırılmış)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Tüm malzemeleri kasede karıştırın.
2. Yapışmaz pişirme kağıdına kaşıkla bırakın.
3. 180°C fırında 10 dakika pişirin (veya tavada tek tarafta 4 dakika).
4. Soğuduktan sonra servis edin.$$,
  ARRAY['50g yulaf ezmesi', '1 olgun muz', '15g bitter çikolata', '15g ceviz', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Yumurtalı Süt Tatlısı',
  'dessert',
  220, 10, 30, 7,
  12,
  'photos/meals/sade_yumurtali_sut_tatlisi.webp',
  $$MALZEMELER:
- 250 ml süt
- 1 yumurta
- 30g toz şeker
- 1 paket vanilya
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yumurtayı şeker ve vanilyayla çırpın.
2. Sütü ısıtıp yavaşça yumurta karışımına ekleyin.
3. Tencereye geri alıp orta ateşte kıvam alana kadar 6 dakika karıştırın.
4. Kaselere paylaştırın, tarçınla süsleyin.$$,
  ARRAY['250 ml süt', '1 yumurta', '30g toz şeker', '1 paket vanilya', '1 tutam tarçın'],
  ARRAY['Yüksek Protein']
),
(
  'Donmuş Yoğurt Topları',
  'dessert',
  160, 12, 22, 3,
  8,
  'photos/meals/donmus_yogurt_toplari.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 100g taze çilek (ezilmiş)
- 1 yemek kaşığı bal
- 1 tutam vanilya

HAZIRLANIŞI:
1. Yoğurt, çilek, bal ve vanilyayı karıştırın.
2. Pişirme kağıdına dondurma kaşığı yardımıyla küçük toplar bırakın.
3. Buzlukta 5 dakika dondurun.
4. Hemen servis edin.$$,
  ARRAY['200g süzme yoğurt', '100g taze çilek', '1 yemek kaşığı bal', '1 tutam vanilya'],
  ARRAY['Düşük Kalori', 'Yüksek Protein']
),
(
  'Hızlı Sade Lokma',
  'dessert',
  380, 6, 60, 14,
  14,
  'photos/meals/hizli_sade_lokma.webp',
  $$MALZEMELER:
- 80g un
- 1 paket maya
- 200 ml ılık su
- 50g toz şeker
- 30 ml ayçiçek yağı
- 1 yemek kaşığı bal

HAZIRLANIŞI:
1. Un, maya ve suyu kasede karıştırıp 5 dakika mayalandırın.
2. Yağı kızdırıp karışımdan kaşıkla küçük topaklar bırakın.
3. Altın renge gelene kadar 4 dakika kızartın.
4. Şeker ve balla şerbetleyip servis edin.$$,
  ARRAY['80g un', '1 paket maya', '200 ml ılık su', '50g toz şeker', '30 ml ayçiçek yağı', '1 yemek kaşığı bal'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade İncir Tatlısı',
  'dessert',
  280, 6, 55, 6,
  10,
  'photos/meals/sade_incir_tatlisi.webp',
  $$MALZEMELER:
- 4 kuru incir
- 250 ml süt
- 15g ceviz (kırılmış)
- 1 yemek kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. İncirleri sütle 6 dakika kaynatın.
2. İncirleri tabağa alın.
3. Sütü kıvam alana kadar 2 dakika daha pişirip incirlerin üzerine dökün.
4. Ceviz, bal ve tarçınla süsleyip servis edin.$$,
  ARRAY['4 kuru incir', '250 ml süt', '15g ceviz', '1 yemek kaşığı bal', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pratik Aşure',
  'dessert',
  380, 10, 65, 10,
  15,
  'photos/meals/pratik_asure.webp',
  $$MALZEMELER:
- 60g önceden haşlanmış aşurelik buğday
- 30g haşlanmış nohut
- 30g haşlanmış kuru fasulye
- 30g kuru üzüm
- 30g toz şeker
- 1 tutam tarçın

HAZIRLANIŞI:
1. Tüm malzemeleri 200 ml suyla tencereye alın.
2. Şekeri ekleyip orta ateşte 8 dakika kaynatın.
3. Kaselere paylaştırın.
4. Tarçınla süsleyip soğuduktan sonra servis edin.$$,
  ARRAY['60g aşurelik buğday', '30g haşlanmış nohut', '30g haşlanmış kuru fasulye', '30g kuru üzüm', '30g toz şeker', '1 tutam tarçın'],
  ARRAY['Hacim', 'Pratik & Ekonomik']
),
(
  'Bal Soslu Vanilyalı Yoğurt',
  'dessert',
  240, 12, 30, 8,
  4,
  'photos/meals/bal_soslu_vanilyali_yogurt.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 paket vanilya
- 1 yemek kaşığı bal
- 15g ceviz (kırılmış)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurda vanilyayı yedirin.
2. Kaseye alıp balı gezdirin.
3. Cevizleri serpin.
4. Tarçınla süsleyip servis edin.$$,
  ARRAY['200g süzme yoğurt', '1 paket vanilya', '1 yemek kaşığı bal', '15g ceviz', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Beyaz Peynirli Bal Tatlısı',
  'dessert',
  320, 18, 22, 18,
  6,
  'photos/meals/beyaz_peynirli_bal_tatlisi.webp',
  $$MALZEMELER:
- 100g beyaz peynir (ezilmiş)
- 1 yemek kaşığı bal
- 15g ceviz (kırılmış)
- 1 tutam tarçın
- 1 dilim tam buğday ekmeği

HAZIRLANIŞI:
1. Beyaz peyniri kaseye alıp ezin.
2. Balı ve cevizi karıştırın.
3. Tarçınla süsleyin.
4. Ekmek dilimi yanında servis edin.$$,
  ARRAY['100g beyaz peynir', '1 yemek kaşığı bal', '15g ceviz', '1 tutam tarçın', '1 dilim tam buğday ekmeği'],
  ARRAY['Yüksek Protein']
),
(
  'Şerbetli Yulaf Topları',
  'dessert',
  280, 6, 45, 10,
  12,
  'photos/meals/serbetli_yulaf_toplari.webp',
  $$MALZEMELER:
- 60g yulaf ezmesi
- 1 yemek kaşığı bal
- 30 ml su
- 30g toz şeker
- 15g hindistan cevizi rendesi
- 1 yemek kaşığı tahin

HAZIRLANIŞI:
1. Su ve şekerle hafif şerbet yapın, ılıtın.
2. Yulaf, tahin ve balı yoğurun.
3. Toplar yapıp şerbete batırın.
4. Hindistan cevizine bulayıp servis edin.$$,
  ARRAY['60g yulaf ezmesi', '1 yemek kaşığı bal', '30 ml su', '30g toz şeker', '15g hindistan cevizi rendesi', '1 yemek kaşığı tahin'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Hindistan Cevizli Süt Pudingi',
  'dessert',
  280, 8, 35, 12,
  14,
  'photos/meals/hindistan_cevizli_sut_pudingi.webp',
  $$MALZEMELER:
- 250 ml süt
- 25g pirinç unu
- 30g toz şeker
- 20g hindistan cevizi rendesi
- 1 paket vanilya

HAZIRLANIŞI:
1. Pirinç ununu 50 ml soğuk sütle açın.
2. Kalan sütü kaynatın, şekeri ve vanilyayı ekleyin.
3. Pirinç unu karışımını ekleyip kıvam alana kadar 6 dakika karıştırın.
4. Kaselere paylaştırın, hindistan cevizini üzerine serpin.$$,
  ARRAY['250 ml süt', '25g pirinç unu', '30g toz şeker', '20g hindistan cevizi rendesi', '1 paket vanilya'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Tahin Mousse',
  'dessert',
  280, 10, 22, 18,
  4,
  'photos/meals/sade_tahin_mousse.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 2 yemek kaşığı tahin
- 1 yemek kaşığı pekmez
- 1 tutam tarçın
- 15g ceviz (kırılmış)

HAZIRLANIŞI:
1. Yoğurda tahini çırparak ekleyin.
2. Pekmezi yedirip mermer desen oluşturun.
3. Kaseye aktarın.
4. Ceviz ve tarçınla süsleyip servis edin.$$,
  ARRAY['200g süzme yoğurt', '2 yemek kaşığı tahin', '1 yemek kaşığı pekmez', '1 tutam tarçın', '15g ceviz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Şekersiz Çikolatalı Yoğurt Mousse',
  'dessert',
  200, 18, 14, 8,
  5,
  'photos/meals/sekersiz_cikolatali_yogurt_mousse.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 yemek kaşığı şekersiz kakao
- 15g vanilyalı protein tozu
- 1 muz (ezilmiş)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurda kakao ve protein tozunu çırpın.
2. Muzu yedirin.
3. Kaseye aktarın.
4. Tarçınla süsleyip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '1 yemek kaşığı şekersiz kakao', '15g vanilyalı protein tozu', '1 muz', '1 tutam tarçın'],
  ARRAY['Düşük Kalori', 'Yüksek Protein']
),
(
  'Yulaflı Çikolata Cookie',
  'dessert',
  280, 8, 40, 10,
  14,
  'photos/meals/yulafli_cikolata_cookie.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 30g un
- 15g bitter çikolata (kırılmış)
- 1 yumurta
- 1 yemek kaşığı bal
- 5g tereyağı

HAZIRLANIŞI:
1. Tüm malzemeleri kasede yoğurun.
2. Yapışmaz pişirme kağıdına kaşıkla cookie şekilleri bırakın.
3. 180°C fırında 10 dakika pişirin (veya tavada her yüzü 3 dakika).
4. Soğuduktan sonra servis edin.$$,
  ARRAY['50g yulaf ezmesi', '30g un', '15g bitter çikolata', '1 yumurta', '1 yemek kaşığı bal', '5g tereyağı'],
  ARRAY['Pratik & Ekonomik']
)
ON CONFLICT (title) DO NOTHING;

-- =============================================================================
-- Sanity check — should return 125 new rows tagged with at least one
-- of: Yüksek Protein / Düşük Kalori / Hacim / Sıkılaşma / Pratik & Ekonomik
-- after running this file. Combined with prior seeds, the catalogue
-- should reach ~290 recipes.
-- =============================================================================
-- SELECT meal_type, count(*)
--   FROM public.recipes
--   GROUP BY meal_type
--   ORDER BY meal_type;
-- Expected post-Phase-84 totals across full catalogue:
--   breakfast: ~50
--   dinner:    ~55
--   lunch:     ~50
--   snack:     ~50
--   dessert:   ~45
--   main:     ~5  (legacy from Phase 24 seed)
