-- =============================================================================
-- Phase 28: Category-balanced recipe seed
-- =============================================================================
-- 25 dietitian-grade recipes distributed across the 5 meal_type buckets the
-- new "Öğün Kategorileri" row on the nutrition tab navigates into:
--
--   • 5 Breakfast  (kahvaltı)
--   • 5 Lunch      (öğle yemeği)
--   • 5 Dinner     (akşam yemeği)
--   • 5 Snack      (ara öğün)
--   • 5 Dessert    (sporcu tatlısı)
--
-- Runs independently of the Phase 24 seed — both can coexist. Each recipe
-- carries realistic fitness-oriented macros, a full MALZEMELER + HAZIRLANIŞI
-- block in Turkish, and a tag array that the Discovery filter chips on the
-- nutrition tab will match against.
--
-- Re-running this file will create duplicates (no unique constraint on
-- `title`). To reset: `DELETE FROM public.recipes;` first, or target by
-- title range if you only want to scrub this seed.
-- =============================================================================

INSERT INTO public.recipes (
  title, meal_type, calories, protein, carbs, fat,
  prep_time_minutes, image_url, instructions, tags
) VALUES
-- ============================ Breakfast (5) ================================
(
  'Fıstık Ezmeli Protein Yulaf Ezmesi',
  'breakfast',
  420, 32, 52, 11,
  12,
  'https://images.unsplash.com/photo-1517093602195-b40af9688b92?w=800&q=80',
  $$MALZEMELER:
- 60g yulaf ezmesi
- 250 ml az yağlı süt
- 30g vanilyalı whey protein tozu
- 20g doğal fıstık ezmesi
- 1/2 muz (dilimlenmiş)
- 1 tatlı kaşığı chia tohumu
- Tarçın

HAZIRLANIŞI:
1. Yulafı sütle kısık ateşte 6 dakika lapalaştırın.
2. Ateşten alıp protein tozunu ılınınca karıştırarak ekleyin.
3. Kaseye aktarın, üzerine muz, fıstık ezmesi ve chia tohumunu koyun.
4. Tarçın serpip sıcak servis edin.$$,
  ARRAY['Yüksek Protein', 'Hacim']
),
(
  'Ispanaklı Peynirli Omlet',
  'breakfast',
  340, 28, 6, 22,
  10,
  'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=800&q=80',
  $$MALZEMELER:
- 3 bütün yumurta
- 1 avuç taze ıspanak
- 30g az yağlı beyaz peynir
- 5 ml zeytinyağı
- Tuz, karabiber, taze dereotu

HAZIRLANIŞI:
1. Yumurtaları çırpın, tuz ve karabiberi ekleyin.
2. Yapışmaz tavada zeytinyağını ısıtın, ıspanağı 1 dakika soteleyin.
3. Yumurta karışımını dökün, kenarlardan tutana kadar orta ateşte pişirin.
4. Peyniri ve dereotunu serpin, omleti ikiye katlayıp sıcak servis edin.$$,
  ARRAY['Yüksek Protein']
),
(
  'Avokadolu Yumurtalı Tam Buğday Tost',
  'breakfast',
  380, 18, 35, 18,
  8,
  'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=800&q=80',
  $$MALZEMELER:
- 2 dilim tam buğday ekmek
- 1/2 avokado
- 2 haşlanmış yumurta
- 1/2 limonun suyu
- Pul biber, tuz, karabiber
- Taze maydanoz

HAZIRLANIŞI:
1. Ekmek dilimlerini tostta 2 dakika kızartın.
2. Avokadoyu çatalla ezin, limon suyu ve tuzla karıştırın.
3. Avokado karışımını ekmeğin üzerine sürün.
4. Dilimlenmiş yumurtayı yerleştirin, pul biber ve maydanozla servis edin.$$,
  ARRAY['Sıkılaşma']
),
(
  'Meyveli Vegan Smoothie Kasesi',
  'breakfast',
  310, 14, 52, 7,
  7,
  'https://images.unsplash.com/photo-1502741224143-90386d7f8c82?w=800&q=80',
  $$MALZEMELER:
- 1 dondurulmuş muz
- 100g dondurulmuş karışık böğürtlen
- 200 ml badem sütü
- 15g bitkisel protein tozu
- 10g chia tohumu
- 15g granola
- 5g hindistancevizi rendesi

HAZIRLANIŞI:
1. Muz, böğürtlen, badem sütü ve protein tozunu blenderda pürüzsüz olana kadar çekin.
2. Geniş bir kaseye aktarın.
3. Üzerine chia tohumu, granola ve hindistancevizini serpiştirin.
4. Dilerseniz ilave taze meyvelerle süsleyip hemen servis edin.$$,
  ARRAY['Vegan', 'Düşük Kalori']
),
(
  'Chia Tohumlu Vegan Pancake',
  'breakfast',
  360, 12, 55, 10,
  15,
  'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=800&q=80',
  $$MALZEMELER:
- 80g tam buğday unu
- 15g chia tohumu
- 200 ml badem sütü
- 1 tatlı kaşığı kabartma tozu
- 15g akçaağaç şurubu
- 1 tatlı kaşığı vanilya özütü
- 80g taze böğürtlen

HAZIRLANIŞI:
1. Chia tohumunu 45 ml su ile 5 dakika şişirin.
2. Un, kabartma tozu, süt, akçaağaç şurubu, vanilya ve şişen chia jelini pürüzsüz çırpın.
3. Yapışmaz tavada orta ateşte her pankeki 2 dakika pişirin.
4. Pankekleri üst üste koyun, üzerine böğürtlen serpip servis edin.$$,
  ARRAY['Vegan']
),
-- ============================== Lunch (5) ==================================
(
  'Izgara Tavuklu Hafif Sezar Salata',
  'lunch',
  420, 38, 18, 22,
  15,
  'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&q=80',
  $$MALZEMELER:
- 150g tavuk göğsü fileto
- 1 büyük avuç marul
- 20g parmesan peyniri
- 20g tam buğday kruton
- 1 yemek kaşığı yağsız yoğurt
- 1 tatlı kaşığı dijon hardalı
- 5 ml zeytinyağı
- Tuz, karabiber, sarımsak tozu

HAZIRLANIŞI:
1. Tavuğu sarımsak tozu, tuz ve karabiberle marine edip ızgarada her yüzü 4 dakika pişirin.
2. Yoğurt, hardal, zeytinyağı ve bir tutam tuzu çırparak hafif sezar sosu hazırlayın.
3. Marulu sosla harmanlayın, parmesan ve krutonları ekleyin.
4. Dinlendirdiğiniz tavuğu dilimleyip üzerine yerleştirerek servis edin.$$,
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
(
  'Hindi Göğsülü Avokadolu Wrap',
  'lunch',
  480, 32, 45, 18,
  10,
  'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80',
  $$MALZEMELER:
- 1 büyük tam buğday tortilla
- 120g dilimli hindi göğsü
- 1/2 avokado
- 1 avuç roka
- 1 domates (dilimli)
- 1 yemek kaşığı humus
- 1 tatlı kaşığı limon suyu

HAZIRLANIŞI:
1. Tortillayı tavada hafifçe ısıtın.
2. Avokadoyu limon suyuyla ezin, tortillaya sürün.
3. Humus, hindi, roka ve domatesi sırayla yerleştirin.
4. Sıkıca sarın, ortadan kesip hemen servis edin.$$,
  ARRAY['Sıkılaşma']
),
(
  'Kırmızı Mercimek Çorbası ve Tam Buğday Ekmeği',
  'lunch',
  380, 18, 58, 7,
  25,
  'https://images.unsplash.com/photo-1547592180-85f173990554?w=800&q=80',
  $$MALZEMELER:
- 150g kırmızı mercimek
- 1 soğan
- 1 havuç
- 2 diş sarımsak
- 1 L sebze suyu
- 10 ml zeytinyağı
- 2 dilim tam buğday ekmek
- Kimyon, pul biber, tuz

HAZIRLANIŞI:
1. Soğan ve sarımsağı zeytinyağında 2 dakika kavurun.
2. Rendelenmiş havucu ekleyip 2 dakika daha pişirin.
3. Mercimek ve sebze suyunu ekleyin, kısık ateşte 20 dakika kaynatın.
4. Blenderdan geçirin, kimyon ve tuzla tatlandırın.
5. Ekmekle birlikte sıcak servis edin.$$,
  ARRAY['Vegan', 'Sıkılaşma']
),
(
  'Izgara Levrek ve Buharda Sebze',
  'lunch',
  360, 34, 22, 14,
  20,
  'https://images.unsplash.com/photo-1547496502-affa22d38842?w=800&q=80',
  $$MALZEMELER:
- 180g levrek fileto
- 120g brokoli
- 100g havuç
- 80g kabak
- 10 ml zeytinyağı
- 1 limon (dilimli)
- Taze dereotu, tuz, karabiber

HAZIRLANIŞI:
1. Levreği limon dilimleri ve dereotuyla marine edin.
2. Sebzeleri 6 dakika buharda pişirin.
3. Yapışmaz tavada levreği her yüzü 3 dakika ızgara yapın.
4. Zeytinyağını gezdirip sebzelerle birlikte servis edin.$$,
  ARRAY['Düşük Kalori', 'Yüksek Protein']
),
(
  'Vejetaryen Quinoa Power Bowl',
  'lunch',
  450, 20, 60, 14,
  18,
  'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80',
  $$MALZEMELER:
- 80g kinoa (kuru ölçü)
- 100g haşlanmış nohut
- 1 havuç (ince dilim)
- 50g mor lahana (rende)
- 1/2 avokado
- 15 ml tahin
- 1 limonun suyu
- Taze maydanoz, tuz, karabiber

HAZIRLANIŞI:
1. Kinoayı bolca suyla 15 dakika haşlayıp süzün.
2. Tahin, limon suyu ve 2 yemek kaşığı suyu çırparak sos yapın.
3. Kaseye kinoa, nohut, havuç, lahana ve avokadoyu sıralayın.
4. Tahin sosunu gezdirip maydanozla servis edin.$$,
  ARRAY['Vegan', 'Sıkılaşma']
),
-- ============================== Dinner (5) =================================
(
  'Izgara Bonfile ve Közlenmiş Sebze',
  'dinner',
  580, 48, 30, 28,
  25,
  'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80',
  $$MALZEMELER:
- 180g sığır bonfile
- 1 patlıcan (küp)
- 1 kabak (küp)
- 1 kırmızı biber (küp)
- 10 ml zeytinyağı
- 2 diş sarımsak
- Biberiye, tuz, karabiber

HAZIRLANIŞI:
1. Sebzeleri zeytinyağı, ezilmiş sarımsak ve baharatlarla karıştırın.
2. 200 derecede 18 dakika fırınlayın.
3. Bonfileyi oda sıcaklığına getirin, dökme demir tavada her yüzü 3 dakika mühürleyin.
4. 5 dakika dinlendirip dilimleyin, sebzelerle birlikte servis edin.$$,
  ARRAY['Yüksek Protein']
),
(
  'Fırında Hindi ve Esmer Pirinç',
  'dinner',
  620, 48, 65, 15,
  30,
  'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800&q=80',
  $$MALZEMELER:
- 200g hindi göğsü fileto
- 90g esmer pirinç (kuru ölçü)
- 100g mantar
- 1 diş sarımsak
- 10 ml zeytinyağı
- Kekik, tuz, karabiber

HAZIRLANIŞI:
1. Pirinci bolca suyla 25 dakika pişirin.
2. Hindiyi kekik, sarımsak ve baharatlarla ovun.
3. Fırın tepsisine alın, 200 derecede 20 dakika fırınlayın.
4. Son 6 dakika mantarları ekleyip birlikte pişirin.
5. Pirinci tabağa alın, hindi ve mantarı üzerine dizin.$$,
  ARRAY['Hacim', 'Yüksek Protein']
),
(
  'Fırın Somonu ve Tatlı Patates Püresi',
  'dinner',
  560, 42, 48, 22,
  25,
  'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800&q=80',
  $$MALZEMELER:
- 170g somon fileto
- 250g tatlı patates (küp)
- 80g ıspanak
- 10 ml zeytinyağı
- 1 diş sarımsak
- Taze dereotu, tuz, karabiber

HAZIRLANIŞI:
1. Tatlı patatesleri tuzlu suda 12 dakika haşlayıp süzün, ezerek püre yapın.
2. Somonu dereotu, sarımsak ve tuzla ovup 180 derecede 14 dakika fırınlayın.
3. Ispanağı zeytinyağında 2 dakika soteleyin.
4. Tabakta tatlı patates püresi, ıspanak ve somonu birleştirip servis edin.$$,
  ARRAY['Yüksek Protein']
),
(
  'Karides Stir-Fry ve Yasemin Pirinci',
  'dinner',
  510, 36, 58, 12,
  18,
  'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80',
  $$MALZEMELER:
- 180g temizlenmiş karides
- 80g yasemin pirinci (kuru ölçü)
- 1 kırmızı biber
- 1 havuç
- 1 yeşil soğan
- 2 yemek kaşığı az tuzlu soya sosu
- 5 ml susam yağı
- 1 diş sarımsak, taze zencefil

HAZIRLANIŞI:
1. Pirinci paket talimatına göre 12 dakika pişirin.
2. Karidesleri sarımsak ve zencefille 2 dakika soteleyin.
3. Sebzeleri ekleyip yüksek ateşte 3 dakika çevirin.
4. Soya sosu ve susam yağını ekleyin, 1 dakika daha pişirin.
5. Pirincin üzerine dökerek servis edin.$$,
  ARRAY['Sıkılaşma']
),
(
  'Hindi Köfte ve Izgara Kabak',
  'dinner',
  460, 42, 22, 22,
  25,
  'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80',
  $$MALZEMELER:
- 180g hindi kıyma
- 1 yemek kaşığı tam buğday ekmek kırıntısı
- 1/4 soğan (rende)
- 1 diş sarımsak
- 1 büyük kabak (dilimli)
- 10 ml zeytinyağı
- Kekik, kimyon, tuz, karabiber

HAZIRLANIŞI:
1. Hindi kıyma, ekmek kırıntısı, soğan, sarımsak ve baharatları yoğurarak 6 köfte şekli verin.
2. Yapışmaz tavada köfteleri her yüzü 4 dakika pişirin.
3. Kabak dilimlerini ızgarada 3 dakika kızartın.
4. Köfteleri kabakla birlikte tabağa alın, zeytinyağı gezdirerek servis edin.$$,
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
-- =============================== Snack (5) =================================
(
  'Ev Yapımı Protein Bar',
  'snack',
  220, 18, 25, 6,
  15,
  'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=800&q=80',
  $$MALZEMELER:
- 50g yulaf ezmesi
- 25g vanilyalı whey protein tozu
- 20g doğal fıstık ezmesi
- 15g bal
- 10g bitter çikolata parçacığı
- 60 ml süt

HAZIRLANIŞI:
1. Tüm kuru malzemeleri bir kasede karıştırın.
2. Fıstık ezmesi, bal ve sütü ekleyip homojen hamur elde edin.
3. Yapışmaz bir kalıba bastırın, üzerine çikolata parçacıklarını serpin.
4. Buzdolabında 1 saat dinlendirip 4 bara bölerek saklayın.$$,
  ARRAY['Yüksek Protein']
),
(
  'Elma Dilimleri ve Fıstık Ezmesi',
  'snack',
  240, 8, 32, 12,
  3,
  'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=800&q=80',
  $$MALZEMELER:
- 1 orta boy elma
- 20g doğal fıstık ezmesi
- 1 tutam tarçın

HAZIRLANIŞI:
1. Elmayı ince dilimleyin.
2. Fıstık ezmesini hafifçe ısıtarak akışkan hale getirin.
3. Elma dilimlerini tabağa dizin, üzerine fıstık ezmesini gezdirin.
4. Tarçın serpip hemen atıştırın.$$,
  ARRAY['Düşük Kalori']
),
(
  'Süzme Peynir ve Böğürtlen',
  'snack',
  180, 22, 14, 4,
  3,
  'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800&q=80',
  $$MALZEMELER:
- 150g süzme peynir (yağsız)
- 80g taze böğürtlen
- 1 tatlı kaşığı bal
- 5g badem kırıkları

HAZIRLANIŞI:
1. Süzme peyniri kaseye alın.
2. Üzerine böğürtlenleri dağıtın.
3. Balı ince bir şerit halinde gezdirin.
4. Badem kırıklarını serpip hemen servis edin.$$,
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Yoğurtlu Granola Parfe',
  'snack',
  290, 20, 35, 7,
  5,
  'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800&q=80',
  $$MALZEMELER:
- 200g süzme yoğurt (yağsız)
- 40g şekersiz granola
- 60g çilek
- 10g bal
- 1/2 tatlı kaşığı vanilya özütü

HAZIRLANIŞI:
1. Yoğurdu vanilya özütüyle karıştırın.
2. Uzun bardağın tabanına bir kat yoğurt koyun.
3. Üzerine granola ve çilek ekleyin, katmanları tekrarlayın.
4. En üste bal gezdirip hemen servis edin.$$,
  ARRAY['Yüksek Protein', 'Sıkılaşma']
),
(
  'Çikolatalı Muzlu Protein Shake',
  'snack',
  310, 28, 36, 6,
  4,
  'https://images.unsplash.com/photo-1502741224143-90386d7f8c82?w=800&q=80',
  $$MALZEMELER:
- 1 muz
- 300 ml az yağlı süt
- 30g çikolatalı whey protein tozu
- 5g kakao tozu
- 100g buz

HAZIRLANIŞI:
1. Tüm malzemeleri blendera alın.
2. 45 saniye yüksek hızda pürüzsüz olana kadar çekin.
3. Uzun bardağa aktarın.
4. İsteğe göre kakao tozu serpip hemen için.$$,
  ARRAY['Yüksek Protein']
),
-- ============================== Dessert (5) ================================
(
  'Çikolatalı Protein Puding',
  'dessert',
  230, 24, 22, 5,
  5,
  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800&q=80',
  $$MALZEMELER:
- 200g süzme yoğurt (yağsız)
- 25g çikolatalı whey protein tozu
- 5g şekersiz kakao tozu
- 15g bal
- 10g çiğ badem

HAZIRLANIŞI:
1. Yoğurt, protein tozu ve kakao tozunu homojen olana kadar çırpın.
2. Balı ekleyip tekrar karıştırın.
3. Servis kasesine alın, buzdolabında 30 dakika dinlendirin.
4. Üzerine iri kıyılmış bademleri serpip servis edin.$$,
  ARRAY['Yüksek Protein', 'Düşük Kalori']
),
(
  'Muzlu Vegan Dondurma',
  'dessert',
  160, 3, 34, 2,
  8,
  'https://images.unsplash.com/photo-1590080875834-4c84d76c05c2?w=800&q=80',
  $$MALZEMELER:
- 2 dondurulmuş muz
- 5g şekersiz kakao tozu
- 5g hindistancevizi rendesi
- 1 tatlı kaşığı vanilya özütü

HAZIRLANIŞI:
1. Dondurulmuş muz dilimlerini blenderda kremamsı kıvama gelene kadar çekin.
2. Kakao tozu ve vanilyayı ekleyip 15 saniye daha karıştırın.
3. Servis kasesine aktarın.
4. Üzerine hindistancevizi rendelerini serpip hemen ikram edin.$$,
  ARRAY['Vegan', 'Düşük Kalori']
),
(
  'Çikolatalı Chia Tohumu Pudingi',
  'dessert',
  290, 10, 28, 16,
  5,
  'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800&q=80',
  $$MALZEMELER:
- 35g chia tohumu
- 250 ml şekersiz badem sütü
- 10g şekersiz kakao tozu
- 15g akçaağaç şurubu
- 1 tatlı kaşığı vanilya özütü
- 60g çilek

HAZIRLANIŞI:
1. Chia tohumu, badem sütü, kakao, akçaağaç şurubu ve vanilyayı kavanozda çırpın.
2. Buzdolabında en az 4 saat (tercihen gece boyu) bekletin.
3. Servis öncesi çatalla hafifçe çalkalayın.
4. Üzerine çilek yerleştirip servis edin.$$,
  ARRAY['Vegan', 'Sıkılaşma']
),
(
  'Fırın Tarçınlı Elma',
  'dessert',
  190, 3, 42, 3,
  20,
  'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=800&q=80',
  $$MALZEMELER:
- 2 orta boy elma
- 1 tatlı kaşığı tarçın
- 10g bal
- 15g çiğ ceviz
- 1 tutam muskat

HAZIRLANIŞI:
1. Elmaların göbeklerini çıkarın, 4 parçaya bölün.
2. Pişirme kâğıdına dizin, bal ve tarçını üzerine gezdirin.
3. 180 derecede 15 dakika fırınlayın.
4. Ceviz kırıkları ve muskatla sıcak servis edin.$$,
  ARRAY['Vegan', 'Düşük Kalori']
),
(
  'Yüksek Protein Cheesecake Isırıkları',
  'dessert',
  260, 20, 18, 11,
  15,
  'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800&q=80',
  $$MALZEMELER:
- 120g yağsız süzme peynir
- 100g süzme yoğurt
- 20g vanilyalı whey protein tozu
- 30g yulaf ezmesi
- 10g bal
- 5g hindistancevizi yağı
- 60g çilek

HAZIRLANIŞI:
1. Yulaf ezmesi ve hindistancevizi yağını mini muffin kalıbının dibine bastırın.
2. Süzme peynir, yoğurt, protein tozu ve balı pürüzsüz olana kadar karıştırın.
3. Karışımı kalıba kaşıkla paylaştırın.
4. Buzdolabında 30 dakika dinlendirin.
5. Her ısırığın üzerine bir çilek dilimi koyarak servis edin.$$,
  ARRAY['Yüksek Protein']
);

-- =============================================================================
-- Sanity check — should add 25 new rows.
-- =============================================================================
-- SELECT meal_type, count(*) FROM public.recipes GROUP BY meal_type
--   ORDER BY meal_type;
