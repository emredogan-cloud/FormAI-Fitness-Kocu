-- =============================================================================
-- Phase 83 · Pratik & Ekonomik (Budget) — Batch 2 · 100 recipes
-- =============================================================================
-- Scales the Phase 83 pilot from 10 to 110 budget recipes (10 pilot + 100
-- this file). Distribution: 20 each across breakfast / lunch / dinner /
-- snack / dessert, all tagged 'Pratik & Ekonomik' so the dashboard
-- strip's five sub-cards every populate.
--
-- Schema unchanged from Phase 83 pilot. This file populates the
-- previously-unused `ingredients` text[] column in addition to the
-- dollar-quoted `instructions` text — the column has been on the
-- model since Phase 57 but the seed never wrote to it. Recipe.fromJson
-- already handles both populated and empty `ingredients` rows
-- gracefully, so existing UI surfaces don't need changes.
--
-- Caveats explicitly accepted by the PM during the pilot:
--   • Macro values are estimates, not dietitian-verified.
--   • All 100 image_url paths point at `photos/meals/<slug>.webp`
--     files that don't yet exist; until the PM generates them via
--     Midjourney (prompts in `docs/MEAL_IMAGE_PROMPTS.md` under
--     "Pratik & Ekonomik — Batch 2"), the recipe list shows the
--     `_Thumb` fallback restaurant icon.
--
-- Idempotency: `ON CONFLICT (title) DO NOTHING` — relies on the
-- `recipes_title_unique` constraint installed by `seed_recipes.sql`.
-- Re-running this file is safe; duplicate titles silently no-op.
-- All 100 titles cross-checked against the existing ~65 seeded titles
-- (Phase 24 + 28 + 35 + Phase 83 pilot) — no collisions.
-- =============================================================================

INSERT INTO public.recipes (
  title, meal_type, calories, protein, carbs, fat,
  prep_time_minutes, image_url, instructions, ingredients, tags
) VALUES
-- ============================ Kahvaltı (20) ============================
(
  'Menemen Klasik',
  'breakfast',
  320, 18, 14, 22,
  12,
  'photos/meals/menemen_klasik.webp',
  $$MALZEMELER:
- 3 yumurta
- 2 olgun domates (rendelenmiş)
- 1 yeşil sivri biber (doğranmış)
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Soğan ve biberi zeytinyağında 2 dakika sote edin.
2. Rendelenmiş domatesi ekleyip suyunu çekene kadar 4 dakika pişirin.
3. Yumurtaları çırpmadan üzerine kırın, baharatları serpin.
4. Yumurtalar tuttuğunda hemen servis edin.$$,
  ARRAY['3 yumurta', '2 olgun domates', '1 yeşil sivri biber', '1 küçük kuru soğan', '10 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Yumurtalı Ekmek',
  'breakfast',
  350, 18, 30, 16,
  7,
  'photos/meals/sade_yumurtali_ekmek.webp',
  $$MALZEMELER:
- 2 yumurta
- 2 dilim tam buğday ekmeği
- 5 ml tereyağı
- 1 tutam tuz ve karabiber

HAZIRLANIŞI:
1. Tereyağını tavada eritin.
2. Yumurtaları kırıp orta ateşte 3 dakika pişirin.
3. Tuz ve karabiberi serpin.
4. Ekmeklerle birlikte servis edin.$$,
  ARRAY['2 yumurta', '2 dilim tam buğday ekmeği', '5 ml tereyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Lor Peynirli Bal Ekmek',
  'breakfast',
  380, 18, 45, 14,
  5,
  'photos/meals/lor_peynirli_bal_ekmek.webp',
  $$MALZEMELER:
- 80g lor peyniri
- 1 yemek kaşığı bal
- 2 dilim tam buğday ekmeği
- 1 tutam tarçın

HAZIRLANIŞI:
1. Lor peynirini bir kasede çatalla ezin.
2. Bal ve tarçını ekleyip karıştırın.
3. Karışımı ekmek dilimlerine sürün.
4. Hemen servis edin.$$,
  ARRAY['80g lor peyniri', '1 yemek kaşığı bal', '2 dilim tam buğday ekmeği', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Kaşar Peynirli Tava Tost',
  'breakfast',
  420, 22, 40, 18,
  8,
  'photos/meals/kasar_peynirli_tava_tost.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 40g kaşar peyniri
- 5 ml tereyağı
- 1 tutam karabiber

HAZIRLANIŞI:
1. Kaşar peynirini ekmek dilimlerinin arasına yerleştirin.
2. Tavanın bir tarafını tereyağıyla yağlayın.
3. Tostu kapalı tavada her iki yüzü altın renk olana kadar 3 dakika pişirin.
4. Karabiberle servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '40g kaşar peyniri', '5 ml tereyağı', '1 tutam karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sütlü Yulaf Ezmesi',
  'breakfast',
  310, 14, 45, 8,
  8,
  'photos/meals/sutlu_yulaf_ezmesi.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 250 ml süt
- 1 tatlı kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yulafı ve sütü tencereye alıp orta ateşte kaynatın.
2. Kıvam aldıkça karıştırarak 4 dakika daha pişirin.
3. Kaseye aktarın, balı ve tarçını üzerine ekleyin.
4. Sıcak servis edin.$$,
  ARRAY['50g yulaf ezmesi', '250 ml süt', '1 tatlı kaşığı bal', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Domatesli Sahanda Yumurta',
  'breakfast',
  290, 16, 8, 22,
  8,
  'photos/meals/domatesli_sahanda_yumurta.webp',
  $$MALZEMELER:
- 2 yumurta
- 1 büyük olgun domates (doğranmış)
- 5 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Zeytinyağını tavada ısıtın.
2. Doğranmış domatesi ekleyip 2 dakika sote edin.
3. Yumurtaları üzerine kırın, baharatları serpin.
4. Yumurtalar tutana kadar 3 dakika pişirin ve sıcak servis edin.$$,
  ARRAY['2 yumurta', '1 büyük olgun domates', '5 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Soğanlı Patates Kavurma',
  'breakfast',
  340, 8, 45, 14,
  14,
  'photos/meals/soganli_patates_kavurma.webp',
  $$MALZEMELER:
- 2 orta boy patates (küp doğranmış)
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- 1 tutam pul biber
- Tuz

HAZIRLANIŞI:
1. Patatesleri zeytinyağında orta ateşte 8 dakika pişirin.
2. Soğanı ekleyip karıştırarak 3 dakika daha kavurun.
3. Tuz ve pul biberi serpin.
4. Sıcak servis edin.$$,
  ARRAY['2 orta boy patates', '1 küçük kuru soğan', '10 ml zeytinyağı', 'Tuz ve pul biber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Bazlama Tava Tost',
  'breakfast',
  380, 16, 55, 12,
  6,
  'photos/meals/bazlama_tava_tost.webp',
  $$MALZEMELER:
- 1 bazlama
- 40g beyaz peynir
- 1 domates (dilimlenmiş)
- 5 zeytin
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Bazlamayı ortadan kesip iç yüzeyine peyniri yayın.
2. Domates dilimlerini ve zeytinleri ekleyin.
3. Kapalı tavada 3 dakika ısıtın.
4. Naneyle süsleyip servis edin.$$,
  ARRAY['1 bazlama', '40g beyaz peynir', '1 domates', '5 zeytin', 'Taze nane'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Bal-Cevizli Süzme Yoğurt',
  'breakfast',
  290, 15, 30, 14,
  3,
  'photos/meals/bal_cevizli_suzme_yogurt.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 yemek kaşığı bal
- 15g ceviz içi (kırılmış)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Bal ve cevizleri üzerine ekleyin.
3. Tarçınla süsleyip servis edin.$$,
  ARRAY['200g süzme yoğurt', '1 yemek kaşığı bal', '15g ceviz içi', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tereyağlı Bal Ekmek',
  'breakfast',
  340, 8, 55, 12,
  3,
  'photos/meals/tereyagli_bal_ekmek.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 15g tereyağı
- 1 yemek kaşığı bal

HAZIRLANIŞI:
1. Ekmek dilimlerini hafifçe kızartın.
2. Tereyağını sıcakken sürün.
3. Üzerine balı gezdirip servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '15g tereyağı', '1 yemek kaşığı bal'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Reçelli Tam Buğday Tost',
  'breakfast',
  310, 8, 55, 8,
  4,
  'photos/meals/receli_tam_bugday_tost.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 2 yemek kaşığı meyve reçeli
- 5 ml tereyağı

HAZIRLANIŞI:
1. Ekmek dilimlerini tost makinesinde kızartın.
2. Sıcakken tereyağını sürün.
3. Üzerine reçeli yayın ve hemen servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '2 yemek kaşığı meyve reçeli', '5 ml tereyağı'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Kakaolu Yulaf Lapası',
  'breakfast',
  320, 12, 50, 9,
  8,
  'photos/meals/kakaolu_yulaf_lapasi.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 250 ml süt
- 1 yemek kaşığı şekersiz kakao
- 1 yemek kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. Süt ve yulafı tencereye alıp orta ateşte kaynatın.
2. Kakaoyu ekleyip topaklanmadan karıştırın.
3. 3 dakika daha pişirip kaseye aktarın.
4. Bal ve tarçınla süsleyip sıcak servis edin.$$,
  ARRAY['50g yulaf ezmesi', '250 ml süt', '1 yemek kaşığı şekersiz kakao', '1 yemek kaşığı bal', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Maydanozlu Sade Omlet',
  'breakfast',
  220, 16, 3, 16,
  7,
  'photos/meals/maydanozlu_sade_omlet.webp',
  $$MALZEMELER:
- 3 yumurta
- 1 yemek kaşığı süt
- 1 yemek kaşığı kıyılmış maydanoz
- 5 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Yumurtaları sütle çırpın, baharatları ve maydanozu ekleyin.
2. Zeytinyağını tavada ısıtın.
3. Karışımı dökün, kenarları piştikçe ortaya çekin.
4. Yumurtalar tuttuğunda ikiye katlayıp servis edin.$$,
  ARRAY['3 yumurta', '1 yemek kaşığı süt', '1 yemek kaşığı kıyılmış maydanoz', '5 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Çiğ Sebze Kahvaltı Tabağı',
  'breakfast',
  180, 8, 14, 10,
  5,
  'photos/meals/cig_sebze_kahvalti_tabagi.webp',
  $$MALZEMELER:
- 1 salatalık (dilimlenmiş)
- 1 domates (dilimlenmiş)
- 5 zeytin
- 40g beyaz peynir
- 5 ml zeytinyağı
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Sebzeleri tabağa dizin.
2. Beyaz peynir ve zeytinleri yan tarafa yerleştirin.
3. Üzerine zeytinyağı gezdirin.
4. Naneyle süsleyip servis edin.$$,
  ARRAY['1 salatalık', '1 domates', '5 zeytin', '40g beyaz peynir', '5 ml zeytinyağı', 'Taze nane'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Salam ve Sade Tabak',
  'breakfast',
  320, 22, 14, 22,
  5,
  'photos/meals/salam_ve_sade_tabak.webp',
  $$MALZEMELER:
- 60g hindi salam
- 40g kaşar peyniri
- 1 dilim tam buğday ekmeği
- 1 domates
- 5 zeytin

HAZIRLANIŞI:
1. Salam ve peyniri tabağa dizin.
2. Domatesi dilimleyip yan tarafa yerleştirin.
3. Zeytinleri ekleyin ve ekmek dilimini ortaya koyun.
4. Hemen servis edin.$$,
  ARRAY['60g hindi salam', '40g kaşar peyniri', '1 dilim tam buğday ekmeği', '1 domates', '5 zeytin'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pratik Yumurtalı Pişi',
  'breakfast',
  380, 16, 40, 16,
  12,
  'photos/meals/pratik_yumurtali_pisi.webp',
  $$MALZEMELER:
- 100g hazır pişi hamuru
- 2 yumurta
- 5 ml zeytinyağı
- 40g beyaz peynir
- Tuz

HAZIRLANIŞI:
1. Pişi hamurunu yağlı tavada her iki yüzü altın olana kadar 4 dakika pişirin.
2. Aynı tavada yumurtaları kırıp tuzlayın.
3. Pişiyi ortadan açıp peynir ve yumurtayı yerleştirin.
4. Sıcak servis edin.$$,
  ARRAY['100g hazır pişi hamuru', '2 yumurta', '5 ml zeytinyağı', '40g beyaz peynir', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Yumurta Salatası',
  'breakfast',
  260, 18, 8, 16,
  12,
  'photos/meals/yogurtlu_yumurta_salatasi.webp',
  $$MALZEMELER:
- 2 haşlanmış yumurta
- 100g süzme yoğurt
- 1 yemek kaşığı kıyılmış maydanoz
- Tuz ve karabiber

HAZIRLANIŞI:
1. Haşlanmış yumurtaları çatalla ezin.
2. Süzme yoğurdu, baharatları ve maydanozu ekleyip karıştırın.
3. Tabağa alın, isteğe göre üzerine biraz daha maydanoz serpin.
4. Soğuk servis edin.$$,
  ARRAY['2 haşlanmış yumurta', '100g süzme yoğurt', '1 yemek kaşığı kıyılmış maydanoz', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Mısır Gevrekli Süt',
  'breakfast',
  290, 12, 55, 4,
  3,
  'photos/meals/misir_gevrekli_sut.webp',
  $$MALZEMELER:
- 50g mısır gevreği
- 250 ml süt
- 1 muz (dilimlenmiş)

HAZIRLANIŞI:
1. Mısır gevreğini bir kaseye alın.
2. Üzerine soğuk sütü dökün.
3. Muz dilimlerini ekleyin ve hemen servis edin.$$,
  ARRAY['50g mısır gevreği', '250 ml süt', '1 muz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Muzlu Sıcak Yulaf Lapası',
  'breakfast',
  340, 13, 60, 7,
  8,
  'photos/meals/muzlu_sicak_yulaf_lapasi.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 250 ml süt
- 1 olgun muz (dilimlenmiş)
- 1 tatlı kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yulafı ve sütü tencereye alıp orta ateşte kaynatın.
2. 3 dakika kıvam alana kadar karıştırın.
3. Kaseye aktarın, üzerine muzu yerleştirin.
4. Bal ve tarçınla süsleyip sıcak servis edin.$$,
  ARRAY['50g yulaf ezmesi', '250 ml süt', '1 olgun muz', '1 tatlı kaşığı bal', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Hızlı Krep ve Reçel',
  'breakfast',
  330, 11, 52, 9,
  12,
  'photos/meals/hizli_krep_ve_recel.webp',
  $$MALZEMELER:
- 2 yumurta
- 60g un
- 150 ml süt
- 5 ml tereyağı
- 2 yemek kaşığı reçel

HAZIRLANIŞI:
1. Yumurta, un ve sütü pürüzsüz olana kadar çırpın.
2. Yağlı tavaya az miktar harç dökerek ince krepler pişirin (her biri 1-2 dk).
3. Krepleri reçelle doldurup ruloya sarın.
4. Tabağa alıp servis edin.$$,
  ARRAY['2 yumurta', '60g un', '150 ml süt', '5 ml tereyağı', '2 yemek kaşığı reçel'],
  ARRAY['Pratik & Ekonomik']
),
-- ============================ Öğle Yemeği (20) ============================
(
  'Ton Balıklı Makarna Salatası',
  'lunch',
  480, 30, 55, 14,
  13,
  'photos/meals/ton_balikli_makarna_salatasi.webp',
  $$MALZEMELER:
- 100g pişmiş makarna
- 1 kutu ton balığı (suyu süzülmüş)
- 1 domates (küp doğranmış)
- 1 salatalık (küp doğranmış)
- 10 ml zeytinyağı
- 1/2 limon (suyu)

HAZIRLANIŞI:
1. Makarnayı, ton balığını ve sebzeleri kasede karıştırın.
2. Zeytinyağı ve limon suyunu ekleyin.
3. Tuz ve karabiberle tatlandırın.
4. Hemen servis edin.$$,
  ARRAY['100g pişmiş makarna', '1 kutu ton balığı', '1 domates', '1 salatalık', '10 ml zeytinyağı', '1/2 limon'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yumurtalı Patates Salatası',
  'lunch',
  380, 18, 45, 14,
  15,
  'photos/meals/yumurtali_patates_salatasi.webp',
  $$MALZEMELER:
- 2 haşlanmış patates (küp doğranmış)
- 2 haşlanmış yumurta (dilimlenmiş)
- 1 yemek kaşığı yoğurt
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Taze maydanoz

HAZIRLANIŞI:
1. Patates, yumurta ve soğanı kasede toplayın.
2. Yoğurt ve zeytinyağını ekleyip hafifçe karıştırın.
3. Tuz ekleyip maydanozla süsleyin.
4. Soğuk servis edin.$$,
  ARRAY['2 haşlanmış patates', '2 haşlanmış yumurta', '1 yemek kaşığı yoğurt', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Taze maydanoz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Klasik Mercimek Çorbası',
  'lunch',
  310, 18, 45, 6,
  14,
  'photos/meals/klasik_mercimek_corbasi.webp',
  $$MALZEMELER:
- 100g haşlanmış kırmızı mercimek (kavanoz)
- 1 küçük kuru soğan (doğranmış)
- 1 havuç (rendelenmiş)
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Soğan ve havucu tereyağında 3 dakika sote edin.
2. Mercimeği ve 500 ml suyu ekleyip kaynatın.
3. Blendırla pürüzsüzleştirin, tuzu ekleyin.
4. Pul biberle süsleyip servis edin.$$,
  ARRAY['100g haşlanmış kırmızı mercimek', '1 küçük kuru soğan', '1 havuç', '1 yemek kaşığı tereyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Beyaz Pilav ve Sade Yoğurt',
  'lunch',
  450, 15, 72, 10,
  14,
  'photos/meals/beyaz_pilav_ve_sade_yogurt.webp',
  $$MALZEMELER:
- 80g pirinç
- 200g süzme yoğurt
- 1 yemek kaşığı tereyağı
- Tuz

HAZIRLANIŞI:
1. Pirinci yıkayıp 10 dakika sıcak suda bekletin.
2. Tereyağını tencerede eritip pirinci ekleyin, 1 dakika kavurun.
3. 200 ml sıcak su ve tuzu ekleyip kapağı kapatın, 12 dakika pişirin.
4. Pilavı dinlendirip yoğurtla servis edin.$$,
  ARRAY['80g pirinç', '200g süzme yoğurt', '1 yemek kaşığı tereyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Domates Soslu Sade Makarna',
  'lunch',
  430, 14, 72, 8,
  12,
  'photos/meals/domates_soslu_sade_makarna.webp',
  $$MALZEMELER:
- 100g makarna
- 2 yemek kaşığı domates salçası
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Makarnayı tuzlu suda paket talimatına göre haşlayın.
2. Soğanı zeytinyağında 2 dakika kavurun, salçayı ekleyip 1 dakika daha pişirin.
3. 100 ml sıcak suyla sosa kıvam verin.
4. Süzülmüş makarnayı sosa katıp baharatlandırın ve servis edin.$$,
  ARRAY['100g makarna', '2 yemek kaşığı domates salçası', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tereyağlı Limonlu Makarna',
  'lunch',
  450, 12, 68, 14,
  10,
  'photos/meals/tereyagli_limonlu_makarna.webp',
  $$MALZEMELER:
- 100g makarna
- 15g tereyağı
- 1/2 limon (suyu ve kabuğu rendesi)
- Tuz ve karabiber

HAZIRLANIŞI:
1. Makarnayı tuzlu suda haşlayıp süzün.
2. Aynı tencerede tereyağını eritin.
3. Limon suyu ve kabuğunu ekleyip karıştırın.
4. Makarnayı geri katın, baharatla servis edin.$$,
  ARRAY['100g makarna', '15g tereyağı', '1/2 limon', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuklu Bulgur Salatası',
  'lunch',
  440, 30, 50, 8,
  14,
  'photos/meals/tavuklu_bulgur_salatasi.webp',
  $$MALZEMELER:
- 80g pilavlık bulgur
- 120g pişmiş tavuk göğsü (kuşbaşı)
- 1 domates (küp)
- 1 salatalık (küp)
- 10 ml zeytinyağı
- 1/2 limon (suyu)

HAZIRLANIŞI:
1. Bulguru sıcak suda 10 dakika bekletip süzün.
2. Tavuğu, sebzeleri ve bulguru kasede birleştirin.
3. Zeytinyağı ve limon suyunu ekleyip karıştırın.
4. Tuzla tatlandırıp soğuk servis edin.$$,
  ARRAY['80g pilavlık bulgur', '120g pişmiş tavuk göğsü', '1 domates', '1 salatalık', '10 ml zeytinyağı', '1/2 limon'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Mercimek Yemeği',
  'lunch',
  320, 20, 45, 6,
  15,
  'photos/meals/sade_mercimek_yemegi.webp',
  $$MALZEMELER:
- 200g haşlanmış kırmızı mercimek
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı zeytinyağı
- 1 yemek kaşığı domates salçası
- 1 çay kaşığı kimyon
- Tuz

HAZIRLANIŞI:
1. Soğanı zeytinyağında 2 dakika kavurun.
2. Salçayı ekleyip 1 dakika daha kavurun.
3. Mercimeği ve 200 ml suyu ekleyin, 8 dakika kaynatın.
4. Kimyon ve tuzla baharatlandırın.$$,
  ARRAY['200g haşlanmış kırmızı mercimek', '1 küçük kuru soğan', '1 yemek kaşığı zeytinyağı', '1 yemek kaşığı domates salçası', '1 çay kaşığı kimyon', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yumurtalı Erişte',
  'lunch',
  420, 16, 55, 14,
  13,
  'photos/meals/yumurtali_eriste.webp',
  $$MALZEMELER:
- 80g erişte
- 2 yumurta
- 1 küçük kuru soğan (doğranmış)
- 5 ml tereyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Erişteyi tuzlu suda 8 dakika haşlayıp süzün.
2. Tereyağında soğanı 2 dakika kavurun.
3. Yumurtaları kırıp soğanla birlikte karıştırarak pişirin.
4. Erişteyi katın, baharatla harmanlayıp servis edin.$$,
  ARRAY['80g erişte', '2 yumurta', '1 küçük kuru soğan', '5 ml tereyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Şehriye Çorbası Yumurtalı',
  'lunch',
  300, 14, 40, 10,
  14,
  'photos/meals/sehriye_corbasi_yumurtali.webp',
  $$MALZEMELER:
- 60g arpa şehriye
- 1 yumurta
- 1/2 limon (suyu)
- 1 yemek kaşığı tereyağı
- 1 çay kaşığı kuru nane
- Tuz

HAZIRLANIŞI:
1. Tereyağında şehriyeyi 1 dakika kavurun.
2. 600 ml suyu ekleyip 8 dakika kaynatın.
3. Yumurtayı limon suyuyla çırpıp çorbaya ince akıtarak ekleyin, sürekli karıştırın.
4. Tuz ve naneyle tatlandırıp servis edin.$$,
  ARRAY['60g arpa şehriye', '1 yumurta', '1/2 limon', '1 yemek kaşığı tereyağı', '1 çay kaşığı kuru nane', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuk Suyu Pirinç Çorbası',
  'lunch',
  280, 12, 35, 9,
  15,
  'photos/meals/tavuk_suyu_pirinc_corbasi.webp',
  $$MALZEMELER:
- 60g pirinç
- 500 ml tavuk suyu
- 1 yumurta
- 1 yemek kaşığı tereyağı
- 1/2 limon (suyu)
- Tuz

HAZIRLANIŞI:
1. Pirinci yıkayıp tavuk suyuna ekleyin, 12 dakika kaynatın.
2. Yumurtayı limon suyuyla çırpıp çorbaya yavaşça ekleyin.
3. Tereyağını sıcakken üzerine ekleyin.
4. Tuzla tatlandırıp servis edin.$$,
  ARRAY['60g pirinç', '500 ml tavuk suyu', '1 yumurta', '1 yemek kaşığı tereyağı', '1/2 limon', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sebzeli Bulgur Pilavı',
  'lunch',
  430, 14, 72, 10,
  15,
  'photos/meals/sebzeli_bulgur_pilavi.webp',
  $$MALZEMELER:
- 80g pilavlık bulgur
- 1 küçük kuru soğan (doğranmış)
- 1 havuç (küp)
- 1 yeşil biber (doğranmış)
- 10 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Sebzeleri zeytinyağında 3 dakika sote edin.
2. Bulguru ekleyip 1 dakika kavurun.
3. 200 ml sıcak su ve tuzu ekleyin, kapağı kapatın.
4. Kısık ateşte 12 dakika pişirip dinlendirin.$$,
  ARRAY['80g pilavlık bulgur', '1 küçük kuru soğan', '1 havuç', '1 yeşil biber', '10 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pratik Patates Köftesi',
  'lunch',
  380, 14, 52, 12,
  15,
  'photos/meals/pratik_patates_koftesi.webp',
  $$MALZEMELER:
- 2 haşlanmış patates (ezilmiş)
- 50g un
- 1 yumurta
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Patates, un, yumurta ve soğanı yoğurun.
2. Karışımdan ceviz büyüklüğünde köfteler şekillendirin.
3. Yağlı tavada her tarafı altın olana kadar 5 dakika pişirin.
4. Sıcak servis edin.$$,
  ARRAY['2 haşlanmış patates', '50g un', '1 yumurta', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yumurtalı Sebze Sote',
  'lunch',
  310, 14, 22, 18,
  12,
  'photos/meals/yumurtali_sebze_sote.webp',
  $$MALZEMELER:
- 2 yumurta
- 1 küçük patlıcan (küp)
- 1 yeşil biber (doğranmış)
- 1 domates (doğranmış)
- 10 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Patlıcanı zeytinyağında 4 dakika kavurun.
2. Biber ve domatesi ekleyip 3 dakika daha pişirin.
3. Yumurtaları üzerine kırıp tuzlayın.
4. Yumurtalar tutana kadar 2 dakika pişirip servis edin.$$,
  ARRAY['2 yumurta', '1 küçük patlıcan', '1 yeşil biber', '1 domates', '10 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Patates Salatası',
  'lunch',
  340, 12, 45, 12,
  14,
  'photos/meals/yogurtlu_patates_salatasi.webp',
  $$MALZEMELER:
- 2 haşlanmış patates (küp)
- 150g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 5 ml zeytinyağı
- 1 yemek kaşığı kıyılmış maydanoz
- Tuz

HAZIRLANIŞI:
1. Yoğurda sarımsağı, tuzu ve zeytinyağını ekleyip karıştırın.
2. Patatesi karışıma katın.
3. Maydanozla süsleyin.
4. Soğuk servis edin.$$,
  ARRAY['2 haşlanmış patates', '150g süzme yoğurt', '1 diş sarımsak', '5 ml zeytinyağı', '1 yemek kaşığı kıyılmış maydanoz', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Hindi Etli Pratik Bulgur',
  'lunch',
  480, 35, 55, 10,
  15,
  'photos/meals/hindi_etli_pratik_bulgur.webp',
  $$MALZEMELER:
- 80g pilavlık bulgur
- 120g hindi göğsü (kıyılmış)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Soğanı zeytinyağında 2 dakika kavurun.
2. Hindi etini ekleyip rengi dönene kadar 4 dakika pişirin.
3. Salça, bulgur ve 200 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 8 dakika pişirin ve servis edin.$$,
  ARRAY['80g pilavlık bulgur', '120g hindi göğsü', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuk Göğsü Salatası',
  'lunch',
  340, 40, 14, 12,
  12,
  'photos/meals/tavuk_gogsu_salatasi.webp',
  $$MALZEMELER:
- 150g pişmiş tavuk göğsü (dilimlenmiş)
- 2 avuç marul
- 1 domates (dilimlenmiş)
- 1 salatalık (dilimlenmiş)
- 10 ml zeytinyağı
- 1/2 limon (suyu)

HAZIRLANIŞI:
1. Marul, domates ve salatalığı kasede karıştırın.
2. Tavuğu üzerine yerleştirin.
3. Zeytinyağı, limon suyu ve tuzla soslu yapın.
4. Hemen servis edin.$$,
  ARRAY['150g pişmiş tavuk göğsü', '2 avuç marul', '1 domates', '1 salatalık', '10 ml zeytinyağı', '1/2 limon'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Patates Çorbası',
  'lunch',
  260, 8, 40, 8,
  15,
  'photos/meals/patates_corbasi.webp',
  $$MALZEMELER:
- 2 patates (küp)
- 1 küçük kuru soğan
- 1 havuç (rendelenmiş)
- 1 yemek kaşığı tereyağı
- 500 ml su
- Tuz

HAZIRLANIŞI:
1. Tereyağında soğan ve havucu 2 dakika kavurun.
2. Patates ve suyu ekleyip 10 dakika kaynatın.
3. Blendırla pürüzsüzleştirin.
4. Tuzla tatlandırıp servis edin.$$,
  ARRAY['2 patates', '1 küçük kuru soğan', '1 havuç', '1 yemek kaşığı tereyağı', '500 ml su', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Soğan-Domates Çorbası',
  'lunch',
  220, 8, 30, 8,
  14,
  'photos/meals/sogan_domates_corbasi.webp',
  $$MALZEMELER:
- 2 büyük kuru soğan (ince doğranmış)
- 2 olgun domates (rendelenmiş)
- 1 yemek kaşığı tereyağı
- 1 dilim tam buğday ekmeği (kruton)
- 500 ml su
- Tuz

HAZIRLANIŞI:
1. Soğanları tereyağında karamelize olana kadar 5 dakika kavurun.
2. Domates ve suyu ekleyip 7 dakika kaynatın.
3. Tuzu ekleyin ve kaselere paylaştırın.
4. Üzerine ekmek krutonlarını yerleştirip servis edin.$$,
  ARRAY['2 büyük kuru soğan', '2 olgun domates', '1 yemek kaşığı tereyağı', '1 dilim tam buğday ekmeği', '500 ml su', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Beyaz Peynirli Sade Makarna',
  'lunch',
  470, 22, 65, 14,
  11,
  'photos/meals/beyaz_peynirli_sade_makarna.webp',
  $$MALZEMELER:
- 100g makarna
- 60g beyaz peynir (ezilmiş)
- 10 ml zeytinyağı
- 1 yemek kaşığı kuru nane
- Tuz

HAZIRLANIŞI:
1. Makarnayı tuzlu suda haşlayıp süzün.
2. Aynı tencerede zeytinyağını ısıtın.
3. Makarnayı geri katın, peyniri ekleyip karıştırın.
4. Naneyle süsleyip sıcak servis edin.$$,
  ARRAY['100g makarna', '60g beyaz peynir', '10 ml zeytinyağı', '1 yemek kaşığı kuru nane', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
-- ============================ Akşam Yemeği (20) ============================
(
  'Tavuk Sote ve Pilav',
  'dinner',
  560, 45, 60, 12,
  15,
  'photos/meals/tavuk_sote_ve_pilav.webp',
  $$MALZEMELER:
- 150g tavuk göğsü (kuşbaşı)
- 60g pirinç
- 1 küçük kuru soğan
- 1 yemek kaşığı domates salçası
- 10 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Pirinci tereyağsız tencerede 200 ml sıcak suyla 12 dakika pişirin.
2. Aynı süre içinde tavuğu zeytinyağında 4 dakika kavurun.
3. Soğan ve salçayı ekleyip 4 dakika daha pişirin.
4. Pilavı tabağa alın, üzerine soteyi koyup servis edin.$$,
  ARRAY['150g tavuk göğsü', '60g pirinç', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '10 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tencerede Sebzeli Yumurta',
  'dinner',
  290, 16, 16, 18,
  12,
  'photos/meals/tencerede_sebzeli_yumurta.webp',
  $$MALZEMELER:
- 2 yumurta
- 1 patates (küp)
- 1 yeşil biber (doğranmış)
- 1 domates (doğranmış)
- 10 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Patatesleri zeytinyağında 6 dakika kavurun.
2. Biber ve domatesi ekleyip 3 dakika daha pişirin.
3. Yumurtaları üzerine kırıp baharatlandırın.
4. Kapağı kapatıp 2 dakika pişirip servis edin.$$,
  ARRAY['2 yumurta', '1 patates', '1 yeşil biber', '1 domates', '10 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Soğanlı Hızlı Tavuk Sote',
  'dinner',
  440, 55, 12, 18,
  15,
  'photos/meals/soganli_hizli_tavuk_sote.webp',
  $$MALZEMELER:
- 200g tavuk göğsü (kuşbaşı)
- 2 büyük kuru soğan (ince dilim)
- 10 ml zeytinyağı
- 1 yemek kaşığı domates salçası
- Tuz ve karabiber

HAZIRLANIŞI:
1. Soğanları zeytinyağında karamelize olana kadar 4 dakika kavurun.
2. Tavuğu ekleyip rengi kapanana kadar 5 dakika pişirin.
3. Salçayı ve 50 ml sıcak suyu ekleyin.
4. Kapağı kapatıp 5 dakika daha pişirin ve servis edin.$$,
  ARRAY['200g tavuk göğsü', '2 büyük kuru soğan', '10 ml zeytinyağı', '1 yemek kaşığı domates salçası', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Domates Soslu Köfte',
  'dinner',
  480, 30, 22, 30,
  15,
  'photos/meals/domates_soslu_kofte.webp',
  $$MALZEMELER:
- 200g hazır köfte harcı
- 2 olgun domates (rendelenmiş)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Köfte harcından küçük topaklar şekillendirip tavada 5 dakika pişirin.
2. Soğanı ayrı tavada zeytinyağıyla 2 dakika kavurun.
3. Domatesleri ekleyip 5 dakika kaynatın.
4. Köfteleri sosa katıp 2 dakika daha pişirin.$$,
  ARRAY['200g hazır köfte harcı', '2 olgun domates', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tencerede Patates Köftesi',
  'dinner',
  520, 26, 55, 22,
  15,
  'photos/meals/tencerede_patates_koftesi.webp',
  $$MALZEMELER:
- 200g hazır köfte harcı
- 2 patates (küp)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 10 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Köftelerden topaklar yapın, zeytinyağında 4 dakika kavurun.
2. Patates ve soğanı ekleyip 3 dakika daha pişirin.
3. Salça ve 200 ml sıcak suyu ilave edin.
4. Kapağı kapatıp 8 dakika pişirin.$$,
  ARRAY['200g hazır köfte harcı', '2 patates', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '10 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Hızlı Tavuk Pirzola',
  'dinner',
  380, 45, 4, 20,
  15,
  'photos/meals/hizli_tavuk_pirzola.webp',
  $$MALZEMELER:
- 200g tavuk pirzola
- 5 ml zeytinyağı
- 1 diş sarımsak (ezilmiş)
- 1/2 limon (suyu)
- Tuz ve karabiber

HAZIRLANIŞI:
1. Pirzolayı zeytinyağı, sarımsak, limon ve baharatla 5 dakika marine edin.
2. Kızgın ızgara tavada her yüzünü 4 dakika pişirin.
3. Kapağı kapatıp 2 dakika dinlendirin.
4. Sıcak servis edin.$$,
  ARRAY['200g tavuk pirzola', '5 ml zeytinyağı', '1 diş sarımsak', '1/2 limon', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Köfte Tava',
  'dinner',
  420, 30, 4, 30,
  12,
  'photos/meals/sade_kofte_tava.webp',
  $$MALZEMELER:
- 200g hazır köfte harcı
- 5 ml zeytinyağı
- 1 çay kaşığı kimyon
- Tuz ve karabiber

HAZIRLANIŞI:
1. Köfteleri yuvarlayıp baharatlarla harmanlayın.
2. Yağlı tavada her yüzünü 4 dakika pişirin.
3. Kapağı kapatıp 2 dakika dinlendirin.
4. Sıcak servis edin.$$,
  ARRAY['200g hazır köfte harcı', '5 ml zeytinyağı', '1 çay kaşığı kimyon', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Salçalı Tavada Yumurta',
  'dinner',
  320, 16, 14, 22,
  8,
  'photos/meals/salcali_tavada_yumurta.webp',
  $$MALZEMELER:
- 3 yumurta
- 2 yemek kaşığı domates salçası
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Soğanı zeytinyağında 2 dakika kavurun.
2. Salçayı ve 50 ml su ekleyip 2 dakika daha pişirin.
3. Yumurtaları üzerine kırın, baharatları serpin.
4. Kapağı kapatıp 3 dakika pişirip servis edin.$$,
  ARRAY['3 yumurta', '2 yemek kaşığı domates salçası', '1 küçük kuru soğan', '10 ml zeytinyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sebzeli Pratik Köfte',
  'dinner',
  440, 26, 30, 22,
  15,
  'photos/meals/sebzeli_pratik_kofte.webp',
  $$MALZEMELER:
- 200g hazır köfte harcı
- 1 küçük kuru soğan (doğranmış)
- 1 yeşil biber (doğranmış)
- 1 havuç (rendelenmiş)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Köfte harcı ve sebzeleri yoğurun.
2. Topaklar şekillendirip zeytinyağında 6 dakika pişirin.
3. Çevirin, 4 dakika daha pişirin.
4. Sıcak servis edin.$$,
  ARRAY['200g hazır köfte harcı', '1 küçük kuru soğan', '1 yeşil biber', '1 havuç', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuklu Bulgur Pilavı',
  'dinner',
  520, 40, 65, 12,
  15,
  'photos/meals/tavuklu_bulgur_pilavi.webp',
  $$MALZEMELER:
- 80g pilavlık bulgur
- 150g tavuk göğsü (kuşbaşı)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı tereyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Tavuğu tereyağında 4 dakika kavurun.
2. Soğanı ekleyip 2 dakika daha pişirin.
3. Bulguru ekleyip 1 dakika kavurun, 200 ml sıcak su ve baharatları ilave edin.
4. Kapağı kapatıp 10 dakika pişirin ve dinlendirin.$$,
  ARRAY['80g pilavlık bulgur', '150g tavuk göğsü', '1 küçük kuru soğan', '1 yemek kaşığı tereyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Patates Tavası',
  'dinner',
  340, 8, 55, 12,
  14,
  'photos/meals/sade_patates_tavasi.webp',
  $$MALZEMELER:
- 3 patates (parmak doğranmış)
- 10 ml zeytinyağı
- 1 çay kaşığı pul biber
- 1 çay kaşığı kuru kekik
- Tuz

HAZIRLANIŞI:
1. Patatesleri yağlı tavada 8 dakika kavurun.
2. Çevirin, 4 dakika daha pişirin.
3. Tuz, pul biber ve kekik serpin.
4. Sıcak servis edin.$$,
  ARRAY['3 patates', '10 ml zeytinyağı', '1 çay kaşığı pul biber', '1 çay kaşığı kuru kekik', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Domatesli Sade Tavuk',
  'dinner',
  420, 45, 14, 18,
  15,
  'photos/meals/domatesli_sade_tavuk.webp',
  $$MALZEMELER:
- 200g tavuk göğsü (kuşbaşı)
- 2 olgun domates (doğranmış)
- 1 yeşil biber (doğranmış)
- 5 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Tavuğu zeytinyağında 4 dakika kavurun.
2. Biberi ekleyip 2 dakika sote edin.
3. Domatesleri ekleyip suyunu salana kadar 5 dakika pişirin.
4. Baharatlandırıp servis edin.$$,
  ARRAY['200g tavuk göğsü', '2 olgun domates', '1 yeşil biber', '5 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Sade Tavuk Sote',
  'dinner',
  480, 50, 14, 22,
  15,
  'photos/meals/yogurtlu_sade_tavuk_sote.webp',
  $$MALZEMELER:
- 200g tavuk göğsü (kuşbaşı)
- 150g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 5 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Tavuğu zeytinyağında 5 dakika kavurun.
2. Sarımsağı ekleyip 1 dakika kavurun.
3. Soslu kıvam için 50 ml sıcak su ilave edin, kapakla 5 dakika pişirin.
4. Yoğurdu ocağın altını kapattıktan sonra ekleyip servis edin.$$,
  ARRAY['200g tavuk göğsü', '150g süzme yoğurt', '1 diş sarımsak', '5 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pratik Yoğurtlu Mantı',
  'dinner',
  560, 22, 72, 22,
  14,
  'photos/meals/pratik_yogurtlu_manti.webp',
  $$MALZEMELER:
- 150g hazır pişmiş mantı
- 200g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 15g tereyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Mantıyı kaynar tuzlu suda paket talimatına göre haşlayın.
2. Yoğurda sarımsağı ve tuzu karıştırın.
3. Tereyağını eritip pul biberi içinde yakın.
4. Mantıyı tabağa alın, yoğurdu ve tereyağ sosunu üzerine gezdirin.$$,
  ARRAY['150g hazır pişmiş mantı', '200g süzme yoğurt', '1 diş sarımsak', '15g tereyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tavuk-Patates Tencere',
  'dinner',
  520, 40, 52, 16,
  15,
  'photos/meals/tavuk_patates_tencere.webp',
  $$MALZEMELER:
- 150g tavuk göğsü (kuşbaşı)
- 2 patates (küp)
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Tavuğu zeytinyağında 4 dakika kavurun.
2. Soğan ve patatesi ekleyip 3 dakika daha pişirin.
3. Salça ve 200 ml sıcak suyu ilave edin.
4. Kapağı kapatıp 8 dakika pişirin.$$,
  ARRAY['150g tavuk göğsü', '2 patates', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yumurtalı Patates Tava',
  'dinner',
  380, 18, 40, 16,
  13,
  'photos/meals/yumurtali_patates_tava.webp',
  $$MALZEMELER:
- 3 patates (küp)
- 2 yumurta
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Patatesleri zeytinyağında 7 dakika kavurun.
2. Soğanı ekleyip 2 dakika daha pişirin.
3. Yumurtaları üzerine kırıp baharatları serpin.
4. Yumurtalar tutana kadar 3 dakika pişirin.$$,
  ARRAY['3 patates', '2 yumurta', '1 küçük kuru soğan', '10 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Kıymalı Sade Makarna',
  'dinner',
  520, 30, 65, 16,
  15,
  'photos/meals/kiymali_sade_makarna.webp',
  $$MALZEMELER:
- 100g makarna
- 100g dana kıyma
- 1 küçük kuru soğan (doğranmış)
- 1 yemek kaşığı domates salçası
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Makarnayı tuzlu suda haşlayıp süzün.
2. Soğanı zeytinyağında 2 dakika kavurun.
3. Kıymayı ekleyip rengi dönene kadar 4 dakika pişirin, salçayı ekleyin.
4. Makarnayı sosa katıp servis edin.$$,
  ARRAY['100g makarna', '100g dana kıyma', '1 küçük kuru soğan', '1 yemek kaşığı domates salçası', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tava Pırasası Yumurtalı',
  'dinner',
  320, 16, 22, 18,
  12,
  'photos/meals/tava_pirasasi_yumurtali.webp',
  $$MALZEMELER:
- 1 büyük pırasa (dilimlenmiş)
- 2 yumurta
- 1 küçük kuru soğan (doğranmış)
- 10 ml zeytinyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Soğan ve pırasayı zeytinyağında 5 dakika kavurun.
2. 50 ml su ekleyip kapakla 4 dakika pişirin.
3. Yumurtaları üzerine kırıp baharatlandırın.
4. Yumurtalar tuttuğunda servis edin.$$,
  ARRAY['1 büyük pırasa', '2 yumurta', '1 küçük kuru soğan', '10 ml zeytinyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sucuklu Sade Patates',
  'dinner',
  520, 22, 45, 30,
  14,
  'photos/meals/sucuklu_sade_patates.webp',
  $$MALZEMELER:
- 3 patates (küp)
- 60g sucuk (dilimlenmiş)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Patatesleri zeytinyağında 7 dakika kavurun.
2. Sucuk dilimlerini ekleyip 2 dakika daha pişirin.
3. Soğanı katıp 3 dakika kavurun.
4. Tuz ve pul biberle servis edin.$$,
  ARRAY['3 patates', '60g sucuk', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Salçalı Yumurtalı Köfte',
  'dinner',
  440, 26, 16, 30,
  15,
  'photos/meals/salcali_yumurtali_kofte.webp',
  $$MALZEMELER:
- 150g hazır köfte harcı
- 2 yumurta
- 2 yemek kaşığı domates salçası
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Köftelerden topaklar yapıp tavada 4 dakika kavurun.
2. Soğan ve salçayı ekleyip 100 ml suyla pişirin.
3. Yumurtaları sosun üzerine kırıp baharatlandırın.
4. Kapağı kapatıp yumurtalar tutana kadar 3 dakika pişirin.$$,
  ARRAY['150g hazır köfte harcı', '2 yumurta', '2 yemek kaşığı domates salçası', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
-- ============================ Atıştırmalıklar (20) ============================
(
  'Ev Yapımı Patates Cipsi',
  'snack',
  220, 4, 35, 10,
  15,
  'photos/meals/ev_yapimi_patates_cipsi.webp',
  $$MALZEMELER:
- 2 patates (ince dilim)
- 5 ml zeytinyağı
- 1 çay kaşığı pul biber
- Tuz

HAZIRLANIŞI:
1. Patates dilimlerini zeytinyağı, tuz ve baharatla karıştırın.
2. Yapışmaz tavada her yüzünü 5 dakika pişirin.
3. Kıtırlaşana kadar arada çevirin.
4. Sıcak servis edin.$$,
  ARRAY['2 patates', '5 ml zeytinyağı', '1 çay kaşığı pul biber', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Salatalık Sticks ve Yoğurt Sosu',
  'snack',
  140, 10, 14, 4,
  5,
  'photos/meals/salatalik_sticks_ve_yogurt_sosu.webp',
  $$MALZEMELER:
- 1 salatalık (parmak doğranmış)
- 150g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 1 çay kaşığı kuru nane
- Tuz

HAZIRLANIŞI:
1. Yoğurda sarımsak, nane ve tuzu ekleyip karıştırın.
2. Salatalık sticklerini tabağa dizin.
3. Sosu ortaya koyup hemen servis edin.$$,
  ARRAY['1 salatalık', '150g süzme yoğurt', '1 diş sarımsak', '1 çay kaşığı kuru nane', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Hazır Çiğ Köfte',
  'snack',
  260, 8, 45, 4,
  12,
  'photos/meals/hazir_cig_kofte.webp',
  $$MALZEMELER:
- 100g hazır çiğ köfte karışımı
- 2 avuç marul
- 1/2 limon (suyu)
- 1 dilim ekmek

HAZIRLANIŞI:
1. Çiğ köfte karışımını paket talimatına göre yoğurun.
2. Küçük top şekilleri verin.
3. Marul yapraklarına sarın.
4. Limonla servis edin.$$,
  ARRAY['100g hazır çiğ köfte karışımı', '2 avuç marul', '1/2 limon', '1 dilim ekmek'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Havuç Atıştırması',
  'snack',
  170, 8, 16, 8,
  8,
  'photos/meals/yogurtlu_havuc_atistirmasi.webp',
  $$MALZEMELER:
- 2 havuç (rendelenmiş)
- 150g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 5 ml zeytinyağı
- 1 yemek kaşığı kıyılmış maydanoz
- Tuz

HAZIRLANIŞI:
1. Havuçları zeytinyağında 3 dakika sote edin.
2. Soğutup yoğurda ekleyin.
3. Sarımsak, tuz ve maydanozu karıştırın.
4. Soğuk servis edin.$$,
  ARRAY['2 havuç', '150g süzme yoğurt', '1 diş sarımsak', '5 ml zeytinyağı', '1 yemek kaşığı kıyılmış maydanoz', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Domates Salatası',
  'snack',
  90, 3, 8, 5,
  5,
  'photos/meals/sade_domates_salatasi.webp',
  $$MALZEMELER:
- 2 olgun domates (doğranmış)
- 1 küçük kuru soğan (ince dilim)
- 5 ml zeytinyağı
- 1 çay kaşığı kuru kekik
- Tuz

HAZIRLANIŞI:
1. Domates ve soğanı kasede karıştırın.
2. Zeytinyağı ve baharatları ekleyin.
3. Hafifçe karıştırıp servis edin.$$,
  ARRAY['2 olgun domates', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 çay kaşığı kuru kekik', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Soğanlı Marul Salatası',
  'snack',
  120, 4, 12, 6,
  5,
  'photos/meals/soganli_marul_salatasi.webp',
  $$MALZEMELER:
- 2 avuç marul (parçalanmış)
- 1 küçük mor soğan (ince dilim)
- 1 domates (dilimlenmiş)
- 5 ml zeytinyağı
- 1/2 limon (suyu)
- Tuz

HAZIRLANIŞI:
1. Marul, soğan ve domatesi kasede toplayın.
2. Zeytinyağı, limon ve tuzu ekleyin.
3. Hafifçe karıştırıp servis edin.$$,
  ARRAY['2 avuç marul', '1 küçük mor soğan', '1 domates', '5 ml zeytinyağı', '1/2 limon', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yumurtalı Sade Krep',
  'snack',
  260, 14, 22, 14,
  10,
  'photos/meals/yumurtali_sade_krep.webp',
  $$MALZEMELER:
- 1 yumurta
- 40g un
- 100 ml süt
- 5 ml tereyağı
- Tuz

HAZIRLANIŞI:
1. Yumurta, un ve sütü pürüzsüz olana kadar çırpın.
2. Yağlı tavaya az miktar harç dökerek krep pişirin.
3. Her yüzünü 1 dakika kızartın.
4. Tabağa alıp ruloya sarıp servis edin.$$,
  ARRAY['1 yumurta', '40g un', '100 ml süt', '5 ml tereyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yumurta-Peynirli Sandviç',
  'snack',
  340, 22, 30, 16,
  7,
  'photos/meals/yumurta_peynirli_sandvic.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 1 haşlanmış yumurta (dilimlenmiş)
- 40g beyaz peynir
- 1 yaprak marul
- 1 dilim domates
- Tuz

HAZIRLANIŞI:
1. Ekmek dilimlerinin iç yüzeyine peyniri ezerek sürün.
2. Yumurta dilimlerini ve domatesi yerleştirin.
3. Marul yaprağını ekleyin, kapatın.
4. Tuz serpip servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '1 haşlanmış yumurta', '40g beyaz peynir', '1 yaprak marul', '1 dilim domates', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Domates ve Beyaz Peynir Tabağı',
  'snack',
  190, 12, 8, 12,
  4,
  'photos/meals/domates_ve_beyaz_peynir_tabagi.webp',
  $$MALZEMELER:
- 2 olgun domates (dilimlenmiş)
- 60g beyaz peynir
- 5 zeytin
- 5 ml zeytinyağı
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Domates dilimlerini tabağa dizin.
2. Beyaz peyniri yan tarafa yerleştirin.
3. Zeytin ve naneyi ekleyin.
4. Üzerine zeytinyağı gezdirip servis edin.$$,
  ARRAY['2 olgun domates', '60g beyaz peynir', '5 zeytin', '5 ml zeytinyağı', 'Taze nane'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Salatalık ve Beyaz Peynir',
  'snack',
  160, 12, 8, 10,
  4,
  'photos/meals/salatalik_ve_beyaz_peynir.webp',
  $$MALZEMELER:
- 1 salatalık (dilimlenmiş)
- 60g beyaz peynir
- 5 ml zeytinyağı
- Birkaç yaprak taze nane

HAZIRLANIŞI:
1. Salatalık dilimlerini tabağa dizin.
2. Beyaz peyniri kenara yerleştirin.
3. Zeytinyağını üzerine gezdirin.
4. Naneyle süsleyip servis edin.$$,
  ARRAY['1 salatalık', '60g beyaz peynir', '5 ml zeytinyağı', 'Taze nane'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Patates Püresi',
  'snack',
  260, 6, 40, 8,
  14,
  'photos/meals/sade_patates_puresi.webp',
  $$MALZEMELER:
- 3 patates
- 60 ml süt
- 10g tereyağı
- Tuz ve karabiber

HAZIRLANIŞI:
1. Patatesleri haşlayıp süzün.
2. Tereyağı ve sütü ekleyin.
3. Pürüzsüz olana kadar ezin.
4. Tuz ve karabiberle servis edin.$$,
  ARRAY['3 patates', '60 ml süt', '10g tereyağı', 'Tuz ve karabiber'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Mısır Salatası',
  'snack',
  180, 6, 30, 4,
  5,
  'photos/meals/sade_misir_salatasi.webp',
  $$MALZEMELER:
- 1 kutu mısır (suyu süzülmüş)
- 1 yeşil biber (doğranmış)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1/2 limon (suyu)
- Tuz

HAZIRLANIŞI:
1. Mısır, biber ve soğanı kasede karıştırın.
2. Zeytinyağı ve limon suyunu ekleyin.
3. Tuzla harmanlayın.
4. Soğuk servis edin.$$,
  ARRAY['1 kutu mısır', '1 yeşil biber', '1 küçük kuru soğan', '5 ml zeytinyağı', '1/2 limon', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sarımsaklı Cacık',
  'snack',
  130, 9, 10, 6,
  6,
  'photos/meals/sarimsakli_cacik.webp',
  $$MALZEMELER:
- 200g yoğurt
- 1 salatalık (rendelenmiş)
- 1 diş sarımsak (ezilmiş)
- 100 ml soğuk su
- 1 çay kaşığı kuru nane
- Tuz

HAZIRLANIŞI:
1. Salatalığın suyunu süzün.
2. Yoğurda salatalığı, sarımsağı, soğuk suyu, naneyi ve tuzu ekleyip karıştırın.
3. Buzdolabında 5 dakika dinlendirin.
4. Soğuk servis edin.$$,
  ARRAY['200g yoğurt', '1 salatalık', '1 diş sarımsak', '100 ml soğuk su', '1 çay kaşığı kuru nane', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Köy Ekmeği ve Tereyağı',
  'snack',
  250, 6, 35, 10,
  3,
  'photos/meals/sade_koy_ekmegi_ve_tereyagi.webp',
  $$MALZEMELER:
- 2 dilim köy ekmeği
- 15g tereyağı
- Tuz

HAZIRLANIŞI:
1. Ekmek dilimlerini hafifçe ısıtın.
2. Tereyağını sıcakken sürün.
3. Bir tutam tuz serpip servis edin.$$,
  ARRAY['2 dilim köy ekmeği', '15g tereyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Karışık Zeytin ve Peynir Tabağı',
  'snack',
  240, 12, 8, 18,
  4,
  'photos/meals/karisik_zeytin_ve_peynir_tabagi.webp',
  $$MALZEMELER:
- 10 zeytin (yeşil ve siyah)
- 60g beyaz peynir
- 5 ml zeytinyağı
- 1 çay kaşığı kuru kekik

HAZIRLANIŞI:
1. Zeytinleri tabağa dizin.
2. Beyaz peyniri yan tarafa yerleştirin.
3. Üzerine zeytinyağı ve kekik serpin.
4. Servis edin.$$,
  ARRAY['10 zeytin', '60g beyaz peynir', '5 ml zeytinyağı', '1 çay kaşığı kuru kekik'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tahinli Sade Yoğurt',
  'snack',
  280, 12, 16, 18,
  3,
  'photos/meals/tahinli_sade_yogurt.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 yemek kaşığı tahin
- 1 yemek kaşığı bal
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Tahin ve balı üzerine sürün.
3. Tarçınla süsleyip servis edin.$$,
  ARRAY['200g süzme yoğurt', '1 yemek kaşığı tahin', '1 yemek kaşığı bal', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Patlıcan Ezmesi',
  'snack',
  220, 8, 14, 14,
  15,
  'photos/meals/yogurtlu_patlican_ezmesi.webp',
  $$MALZEMELER:
- 1 közlenmiş patlıcan
- 100g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 5 ml zeytinyağı
- 1 yemek kaşığı kıyılmış maydanoz
- Tuz

HAZIRLANIŞI:
1. Közlenmiş patlıcanı kabuğunu soyup ezin.
2. Yoğurt, sarımsak ve tuzu ekleyip karıştırın.
3. Zeytinyağını üzerine gezdirin.
4. Maydanozla süsleyip servis edin.$$,
  ARRAY['1 közlenmiş patlıcan', '100g süzme yoğurt', '1 diş sarımsak', '5 ml zeytinyağı', '1 yemek kaşığı kıyılmış maydanoz', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Bulgurlu Salata',
  'snack',
  260, 8, 45, 6,
  12,
  'photos/meals/sade_bulgurlu_salata.webp',
  $$MALZEMELER:
- 80g ince bulgur
- 1 domates (doğranmış)
- 1 salatalık (doğranmış)
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- 1 yemek kaşığı kıyılmış maydanoz

HAZIRLANIŞI:
1. Bulguru sıcak suda 10 dakika bekletip süzün.
2. Sebzeleri ve maydanozu kasede karıştırın.
3. Bulguru ekleyip zeytinyağıyla harmanlayın.
4. Tuzlayıp servis edin.$$,
  ARRAY['80g ince bulgur', '1 domates', '1 salatalık', '1 küçük kuru soğan', '5 ml zeytinyağı', '1 yemek kaşığı kıyılmış maydanoz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Çiğ Sebze ve Yoğurtlu Sos',
  'snack',
  160, 9, 14, 8,
  5,
  'photos/meals/cig_sebze_ve_yogurtlu_sos.webp',
  $$MALZEMELER:
- 1 havuç (parmak)
- 1 salatalık (parmak)
- 1 yeşil biber (parmak)
- 150g süzme yoğurt
- 1 diş sarımsak (ezilmiş)
- 1 çay kaşığı kuru nane

HAZIRLANIŞI:
1. Sebzeleri parmak şeklinde doğrayıp tabağa dizin.
2. Yoğurda sarımsak ve naneyi karıştırın.
3. Sosu kase içinde tabağa koyun.
4. Hemen servis edin.$$,
  ARRAY['1 havuç', '1 salatalık', '1 yeşil biber', '150g süzme yoğurt', '1 diş sarımsak', '1 çay kaşığı kuru nane'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Patates Pofuduk',
  'snack',
  260, 8, 40, 9,
  14,
  'photos/meals/patates_pofuduk.webp',
  $$MALZEMELER:
- 2 haşlanmış patates (ezilmiş)
- 40g un
- 1 yumurta
- 1 küçük kuru soğan (doğranmış)
- 5 ml zeytinyağı
- Tuz

HAZIRLANIŞI:
1. Patates, un, yumurta, soğan ve tuzu yoğurun.
2. Karışımdan küçük topaklar yapın.
3. Yapışmaz tavada her yüzünü 4 dakika pişirin.
4. Sıcak servis edin.$$,
  ARRAY['2 haşlanmış patates', '40g un', '1 yumurta', '1 küçük kuru soğan', '5 ml zeytinyağı', 'Tuz'],
  ARRAY['Pratik & Ekonomik']
),
-- ============================ Tatlı Çeşitleri (20) ============================
(
  'Hızlı İrmik Helvası',
  'dessert',
  380, 6, 55, 14,
  14,
  'photos/meals/hizli_irmik_helvasi.webp',
  $$MALZEMELER:
- 100g irmik
- 50g tereyağı
- 60g toz şeker
- 300 ml süt
- 15g çam fıstığı

HAZIRLANIŞI:
1. Tereyağında çam fıstıklarını 1 dakika kavurun.
2. İrmiği ekleyip pembeleşene kadar 4 dakika kavurun.
3. Süt ve şekeri ekleyip kıvam alana kadar karıştırın.
4. Ocaktan alıp 5 dakika dinlendirin, kalıba alıp servis edin.$$,
  ARRAY['100g irmik', '50g tereyağı', '60g toz şeker', '300 ml süt', '15g çam fıstığı'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tahin-Pekmez Topları',
  'dessert',
  310, 8, 40, 13,
  8,
  'photos/meals/tahin_pekmez_toplari.webp',
  $$MALZEMELER:
- 80g yulaf ezmesi
- 2 yemek kaşığı tahin
- 2 yemek kaşığı pekmez
- 15g toz hindistan cevizi

HAZIRLANIŞI:
1. Yulaf, tahin ve pekmezi yoğurun.
2. Karışımı 1 dakika dinlendirin.
3. Ceviz büyüklüğünde toplar yapıp hindistan cevizine bulayın.
4. Buzdolabında 5 dakika soğutup servis edin.$$,
  ARRAY['80g yulaf ezmesi', '2 yemek kaşığı tahin', '2 yemek kaşığı pekmez', '15g toz hindistan cevizi'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Muzlu Yoğurt Tatlısı',
  'dessert',
  260, 12, 35, 8,
  5,
  'photos/meals/muzlu_yogurt_tatlisi.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1 olgun muz (dilimlenmiş)
- 1 yemek kaşığı bal
- 15g ceviz (kırılmış)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Muz dilimlerini üzerine yerleştirin.
3. Bal ve cevizi ekleyin.
4. Tarçınla süsleyip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '1 olgun muz', '1 yemek kaşığı bal', '15g ceviz', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Cevizli Yoğurt Tatlısı',
  'dessert',
  290, 13, 22, 16,
  4,
  'photos/meals/cevizli_yogurt_tatlisi.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 20g ceviz (iri kırılmış)
- 1 yemek kaşığı bal
- 1 tutam tarçın
- 5g hindistan cevizi rendesi

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Bal ve cevizi üzerine ekleyin.
3. Tarçın ve hindistan cevizi rendesini serpin.
4. Hemen servis edin.$$,
  ARRAY['200g süzme yoğurt', '20g ceviz', '1 yemek kaşığı bal', '1 tutam tarçın', '5g hindistan cevizi rendesi'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Mikrodalgada Tarçınlı Elma',
  'dessert',
  160, 1, 35, 2,
  7,
  'photos/meals/mikrodalgada_tarcinli_elma.webp',
  $$MALZEMELER:
- 2 elma (küp doğranmış)
- 1 yemek kaşığı bal
- 1 çay kaşığı tarçın
- 5g tereyağı

HAZIRLANIŞI:
1. Elma küplerini mikrodalgaya uygun kaseye alın.
2. Bal, tarçın ve tereyağını ekleyin.
3. 800W güçte 4 dakika pişirin.
4. Karıştırıp servis edin.$$,
  ARRAY['2 elma', '1 yemek kaşığı bal', '1 çay kaşığı tarçın', '5g tereyağı'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Reçelli Yoğurt Kasesi',
  'dessert',
  240, 10, 35, 6,
  3,
  'photos/meals/receli_yogurt_kasesi.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 2 yemek kaşığı meyve reçeli
- 15g granola

HAZIRLANIŞI:
1. Yoğurdu kaseye alın.
2. Reçeli üzerine yerleştirin.
3. Granolayı serpip hemen servis edin.$$,
  ARRAY['200g süzme yoğurt', '2 yemek kaşığı meyve reçeli', '15g granola'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Çikolatalı Yulaf Topları',
  'dessert',
  320, 8, 40, 14,
  12,
  'photos/meals/cikolatali_yulaf_toplari.webp',
  $$MALZEMELER:
- 80g yulaf ezmesi
- 2 yemek kaşığı şekersiz kakao
- 2 yemek kaşığı bal
- 20g hindistan cevizi rendesi
- 15g fıstık ezmesi

HAZIRLANIŞI:
1. Yulaf, kakao, bal ve fıstık ezmesini yoğurun.
2. Karışımdan ceviz büyüklüğünde toplar yapın.
3. Hindistan cevizine bulayın.
4. Buzdolabında 5 dakika soğutup servis edin.$$,
  ARRAY['80g yulaf ezmesi', '2 yemek kaşığı şekersiz kakao', '2 yemek kaşığı bal', '20g hindistan cevizi rendesi', '15g fıstık ezmesi'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pekmezli Yoğurt Mousse',
  'dessert',
  260, 13, 35, 8,
  5,
  'photos/meals/pekmezli_yogurt_mousse.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 2 yemek kaşığı pekmez
- 10g toz şeker
- 15g ceviz

HAZIRLANIŞI:
1. Yoğurda toz şekeri ekleyip çırpın.
2. Pekmezi karışıma yedirin.
3. Kasede mermer desen oluşturun.
4. Cevizle süsleyip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '2 yemek kaşığı pekmez', '10g toz şeker', '15g ceviz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Limon-Bal Yoğurt',
  'dessert',
  220, 12, 22, 8,
  3,
  'photos/meals/limon_bal_yogurt.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 1/2 limon (suyu)
- 1 yemek kaşığı bal
- 1 tutam limon kabuğu rendesi

HAZIRLANIŞI:
1. Yoğurda limon suyunu ekleyip çırpın.
2. Balı yedirin.
3. Limon kabuğu rendesiyle süsleyip servis edin.$$,
  ARRAY['200g süzme yoğurt', '1/2 limon', '1 yemek kaşığı bal', '1 tutam limon kabuğu rendesi'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pratik Sütlaç',
  'dessert',
  320, 10, 55, 8,
  14,
  'photos/meals/pratik_sutlac.webp',
  $$MALZEMELER:
- 100g pişmiş pirinç
- 300 ml süt
- 40g toz şeker
- 1 yemek kaşığı pirinç unu
- 1 tutam tarçın

HAZIRLANIŞI:
1. Pirinç ve sütü tencereye alıp orta ateşte kaynatın.
2. Pirinç ununu az suyla açıp ekleyin.
3. Şekeri ekleyip kıvam alana kadar 6 dakika karıştırın.
4. Kaselere paylaştırıp tarçınla süsleyin.$$,
  ARRAY['100g pişmiş pirinç', '300 ml süt', '40g toz şeker', '1 yemek kaşığı pirinç unu', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Hindistan Cevizli Chia Pudingi',
  'dessert',
  310, 9, 30, 16,
  12,
  'photos/meals/hindistan_cevizli_chia_pudingi.webp',
  $$MALZEMELER:
- 25g chia tohumu
- 250 ml hindistan cevizi sütü
- 1 yemek kaşığı bal
- 20g hindistan cevizi rendesi
- 1 muz (dilimlenmiş)

HAZIRLANIŞI:
1. Chia, süt ve balı çırpıp 10 dakika dinlendirin.
2. Tekrar karıştırın, kaselere paylaştırın.
3. Muz dilimlerini ve hindistan cevizini ekleyin.
4. Soğuk servis edin.$$,
  ARRAY['25g chia tohumu', '250 ml hindistan cevizi sütü', '1 yemek kaşığı bal', '20g hindistan cevizi rendesi', '1 muz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Bal-Tarçınlı Ekmek Tatlısı',
  'dessert',
  340, 9, 52, 12,
  10,
  'photos/meals/bal_tarcinli_ekmek_tatlisi.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 1 yumurta
- 60 ml süt
- 15g tereyağı
- 2 yemek kaşığı bal
- 1 çay kaşığı tarçın

HAZIRLANIŞI:
1. Yumurta, süt ve tarçını çırpın.
2. Ekmek dilimlerini karışıma batırın.
3. Tereyağında her yüzünü 2 dakika kızartın.
4. Üzerine balı gezdirip sıcak servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '1 yumurta', '60 ml süt', '15g tereyağı', '2 yemek kaşığı bal', '1 çay kaşığı tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Yoğurtlu Çilek Mousse',
  'dessert',
  240, 12, 30, 7,
  6,
  'photos/meals/yogurtlu_cilek_mousse.webp',
  $$MALZEMELER:
- 200g süzme yoğurt
- 100g taze çilek (dilimlenmiş)
- 1 yemek kaşığı bal
- 10g toz şeker

HAZIRLANIŞI:
1. Çilekleri toz şekerle ezerek püre yapın.
2. Yoğurda balı ve çilek püresini yedirin.
3. Kaselere paylaştırın.
4. Bütün çilekle süsleyip soğuk servis edin.$$,
  ARRAY['200g süzme yoğurt', '100g taze çilek', '1 yemek kaşığı bal', '10g toz şeker'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Cevizli Hurma Topları',
  'dessert',
  310, 6, 40, 14,
  10,
  'photos/meals/cevizli_hurma_toplari.webp',
  $$MALZEMELER:
- 8 hurma (çekirdeksiz)
- 30g ceviz
- 15g hindistan cevizi rendesi
- 1 yemek kaşığı şekersiz kakao

HAZIRLANIŞI:
1. Hurma ve cevizleri rondodan geçirin.
2. Karışımdan ceviz büyüklüğünde toplar yapın.
3. Toplara önce kakao sonra hindistan cevizi bulayın.
4. Buzdolabında 5 dakika soğutup servis edin.$$,
  ARRAY['8 hurma', '30g ceviz', '15g hindistan cevizi rendesi', '1 yemek kaşığı şekersiz kakao'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Muz-Tahin Sandviç',
  'dessert',
  380, 10, 45, 18,
  5,
  'photos/meals/muz_tahin_sandvic.webp',
  $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 1 muz (dilimlenmiş)
- 2 yemek kaşığı tahin
- 1 yemek kaşığı pekmez

HAZIRLANIŞI:
1. Ekmek dilimlerine tahini sürün.
2. Muz dilimlerini yerleştirin.
3. Pekmezi gezdirin.
4. Kapatıp ikiye keserek servis edin.$$,
  ARRAY['2 dilim tam buğday ekmeği', '1 muz', '2 yemek kaşığı tahin', '1 yemek kaşığı pekmez'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Donmuş Muz Dilimleri',
  'dessert',
  220, 4, 40, 7,
  8,
  'photos/meals/donmus_muz_dilimleri.webp',
  $$MALZEMELER:
- 2 muz (önceden dondurulmuş)
- 40g bitter çikolata
- 15g hindistan cevizi rendesi
- 15g ceviz

HAZIRLANIŞI:
1. Çikolatayı benmari usulü eritin.
2. Donmuş muz dilimlerini çikolataya batırın.
3. Hindistan cevizi ve cevize bulayın.
4. Yağlı kağıda alıp 3 dakika daha donmaya bırakın.$$,
  ARRAY['2 muz', '40g bitter çikolata', '15g hindistan cevizi rendesi', '15g ceviz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pekmezli Süt Tatlısı',
  'dessert',
  280, 9, 45, 8,
  12,
  'photos/meals/pekmezli_sut_tatlisi.webp',
  $$MALZEMELER:
- 250 ml süt
- 1 yemek kaşığı nişasta
- 2 yemek kaşığı pekmez
- 15g ceviz (kırılmış)
- 1 tutam tarçın

HAZIRLANIŞI:
1. Nişastayı 50 ml soğuk sütle açın.
2. Kalan sütü tencerede kaynatın, nişasta karışımını ekleyip kıvam alana kadar 4 dakika pişirin.
3. Kaselere paylaştırın, üzerine pekmezi gezdirin.
4. Ceviz ve tarçınla süsleyin.$$,
  ARRAY['250 ml süt', '1 yemek kaşığı nişasta', '2 yemek kaşığı pekmez', '15g ceviz', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Tarçınlı Yulaf Tatlısı',
  'dessert',
  290, 9, 45, 8,
  8,
  'photos/meals/tarcinli_yulaf_tatlisi.webp',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 200 ml süt
- 1 yemek kaşığı bal
- 1 çay kaşığı tarçın
- 15g ceviz

HAZIRLANIŞI:
1. Yulaf ve sütü tencerede orta ateşte kaynatın.
2. Tarçını ekleyip 3 dakika daha pişirin.
3. Kaseye aktarın, üzerine balı gezdirin.
4. Cevizle süsleyip sıcak servis edin.$$,
  ARRAY['50g yulaf ezmesi', '200 ml süt', '1 yemek kaşığı bal', '1 çay kaşığı tarçın', '15g ceviz'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Sade Un Helvası',
  'dessert',
  340, 6, 45, 14,
  14,
  'photos/meals/sade_un_helvasi.webp',
  $$MALZEMELER:
- 80g un
- 40g tereyağı
- 50g toz şeker
- 300 ml su
- 15g çam fıstığı

HAZIRLANIŞI:
1. Tereyağında çam fıstığını 1 dakika kavurun.
2. Unu ekleyip altın renge gelene kadar 5 dakika kavurun.
3. Su ve şekeri ayrı tencerede ısıtıp helvaya yedirin.
4. Kıvam alınca dinlendirip kalıba alıp servis edin.$$,
  ARRAY['80g un', '40g tereyağı', '50g toz şeker', '300 ml su', '15g çam fıstığı'],
  ARRAY['Pratik & Ekonomik']
),
(
  'Pratik Muhallebi',
  'dessert',
  260, 8, 45, 6,
  14,
  'photos/meals/pratik_muhallebi.webp',
  $$MALZEMELER:
- 400 ml süt
- 40g toz şeker
- 20g pirinç unu
- 1 paket vanilya
- 1 tutam tarçın

HAZIRLANIŞI:
1. Pirinç ununu 50 ml soğuk sütle açın.
2. Kalan sütü tencerede ısıtın, şekeri ekleyin.
3. Pirinç unu karışımını ekleyip kıvam alana kadar 6 dakika karıştırın.
4. Vanilyayı ekleyip kaselere paylaştırın, tarçınla süsleyin.$$,
  ARRAY['400 ml süt', '40g toz şeker', '20g pirinç unu', '1 paket vanilya', '1 tutam tarçın'],
  ARRAY['Pratik & Ekonomik']
)
ON CONFLICT (title) DO NOTHING;

-- =============================================================================
-- Sanity check — should return 110 rows tagged with 'Pratik & Ekonomik'
-- after running this file on top of phase83_budget_meals.sql.
-- =============================================================================
-- SELECT meal_type, count(*)
--   FROM public.recipes
--   WHERE 'Pratik & Ekonomik' = ANY(tags)
--   GROUP BY meal_type
--   ORDER BY meal_type;
-- Expected: breakfast=22, dinner=23, lunch=22, snack=23, dessert=20
-- (Phase 83 pilot: 2 breakfast / 2 lunch / 3 dinner / 3 snack + this batch's
-- 20 each + 0 desserts in pilot.)
