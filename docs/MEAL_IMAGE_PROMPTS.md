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
