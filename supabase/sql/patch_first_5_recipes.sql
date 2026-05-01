-- =============================================================================
-- Phase 35: Instruction uplift for the first 5 (pre-Phase-28) recipes
-- =============================================================================
-- The five recipes seeded before the Phase 28 dietitian pass ship with short,
-- unstructured instructions. This patch rewrites each one in the same
-- `MALZEMELER:` / `HAZIRLANIŞI:` format used by the Phase 28 seed so the
-- recipe detail screen renders them consistently.
--
-- Copy this file into the Supabase SQL Editor and run it once. Each UPDATE
-- keys on `title`; if a row doesn't exist (e.g. you wiped and re-seeded),
-- the statement is a safe no-op. Dollar-quoted strings ($$...$$) let the
-- instructions carry literal newlines and Turkish apostrophes without
-- escaping.
--
-- Phase 69 · each UPDATE now also rewrites `image_url` to the bundled
-- `photos/meals/<slug>.webp` asset path so the recipe detail screen
-- renders the new dietitian-shot cover photos instead of the legacy
-- Unsplash thumbnail. The Flutter `CachedImage` wrapper auto-detects
-- the local path (anything not starting with `http`) and switches to
-- `Image.asset` — no client-side change required beyond Phase 69's
-- `cached_image.dart` dispatch.
-- =============================================================================

UPDATE public.recipes
SET instructions = $$MALZEMELER:
- 50g yulaf ezmesi
- 250 ml yağsız süt (veya yulaf sütü)
- 1 yemek kaşığı doğal fıstık ezmesi (şekersiz)
- 1 olgun muz (dilimlenmiş)
- 10g ceviz içi (iri kırılmış)
- 1 tatlı kaşığı bal veya akçaağaç şurubu
- 1 çimdik tarçın
- 1 çay kaşığı chia tohumu

HAZIRLANIŞI:
1. Küçük bir tencereye yulafı ve sütü alın, orta ateşte kaynayana kadar ara sıra karıştırın.
2. Kaynamaya başlayınca ateşi kısın ve kremsi kıvam alana kadar 4-5 dakika daha pişirin.
3. Tencereyi ateşten alın, chia tohumunu ekleyip 1 dakika dinlenmeye bırakın.
4. Kaseye aktarın; fıstık ezmesini ılıkken üzerine ekleyerek erimesini sağlayın.
5. Dilimli muz, kırık ceviz ve tarçını serpin, bal ile tatlandırıp sıcak servis edin.$$,
    image_url = 'photos/meals/fistik_ezmeli_yulaf_lapasi.webp'
WHERE title = 'Fıstık Ezmeli Yulaf Lapası';

UPDATE public.recipes
SET instructions = $$MALZEMELER:
- 150g tavuk göğsü fileto
- 50g kinoa (kuru ölçü)
- 1 avuç roka
- 1/2 salatalık (küp doğranmış)
- 8 adet kiraz domates (ikiye bölünmüş)
- 30g light beyaz peynir (küp)
- 10g ayçekirdeği içi
- 15 ml sızma zeytinyağı
- 1 yemek kaşığı limon suyu
- Tuz, karabiber, kekik

HAZIRLANIŞI:
1. Kinoayı akar suda durulayın, 150 ml kaynar suda kısık ateşte 15 dakika pişirin; su çekilince kapağı kapatıp 5 dakika daha dinlendirin.
2. Tavuk göğsünü tuz, karabiber ve kekikle ovun; kızgın ızgara tavada her yüzünü 4 dakika pişirip 2 dakika dinlendirin.
3. Pişmiş kinoayı, rokayı, salatalık, kiraz domates ve peynir küplerini geniş bir salata kasesinde birleştirin.
4. Tavuğu eğik şekilde kalın dilimler halinde doğrayıp salatanın üzerine yerleştirin.
5. Zeytinyağı ve limon suyunu küçük bir kapta çırpın, salatanın üzerine gezdirin.
6. Ayçekirdeğini serpip hemen servis edin.$$,
    image_url = 'photos/meals/izgara_tavuklu_kinoa_salatasi.webp'
WHERE title = 'Izgara Tavuklu Kinoa Salatası';

UPDATE public.recipes
SET instructions = $$MALZEMELER:
- 180g somon fileto (derili)
- 250g tatlı patates (kabuklu, 1 cm dilim)
- 120g kuşkonmaz
- 1 diş sarımsak (ezilmiş)
- 15 ml sızma zeytinyağı
- 1/2 limon (ince dilim)
- 1 dal taze kekik
- Tuz, karabiber, pul biber

HAZIRLANIŞI:
1. Fırını 200 dereceye önceden ısıtın, tepsiye yağlı kağıt yerleştirin.
2. Tatlı patates dilimlerini zeytinyağının yarısı, tuz ve pul biberle harmanlayıp tepsinin bir kenarına tek sıra yayın; 15 dakika pişirin.
3. Tepsiyi çıkarıp diğer kenara kuşkonmazları ekleyin; ortaya somonu derisi alta gelecek şekilde yerleştirin.
4. Somonun üzerini tuz, karabiber ve ezilmiş sarımsakla ovun; üzerine limon dilimleri ve kekik dalını koyun, kalan yağı gezdirin.
5. Tepsiyi fırına geri verin ve 12-14 dakika daha pişirin (somon ortadan hafif pembe görünecek).
6. 2 dakika dinlendirip tabaklara alın ve sıcak servis edin.$$,
    image_url = 'photos/meals/firinlanmis_somon_tatli_patates.webp'
WHERE title = 'Fırınlanmış Somon ve Tatlı Patates';

UPDATE public.recipes
SET instructions = $$MALZEMELER:
- 250 ml yağsız süt (veya badem sütü)
- 30g çikolatalı whey protein tozu
- 15g şekersiz kakao tozu
- 20g chia tohumu
- 1 tatlı kaşığı bal (veya 2-3 damla stevia)
- 1/2 çay kaşığı vanilya özütü
- Üzerine: 10g kırık fındık, 3 adet dilim çilek

HAZIRLANIŞI:
1. Karıştırma kabında sütü, protein tozunu, kakao tozunu ve vanilyayı topak kalmayana kadar çırpın.
2. Bal veya stevia ile tatlandırın; chia tohumlarını ekleyip yeniden iyice karıştırın.
3. Karışımı iki adet servis kavanozuna eşit şekilde paylaştırın.
4. 5 dakika bekleyin, kavanozları yeniden karıştırarak chia'nın dibe çökmesini engelleyin.
5. Kavanozların ağzını kapatıp buzdolabında en az 4 saat (ideali bir gece) dinlendirin.
6. Servis etmeden önce üzerine kırık fındık ve dilim çilek ekleyip sunun.$$,
    image_url = 'photos/meals/yuksek_proteinli_cikolatali_puding.webp'
WHERE title = 'Yüksek Proteinli Çikolatalı Puding';

UPDATE public.recipes
SET instructions = $$MALZEMELER:
- 2 dilim tam buğday ekmeği
- 1 adet olgun avokado
- 2 adet yumurta
- 1 yemek kaşığı beyaz sirke (poşe suyu için)
- 1 çay kaşığı limon suyu
- 1 tatlı kaşığı sızma zeytinyağı
- Pul biber, tuz, karabiber
- 5g taze kekik veya maydanoz (ince doğranmış)

HAZIRLANIŞI:
1. Ekmek dilimlerini tostlayıcıda veya kuru tavada her iki yüzü altın rengi alana kadar kızartın.
2. Avokadoyu ikiye bölüp çekirdeğini çıkarın; iç kısmını çatalla ezerek limon suyu, tuz ve karabiberle harmanlayın.
3. Küçük bir tencerede suyu kaynatın; kaynamaya başlayınca ateşi kısın ve sirkeyi ekleyin.
4. Her yumurtayı ayrı ayrı kâsede kırın; suda hafif bir girdap oluşturup yumurtayı yavaşça boşaltın.
5. 2-3 dakika (akışkan sarı için) haşlayın, oluklu kaşıkla çıkarıp kağıt havlu üzerinde süzün.
6. Ezilmiş avokadoyu tost dilimlerine bolca sürün, her tostun üstüne bir poşe yumurta yerleştirin.
7. Üzerine pul biber, zeytinyağı ve doğranmış kekiği serpip hemen servis edin.$$,
    image_url = 'photos/meals/avokadolu_tam_bugday_tost.webp'
WHERE title = 'Avokadolu Tam Buğday Tost';
