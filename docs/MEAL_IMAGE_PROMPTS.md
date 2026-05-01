# Meal Image Prompts — Phase 66

Master prompt sheet for generating photorealistic meal images for every recipe shipped in the SixPack-AI app. The PM should feed each prompt verbatim into Midjourney (or an equivalent text-to-image tool), then save the output to the file path indicated above the prompt.

**Source of truth:** the meal names below are extracted from `supabase_seed_recipes.sql` (Phase 24, 25 recipes) and `supabase_patch_first_5_recipes.sql` (5 pre-Phase-28 recipes). 30 unique meals total. The `lib/` Dart sources do not contain hardcoded meals — recipes are loaded from Supabase at runtime.

**Prompt template (do not deviate):**

```
Ultra realistic food photography, [meal description], modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k
```

---

## Yüksek Protein (High Protein)

### Izgara Tavuk ve Kinoa Kasesi
**File Path:** `photos/meals/izgara_tavuk_kinoa_kasesi.webp`
**Prompt:** Ultra realistic food photography, grilled chicken breast slices over fluffy quinoa with fresh spinach leaves and sliced avocado, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fırında Somon ve Tatlı Patates
**File Path:** `photos/meals/firinda_somon_tatli_patates.webp`
**Prompt:** Ultra realistic food photography, oven-baked salmon fillet with roasted sweet potato cubes and steamed broccoli florets, garnished with fresh dill, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurta Akı Omleti ve Hindi Eti
**File Path:** `photos/meals/yumurta_aki_omleti_hindi_eti.webp`
**Prompt:** Ultra realistic food photography, fluffy egg white omelette folded over sliced turkey breast and diced red bell pepper, sprinkled with fresh parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Yoğurtlu Protein Kasesi
**File Path:** `photos/meals/suzme_yogurtlu_protein_kasesi.webp`
**Prompt:** Ultra realistic food photography, thick strained Greek yogurt protein bowl topped with fresh strawberries, blueberries, sliced almonds, chia seeds, and a honey drizzle, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Bonfile ve Brokoli
**File Path:** `photos/meals/izgara_bonfile_brokoli.webp`
**Prompt:** Ultra realistic food photography, grilled beef tenderloin steak sliced and basted with garlic-rosemary butter, served with sautéed broccoli florets, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Düşük Kalori (Low Calorie)

### Izgara Sebzeli Ton Balığı Salatası
**File Path:** `photos/meals/izgara_sebzeli_ton_baligi_salatasi.webp`
**Prompt:** Ultra realistic food photography, light tuna salad with fresh lettuce, sliced cucumber, tomato wedges, grilled zucchini and grilled red bell pepper, dressed with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sebzeli Ev Çorbası
**File Path:** `photos/meals/sebzeli_ev_corbasi.webp`
**Prompt:** Ultra realistic food photography, homemade vegetable soup with diced carrots, zucchini and celery in a clear broth, garnished with fresh thyme, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Göğsü Marul Sarma
**File Path:** `photos/meals/tavuk_gogsu_marul_sarma.webp`
**Prompt:** Ultra realistic food photography, shredded poached chicken breast lettuce wraps with grated carrot and thin red onion, drizzled with tahini and soy lemon dressing, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Karides ve Roka Salatası
**File Path:** `photos/meals/izgara_karides_roka_salatasi.webp`
**Prompt:** Ultra realistic food photography, grilled garlic shrimp over fresh arugula with sliced avocado and cherry tomatoes, finished with lemon zest, olive oil and red pepper flakes, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Meyveli Süzme Yoğurt
**File Path:** `photos/meals/meyveli_suzme_yogurt.webp`
**Prompt:** Ultra realistic food photography, strained Greek yogurt topped with fresh blackberries, sliced kiwi, a honey drizzle, and a sprinkle of rolled oats, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Hacim (Bulk)

### Tavuklu Yulaflı Wrap
**File Path:** `photos/meals/tavuklu_yulafli_wrap.webp`
**Prompt:** Ultra realistic food photography, whole wheat lavash wrap halved on the diagonal, filled with grilled chicken breast, oat porridge layer, sliced avocado, melted cheddar, hummus, lettuce, tomato and cucumber, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kıymalı Yüksek Protein Makarna
**File Path:** `photos/meals/kiymali_yuksek_protein_makarna.webp`
**Prompt:** Ultra realistic food photography, whole wheat pasta tossed in lean ground beef tomato bolognese, topped with grated parmesan and fresh basil leaves, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fıstık Ezmeli Muzlu Yulaf Ezmesi
**File Path:** `photos/meals/fistik_ezmeli_muzlu_yulaf_ezmesi.webp`
**Prompt:** Ultra realistic food photography, creamy oatmeal porridge topped with fresh banana slices, a swirl of natural peanut butter, chia seeds, a honey drizzle and a dusting of cinnamon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bonfileli Burrito
**File Path:** `photos/meals/bonfileli_burrito.webp`
**Prompt:** Ultra realistic food photography, large whole wheat tortilla burrito sliced in half showing grilled beef tenderloin strips, brown rice, red kidney beans, melted cheddar, sliced avocado and salsa, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Protein Pankek Yığını
**File Path:** `photos/meals/protein_pankek_yigini.webp`
**Prompt:** Ultra realistic food photography, fluffy stack of golden protein oat pancakes topped with fresh blueberries and a generous honey drizzle, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Sıkılaşma (Toning / Recomp)

### Akdeniz Kinoa Salatası
**File Path:** `photos/meals/akdeniz_kinoa_salatasi.webp`
**Prompt:** Ultra realistic food photography, Mediterranean quinoa salad with chickpeas, diced cucumber, cherry tomatoes, low-fat feta cheese cubes, kalamata olives and fresh parsley, dressed with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Hindi ve Pirinç Kasesi
**File Path:** `photos/meals/izgara_hindi_pirinc_kasesi.webp`
**Prompt:** Ultra realistic food photography, grilled turkey breast slices over fluffy brown rice with grilled zucchini and grilled red bell pepper strips, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sebzeli Mercimek Çorbası
**File Path:** `photos/meals/sebzeli_mercimek_corbasi.webp`
**Prompt:** Ultra realistic food photography, smooth pureed red lentil and vegetable soup in a warm orange tone, finished with a swirl of olive oil and a dusting of cumin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fırında Levrek ve Kuskus
**File Path:** `photos/meals/firinda_levrek_kuskus.webp`
**Prompt:** Ultra realistic food photography, oven-baked sea bass fillet with lemon slices and fresh dill, served alongside fluffy couscous, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Yoğurtlu Meyve Parfe
**File Path:** `photos/meals/suzme_yogurtlu_meyve_parfe.webp`
**Prompt:** Ultra realistic food photography, layered Greek yogurt parfait in a tall glass with sugar-free granola, fresh strawberries, raspberries and a honey drizzle on top, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Vegan

### Nohutlu Kinoa Buddha Kasesi
**File Path:** `photos/meals/nohutlu_kinoa_buddha_kasesi.webp`
**Prompt:** Ultra realistic food photography, vegan Buddha bowl with fluffy quinoa, roasted chickpeas, grated carrot, shredded purple cabbage and sliced avocado, drizzled with creamy tahini-lemon dressing, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tofu Soteli Kahverengi Pirinç
**File Path:** `photos/meals/tofu_soteli_kahverengi_pirinc.webp`
**Prompt:** Ultra realistic food photography, golden pan-seared tofu cubes stir-fried with broccoli, red bell pepper and carrot strips in soy-ginger sauce, served over brown rice, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Chia Tohumu Pudingi
**File Path:** `photos/meals/chia_tohumu_pudingi.webp`
**Prompt:** Ultra realistic food photography, vanilla almond milk chia seed pudding topped with fresh strawberries and whole almonds, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mercimek Köftesi Wrap
**File Path:** `photos/meals/mercimek_koftesi_wrap.webp`
**Prompt:** Ultra realistic food photography, whole wheat lavash wrap filled with vegan red lentil patties, lettuce, tomato slices, red onion, hummus and fresh parsley, halved diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fıstık Ezmeli Muzlu Vegan Smoothie
**File Path:** `photos/meals/fistik_ezmeli_muzlu_vegan_smoothie.webp`
**Prompt:** Ultra realistic food photography, thick chocolate peanut butter banana vegan smoothie in a tall glass, dusted with cocoa powder on top, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Pre-Phase-28 Classics (legacy seed)

### Fıstık Ezmeli Yulaf Lapası
**File Path:** `photos/meals/fistik_ezmeli_yulaf_lapasi.webp`
**Prompt:** Ultra realistic food photography, creamy oat porridge topped with sliced banana, a generous swirl of natural peanut butter, crushed walnuts, chia seeds and a cinnamon dusting, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Tavuklu Kinoa Salatası
**File Path:** `photos/meals/izgara_tavuklu_kinoa_salatasi.webp`
**Prompt:** Ultra realistic food photography, grilled chicken breast slices over a quinoa salad with arugula, diced cucumber, halved cherry tomatoes, light feta cheese cubes and sunflower seeds, dressed with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fırınlanmış Somon ve Tatlı Patates
**File Path:** `photos/meals/firinlanmis_somon_tatli_patates.webp`
**Prompt:** Ultra realistic food photography, oven-roasted salmon fillet with lemon slices and fresh thyme, served with sliced roasted sweet potato and tender asparagus spears, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yüksek Proteinli Çikolatalı Puding
**File Path:** `photos/meals/yuksek_proteinli_cikolatali_puding.webp`
**Prompt:** Ultra realistic food photography, rich high-protein chocolate chia pudding in a glass jar topped with crushed hazelnuts and three fresh strawberry slices, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Avokadolu Tam Buğday Tost
**File Path:** `photos/meals/avokadolu_tam_bugday_tost.webp`
**Prompt:** Ultra realistic food photography, two slices of toasted whole wheat bread topped with smashed avocado and a perfectly poached egg each, finished with red pepper flakes, olive oil and fresh thyme, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Phase 72 — Pending Generation

Live-DB recipes added after Phase 66 that still need a Midjourney
pass. Replace `<TODO: english description>` with a one-line plate
description and feed the prompt verbatim to Midjourney v6, then drop
the output at the file path indicated.

### Avokadolu Yumurtalı Tam Buğday Tost
**File Path:** `photos/meals/avokadolu_yumurtali_tam_bugday_tost.webp`
**Prompt:** Ultra realistic food photography, two slices of toasted whole wheat bread topped with smashed avocado and a soft poached egg, finished with red pepper flakes, sea salt and fresh microgreens, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Chia Tohumlu Vegan Pancake
**File Path:** `photos/meals/chia_tohumlu_vegan_pancake.webp`
**Prompt:** Ultra realistic food photography, stack of fluffy vegan pancakes made with chia seeds and oat flour, topped with sliced banana, fresh raspberries and a drizzle of maple syrup, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Elma Dilimleri ve Fıstık Ezmesi
**File Path:** `photos/meals/elma_dilimleri_fistik_ezmesi.webp`
**Prompt:** Ultra realistic food photography, fresh red apple slices fanned out beside a small bowl of creamy natural peanut butter, sprinkled with chia seeds and a few crushed almonds, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Ev Yapımı Protein Bar
**File Path:** `photos/meals/ev_yapimi_protein_bar.webp`
**Prompt:** Ultra realistic food photography, homemade no-bake protein bars stacked together, made with rolled oats, chopped dates, dark chocolate chips and a swirl of almond butter on top, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fırın Somonu ve Tatlı Patates Püresi
**File Path:** `photos/meals/firin_somonu_tatli_patates_puresi.webp`
**Prompt:** Ultra realistic food photography, oven-baked salmon fillet served beside a smooth sweet potato purée, garnished with steamed asparagus tips and fresh dill, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fırın Tarçınlı Elma
**File Path:** `photos/meals/firin_tarcinli_elma.webp`
**Prompt:** Ultra realistic food photography, baked apple slices dusted with cinnamon and a light honey drizzle, finished with a few toasted walnut pieces, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fırında Hindi ve Esmer Pirinç
**File Path:** `photos/meals/firinda_hindi_esmer_pirinc.webp`
**Prompt:** Ultra realistic food photography, sliced oven-roasted turkey breast resting over a bed of fluffy brown rice with steamed green beans and a sprig of fresh rosemary, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Fıstık Ezmeli Protein Yulaf Ezmesi
**File Path:** `photos/meals/fistik_ezmeli_protein_yulaf_ezmesi.webp`
**Prompt:** Ultra realistic food photography, creamy bowl of high-protein oatmeal topped with a generous swirl of natural peanut butter, sliced banana, chia seeds and a sprinkle of cocoa nibs, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Göğsülü Avokadolu Wrap
**File Path:** `photos/meals/hindi_gogsulu_avokadolu_wrap.webp`
**Prompt:** Ultra realistic food photography, whole wheat wrap filled with sliced roasted turkey breast, fresh avocado, crisp lettuce and light mayo, cut in half and stacked, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Köfte ve Izgara Kabak
**File Path:** `photos/meals/hindi_kofte_izgara_kabak.webp`
**Prompt:** Ultra realistic food photography, juicy grilled turkey meatballs paired with charred zucchini ribbons and a small dollop of garlic yogurt sauce, garnished with fresh parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Ispanaklı Peynirli Omlet
**File Path:** `photos/meals/ispanakli_peynirli_omlet.webp`
**Prompt:** Ultra realistic food photography, fluffy folded omelette stuffed with sautéed baby spinach and crumbled feta cheese, topped with cracked black pepper and a sprig of dill, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Bonfile ve Közlenmiş Sebze
**File Path:** `photos/meals/izgara_bonfile_kozlenmis_sebze.webp`
**Prompt:** Ultra realistic food photography, sliced grilled beef tenderloin medallions served with charred roasted bell peppers, eggplant and zucchini, drizzled with extra virgin olive oil, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Levrek ve Buharda Sebze
**File Path:** `photos/meals/izgara_levrek_buharda_sebze.webp`
**Prompt:** Ultra realistic food photography, grilled sea bass fillet topped with lemon slices and fresh thyme, served alongside steamed broccoli, baby carrots and asparagus tips, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Somon & Tatlı Patates
**File Path:** `photos/meals/izgara_somon_tatli_patates.webp`
**Prompt:** Ultra realistic food photography, grilled salmon fillet with crispy seared edges, served beside roasted sweet potato cubes and steamed broccoli florets, garnished with lemon wedges, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Izgara Tavuklu Hafif Sezar Salata
**File Path:** `photos/meals/izgara_tavuklu_hafif_sezar_salata.webp`
**Prompt:** Ultra realistic food photography, crisp romaine lettuce tossed with grilled chicken breast strips, shaved parmesan, whole wheat croutons and a light yogurt-based caesar dressing, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Karides Stir-Fry ve Yasemin Pirinci
**File Path:** `photos/meals/karides_stirfry_yasemin_pirinci.webp`
**Prompt:** Ultra realistic food photography, sizzling shrimp stir-fry with red bell peppers, snap peas and broccoli over fluffy jasmine rice, sprinkled with sesame seeds and sliced spring onions, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kırmızı Mercimek Çorbası ve Tam Buğday Ekmeği
**File Path:** `photos/meals/kirmizi_mercimek_corbasi_tam_bugday_ekmegi.webp`
**Prompt:** Ultra realistic food photography, creamy red lentil soup garnished with dried mint flakes and a swirl of olive oil, served with a slice of toasted whole wheat bread on the side, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Meyveli Vegan Smoothie Kasesi
**File Path:** `photos/meals/meyveli_vegan_smoothie_kasesi.webp`
**Prompt:** Ultra realistic food photography, thick vegan smoothie bowl with a vibrant berry base topped with sliced strawberries, blueberries, kiwi, granola, coconut flakes and chia seeds, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Muzlu Vegan Dondurma
**File Path:** `photos/meals/muzlu_vegan_dondurma.webp`
**Prompt:** Ultra realistic food photography, scoops of creamy banana nice cream made from frozen bananas, topped with crushed walnuts, cocoa nibs and a drizzle of date syrup, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Protein Omlet & Avokado
**File Path:** `photos/meals/protein_omlet_avokado.webp`
**Prompt:** Ultra realistic food photography, high-protein egg omelette folded over melted cheese, served with sliced fresh avocado fanned alongside, sprinkled with chili flakes and chives, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Peynir ve Böğürtlen
**File Path:** `photos/meals/suzme_peynir_bogurtlen.webp`
**Prompt:** Ultra realistic food photography, bowl of creamy strained cottage cheese topped with fresh blackberries, a drizzle of honey and a sprinkle of crushed almonds, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Vejetaryen Quinoa Power Bowl
**File Path:** `photos/meals/vejetaryen_quinoa_power_bowl.webp`
**Prompt:** Ultra realistic food photography, vegetarian power bowl of fluffy quinoa with roasted chickpeas, sliced avocado, cherry tomatoes, baby spinach, shredded carrots and a tahini-lemon drizzle, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Granola Parfe
**File Path:** `photos/meals/yogurtlu_granola_parfe.webp`
**Prompt:** Ultra realistic food photography, layered parfait of thick Greek yogurt, crunchy honey granola, fresh strawberries and blueberries in a tall clear glass, finished with a drizzle of honey, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yüksek Protein Cheesecake Isırıkları
**File Path:** `photos/meals/yuksek_protein_cheesecake_isiriklari.webp`
**Prompt:** Ultra realistic food photography, bite-sized no-bake protein cheesecake squares with a graham crust and creamy vanilla top, garnished with fresh raspberries and a dusting of crushed pistachio, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yüksek Proteinli Çikolatalı Puding (Sporcu Tatlısı)
**File Path:** `photos/meals/yuksek_proteinli_cikolatali_puding_sporcu_tatlisi.webp`
**Prompt:** Ultra realistic food photography, rich high-protein chocolate pudding in a small glass jar, topped with whipped coconut cream, dark chocolate shavings and a few fresh raspberries, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çikolatalı Chia Tohumu Pudingi
**File Path:** `photos/meals/cikolatali_chia_tohumu_pudingi.webp`
**Prompt:** Ultra realistic food photography, creamy chocolate chia seed pudding in a glass jar, topped with sliced banana, fresh strawberries and a sprinkle of cocoa nibs, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çikolatalı Muzlu Protein Shake
**File Path:** `photos/meals/cikolatali_muzlu_protein_shake.webp`
**Prompt:** Ultra realistic food photography, tall glass of frothy chocolate banana protein shake topped with whipped cream, a dusting of cocoa powder and a fresh banana slice on the rim, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çikolatalı Protein Puding
**File Path:** `photos/meals/cikolatali_protein_puding.webp`
**Prompt:** Ultra realistic food photography, smooth chocolate protein pudding in a small ramekin, dusted with cocoa powder and garnished with crushed hazelnuts and a fresh mint leaf, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Pratik & Ekonomik (Budget) — Phase 83

Pilot batch of 10 quick, low-cost, high-protein Turkish meals. Source SQL: `supabase/sql/phase83_budget_meals.sql`. Generate each webp at 1080×1080, save to the indicated path, and run the existing `lib/scripts/sync_recipes_db.dart` workflow if URL canonicalisation is needed (Phase 72 pattern).

### Yumurtalı Sucuklu Tava
**File Path:** `photos/meals/yumurtali_sucuklu_tava.webp`
**Prompt:** Ultra realistic food photography, three sunny-side-up eggs scrambled with sliced Turkish sucuk sausage in a small black cast iron skillet, served with a slice of whole wheat bread on the side, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Beyaz Peynirli Tam Buğday Tost
**File Path:** `photos/meals/beyaz_peynirli_tam_bugday_tost.webp`
**Prompt:** Ultra realistic food photography, golden grilled whole wheat sandwich filled with crumbled Turkish white cheese, served with sliced fresh tomato, black olives and a sprig of mint on the side, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Bulgur Pilavı
**File Path:** `photos/meals/yogurtlu_bulgur_pilavi.webp`
**Prompt:** Ultra realistic food photography, fluffy buttered bulgur pilaf served alongside a generous bowl of thick strained yogurt sprinkled with dried mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hızlı Mercimek Köftesi
**File Path:** `photos/meals/hizli_mercimek_koftesi.webp`
**Prompt:** Ultra realistic food photography, hand-shaped Turkish red lentil and bulgur kofte balls arranged on crisp lettuce leaves, garnished with chopped parsley and a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tencerede Tavuk Sote
**File Path:** `photos/meals/tencerede_tavuk_sote.webp`
**Prompt:** Ultra realistic food photography, Turkish chicken sauté with diced chicken breast, sliced onion and green pepper in a rich tomato paste sauce, finished with red pepper flakes, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sucuklu Yumurtalı Bulgur
**File Path:** `photos/meals/sucuklu_yumurtali_bulgur.webp`
**Prompt:** Ultra realistic food photography, fluffy bulgur pilaf topped with sliced Turkish sucuk sausage and two sunny-side-up eggs, sprinkled with cracked black pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hızlı Yumurtalı Mercimek Çorbası
**File Path:** `photos/meals/hizli_yumurtali_mercimek_corbasi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish red lentil soup with delicate egg ribbons, finished with a swirl of brown butter and red pepper flakes, served with a lemon wedge on the side, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Salatalık Atıştırması
**File Path:** `photos/meals/yogurtlu_salatalik_atistirmasi.webp`
**Prompt:** Ultra realistic food photography, thick Turkish strained yogurt cacık with grated cucumber, garlic and dried mint, drizzled with olive oil and garnished with fresh mint leaves, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Haşlanmış Yumurta ve Domates
**File Path:** `photos/meals/haslanmis_yumurta_ve_domates.webp`
**Prompt:** Ultra realistic food photography, two halved hard-boiled eggs arranged with sliced ripe tomatoes and black olives, sprinkled with salt, cracked pepper and chopped parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tahin Pekmez Ekmek
**File Path:** `photos/meals/tahin_pekmez_ekmek.webp`
**Prompt:** Ultra realistic food photography, two slices of toasted whole wheat bread spread with a swirled tahini and grape molasses mixture, dusted with cinnamon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Pratik & Ekonomik — Batch 2

100 budget meals expanding the Phase 83 pilot from 10 to 110, distributed 20 per meal_type (breakfast / lunch / dinner / snack / dessert). Source SQL: `supabase/sql/phase83_budget_meals_batch2.sql`. Generate each webp at 1080×1080 and save to the indicated path.

### Menemen Klasik
**File Path:** `photos/meals/menemen_klasik.webp`
**Prompt:** Ultra realistic food photography, classic Turkish menemen with scrambled eggs in a tomato and green pepper base with diced onion, served bubbling in a small black cast iron skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Yumurtalı Ekmek
**File Path:** `photos/meals/sade_yumurtali_ekmek.webp`
**Prompt:** Ultra realistic food photography, two pan-fried sunny-side-up eggs served with two slices of golden whole wheat bread, sprinkled with cracked black pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Lor Peynirli Bal Ekmek
**File Path:** `photos/meals/lor_peynirli_bal_ekmek.webp`
**Prompt:** Ultra realistic food photography, two slices of whole wheat bread spread with creamy Turkish curd cheese (lor) drizzled with golden honey and dusted with cinnamon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kaşar Peynirli Tava Tost
**File Path:** `photos/meals/kasar_peynirli_tava_tost.webp`
**Prompt:** Ultra realistic food photography, golden grilled whole wheat sandwich filled with melted Turkish kaşar cheese, sliced diagonally to show the cheese pull, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sütlü Yulaf Ezmesi
**File Path:** `photos/meals/sutlu_yulaf_ezmesi.webp`
**Prompt:** Ultra realistic food photography, creamy hot oatmeal in milk drizzled with golden honey and dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Domatesli Sahanda Yumurta
**File Path:** `photos/meals/domatesli_sahanda_yumurta.webp`
**Prompt:** Ultra realistic food photography, two sunny-side-up eggs cooked over a bed of sautéed diced tomatoes in a small black cast iron skillet, sprinkled with cracked pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Soğanlı Patates Kavurma
**File Path:** `photos/meals/soganli_patates_kavurma.webp`
**Prompt:** Ultra realistic food photography, golden sautéed potato cubes with caramelized diced onions, sprinkled with red pepper flakes, served in a small skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bazlama Tava Tost
**File Path:** `photos/meals/bazlama_tava_tost.webp`
**Prompt:** Ultra realistic food photography, warm Turkish bazlama flatbread sliced open and filled with white cheese, fresh tomato slices and black olives, garnished with mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bal-Cevizli Süzme Yoğurt
**File Path:** `photos/meals/bal_cevizli_suzme_yogurt.webp`
**Prompt:** Ultra realistic food photography, thick strained Turkish yogurt topped with golden honey and crushed walnut pieces, dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tereyağlı Bal Ekmek
**File Path:** `photos/meals/tereyagli_bal_ekmek.webp`
**Prompt:** Ultra realistic food photography, two slices of toasted whole wheat bread spread with melting butter and drizzled with golden honey, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Reçelli Tam Buğday Tost
**File Path:** `photos/meals/receli_tam_bugday_tost.webp`
**Prompt:** Ultra realistic food photography, two golden toasted whole wheat bread slices spread with butter and topped with vibrant red fruit jam, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kakaolu Yulaf Lapası
**File Path:** `photos/meals/kakaolu_yulaf_lapasi.webp`
**Prompt:** Ultra realistic food photography, rich chocolate oatmeal made with cocoa powder and milk, drizzled with honey and dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Maydanozlu Sade Omlet
**File Path:** `photos/meals/maydanozlu_sade_omlet.webp`
**Prompt:** Ultra realistic food photography, fluffy folded plain omelette with chopped fresh parsley flecks visible throughout, lightly seasoned, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çiğ Sebze Kahvaltı Tabağı
**File Path:** `photos/meals/cig_sebze_kahvalti_tabagi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish breakfast plate with sliced cucumber, sliced tomato, black olives, white cheese cubes, drizzled with olive oil and garnished with fresh mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Salam ve Sade Tabak
**File Path:** `photos/meals/salam_ve_sade_tabak.webp`
**Prompt:** Ultra realistic food photography, breakfast plate with sliced Turkish turkey salami, kaşar cheese cubes, a slice of whole wheat bread, fresh tomato and black olives, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Yumurtalı Pişi
**File Path:** `photos/meals/pratik_yumurtali_pisi.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried Turkish pişi flatbread split open and filled with sunny-side-up egg and crumbled white cheese, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Yumurta Salatası
**File Path:** `photos/meals/yogurtlu_yumurta_salatasi.webp`
**Prompt:** Ultra realistic food photography, creamy hard-boiled egg salad mixed with strained yogurt and chopped parsley, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mısır Gevrekli Süt
**File Path:** `photos/meals/misir_gevrekli_sut.webp`
**Prompt:** Ultra realistic food photography, bowl of cornflakes with cold milk and fresh banana slices on top, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Muzlu Sıcak Yulaf Lapası
**File Path:** `photos/meals/muzlu_sicak_yulaf_lapasi.webp`
**Prompt:** Ultra realistic food photography, hot creamy oatmeal topped with caramelized banana slices, drizzled with honey and dusted with cinnamon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hızlı Krep ve Reçel
**File Path:** `photos/meals/hizli_krep_ve_recel.webp`
**Prompt:** Ultra realistic food photography, thin rolled crepes filled with vibrant red fruit jam and dusted with powdered sugar, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Ton Balıklı Makarna Salatası
**File Path:** `photos/meals/ton_balikli_makarna_salatasi.webp`
**Prompt:** Ultra realistic food photography, cold pasta salad with flaked tuna, diced tomato, diced cucumber, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Patates Salatası
**File Path:** `photos/meals/yumurtali_patates_salatasi.webp`
**Prompt:** Ultra realistic food photography, classic potato salad with diced boiled potatoes, sliced hard-boiled eggs, finely chopped onion and fresh parsley, dressed with yogurt and olive oil, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Klasik Mercimek Çorbası
**File Path:** `photos/meals/klasik_mercimek_corbasi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish red lentil soup with a swirl of melted butter and red pepper flakes on top, served in a small ceramic bowl with a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Beyaz Pilav ve Sade Yoğurt
**File Path:** `photos/meals/beyaz_pilav_ve_sade_yogurt.webp`
**Prompt:** Ultra realistic food photography, fluffy buttered Turkish white rice pilaf served alongside a generous bowl of thick strained yogurt, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Domates Soslu Sade Makarna
**File Path:** `photos/meals/domates_soslu_sade_makarna.webp`
**Prompt:** Ultra realistic food photography, simple pasta in rich red tomato sauce with caramelized onions, sprinkled with black pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tereyağlı Limonlu Makarna
**File Path:** `photos/meals/tereyagli_limonlu_makarna.webp`
**Prompt:** Ultra realistic food photography, glossy buttered pasta with lemon zest and lemon juice, finished with cracked black pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Bulgur Salatası
**File Path:** `photos/meals/tavuklu_bulgur_salatasi.webp`
**Prompt:** Ultra realistic food photography, cold bulgur salad with diced cooked chicken breast, fresh diced tomato and cucumber, dressed with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Mercimek Yemeği
**File Path:** `photos/meals/sade_mercimek_yemegi.webp`
**Prompt:** Ultra realistic food photography, simple Turkish red lentil stew with sautéed onion and tomato paste seasoned with cumin, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Erişte
**File Path:** `photos/meals/yumurtali_eriste.webp`
**Prompt:** Ultra realistic food photography, Turkish homemade noodles tossed with scrambled eggs and butter-sautéed onion, sprinkled with black pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Şehriye Çorbası Yumurtalı
**File Path:** `photos/meals/sehriye_corbasi_yumurtali.webp`
**Prompt:** Ultra realistic food photography, Turkish vermicelli soup with delicate egg ribbons and a swirl of melted butter, finished with dried mint, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Suyu Pirinç Çorbası
**File Path:** `photos/meals/tavuk_suyu_pirinc_corbasi.webp`
**Prompt:** Ultra realistic food photography, golden chicken broth rice soup with fluffy rice grains and egg-lemon thickening, served with a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sebzeli Bulgur Pilavı
**File Path:** `photos/meals/sebzeli_bulgur_pilavi.webp`
**Prompt:** Ultra realistic food photography, fluffy bulgur pilaf with diced carrots, green peppers and onion, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Patates Köftesi
**File Path:** `photos/meals/pratik_patates_koftesi.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried potato patties with crispy edges, served on a small ceramic plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Sebze Sote
**File Path:** `photos/meals/yumurtali_sebze_sote.webp`
**Prompt:** Ultra realistic food photography, sautéed eggplant cubes with green peppers and tomato topped with sunny-side-up eggs in a small black skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Patates Salatası
**File Path:** `photos/meals/yogurtlu_patates_salatasi.webp`
**Prompt:** Ultra realistic food photography, creamy Turkish yogurt potato salad with diced boiled potatoes, garlic and fresh parsley, drizzled with olive oil, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Etli Pratik Bulgur
**File Path:** `photos/meals/hindi_etli_pratik_bulgur.webp`
**Prompt:** Ultra realistic food photography, fluffy bulgur pilaf cooked with ground turkey, sautéed onion and tomato paste, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Göğsü Salatası
**File Path:** `photos/meals/tavuk_gogsu_salatasi.webp`
**Prompt:** Ultra realistic food photography, sliced grilled chicken breast over fresh lettuce with sliced cucumber and tomato, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Patates Çorbası
**File Path:** `photos/meals/patates_corbasi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish potato soup with grated carrot and butter swirl, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Soğan-Domates Çorbası
**File Path:** `photos/meals/sogan_domates_corbasi.webp`
**Prompt:** Ultra realistic food photography, rustic onion and tomato soup with golden caramelized onions and bread croutons floating on top, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Beyaz Peynirli Sade Makarna
**File Path:** `photos/meals/beyaz_peynirli_sade_makarna.webp`
**Prompt:** Ultra realistic food photography, simple pasta tossed with crumbled Turkish white cheese and dried mint, drizzled with olive oil, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Sote ve Pilav
**File Path:** `photos/meals/tavuk_sote_ve_pilav.webp`
**Prompt:** Ultra realistic food photography, Turkish chicken sauté with diced chicken breast in tomato paste sauce served alongside fluffy white rice pilaf, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tencerede Sebzeli Yumurta
**File Path:** `photos/meals/tencerede_sebzeli_yumurta.webp`
**Prompt:** Ultra realistic food photography, one-pot dish with sautéed diced potatoes, green peppers and tomatoes topped with sunny-side-up eggs, served in a small skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Soğanlı Hızlı Tavuk Sote
**File Path:** `photos/meals/soganli_hizli_tavuk_sote.webp`
**Prompt:** Ultra realistic food photography, diced chicken breast sautéed with deeply caramelized onions in tomato paste sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Domates Soslu Köfte
**File Path:** `photos/meals/domates_soslu_kofte.webp`
**Prompt:** Ultra realistic food photography, Turkish meatballs simmered in fresh tomato sauce with diced onion, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tencerede Patates Köftesi
**File Path:** `photos/meals/tencerede_patates_koftesi.webp`
**Prompt:** Ultra realistic food photography, Turkish meatballs and potato cubes simmered in tomato paste sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hızlı Tavuk Pirzola
**File Path:** `photos/meals/hizli_tavuk_pirzola.webp`
**Prompt:** Ultra realistic food photography, grilled Turkish chicken cutlet with garlic-lemon marinade, served with a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Köfte Tava
**File Path:** `photos/meals/sade_kofte_tava.webp`
**Prompt:** Ultra realistic food photography, classic Turkish pan-fried meatballs seasoned with cumin and black pepper, served in a small skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Salçalı Tavada Yumurta
**File Path:** `photos/meals/salcali_tavada_yumurta.webp`
**Prompt:** Ultra realistic food photography, three sunny-side-up eggs cooked in a tomato paste and onion sauce in a small black skillet, sprinkled with red pepper flakes, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sebzeli Pratik Köfte
**File Path:** `photos/meals/sebzeli_pratik_kofte.webp`
**Prompt:** Ultra realistic food photography, Turkish meatballs with mixed grated carrot and diced green pepper, pan-fried golden, served on a small ceramic plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Bulgur Pilavı
**File Path:** `photos/meals/tavuklu_bulgur_pilavi.webp`
**Prompt:** Ultra realistic food photography, fluffy bulgur pilaf cooked with diced chicken breast and onion, finished with butter, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Patates Tavası
**File Path:** `photos/meals/sade_patates_tavasi.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried potato wedges with red pepper flakes and dried oregano, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Domatesli Sade Tavuk
**File Path:** `photos/meals/domatesli_sade_tavuk.webp`
**Prompt:** Ultra realistic food photography, simple chicken breast cubes sautéed with fresh tomatoes and green pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Sade Tavuk Sote
**File Path:** `photos/meals/yogurtlu_sade_tavuk_sote.webp`
**Prompt:** Ultra realistic food photography, sautéed chicken breast cubes finished with a creamy garlic yogurt sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Yoğurtlu Mantı
**File Path:** `photos/meals/pratik_yogurtlu_manti.webp`
**Prompt:** Ultra realistic food photography, Turkish mantı dumplings topped with creamy garlic yogurt and a drizzle of red pepper flake butter, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk-Patates Tencere
**File Path:** `photos/meals/tavuk_patates_tencere.webp`
**Prompt:** Ultra realistic food photography, one-pot dish with diced chicken breast and potato cubes in a tomato-based sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Patates Tava
**File Path:** `photos/meals/yumurtali_patates_tava.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried potato cubes topped with two sunny-side-up eggs, sprinkled with cracked pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kıymalı Sade Makarna
**File Path:** `photos/meals/kiymali_sade_makarna.webp`
**Prompt:** Ultra realistic food photography, pasta with rich ground beef tomato sauce and onion, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tava Pırasası Yumurtalı
**File Path:** `photos/meals/tava_pirasasi_yumurtali.webp`
**Prompt:** Ultra realistic food photography, sautéed Turkish leek slices with onion topped with sunny-side-up eggs, served in a small skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sucuklu Sade Patates
**File Path:** `photos/meals/sucuklu_sade_patates.webp`
**Prompt:** Ultra realistic food photography, golden sautéed potato cubes with sliced Turkish sucuk sausage and onion, sprinkled with red pepper flakes, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Salçalı Yumurtalı Köfte
**File Path:** `photos/meals/salcali_yumurtali_kofte.webp`
**Prompt:** Ultra realistic food photography, Turkish meatballs in a rich tomato paste sauce topped with sunny-side-up eggs, served in a small skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Ev Yapımı Patates Cipsi
**File Path:** `photos/meals/ev_yapimi_patates_cipsi.webp`
**Prompt:** Ultra realistic food photography, homemade thin-sliced potato chips seasoned with red pepper flakes and salt, served on a small ceramic plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Salatalık Sticks ve Yoğurt Sosu
**File Path:** `photos/meals/salatalik_sticks_ve_yogurt_sosu.webp`
**Prompt:** Ultra realistic food photography, fresh cucumber sticks arranged around a small ceramic bowl of strained yogurt dip with garlic and dried mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hazır Çiğ Köfte
**File Path:** `photos/meals/hazir_cig_kofte.webp`
**Prompt:** Ultra realistic food photography, Turkish çiğ köfte balls wrapped in fresh lettuce leaves with a lemon wedge on the side, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Havuç Atıştırması
**File Path:** `photos/meals/yogurtlu_havuc_atistirmasi.webp`
**Prompt:** Ultra realistic food photography, Turkish carrot yogurt salad with grated sautéed carrots in creamy garlic yogurt, sprinkled with chopped parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Domates Salatası
**File Path:** `photos/meals/sade_domates_salatasi.webp`
**Prompt:** Ultra realistic food photography, simple sliced tomato salad with thin onion rings, drizzled with olive oil and dried oregano, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Soğanlı Marul Salatası
**File Path:** `photos/meals/soganli_marul_salatasi.webp`
**Prompt:** Ultra realistic food photography, fresh lettuce salad with thin red onion rings and tomato slices, dressed with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Sade Krep
**File Path:** `photos/meals/yumurtali_sade_krep.webp`
**Prompt:** Ultra realistic food photography, thin rolled plain crepe with golden edges, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurta-Peynirli Sandviç
**File Path:** `photos/meals/yumurta_peynirli_sandvic.webp`
**Prompt:** Ultra realistic food photography, whole wheat sandwich with sliced hard-boiled egg, white cheese, lettuce and tomato, sliced diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Domates ve Beyaz Peynir Tabağı
**File Path:** `photos/meals/domates_ve_beyaz_peynir_tabagi.webp`
**Prompt:** Ultra realistic food photography, sliced fresh tomatoes with cubes of Turkish white cheese and black olives, drizzled with olive oil, garnished with mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Salatalık ve Beyaz Peynir
**File Path:** `photos/meals/salatalik_ve_beyaz_peynir.webp`
**Prompt:** Ultra realistic food photography, sliced fresh cucumber with cubes of Turkish white cheese, drizzled with olive oil and garnished with fresh mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Patates Püresi
**File Path:** `photos/meals/sade_patates_puresi.webp`
**Prompt:** Ultra realistic food photography, creamy mashed potatoes with a small pat of butter melting on top, sprinkled with cracked pepper, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Mısır Salatası
**File Path:** `photos/meals/sade_misir_salatasi.webp`
**Prompt:** Ultra realistic food photography, vibrant yellow corn salad with diced green pepper and onion, dressed with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sarımsaklı Cacık
**File Path:** `photos/meals/sarimsakli_cacik.webp`
**Prompt:** Ultra realistic food photography, classic Turkish cacık cold yogurt soup with grated cucumber, garlic and dried mint, garnished with fresh mint leaves, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Köy Ekmeği ve Tereyağı
**File Path:** `photos/meals/sade_koy_ekmegi_ve_tereyagi.webp`
**Prompt:** Ultra realistic food photography, two slices of rustic Turkish village bread spread with melting butter, sprinkled with sea salt, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Karışık Zeytin ve Peynir Tabağı
**File Path:** `photos/meals/karisik_zeytin_ve_peynir_tabagi.webp`
**Prompt:** Ultra realistic food photography, plate of mixed green and black olives with cubes of Turkish white cheese, drizzled with olive oil and sprinkled with dried oregano, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tahinli Sade Yoğurt
**File Path:** `photos/meals/tahinli_sade_yogurt.webp`
**Prompt:** Ultra realistic food photography, thick strained yogurt swirled with golden tahini and honey, dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Patlıcan Ezmesi
**File Path:** `photos/meals/yogurtlu_patlican_ezmesi.webp`
**Prompt:** Ultra realistic food photography, Turkish smoky charred eggplant dip with strained yogurt and garlic, drizzled with olive oil and topped with chopped parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Bulgurlu Salata
**File Path:** `photos/meals/sade_bulgurlu_salata.webp`
**Prompt:** Ultra realistic food photography, fine bulgur salad with diced tomato, cucumber, onion and chopped parsley, dressed with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çiğ Sebze ve Yoğurtlu Sos
**File Path:** `photos/meals/cig_sebze_ve_yogurtlu_sos.webp`
**Prompt:** Ultra realistic food photography, fresh raw vegetable sticks (carrot, cucumber, green pepper) arranged around a small ceramic bowl of garlic-mint yogurt dip, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Patates Pofuduk
**File Path:** `photos/meals/patates_pofuduk.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried potato fritters made from mashed boiled potatoes with onion and parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hızlı İrmik Helvası
**File Path:** `photos/meals/hizli_irmik_helvasi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish semolina halva with toasted pine nuts dusted with cinnamon, scooped into a small mound, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tahin-Pekmez Topları
**File Path:** `photos/meals/tahin_pekmez_toplari.webp`
**Prompt:** Ultra realistic food photography, no-bake energy balls made from oats, tahini and grape molasses, rolled in shredded coconut, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Muzlu Yoğurt Tatlısı
**File Path:** `photos/meals/muzlu_yogurt_tatlisi.webp`
**Prompt:** Ultra realistic food photography, thick yogurt dessert topped with sliced bananas, honey drizzle and chopped walnuts, dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Cevizli Yoğurt Tatlısı
**File Path:** `photos/meals/cevizli_yogurt_tatlisi.webp`
**Prompt:** Ultra realistic food photography, thick strained yogurt topped with crushed walnuts, golden honey, cinnamon and shredded coconut, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mikrodalgada Tarçınlı Elma
**File Path:** `photos/meals/mikrodalgada_tarcinli_elma.webp`
**Prompt:** Ultra realistic food photography, warm cinnamon-baked apple cubes in a small ceramic dish, glistening with honey and butter, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Reçelli Yoğurt Kasesi
**File Path:** `photos/meals/receli_yogurt_kasesi.webp`
**Prompt:** Ultra realistic food photography, thick yogurt topped with vibrant red fruit jam and a sprinkle of golden granola, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çikolatalı Yulaf Topları
**File Path:** `photos/meals/cikolatali_yulaf_toplari.webp`
**Prompt:** Ultra realistic food photography, no-bake chocolate oat balls made with cocoa, peanut butter and honey, rolled in shredded coconut, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pekmezli Yoğurt Mousse
**File Path:** `photos/meals/pekmezli_yogurt_mousse.webp`
**Prompt:** Ultra realistic food photography, strained yogurt mousse swirled with grape molasses creating a marble pattern, topped with crushed walnuts, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Limon-Bal Yoğurt
**File Path:** `photos/meals/limon_bal_yogurt.webp`
**Prompt:** Ultra realistic food photography, refreshing strained yogurt with lemon zest, lemon juice and a swirl of golden honey, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Sütlaç
**File Path:** `photos/meals/pratik_sutlac.webp`
**Prompt:** Ultra realistic food photography, classic Turkish rice pudding (sütlaç) dusted with cinnamon, served in a small ceramic ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindistan Cevizli Chia Pudingi
**File Path:** `photos/meals/hindistan_cevizli_chia_pudingi.webp`
**Prompt:** Ultra realistic food photography, coconut milk chia seed pudding topped with banana slices and shredded coconut, drizzled with honey, served in a small mason jar, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bal-Tarçınlı Ekmek Tatlısı
**File Path:** `photos/meals/bal_tarcinli_ekmek_tatlisi.webp`
**Prompt:** Ultra realistic food photography, golden Turkish-style French toast with cinnamon-egg batter, drizzled with honey, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Çilek Mousse
**File Path:** `photos/meals/yogurtlu_cilek_mousse.webp`
**Prompt:** Ultra realistic food photography, creamy strained yogurt mousse swirled with fresh strawberry purée, topped with whole strawberries, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Cevizli Hurma Topları
**File Path:** `photos/meals/cevizli_hurma_toplari.webp`
**Prompt:** Ultra realistic food photography, no-bake date and walnut energy balls dusted with cocoa powder and rolled in shredded coconut, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Muz-Tahin Sandviç
**File Path:** `photos/meals/muz_tahin_sandvic.webp`
**Prompt:** Ultra realistic food photography, whole wheat sandwich filled with sliced banana, tahini and grape molasses, sliced diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Donmuş Muz Dilimleri
**File Path:** `photos/meals/donmus_muz_dilimleri.webp`
**Prompt:** Ultra realistic food photography, frozen banana slices half-dipped in dark chocolate, sprinkled with shredded coconut and crushed walnuts, served on parchment paper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pekmezli Süt Tatlısı
**File Path:** `photos/meals/pekmezli_sut_tatlisi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish milk pudding topped with grape molasses, crushed walnuts and a dusting of cinnamon, served in a small ceramic ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tarçınlı Yulaf Tatlısı
**File Path:** `photos/meals/tarcinli_yulaf_tatlisi.webp`
**Prompt:** Ultra realistic food photography, warm cinnamon oatmeal dessert drizzled with honey and topped with crushed walnuts, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Un Helvası
**File Path:** `photos/meals/sade_un_helvasi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish flour halva with toasted pine nuts, scooped into a small mound, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Muhallebi
**File Path:** `photos/meals/pratik_muhallebi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish milk pudding (muhallebi) dusted with cinnamon, served in a small ceramic ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Budget Category Covers

Five hero compositions for the dashboard "Pratik & Ekonomik" strip's sub-cards. Unlike the per-meal prompts above, these are deliberately multi-food scenes — the cards live next to the canonical "Öğün Kategorileri" strip, so the visual language must read as "a bucket of meals" rather than a single dish. File paths are placeholder; once generated, swap the `imageUrl` on the corresponding `_budgetCategoryEntries` entry in `lib/features/nutrition/presentation/nutrition_tab.dart`.

### Pratik & Ekonomik · Kahvaltı (cover)
**File Path:** `photos/meals/budget_cover_breakfast.webp`
**Prompt:** Ultra realistic food photography, Turkish budget breakfast spread with menemen in a small skillet, white cheese cubes, sliced tomatoes and cucumbers, black olives, simit bread and a glass of tea, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik & Ekonomik · Öğle Yemeği (cover)
**File Path:** `photos/meals/budget_cover_lunch.webp`
**Prompt:** Ultra realistic food photography, Turkish budget lunch spread with red lentil soup, white rice pilaf, simple bulgur salad, sliced tomato salad and a glass of ayran, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik & Ekonomik · Akşam Yemeği (cover)
**File Path:** `photos/meals/budget_cover_dinner.webp`
**Prompt:** Ultra realistic food photography, Turkish budget dinner spread with chicken sauté, fluffy bulgur pilaf, sautéed potato wedges, white cheese plate and yogurt bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik & Ekonomik · Tatlı Çeşitleri (cover)
**File Path:** `photos/meals/budget_cover_dessert.webp`
**Prompt:** Ultra realistic food photography, Turkish budget dessert spread with semolina halva, rice pudding ramekins, yogurt with honey and walnuts, tahini-molasses energy balls and stewed cinnamon apples, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik & Ekonomik · Atıştırmalıklar (cover)
**File Path:** `photos/meals/budget_cover_snack.webp`
**Prompt:** Ultra realistic food photography, Turkish budget snack spread with cucumber sticks and yogurt dip, mixed olives and cheese plate, homemade potato chips, sliced tomato salad and a small cacık bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

---

## Phase 84 — Full Expansion

125 meals (25 per meal_type) covering tag gaps the existing catalogue under-served: Yüksek Protein (fitness primary), Düşük Kalori, Hacim (bulk/gain), Sıkılaşma (toning), with Pratik & Ekonomik as a budget overlay where natural. Source SQL: `supabase/sql/phase84_full_meal_expansion.sql`. Generate each webp at 1080×1080 and re-encode through `convert in -quality 90 WEBP:out` if the Midjourney export saves as PNG-disguised-as-webp.

### Çılbır
**File Path:** `photos/meals/cilbir.webp`
**Prompt:** Ultra realistic food photography, classic Turkish çılbır with two poached eggs nesting in a bed of garlicky strained yogurt, drizzled with red pepper flake butter, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Mıhlama
**File Path:** `photos/meals/sade_mihlama.webp`
**Prompt:** Ultra realistic food photography, traditional Black Sea Turkish mıhlama, melted kaşar cheese stretched into a stringy cornmeal fondue in a small black skillet, garnished with cracked pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Tarhana Çorbası
**File Path:** `photos/meals/yumurtali_tarhana_corbasi.webp`
**Prompt:** Ultra realistic food photography, Turkish tarhana soup with delicate egg ribbons and a swirl of red pepper butter, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hellim Peyniri Tava
**File Path:** `photos/meals/hellim_peyniri_tava.webp`
**Prompt:** Ultra realistic food photography, golden pan-seared halloumi cheese slices arranged with a slice of bread, black olives, fresh mint and a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tarçınlı Yumurta Tostu
**File Path:** `photos/meals/tarcinli_yumurta_tostu.webp`
**Prompt:** Ultra realistic food photography, Turkish-style French toast with whole wheat bread soaked in cinnamon-egg batter, drizzled with golden honey, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kuru Kayısı Yulaflı Süt
**File Path:** `photos/meals/kuru_kayisi_yulafli_sut.webp`
**Prompt:** Ultra realistic food photography, hot creamy oatmeal with diced dried apricots and honey drizzle, dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Karadeniz Kuymak
**File Path:** `photos/meals/karadeniz_kuymak.webp`
**Prompt:** Ultra realistic food photography, traditional Black Sea Turkish kuymak with stringy melted fresh cheese stretching from a cornmeal-butter base in a small black skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Beyaz Peynirli Krep
**File Path:** `photos/meals/beyaz_peynirli_krep.webp`
**Prompt:** Ultra realistic food photography, savory Turkish crepe folded in half over crumbled white cheese and chopped parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Limonlu Bal Sıcak Süt
**File Path:** `photos/meals/limonlu_bal_sicak_sut.webp`
**Prompt:** Ultra realistic food photography, glass mug of warm milk with golden honey drizzle and lemon slices, dusted with cinnamon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Yoğurtlu Çilek Kasesi
**File Path:** `photos/meals/suzme_yogurtlu_cilek_kasesi.webp`
**Prompt:** Ultra realistic food photography, thick strained yogurt topped with sliced fresh strawberries, golden honey drizzle and a sprinkle of granola, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Göğsülü Sade Sandviç
**File Path:** `photos/meals/tavuk_gogsulu_sade_sandvic.webp`
**Prompt:** Ultra realistic food photography, whole wheat sandwich layered with sliced grilled chicken breast, lettuce and tomato with a yogurt spread, sliced diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Yoğurtlu Protein Smoothie
**File Path:** `photos/meals/suzme_yogurtlu_protein_smoothie.webp`
**Prompt:** Ultra realistic food photography, tall glass of frothy protein smoothie made with strained yogurt, banana and vanilla protein, topped with a banana slice, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çırpılmış Yumurta ve Pastırma
**File Path:** `photos/meals/cirpilmis_yumurta_ve_pastirma.webp`
**Prompt:** Ultra realistic food photography, soft scrambled eggs studded with thin slices of Turkish pastırma cured beef, topped with a small pat of melting butter, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurta Akı ve Sebze Tabağı
**File Path:** `photos/meals/yumurta_aki_ve_sebze_tabagi.webp`
**Prompt:** Ultra realistic food photography, fluffy egg white scramble served with sliced cucumber, tomato wedges and fresh mint leaves, drizzled with olive oil, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tarçınlı Süzme Yoğurt
**File Path:** `photos/meals/tarcinli_suzme_yogurt.webp`
**Prompt:** Ultra realistic food photography, thick strained yogurt with cinnamon dusting, golden honey drizzle and crushed walnut pieces, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yulaflı Süt Çorbası
**File Path:** `photos/meals/yulafli_sut_corbasi.webp`
**Prompt:** Ultra realistic food photography, smooth hot oat milk soup with butter swirl, drizzled with honey and dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Üzümlü Yulaf
**File Path:** `photos/meals/uzumlu_yulaf.webp`
**Prompt:** Ultra realistic food photography, warm oatmeal with raisins and a drizzle of honey, dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Çıtır Yumurtalı Sandviç
**File Path:** `photos/meals/citir_yumurtali_sandvic.webp`
**Prompt:** Ultra realistic food photography, golden whole wheat sandwich filled with two crispy fried eggs, lettuce leaf and tomato slice, sliced diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Yoğurtlu Yer Fıstığı
**File Path:** `photos/meals/suzme_yogurtlu_yer_fistigi.webp`
**Prompt:** Ultra realistic food photography, thick strained yogurt topped with whole roasted peanuts, golden honey drizzle and cinnamon dust, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Sucuklu Krep
**File Path:** `photos/meals/sade_sucuklu_krep.webp`
**Prompt:** Ultra realistic food photography, golden crepe rolled around sliced Turkish sucuk sausage, sprinkled with cracked pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yulaflı Tarçınlı Smoothie
**File Path:** `photos/meals/yulafli_tarcinli_smoothie.webp`
**Prompt:** Ultra realistic food photography, tall glass of cinnamon oat smoothie with banana, dusted with cinnamon on top, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Peynirli Tost
**File Path:** `photos/meals/suzme_peynirli_tost.webp`
**Prompt:** Ultra realistic food photography, golden grilled whole wheat sandwich filled with creamy strained Turkish white cheese, fresh tomato slices and mint leaves, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mantarlı Sade Omlet
**File Path:** `photos/meals/mantarli_sade_omlet.webp`
**Prompt:** Ultra realistic food photography, fluffy folded mushroom omelette with sautéed mushroom slices peeking out, sprinkled with cracked pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Salam ve Yumurta
**File Path:** `photos/meals/hindi_salam_ve_yumurta.webp`
**Prompt:** Ultra realistic food photography, two sunny-side-up eggs over sautéed Turkish turkey salami slices in a small black skillet, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kıymalı Yumurta Tava
**File Path:** `photos/meals/kiymali_yumurta_tava.webp`
**Prompt:** Ultra realistic food photography, ground beef sautéed with onion and tomato paste topped with two sunny-side-up eggs in a small black skillet, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Acılı Domates Çorbası
**File Path:** `photos/meals/acili_domates_corbasi.webp`
**Prompt:** Ultra realistic food photography, vibrant red Turkish spicy tomato soup with red pepper flakes and a butter swirl, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Mercimek Çorbası
**File Path:** `photos/meals/yogurtlu_mercimek_corbasi.webp`
**Prompt:** Ultra realistic food photography, smooth red lentil soup topped with a generous swirl of strained yogurt and red pepper butter, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bahçıvan Salatası
**File Path:** `photos/meals/bahcivan_salatasi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish garden salad with mixed lettuce, diced tomato, cucumber, green pepper and grated carrot, dressed with olive oil, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Erişte Çorbası
**File Path:** `photos/meals/tavuklu_eriste_corbasi.webp`
**Prompt:** Ultra realistic food photography, Turkish chicken noodle soup with shredded chicken breast, homemade noodles and diced carrot, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Etli Tarhana Çorbası
**File Path:** `photos/meals/etli_tarhana_corbasi.webp`
**Prompt:** Ultra realistic food photography, hearty tarhana soup with ground beef and tomato paste, finished with butter, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Soslu Makarna
**File Path:** `photos/meals/hindi_soslu_makarna.webp`
**Prompt:** Ultra realistic food photography, pasta with rich ground turkey tomato sauce and onion, sprinkled with black pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Beyaz Pilav ve Etli Sote
**File Path:** `photos/meals/beyaz_pilav_ve_etli_sote.webp`
**Prompt:** Ultra realistic food photography, fluffy white rice pilaf served alongside Turkish beef sauté in tomato paste sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Pirinç Çorbası
**File Path:** `photos/meals/yogurtlu_pirinc_corbasi.webp`
**Prompt:** Ultra realistic food photography, creamy Turkish yogurt-rice soup with delicate egg-yogurt thickening, finished with a swirl of mint butter, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Ezogelin Çorbası
**File Path:** `photos/meals/ezogelin_corbasi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish ezogelin soup with red lentils and bulgur in a tomato-paste base, finished with dried mint, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mercimekli Erişte
**File Path:** `photos/meals/mercimekli_eriste.webp`
**Prompt:** Ultra realistic food photography, Turkish homemade noodles tossed with red lentils, sautéed onion and dried mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Karnabahar Sote
**File Path:** `photos/meals/tavuklu_karnabahar_sote.webp`
**Prompt:** Ultra realistic food photography, sautéed chicken breast cubes with cauliflower florets in tomato paste sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Etli Yoğurtlu Köfte
**File Path:** `photos/meals/hindi_etli_yogurtlu_kofte.webp`
**Prompt:** Ultra realistic food photography, ground turkey meatballs served over thick strained yogurt sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Yoğurtlu Wrap
**File Path:** `photos/meals/hindi_yogurtlu_wrap.webp`
**Prompt:** Ultra realistic food photography, Turkish lavash wrap rolled around sliced turkey breast, lettuce, tomato and creamy yogurt spread, sliced diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Patates Salatası
**File Path:** `photos/meals/tavuklu_patates_salatasi.webp`
**Prompt:** Ultra realistic food photography, creamy Turkish chicken-potato salad with diced boiled potatoes, shredded chicken breast and onion, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Roka Salatası ve Izgara Tavuk
**File Path:** `photos/meals/roka_salatasi_ve_izgara_tavuk.webp`
**Prompt:** Ultra realistic food photography, sliced grilled chicken breast over fresh arugula with sliced tomato, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavada Karnabahar Köftesi
**File Path:** `photos/meals/tavada_karnabahar_koftesi.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried cauliflower fritters with crispy edges, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Hindi Etli Pilav
**File Path:** `photos/meals/sade_hindi_etli_pilav.webp`
**Prompt:** Ultra realistic food photography, fluffy buttered rice pilaf cooked with ground turkey and sautéed onion, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hızlı Kuru Fasulye Yemeği
**File Path:** `photos/meals/hizli_kuru_fasulye_yemegi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish white bean stew (kuru fasulye) in tomato paste sauce sprinkled with red pepper flakes, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Nohut Yemeği
**File Path:** `photos/meals/pratik_nohut_yemegi.webp`
**Prompt:** Ultra realistic food photography, Turkish chickpea stew in tomato paste sauce seasoned with cumin, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Domatesli Pirinç Pilavı
**File Path:** `photos/meals/domatesli_pirinc_pilavi.webp`
**Prompt:** Ultra realistic food photography, vibrant Turkish tomato rice pilaf with diced tomato and butter, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Sebze Çorbası
**File Path:** `photos/meals/tavuklu_sebze_corbasi.webp`
**Prompt:** Ultra realistic food photography, hearty chicken vegetable soup with shredded chicken breast, diced potato and carrot, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Soğanlı Etli Sote
**File Path:** `photos/meals/soganli_etli_sote.webp`
**Prompt:** Ultra realistic food photography, beef sauté with deeply caramelized onions and red pepper flakes in tomato paste sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Etli Sebzeli Çorba
**File Path:** `photos/meals/etli_sebzeli_corba.webp`
**Prompt:** Ultra realistic food photography, hearty beef vegetable soup with diced potato, carrot and beef cubes in a clear broth, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Mantar Sote
**File Path:** `photos/meals/tavuklu_mantar_sote.webp`
**Prompt:** Ultra realistic food photography, sautéed chicken breast cubes with sliced mushrooms in a light tomato sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bonfileli Salata
**File Path:** `photos/meals/bonfileli_salata.webp`
**Prompt:** Ultra realistic food photography, sliced grilled beef tenderloin over fresh arugula with sliced tomato and cucumber, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Şinitzel
**File Path:** `photos/meals/tavuk_sinitzel.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried Turkish-style chicken schnitzel with crispy breadcrumb coating, served with a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Levrek Tava
**File Path:** `photos/meals/levrek_tava.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried sea bass fillet with crispy edges, garnished with fresh parsley and a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hamsi Tava
**File Path:** `photos/meals/hamsi_tava.webp`
**Prompt:** Ultra realistic food photography, traditional Turkish anchovies (hamsi) coated in cornmeal and pan-fried golden, arranged in a fan pattern with lemon wedges, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Bonfile Sote
**File Path:** `photos/meals/sade_bonfile_sote.webp`
**Prompt:** Ultra realistic food photography, simple beef tenderloin sauté with diced onion in tomato paste sauce, sprinkled with cracked pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Domates Salçalı Bonfile Yemeği
**File Path:** `photos/meals/domates_salcali_bonfile_yemegi.webp`
**Prompt:** Ultra realistic food photography, beef tenderloin cubes simmered in a rich tomato-paste and fresh tomato sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Karnıyarık
**File Path:** `photos/meals/pratik_karniyarik.webp`
**Prompt:** Ultra realistic food photography, classic Turkish karnıyarık with split eggplants stuffed with seasoned ground beef, onion and tomato, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mücver Tava
**File Path:** `photos/meals/mucver_tava.webp`
**Prompt:** Ultra realistic food photography, golden Turkish zucchini fritters (mücver) with white cheese and dill, served on a small ceramic plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuklu Karnıyarık
**File Path:** `photos/meals/tavuklu_karniyarik.webp`
**Prompt:** Ultra realistic food photography, Turkish karnıyarık variation with split eggplants stuffed with ground chicken, onion and tomato paste, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Etli Kuru Fasulye
**File Path:** `photos/meals/etli_kuru_fasulye.webp`
**Prompt:** Ultra realistic food photography, hearty Turkish white bean stew with beef cubes in tomato paste sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Etli Nohut
**File Path:** `photos/meals/etli_nohut.webp`
**Prompt:** Ultra realistic food photography, Turkish chickpea and beef stew in rich tomato paste sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Şiş
**File Path:** `photos/meals/tavuk_sis.webp`
**Prompt:** Ultra realistic food photography, Turkish chicken shish kebab skewers with grilled chicken breast cubes alternating with green pepper and onion, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Etli Pırasa Yemeği
**File Path:** `photos/meals/etli_pirasa_yemegi.webp`
**Prompt:** Ultra realistic food photography, Turkish leek and ground beef stew in tomato paste sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Etli Kabak Yemeği
**File Path:** `photos/meals/etli_kabak_yemegi.webp`
**Prompt:** Ultra realistic food photography, Turkish zucchini and ground beef stew in tomato paste sauce, garnished with fresh dill, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavuk Göğsü Tava
**File Path:** `photos/meals/tavuk_gogsu_tava.webp`
**Prompt:** Ultra realistic food photography, simple pan-seared chicken breast with garlic and lemon, served with a lemon wedge, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Izgara Köfte
**File Path:** `photos/meals/sade_izgara_kofte.webp`
**Prompt:** Ultra realistic food photography, classic Turkish grilled meatballs with cumin seasoning, arranged in a row on a small plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik İmam Bayıldı
**File Path:** `photos/meals/pratik_imam_bayildi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish imam bayıldı with split eggplants filled with caramelized onions, garlic and tomato in olive oil, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Taze Fasulye Etli
**File Path:** `photos/meals/taze_fasulye_etli.webp`
**Prompt:** Ultra realistic food photography, Turkish green bean and beef stew in tomato paste sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Türlü Sebze Etli
**File Path:** `photos/meals/turlu_sebze_etli.webp`
**Prompt:** Ultra realistic food photography, Turkish türlü mixed vegetable stew with eggplant, zucchini, potato and ground beef in tomato paste sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kıymalı Patates Yemeği
**File Path:** `photos/meals/kiymali_patates_yemegi.webp`
**Prompt:** Ultra realistic food photography, Turkish ground beef and potato stew in tomato paste sauce with diced onion, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mantarlı Tavuk Sote
**File Path:** `photos/meals/mantarli_tavuk_sote.webp`
**Prompt:** Ultra realistic food photography, sautéed chicken breast cubes with sliced mushrooms and onion in tomato paste sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bezelye Etli
**File Path:** `photos/meals/bezelye_etli.webp`
**Prompt:** Ultra realistic food photography, Turkish green pea and beef stew with diced carrot in light tomato sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Etli Nohutlu Pilav
**File Path:** `photos/meals/etli_nohutlu_pilav.webp`
**Prompt:** Ultra realistic food photography, fluffy buttered rice pilaf with chickpeas and beef cubes, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Soğanlı Köfte
**File Path:** `photos/meals/soganli_kofte.webp`
**Prompt:** Ultra realistic food photography, Turkish meatballs in caramelized onion and tomato paste sauce seasoned with cumin, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pırasalı Pilav
**File Path:** `photos/meals/pirasali_pilav.webp`
**Prompt:** Ultra realistic food photography, fluffy buttered rice pilaf with sautéed leek slices, sprinkled with cracked pepper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pırasa Köftesi
**File Path:** `photos/meals/pirasa_koftesi.webp`
**Prompt:** Ultra realistic food photography, golden pan-fried Turkish leek fritters with white cheese, served on a small ceramic plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Soğuk Tavuk Göğsü Dilimleri
**File Path:** `photos/meals/soguk_tavuk_gogsu_dilimleri.webp`
**Prompt:** Ultra realistic food photography, sliced poached chicken breast arranged with green pepper strips, drizzled with olive oil and lemon, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurta-Avokado Tabağı
**File Path:** `photos/meals/yumurta_avokado_tabagi.webp`
**Prompt:** Ultra realistic food photography, halved hard-boiled eggs arranged with sliced avocado and black olives, drizzled with olive oil, served with a slice of bread, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hardallı Tavuk Salatası
**File Path:** `photos/meals/hardalli_tavuk_salatasi.webp`
**Prompt:** Ultra realistic food photography, mixed lettuce salad topped with diced grilled chicken breast and creamy mustard-yogurt dressing, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Lor Peynirli Domates Tabağı
**File Path:** `photos/meals/lor_peynirli_domates_tabagi.webp`
**Prompt:** Ultra realistic food photography, plate of fresh sliced tomatoes alongside Turkish curd cheese (lor) and black olives, drizzled with olive oil and oregano, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Roka ve Ceviz Salatası
**File Path:** `photos/meals/roka_ve_ceviz_salatasi.webp`
**Prompt:** Ultra realistic food photography, fresh arugula salad with crumbled white cheese and walnut pieces, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tahin Soslu Marul Salatası
**File Path:** `photos/meals/tahin_soslu_marul_salatasi.webp`
**Prompt:** Ultra realistic food photography, fresh lettuce salad drizzled with creamy tahini-lemon-garlic dressing, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Karnabahar Salatası
**File Path:** `photos/meals/yogurtlu_karnabahar_salatasi.webp`
**Prompt:** Ultra realistic food photography, Turkish cauliflower yogurt salad with cooked cauliflower florets in garlic yogurt sauce, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Yumurtalı Salata
**File Path:** `photos/meals/pratik_yumurtali_salata.webp`
**Prompt:** Ultra realistic food photography, fresh lettuce and tomato salad topped with sliced hard-boiled eggs, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Karpuzlu Beyaz Peynir
**File Path:** `photos/meals/karpuzlu_beyaz_peynir.webp`
**Prompt:** Ultra realistic food photography, classic Turkish summer plate of cubed watermelon and Turkish white cheese, garnished with fresh mint, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Yoğurtlu Beyaz Peynir Tabağı
**File Path:** `photos/meals/suzme_yogurtlu_beyaz_peynir_tabagi.webp`
**Prompt:** Ultra realistic food photography, plate with strained yogurt bowl, white cheese cubes, walnut pieces and a honey drizzle, dusted with cinnamon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Salam Tabağı
**File Path:** `photos/meals/hindi_salam_tabagi.webp`
**Prompt:** Ultra realistic food photography, plate of sliced Turkish turkey salami with white cheese cubes, black olives, sliced tomato and a slice of whole wheat bread, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tavada Sade Sebze Atıştırmalığı
**File Path:** `photos/meals/tavada_sade_sebze_atistirmaligi.webp`
**Prompt:** Ultra realistic food photography, simple pan-sautéed sliced eggplant, zucchini and green pepper sprinkled with dried oregano, served on a small plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Tahin Soslu Havuç Sticks
**File Path:** `photos/meals/tahin_soslu_havuc_sticks.webp`
**Prompt:** Ultra realistic food photography, fresh carrot sticks arranged around a small bowl of tahini-grape molasses dipping sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Pancar Salatası
**File Path:** `photos/meals/yogurtlu_pancar_salatasi.webp`
**Prompt:** Ultra realistic food photography, Turkish beet yogurt salad with grated cooked beet in garlic-yogurt sauce, sprinkled with crushed walnuts, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Maydanozlu Yumurta Salatası
**File Path:** `photos/meals/maydanozlu_yumurta_salatasi.webp`
**Prompt:** Ultra realistic food photography, creamy egg salad with chopped hard-boiled eggs, strained yogurt and abundant fresh parsley, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Peynirli Roll
**File Path:** `photos/meals/yumurtali_peynirli_roll.webp`
**Prompt:** Ultra realistic food photography, Turkish lavash roll filled with hard-boiled egg slices, white cheese and parsley, sliced into pinwheels, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Tahıl Bar
**File Path:** `photos/meals/sade_tahil_bar.webp`
**Prompt:** Ultra realistic food photography, homemade no-bake oat granola bars with raisins, walnuts, tahini and honey, sliced into rectangles, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Tavuk Sandviç
**File Path:** `photos/meals/yogurtlu_tavuk_sandvic.webp`
**Prompt:** Ultra realistic food photography, whole wheat sandwich filled with sliced grilled chicken breast, lettuce, tomato and creamy yogurt spread, sliced diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Limon Soslu Roka Salatası
**File Path:** `photos/meals/limon_soslu_roka_salatasi.webp`
**Prompt:** Ultra realistic food photography, fresh arugula salad with walnut pieces and fresh mint, dressed with lemon-olive oil vinaigrette, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bal-Cevizli Lor Peyniri
**File Path:** `photos/meals/bal_cevizli_lor_peyniri.webp`
**Prompt:** Ultra realistic food photography, Turkish curd cheese (lor) topped with crushed walnuts and golden honey drizzle, dusted with cinnamon, served with a slice of bread, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Pancar Salatası
**File Path:** `photos/meals/sade_pancar_salatasi.webp`
**Prompt:** Ultra realistic food photography, simple cooked beet salad with thin onion rings, drizzled with olive oil and lemon, garnished with parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yumurtalı Domates Sandviç
**File Path:** `photos/meals/yumurtali_domates_sandvic.webp`
**Prompt:** Ultra realistic food photography, whole wheat sandwich with sliced hard-boiled egg, fresh tomato slice and mint leaves, sliced diagonally, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Peynirli Avokado
**File Path:** `photos/meals/suzme_peynirli_avokado.webp`
**Prompt:** Ultra realistic food photography, halved avocado with the pit cavity filled with creamy strained Turkish white cheese, drizzled with olive oil and lemon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindi Etli Marul Wrap
**File Path:** `photos/meals/hindi_etli_marul_wrap.webp`
**Prompt:** Ultra realistic food photography, lettuce-leaf wrap rolled around sliced turkey breast, cucumber sticks and yogurt-mustard sauce, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Pirinç Salatası
**File Path:** `photos/meals/yogurtlu_pirinc_salatasi.webp`
**Prompt:** Ultra realistic food photography, cold rice salad with strained yogurt, diced cucumber, onion and abundant fresh parsley, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yüksek Proteinli Yoğurt Mousse
**File Path:** `photos/meals/yuksek_proteinli_yogurt_mousse.webp`
**Prompt:** Ultra realistic food photography, thick high-protein yogurt mousse swirled with vanilla protein powder, topped with golden honey and a sprinkle of granola, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Kakaolu Hurma Topları
**File Path:** `photos/meals/kakaolu_hurma_toplari.webp`
**Prompt:** Ultra realistic food photography, no-bake date and almond energy balls dusted with cocoa powder and rolled in shredded coconut, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Süzme Yoğurtlu Frozen Bar
**File Path:** `photos/meals/suzme_yogurtlu_frozen_bar.webp`
**Prompt:** Ultra realistic food photography, frozen yogurt bars made with strained yogurt and crushed strawberries, topped with granola, sliced into rectangles, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yoğurtlu Çikolata Mousse
**File Path:** `photos/meals/yogurtlu_cikolata_mousse.webp`
**Prompt:** Ultra realistic food photography, thick chocolate yogurt mousse with strained yogurt and cocoa, topped with grated dark chocolate and cinnamon, served in a small ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bademli Süt Pudingi
**File Path:** `photos/meals/bademli_sut_pudingi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish milk pudding topped with crushed almonds and a dusting of vanilla, served in a small ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Karamel Soslu Yoğurt
**File Path:** `photos/meals/karamel_soslu_yogurt.webp`
**Prompt:** Ultra realistic food photography, thick strained yogurt drizzled with golden butter caramel sauce, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pekmezli Hurma Pudingi
**File Path:** `photos/meals/pekmezli_hurma_pudingi.webp`
**Prompt:** Ultra realistic food photography, Turkish milk pudding studded with chopped dates, drizzled with grape molasses and topped with crushed walnuts, served in a small ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Limonlu Yoğurt Bar
**File Path:** `photos/meals/limonlu_yogurt_bar.webp`
**Prompt:** Ultra realistic food photography, frozen lemon yogurt bars with lemon zest and granola crust, sliced into rectangles, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Cevizli Karamelize Muz
**File Path:** `photos/meals/cevizli_karamelize_muz.webp`
**Prompt:** Ultra realistic food photography, halved bananas pan-caramelized in butter and honey, topped with crushed walnuts and dusted with cinnamon, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Pirinç Sütü Tatlısı
**File Path:** `photos/meals/sade_pirinc_sutu_tatlisi.webp`
**Prompt:** Ultra realistic food photography, classic Turkish rice pudding made with cooked rice and milk, dusted with cinnamon, served in a small ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Süt Helvası
**File Path:** `photos/meals/sade_sut_helvasi.webp`
**Prompt:** Ultra realistic food photography, Turkish milk halva with toasted flour and walnuts, scooped into a small mound, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Mikrodalgada Çikolatalı Kek
**File Path:** `photos/meals/mikrodalgada_cikolatali_kek.webp`
**Prompt:** Ultra realistic food photography, microwave chocolate mug cake with a soft fluffy crumb, dusted with cocoa powder, served in a white ceramic mug, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yulaflı Muzlu Cookie
**File Path:** `photos/meals/yulafli_muzlu_cookie.webp`
**Prompt:** Ultra realistic food photography, homemade oat-banana cookies with chocolate chips and walnut pieces, arranged on parchment paper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Yumurtalı Süt Tatlısı
**File Path:** `photos/meals/sade_yumurtali_sut_tatlisi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish egg-milk custard dessert dusted with cinnamon, served in a small ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Donmuş Yoğurt Topları
**File Path:** `photos/meals/donmus_yogurt_toplari.webp`
**Prompt:** Ultra realistic food photography, frozen yogurt scoops made with strained yogurt and crushed strawberries on parchment paper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hızlı Sade Lokma
**File Path:** `photos/meals/hizli_sade_lokma.webp`
**Prompt:** Ultra realistic food photography, Turkish lokma (sweet fritters) drizzled with light syrup, piled in a small bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade İncir Tatlısı
**File Path:** `photos/meals/sade_incir_tatlisi.webp`
**Prompt:** Ultra realistic food photography, dried figs simmered in milk topped with crushed walnuts and a honey drizzle, dusted with cinnamon, served in a small bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Pratik Aşure
**File Path:** `photos/meals/pratik_asure.webp`
**Prompt:** Ultra realistic food photography, classic Turkish aşure (Noah's pudding) with mixed grains, chickpeas, beans and raisins, dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Bal Soslu Vanilyalı Yoğurt
**File Path:** `photos/meals/bal_soslu_vanilyali_yogurt.webp`
**Prompt:** Ultra realistic food photography, vanilla-scented strained yogurt drizzled with golden honey and topped with crushed walnuts, dusted with cinnamon, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Beyaz Peynirli Bal Tatlısı
**File Path:** `photos/meals/beyaz_peynirli_bal_tatlisi.webp`
**Prompt:** Ultra realistic food photography, crumbled Turkish white cheese topped with crushed walnuts, golden honey drizzle and cinnamon, served with a slice of whole wheat bread, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Şerbetli Yulaf Topları
**File Path:** `photos/meals/serbetli_yulaf_toplari.webp`
**Prompt:** Ultra realistic food photography, syrup-soaked oat balls rolled in shredded coconut, arranged on a small ceramic plate, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Hindistan Cevizli Süt Pudingi
**File Path:** `photos/meals/hindistan_cevizli_sut_pudingi.webp`
**Prompt:** Ultra realistic food photography, smooth Turkish milk pudding topped with abundant shredded coconut, served in a small ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Sade Tahin Mousse
**File Path:** `photos/meals/sade_tahin_mousse.webp`
**Prompt:** Ultra realistic food photography, strained yogurt mousse swirled with tahini and grape molasses creating a marble pattern, topped with crushed walnuts, served in a small ceramic bowl, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Şekersiz Çikolatalı Yoğurt Mousse
**File Path:** `photos/meals/sekersiz_cikolatali_yogurt_mousse.webp`
**Prompt:** Ultra realistic food photography, sugar-free chocolate yogurt mousse made with strained yogurt, cocoa and protein powder, topped with banana slices, served in a small ramekin, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k

### Yulaflı Çikolata Cookie
**File Path:** `photos/meals/yulafli_cikolata_cookie.webp`
**Prompt:** Ultra realistic food photography, homemade oat cookies with melted dark chocolate chips, arranged on parchment paper, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k
