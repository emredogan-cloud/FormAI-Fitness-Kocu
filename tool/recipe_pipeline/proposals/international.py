"""Roadmap Phase 7 §5.3 · the international athlete catalogue, authored.

    python3 tool/recipe_pipeline/proposals/international.py

Forty recipes aimed at nobody's home country in particular: Japanese
salmon-rice bowls, Mexican egg-and-bean plates, Indian paneer and dal,
Greek and Levantine mezze, Korean tofu stews.

`locale_scope = []` on every one — empty, not `['en']`. These are the
recipes that make the catalogue feel worldly to EVERY user, including
the Turkish one, and scoping them to a language would be the exact
mistake `015_recipe_origin_and_diet.sql` warns about one step earlier
than usual.

The briefs are macro-legible on purpose. A poke bowl and a dal are both
recognisable dishes and both readable as protein/carb/fat, which is what
makes them usable by somebody tracking rather than merely browsing.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _authoring import emit, ing, recipe  # noqa: E402

ALL = []          # locale_scope: empty means "no preference"
R = []

# ─── Japanese (6) ───────────────────────────────────────────────────

R.append(recipe(
    "salmon-donburi", "Salmon Donburi",
    "Somonlu Donburi", "dinner", "japanese", 25, ["high_protein", "bulking"],
    ALL, 42, 64, 18,
    [ing(170, "g", "salmon fillet", "somon fileto"),
     ing(85, "g", "sushi rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(2, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "yemek kaşığı", "mirin", "mirin", "sweet rice wine; honey and "
         "water works", "tatlı pirinç sirkesi; bal ve su da olur"),
     ing(1, "çay kaşığı", "sesame seeds", "susam"),
     ing(1, "yemek kaşığı", "spring onion", "yeşil soğan")],
    ["Cook the rice and keep it warm.",
     "Simmer the soy sauce and mirin for 2 minutes until slightly syrupy.",
     "Sear the salmon skin-side down for 4 minutes, then 2 on the flesh.",
     "Flake the salmon over the rice, pour the glaze on, and finish with "
     "sesame and spring onion."],
    ["Pirinci pişirip sıcak tutun.",
     "Soya sosu ve mirini hafif kıvam alana kadar 2 dakika kaynatın.",
     "Somonu derili tarafı altta 4 dakika, sonra etli tarafı 2 dakika "
     "pişirin.",
     "Somonu pilavın üzerine parçalayın, sosu gezdirin, susam ve yeşil "
     "soğanla bitirin."],
    "Japanese donburi bowl with flaked glazed salmon over rice, sesame "
    "seeds and spring onion, dark ceramic bowl, moody izakaya lighting"))

R.append(recipe(
    "chicken-teriyaki-rice", "Chicken Teriyaki with Rice",
    "Teriyaki Tavuk ve Pilav", "dinner", "japanese", 25,
    ["high_protein", "bulking"], ALL, 48, 66, 14,
    [ing(180, "g", "chicken thigh", "tavuk but"),
     ing(85, "g", "jasmine rice", "yasemin pirinci", "dry weight",
         "kuru ölçü"),
     ing(2, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "yemek kaşığı", "honey", "bal"),
     ing(1, "çay kaşığı", "grated ginger", "zencefil rende"),
     ing(100, "g", "broccoli", "brokoli")],
    ["Cook the rice and steam the broccoli over it for the last "
     "5 minutes.",
     "Sear the chicken skin-side down for 6 minutes until it renders.",
     "Turn it, add the soy sauce, honey and ginger, and let the glaze "
     "reduce for 4 minutes.",
     "Slice the chicken and serve it over the rice with the broccoli."],
    ["Pirinci pişirin, son 5 dakikada brokoliyi üzerinde buharda haşlayın.",
     "Tavuğu derili tarafı altta yağını salana kadar 6 dakika pişirin.",
     "Çevirin, soya sosu, bal ve zencefili ekleyip sosu 4 dakika "
     "koyulaştırın.",
     "Tavuğu dilimleyip brokoliyle birlikte pilavın üzerinde servis edin."],
    "Glossy teriyaki chicken sliced over steamed rice with broccoli, "
    "glaze pooling, warm japanese home-cooking styling"))

R.append(recipe(
    "miso-tofu-soup-bowl", "Miso Tofu Soup",
    "Misolu Tofu Çorbası", "lunch", "japanese", 15,
    ["low_calorie", "toning"], ALL, 28, 12, 19,
    [ing(200, "g", "firm tofu", "katı tofu"),
     ing(2, "yemek kaşığı", "miso paste", "miso ezmesi", "fermented soybean",
         "fermente soya ezmesi"),
     ing(600, "ml", "vegetable stock", "sebze suyu"),
     ing(50, "g", "spinach", "ıspanak"),
     ing(2, "yemek kaşığı", "spring onion", "yeşil soğan"),
     ing(1, "çay kaşığı", "sesame oil", "susam yağı")],
    ["Bring the stock to a bare simmer — miso goes bitter if it boils.",
     "Whisk the miso paste into a ladleful of stock, then stir it back in.",
     "Add the cubed tofu and spinach and warm them for 3 minutes.",
     "Finish with sesame oil and spring onion."],
    ["Sebze suyunu kaynama noktasının altında tutun — miso kaynayınca "
     "acılaşır.",
     "Miso ezmesini bir kepçe suyla açıp tencereye geri karıştırın.",
     "Küp doğranmış tofu ve ıspanağı ekleyip 3 dakika ısıtın.",
     "Susam yağı ve yeşil soğanla bitirin."],
    "Steaming miso soup with tofu cubes and spinach in a lacquer bowl, "
    "spring onion floating, minimal japanese styling"))

R.append(recipe(
    "tamago-protein-breakfast", "Tamago Rice Breakfast Bowl",
    "Tamagolu Kahvaltı Kasesi", "breakfast", "japanese", 12,
    ["high_protein", "budget_friendly"], ALL, 26, 52, 12,
    [ing(3, None, "eggs", "yumurta"),
     ing(80, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(1, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "çay kaşığı", "sesame oil", "susam yağı"),
     ing(1, "yaprak", "nori", "nori", "dried seaweed sheet",
         "kurutulmuş deniz yosunu")],
    ["Cook the rice.",
     "Beat the eggs with the soy sauce.",
     "Cook them in a hot oiled pan in three thin layers, rolling each one "
     "over the last.",
     "Slice the roll and lay it on the rice with torn nori."],
    ["Pirinci pişirin.",
     "Yumurtaları soya sosuyla çırpın.",
     "Yağlanmış kızgın tavada üç ince kat hâlinde pişirip her katı bir "
     "öncekinin üzerine sarın.",
     "Ruloyu dilimleyip pilavın üzerine, koparılmış noriyle dizin."],
    "Japanese rolled omelette sliced over a bowl of rice with nori strips, "
    "clean minimal breakfast styling"))

R.append(recipe(
    "edamame-tuna-rice-bowl", "Tuna Edamame Rice Bowl",
    "Ton Balıklı Edamame Kasesi", "lunch", "japanese", 15,
    ["high_protein", "budget_friendly"], ALL, 40, 56, 12,
    [ing(150, "g", "canned tuna", "ton balığı", "drained", "suyu süzülmüş"),
     ing(80, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(80, "g", "edamame", "edamame"),
     ing(1, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "çay kaşığı", "sesame oil", "susam yağı"),
     ing(1, "çay kaşığı", "sesame seeds", "susam")],
    ["Cook the rice and let it cool slightly.",
     "Warm the edamame in boiling water for 3 minutes.",
     "Fork the tuna through the soy sauce and sesame oil.",
     "Build the bowl and scatter the sesame seeds."],
    ["Pirinci pişirip hafif soğumaya bırakın.",
     "Edamameyi kaynar suda 3 dakika ısıtın.",
     "Ton balığını soya sosu ve susam yağıyla çatalla karıştırın.",
     "Kaseyi kurup susamı serpin."],
    "Rice bowl with seasoned tuna, bright green edamame and sesame seeds, "
    "overhead, fresh japanese-inspired styling"))

R.append(recipe(
    "matcha-protein-smoothie", "Matcha Protein Smoothie",
    "Matcha Protein Smoothie", "snack", "japanese", 5,
    ["high_protein", "low_calorie"], ALL, 32, 24, 10,
    [ing(30, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(1, "çay kaşığı", "matcha powder", "matcha tozu",
         "green tea powder", "yeşil çay tozu"),
     ing(250, "ml", "almond milk", "badem sütü"),
     ing(1, None, "frozen banana", "dondurulmuş muz"),
     ing(1, "çay kaşığı", "honey", "bal")],
    ["Sift the matcha so it does not clump in the blender.",
     "Add every other ingredient and blend for 30 seconds.",
     "Serve cold in a tall glass."],
    ["Matchayı blenderda topaklanmaması için eleyin.",
     "Diğer tüm malzemeleri ekleyip 30 saniye çekin.",
     "Uzun bir bardakta soğuk servis edin."],
    "Vivid green matcha protein smoothie in a tall glass with matcha "
    "powder dusted on top, bright minimal styling"))

# ─── Mexican (6) ────────────────────────────────────────────────────

R.append(recipe(
    "huevos-rancheros-protein", "Huevos Rancheros",
    "Huevos Rancheros", "breakfast", "mexican", 20,
    ["high_protein", "budget_friendly"], ALL, 32, 44, 22,
    [ing(3, None, "eggs", "yumurta"),
     ing(2, None, "corn tortillas", "mısır tortilla"),
     ing(150, "g", "black beans", "siyah fasulye"),
     ing(150, "g", "chopped tomatoes", "doğranmış domates"),
     ing(1, None, "onion", "kuru soğan"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "cumin, chilli, salt", "kimyon, acı biber, tuz")],
    ["Soften the onion in the oil, then add the tomatoes, cumin and "
     "chilli.",
     "Simmer the sauce for 8 minutes and stir the beans through.",
     "Warm the tortillas in a dry pan.",
     "Fry the eggs and serve them over the tortillas and sauce."],
    ["Soğanı yağda yumuşatın, sonra domatesi, kimyonu ve acı biberi "
     "ekleyin.",
     "Sosu 8 dakika pişirip fasulyeyi içine karıştırın.",
     "Tortillaları kuru tavada ısıtın.",
     "Yumurtaları pişirip tortilla ve sosun üzerinde servis edin."],
    "Huevos rancheros with fried eggs over corn tortillas, black beans and "
    "red salsa, vibrant mexican colours, overhead"))

R.append(recipe(
    "chicken-tinga-bowl", "Chicken Tinga Bowl",
    "Tavuklu Tinga Kasesi", "dinner", "mexican", 35,
    ["high_protein", "bulking"], ALL, 46, 56, 16,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(80, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(200, "g", "chopped tomatoes", "doğranmış domates"),
     ing(1, None, "onion", "kuru soğan"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "chipotle, oregano, salt", "chipotle, kekik, tuz")],
    ["Poach the chicken for 15 minutes, then shred it with two forks.",
     "Blend the tomatoes, onion, garlic and chipotle into a sauce.",
     "Fry the sauce in the oil for 6 minutes to deepen it.",
     "Fold the shredded chicken through and serve over the rice."],
    ["Tavuğu 15 dakika haşlayıp iki çatalla lif lif ayırın.",
     "Domates, soğan, sarımsak ve chipotleyi blenderdan geçirerek sos "
     "yapın.",
     "Sosu yağda 6 dakika kavurarak koyulaştırın.",
     "Didilmiş tavuğu sosa karıştırıp pilavın üzerinde servis edin."],
    "Shredded chipotle chicken tinga over rice with lime wedges, deep red "
    "sauce, rustic mexican plating"))

R.append(recipe(
    "black-bean-quinoa-tacos", "Black Bean and Quinoa Tacos",
    "Siyah Fasulyeli Kinoa Taco", "lunch", "mexican", 20,
    ["budget_friendly", "toning"], ALL, 22, 62, 16,
    [ing(150, "g", "black beans", "siyah fasulye"),
     ing(60, "g", "quinoa", "kinoa", "dry weight", "kuru ölçü"),
     ing(3, None, "corn tortillas", "mısır tortilla"),
     ing(1, None, "avocado", "avokado"),
     ing(1, None, "lime", "misket limonu"),
     ing(1, "avuç", "coriander", "kişniş"),
     ing(None, None, "cumin, salt", "kimyon, tuz")],
    ["Simmer the quinoa for 15 minutes.",
     "Warm the beans with the cumin and mash a third of them for body.",
     "Fold the quinoa through the beans.",
     "Fill the warmed tortillas and top with avocado, coriander and lime."],
    ["Kinoayı 15 dakika haşlayın.",
     "Fasulyeyi kimyonla ısıtın ve kıvam için üçte birini ezin.",
     "Kinoayı fasulyeye karıştırın.",
     "Isıtılmış tortillaları doldurup avokado, kişniş ve misket limonuyla "
     "servis edin."],
    "Three corn tacos filled with black beans and quinoa, topped with "
    "avocado and coriander, lime wedges, bright cantina styling"))

R.append(recipe(
    "mexican-street-corn-salad", "Mexican Street Corn Salad",
    "Meksika Sokak Mısırı Salatası", "snack", "mexican", 15,
    ["low_calorie", "budget_friendly"], ALL, 12, 38, 14,
    [ing(300, "g", "sweetcorn", "mısır"),
     ing(60, "g", "feta cheese", "beyaz peynir"),
     ing(2, "yemek kaşığı", "Greek yogurt", "süzme yoğurt"),
     ing(1, None, "lime", "misket limonu"),
     ing(1, "avuç", "coriander", "kişniş"),
     ing(1, "çay kaşığı", "chilli powder", "toz acı biber")],
    ["Char the corn in a dry hot pan until it blisters, about 6 minutes.",
     "Mix the yogurt, lime juice and chilli into a dressing.",
     "Toss the warm corn through the dressing.",
     "Crumble the feta over and scatter the coriander."],
    ["Mısırı kuru kızgın tavada kabarana kadar, yaklaşık 6 dakika kavurun.",
     "Yoğurt, misket limonu suyu ve acı biberi karıştırarak sos yapın.",
     "Sıcak mısırı sosla harmanlayın.",
     "Üzerine beyaz peyniri ufalayıp kişnişi serpin."],
    "Charred street corn salad with crumbled white cheese, chilli powder "
    "and coriander in a bowl, lime wedge, vibrant"))

R.append(recipe(
    "beef-barbacoa-bowl", "Beef Barbacoa Bowl",
    "Barbacoa Dana Kasesi", "dinner", "mexican", 45,
    ["high_protein", "bulking"], ALL, 48, 52, 22,
    [ing(200, "g", "beef brisket", "dana kuşbaşı"),
     ing(80, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(100, "g", "black beans", "siyah fasulye"),
     ing(200, "ml", "beef stock", "et suyu"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, None, "lime", "misket limonu"),
     ing(None, None, "cumin, oregano, chilli", "kimyon, kekik, acı biber")],
    ["Brown the beef on every side, then add the stock, garlic and spices.",
     "Cover and simmer for 35 minutes until it pulls apart.",
     "Shred the beef and reduce the remaining liquid over it.",
     "Serve over rice and beans with a squeeze of lime."],
    ["Eti her tarafı kızarana kadar mühürleyin, sonra et suyu, sarımsak ve "
     "baharatları ekleyin.",
     "Kapağını kapatıp lif lif ayrılana kadar 35 dakika pişirin.",
     "Eti didikleyip kalan suyu üzerinde koyulaştırın.",
     "Pilav ve fasulyeyle, misket limonu sıkarak servis edin."],
    "Shredded barbacoa beef over rice and black beans with lime, rich dark "
    "sauce, rustic mexican bowl"))

R.append(recipe(
    "mexican-chocolate-protein-pudding", "Mexican Chocolate Protein Pudding",
    "Meksika Çikolatalı Protein Puding", "dessert", "mexican", 10,
    ["high_protein", "toning"], ALL, 30, 22, 10,
    [ing(35, "g", "chocolate whey protein powder",
         "çikolatalı whey protein tozu"),
     ing(200, "ml", "milk", "süt"),
     ing(2, "yemek kaşığı", "chia seeds", "chia tohumu"),
     ing(1, "çay kaşığı", "cinnamon", "tarçın"),
     ing(1, "çimdik", "cayenne pepper", "acı toz biber")],
    ["Whisk everything together in a jar.",
     "Whisk again after 5 minutes so the chia does not settle.",
     "Chill for 3 hours — the cayenne is what makes it Mexican, and a "
     "pinch is enough."],
    ["Her şeyi bir kavanozda çırpın.",
     "Chia dibe çökmesin diye 5 dakika sonra tekrar çırpın.",
     "3 saat soğutun — bunu Meksika yapan acı biberdir ve bir tutam "
     "yeterlidir."],
    "Dark chocolate chia pudding dusted with cinnamon in a small glass, "
    "warm spice tones, moody styling"))

# ─── Indian (6) ─────────────────────────────────────────────────────

R.append(recipe(
    "paneer-tikka-bowl", "Paneer Tikka Bowl",
    "Paneer Tikka Kasesi", "dinner", "indian", 30,
    ["high_protein", "toning"], ALL, 34, 48, 26,
    [ing(200, "g", "paneer", "paneer", "Indian fresh cheese",
         "Hint taze peyniri"),
     ing(70, "g", "basmati rice", "basmati pirinci", "dry weight",
         "kuru ölçü"),
     ing(120, "g", "Greek yogurt", "süzme yoğurt"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(2, "çay kaşığı", "garam masala", "garam masala baharatı"),
     ing(1, "çay kaşığı", "grated ginger", "zencefil rende"),
     ing(1, None, "bell pepper", "renkli biber")],
    ["Marinate the cubed paneer in the yogurt, garam masala and ginger for "
     "15 minutes.",
     "Cook the rice.",
     "Sear the paneer and pepper in a very hot pan until charred at the "
     "edges, about 8 minutes.",
     "Serve over the rice with the remaining marinade warmed through."],
    ["Küp doğranmış paneeri yoğurt, garam masala ve zencefille 15 dakika "
     "marine edin.",
     "Pirinci pişirin.",
     "Paneer ve biberi çok kızgın tavada kenarları yanana kadar, yaklaşık "
     "8 dakika pişirin.",
     "Kalan marinatı ısıtıp pilavın üzerinde servis edin."],
    "Charred paneer tikka cubes with peppers over basmati rice, yogurt "
    "marinade, vibrant indian spice colours"))

R.append(recipe(
    "red-lentil-dal", "Red Lentil Dal",
    "Kırmızı Mercimek Dal", "lunch", "indian", 30,
    ["budget_friendly", "toning"], ALL, 24, 62, 12,
    [ing(150, "g", "red lentils", "kırmızı mercimek"),
     ing(600, "ml", "vegetable stock", "sebze suyu"),
     ing(1, None, "onion", "kuru soğan"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, "çay kaşığı", "turmeric", "zerdeçal"),
     ing(1, "çay kaşığı", "cumin", "kimyon"),
     ing(1, "yemek kaşığı", "coconut oil", "hindistancevizi yağı")],
    ["Rinse the lentils until the water runs clear.",
     "Fry the onion, garlic and spices in the coconut oil for 4 minutes.",
     "Add the lentils and stock and simmer for 22 minutes, stirring.",
     "Mash a little against the side of the pan to thicken it."],
    ["Mercimeği suyu berraklaşana kadar yıkayın.",
     "Soğan, sarımsak ve baharatları hindistancevizi yağında 4 dakika "
     "kavurun.",
     "Mercimeği ve sebze suyunu ekleyip karıştırarak 22 dakika pişirin.",
     "Kıvam alması için bir kısmını tencerenin kenarında ezin."],
    "Golden red lentil dal in a bowl with a swirl of oil and fresh "
    "coriander, warm spice tones, indian home cooking"))

R.append(recipe(
    "chicken-tikka-masala-light", "Lighter Chicken Tikka Masala",
    "Hafif Tavuklu Tikka Masala", "dinner", "indian", 35,
    ["high_protein", "bulking"], ALL, 48, 52, 20,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(70, "g", "basmati rice", "basmati pirinci", "dry weight",
         "kuru ölçü"),
     ing(150, "g", "Greek yogurt", "süzme yoğurt"),
     ing(200, "g", "chopped tomatoes", "doğranmış domates"),
     ing(2, "çay kaşığı", "garam masala", "garam masala baharatı"),
     ing(1, "çay kaşığı", "grated ginger", "zencefil rende"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı")],
    ["Marinate the cubed chicken in half the yogurt with the spices for "
     "20 minutes.",
     "Sear it hard in the oil until charred at the edges.",
     "Add the tomatoes and simmer for 12 minutes.",
     "Stir the remaining yogurt in off the heat — boiling it splits the "
     "sauce.",
     "Serve over the basmati."],
    ["Küp doğranmış tavuğu yoğurdun yarısı ve baharatlarla 20 dakika "
     "marine edin.",
     "Yağda kenarları yanana kadar yüksek ateşte mühürleyin.",
     "Domatesi ekleyip 12 dakika pişirin.",
     "Kalan yoğurdu ateşten uzakta karıştırın — kaynatmak sosu kestirir.",
     "Basmati pilavının üzerinde servis edin."],
    "Creamy tikka masala with charred chicken pieces over basmati rice, "
    "coriander garnish, warm indian restaurant lighting"))

R.append(recipe(
    "chana-masala", "Chana Masala",
    "Nohutlu Chana Masala", "lunch", "indian", 25,
    ["budget_friendly", "toning"], ALL, 20, 64, 14,
    [ing(300, "g", "chickpeas", "haşlanmış nohut"),
     ing(200, "g", "chopped tomatoes", "doğranmış domates"),
     ing(1, None, "onion", "kuru soğan"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(2, "çay kaşığı", "garam masala", "garam masala baharatı"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "avuç", "coriander", "kişniş")],
    ["Fry the onion and garlic until deeply golden — this is where the "
     "flavour comes from, so do not rush it.",
     "Add the garam masala and cook for 1 minute.",
     "Add the tomatoes and chickpeas and simmer for 15 minutes.",
     "Finish with coriander."],
    ["Soğan ve sarımsağı koyu altın rengi olana kadar kavurun — lezzet "
     "buradan gelir, acele etmeyin.",
     "Garam masalayı ekleyip 1 dakika pişirin.",
     "Domates ve nohudu ekleyip 15 dakika pişirin.",
     "Kişnişle bitirin."],
    "Chana masala chickpea curry in a deep bowl with fresh coriander, rich "
    "tomato sauce, indian street food styling"))

R.append(recipe(
    "masala-egg-bhurji", "Masala Egg Bhurji",
    "Baharatlı Yumurta Bhurji", "breakfast", "indian", 15,
    ["high_protein", "budget_friendly"], ALL, 26, 14, 20,
    [ing(4, None, "eggs", "yumurta"),
     ing(1, None, "onion", "kuru soğan"),
     ing(1, None, "tomato", "domates"),
     ing(1, "çay kaşığı", "turmeric", "zerdeçal"),
     ing(1, "çay kaşığı", "cumin", "kimyon"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "avuç", "coriander", "kişniş")],
    ["Fry the diced onion in the oil until it softens.",
     "Add the cumin and turmeric and cook for 30 seconds.",
     "Add the chopped tomato and cook it down for 3 minutes.",
     "Pour in the beaten eggs and scramble them into the masala.",
     "Finish with coriander."],
    ["Doğranmış soğanı yağda yumuşayana kadar kavurun.",
     "Kimyon ve zerdeçalı ekleyip 30 saniye pişirin.",
     "Doğranmış domatesi ekleyip 3 dakika suyunu çektirin.",
     "Çırpılmış yumurtaları dökün ve masalanın içinde karıştırın.",
     "Kişnişle bitirin."],
    "Spiced Indian scrambled eggs with tomato and onion in a pan, "
    "coriander scattered, warm golden tones"))

R.append(recipe(
    "mango-lassi-protein", "Mango Protein Lassi",
    "Mangolu Protein Lassi", "snack", "indian", 5,
    ["high_protein", "low_calorie"], ALL, 30, 40, 6,
    [ing(150, "g", "Greek yogurt", "süzme yoğurt"),
     ing(150, "g", "mango", "mango"),
     ing(25, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(100, "ml", "milk", "süt"),
     ing(1, "çimdik", "cardamom", "kakule")],
    ["Blend everything for 30 seconds.",
     "Add the cardamom last and pulse once — too much and it dominates.",
     "Serve over ice."],
    ["Her şeyi 30 saniye blenderdan geçirin.",
     "Kakuleyi en son ekleyip bir kez çalıştırın — fazlası her şeyi bastırır.",
     "Buz üzerine servis edin."],
    "Creamy orange mango lassi in a tall glass with a dusting of cardamom, "
    "bright fresh styling"))

# ─── Greek (5) ──────────────────────────────────────────────────────

R.append(recipe(
    "greek-chicken-souvlaki-bowl", "Chicken Souvlaki Bowl",
    "Tavuklu Souvlaki Kasesi", "dinner", "greek", 25,
    ["high_protein", "toning"], ALL, 48, 32, 22,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(150, "g", "Greek yogurt", "süzme yoğurt"),
     ing(1, None, "cucumber", "salatalık"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, None, "lemon", "limon"),
     ing(None, None, "oregano, salt, pepper", "kekik, tuz, karabiber")],
    ["Marinate the cubed chicken in the oil, lemon juice and oregano for "
     "20 minutes.",
     "Grate the cucumber, squeeze the water out, and mix it with the "
     "yogurt and garlic for the tzatziki.",
     "Grill the chicken for 10 minutes, turning, until charred.",
     "Serve the chicken over the tzatziki."],
    ["Küp doğranmış tavuğu zeytinyağı, limon suyu ve kekikle 20 dakika "
     "marine edin.",
     "Salatalığı rendeleyip suyunu sıkın, yoğurt ve sarımsakla "
     "karıştırarak cacık yapın.",
     "Tavuğu çevirerek 10 dakika, kenarları yanana kadar ızgarada pişirin.",
     "Tavuğu cacığın üzerinde servis edin."],
    "Grilled chicken souvlaki over thick tzatziki with lemon and oregano, "
    "aegean blue and white styling"))

R.append(recipe(
    "greek-salad-with-feta", "Greek Salad with Feta",
    "Beyaz Peynirli Yunan Salatası", "lunch", "greek", 12,
    ["low_calorie", "toning"], ALL, 16, 18, 28,
    [ing(200, "g", "tomatoes", "domates"),
     ing(150, "g", "cucumber", "salatalık"),
     ing(100, "g", "feta cheese", "beyaz peynir"),
     ing(60, "g", "olives", "zeytin"),
     ing(1, None, "red onion", "kırmızı soğan"),
     ing(2, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "oregano, salt", "kekik, tuz")],
    ["Cut the tomatoes into wedges rather than dice — a Greek salad is "
     "chunky.",
     "Slice the cucumber and onion and combine them with the olives.",
     "Lay the feta on top whole, not crumbled.",
     "Pour the olive oil over and finish with oregano and salt."],
    ["Domatesleri küp değil, dilim dilim kesin — Yunan salatası iri "
     "doğranır.",
     "Salatalık ve soğanı dilimleyip zeytinlerle birleştirin.",
     "Beyaz peyniri ufalamadan bütün hâlde üzerine koyun.",
     "Zeytinyağını gezdirip kekik ve tuzla bitirin."],
    "Traditional Greek salad with a whole slab of feta on top, olives and "
    "oregano, olive oil pooling, rustic taverna styling"))

R.append(recipe(
    "greek-baked-peaches", "Baked Peaches with Pistachios",
    "Fırında Antep Fıstıklı Şeftali", "dessert", "greek", 25,
    ["low_calorie", "budget_friendly"], ALL, 6, 34, 14,
    [ing(3, None, "peaches", "şeftali"),
     ing(30, "g", "pistachios", "antep fıstığı"),
     ing(1, "yemek kaşığı", "honey", "bal"),
     ing(1, "çay kaşığı", "cinnamon", "tarçın"),
     ing(1, None, "lemon", "limon")],
    ["Halve the peaches and set them cut-side up in a dish.",
     "Drizzle the honey and lemon juice over and dust with cinnamon.",
     "Bake at 190 degrees for 20 minutes until they collapse slightly.",
     "Scatter the chopped pistachios over while they are still hot."],
    ["Şeftalileri ikiye bölüp kesik yüzleri yukarı bakacak şekilde kaba "
     "dizin.",
     "Bal ve limon suyunu gezdirip tarçın serpin.",
     "Hafifçe çökene kadar 190 derecede 20 dakika pişirin.",
     "Sıcakken üzerine doğranmış antep fıstığını serpin."],
    "Baked peach halves glistening with honey and scattered with chopped "
    "pistachios, cinnamon dusting, warm golden dessert styling"))

R.append(recipe(
    "baked-feta-tomato-protein", "Baked Feta with Tomatoes",
    "Fırında Beyaz Peynir ve Domates", "dinner", "greek", 30,
    ["toning", "low_calorie"], ALL, 22, 22, 30,
    [ing(150, "g", "feta cheese", "beyaz peynir"),
     ing(300, "g", "cherry tomatoes", "cherry domates"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(2, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "avuç", "basil", "fesleğen"),
     ing(None, None, "oregano, pepper", "kekik, karabiber")],
    ["Put the feta in the middle of a dish and surround it with the "
     "tomatoes and garlic.",
     "Pour the olive oil over everything and season.",
     "Bake at 200 degrees for 25 minutes until the tomatoes burst.",
     "Stir it all together and finish with basil."],
    ["Beyaz peyniri kabın ortasına koyup etrafına domates ve sarımsağı "
     "dizin.",
     "Zeytinyağını üzerine gezdirip tatlandırın.",
     "Domatesler patlayana kadar 200 derecede 25 dakika pişirin.",
     "Hepsini karıştırıp fesleğenle bitirin."],
    "Baked feta block surrounded by burst cherry tomatoes in olive oil, "
    "fresh basil, rustic ceramic dish"))

R.append(recipe(
    "greek-lemon-chicken-soup", "Greek Lemon Chicken Soup",
    "Yunan Limonlu Tavuk Çorbası", "lunch", "greek", 30,
    ["high_protein", "low_calorie"], ALL, 32, 36, 12,
    [ing(150, "g", "chicken breast", "tavuk göğsü"),
     ing(60, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(700, "ml", "chicken stock", "tavuk suyu"),
     ing(2, None, "eggs", "yumurta"),
     ing(2, None, "lemons", "limon"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Poach the chicken in the stock for 15 minutes, then shred it.",
     "Cook the rice in the same stock for 15 minutes.",
     "Whisk the eggs with the lemon juice, then temper them by whisking "
     "in hot stock a ladleful at a time.",
     "Stir the mixture back into the pan OFF the heat — it curdles at a "
     "simmer."],
    ["Tavuğu et suyunda 15 dakika haşlayıp didikleyin.",
     "Pirinci aynı suda 15 dakika pişirin.",
     "Yumurtaları limon suyuyla çırpın, sonra kepçe kepçe sıcak su "
     "ekleyerek ısıtın.",
     "Karışımı ateşten uzakta tencereye geri karıştırın — kaynarken "
     "kesilir."],
    "Creamy avgolemono lemon chicken soup with rice, lemon slices on the "
    "side, steam rising, mediterranean styling"))

# ─── Levantine (5) ──────────────────────────────────────────────────

R.append(recipe(
    "shawarma-chicken-plate", "Chicken Shawarma Plate",
    "Tavuk Shawarma Tabağı", "dinner", "levantine", 30,
    ["high_protein", "bulking"], ALL, 46, 48, 22,
    [ing(200, "g", "chicken thigh", "tavuk but"),
     ing(100, "g", "bulgur", "pilavlık bulgur", "dry weight", "kuru ölçü"),
     ing(2, "yemek kaşığı", "tahini", "tahin"),
     ing(1, None, "lemon", "limon"),
     ing(2, "çay kaşığı", "baharat spice mix", "baharat karışımı"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, None, "tomato", "domates")],
    ["Toss the sliced chicken in the spice mix and oil and leave it for "
     "15 minutes.",
     "Cook the bulgur in twice its volume of water for 12 minutes.",
     "Sear the chicken hard until the edges crisp.",
     "Loosen the tahini with lemon juice and water and pour it over."],
    ["Dilimlenmiş tavuğu baharat karışımı ve yağla harmanlayıp 15 dakika "
     "bekletin.",
     "Bulguru iki katı suda 12 dakika pişirin.",
     "Tavuğu kenarları çıtırlaşana kadar yüksek ateşte kızartın.",
     "Tahini limon suyu ve suyla açıp üzerine gezdirin."],
    "Chicken shawarma over bulgur with tahini sauce drizzled across, "
    "tomato and parsley, levantine street food styling"))

R.append(recipe(
    "falafel-protein-bowl", "Baked Falafel Bowl",
    "Fırında Falafel Kasesi", "lunch", "levantine", 35,
    ["budget_friendly", "toning"], ALL, 24, 58, 20,
    [ing(300, "g", "chickpeas", "haşlanmış nohut"),
     ing(1, None, "onion", "kuru soğan"),
     ing(3, "diş", "garlic", "sarımsak"),
     ing(1, "avuç", "parsley", "maydanoz"),
     ing(2, "yemek kaşığı", "tahini", "tahin"),
     ing(2, "çay kaşığı", "cumin", "kimyon"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı")],
    ["Blitz the chickpeas, onion, garlic, parsley and cumin to a coarse "
     "paste — a smooth one makes falafel dense.",
     "Shape into 10 patties and brush them with the oil.",
     "Bake at 200 degrees for 25 minutes, turning once.",
     "Loosen the tahini with water and lemon and serve alongside."],
    ["Nohut, soğan, sarımsak, maydanoz ve kimyonu iri taneli bir hamur "
     "olana kadar çekin — pürüzsüz hamur falafeli ağırlaştırır.",
     "10 köfte şekli verip üzerlerine yağ sürün.",
     "200 derecede bir kez çevirerek 25 dakika pişirin.",
     "Tahini su ve limonla açıp yanında servis edin."],
    "Baked falafel patties on a bed of salad with tahini sauce, lemon "
    "wedges, middle eastern styling"))

R.append(recipe(
    "shakshuka-protein", "Shakshuka",
    "Şakşuka", "breakfast", "levantine", 25,
    ["high_protein", "budget_friendly"], ALL, 26, 26, 22,
    [ing(4, None, "eggs", "yumurta"),
     ing(400, "g", "chopped tomatoes", "doğranmış domates"),
     ing(1, None, "bell pepper", "renkli biber"),
     ing(1, None, "onion", "kuru soğan"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "cumin, paprika, salt", "kimyon, toz biber, tuz")],
    ["Soften the onion and pepper in the oil for 8 minutes.",
     "Add the garlic and spices, then the tomatoes, and simmer for "
     "10 minutes.",
     "Make four wells and crack an egg into each.",
     "Cover and cook for 6 minutes until the whites set and the yolks "
     "stay soft."],
    ["Soğan ve biberi yağda 8 dakika yumuşatın.",
     "Sarımsak ve baharatları, sonra domatesi ekleyip 10 dakika pişirin.",
     "Dört çukur açıp her birine bir yumurta kırın.",
     "Kapağını kapatıp beyazları donana, sarılar akışkan kalana kadar "
     "6 dakika pişirin."],
    "Shakshuka in a cast iron pan with four eggs nestled in red pepper "
    "sauce, parsley scattered, rustic overhead"))

R.append(recipe(
    "muhammara-protein-dip", "Muhammara with Vegetables",
    "Sebzeli Muhammara", "snack", "levantine", 15,
    ["budget_friendly", "toning"], ALL, 10, 30, 26,
    [ing(200, "g", "roasted red peppers", "ızgara kırmızı biber"),
     ing(60, "g", "walnuts", "ceviz"),
     ing(30, "g", "breadcrumbs", "galeta unu"),
     ing(1, "yemek kaşığı", "pomegranate molasses", "nar ekşisi"),
     ing(2, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "çay kaşığı", "cumin", "kimyon"),
     ing(150, "g", "cucumber sticks", "salatalık çubukları")],
    ["Blitz the peppers, walnuts, breadcrumbs, cumin and pomegranate "
     "molasses to a coarse paste.",
     "Loosen it with the olive oil until it is spoonable.",
     "Rest it for 10 minutes so the breadcrumbs swell.",
     "Serve with the cucumber sticks."],
    ["Biberleri, cevizi, galeta ununu, kimyonu ve nar ekşisini iri taneli "
     "bir ezme olana kadar çekin.",
     "Zeytinyağıyla kaşıkla alınabilecek kıvama getirin.",
     "Galeta unu şişsin diye 10 dakika dinlendirin.",
     "Salatalık çubuklarıyla servis edin."],
    "Deep red muhammara dip with walnut pieces and a swirl of olive oil, "
    "cucumber sticks beside, levantine mezze styling"))

R.append(recipe(
    "tabbouleh-protein-salad", "Tabbouleh with Chickpeas",
    "Nohutlu Tabule", "lunch", "levantine", 20,
    ["low_calorie", "budget_friendly"], ALL, 16, 48, 14,
    [ing(60, "g", "fine bulgur", "ince bulgur", "dry weight", "kuru ölçü"),
     ing(150, "g", "chickpeas", "haşlanmış nohut"),
     ing(2, "demet", "parsley", "maydanoz"),
     ing(2, None, "tomatoes", "domates"),
     ing(1, None, "lemon", "limon"),
     ing(2, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "avuç", "mint", "nane")],
    ["Soak the bulgur in warm water for 15 minutes and drain it well.",
     "Chop the parsley very fine — tabbouleh is a herb salad with bulgur "
     "in it, not the other way round.",
     "Dice the tomatoes and combine everything.",
     "Dress with lemon juice and olive oil and rest for 10 minutes."],
    ["Bulguru ılık suda 15 dakika bekletip iyice süzün.",
     "Maydanozu çok ince kıyın — tabule, içinde bulgur olan bir yeşillik "
     "salatasıdır, tersi değil.",
     "Domatesleri küp doğrayıp hepsini birleştirin.",
     "Limon suyu ve zeytinyağıyla harmanlayıp 10 dakika dinlendirin."],
    "Bright green tabbouleh with chickpeas, tomato and lemon in a wide "
    "bowl, fresh herbs dominating, mezze styling"))

# ─── Korean (5) ─────────────────────────────────────────────────────

R.append(recipe(
    "korean-tofu-stew", "Korean Soft Tofu Stew",
    "Kore Usulü Tofu Güveci", "dinner", "korean", 25,
    ["toning", "low_calorie"], ALL, 26, 24, 16,
    [ing(300, "g", "silken tofu", "yumuşak tofu"),
     ing(500, "ml", "vegetable stock", "sebze suyu"),
     ing(1, "yemek kaşığı", "gochujang", "gochujang", "Korean chilli paste",
         "Kore acı biber ezmesi"),
     ing(1, None, "courgette", "kabak"),
     ing(1, None, "egg", "yumurta"),
     ing(2, "yemek kaşığı", "spring onion", "yeşil soğan"),
     ing(1, "çay kaşığı", "sesame oil", "susam yağı")],
    ["Dissolve the gochujang in the stock and bring it to a simmer.",
     "Add the sliced courgette and cook for 5 minutes.",
     "Spoon the tofu in whole chunks — breaking it up makes it grainy.",
     "Crack the egg in, cover for 2 minutes, and finish with sesame oil "
     "and spring onion."],
    ["Gochujangı sebze suyunda eritip kaynama noktasına getirin.",
     "Dilimlenmiş kabağı ekleyip 5 dakika pişirin.",
     "Tofuyu iri parçalar hâlinde kaşıkla ekleyin — dağıtmak dokusunu "
     "bozar.",
     "Yumurtayı kırın, 2 dakika kapağını kapatın, susam yağı ve yeşil "
     "soğanla bitirin."],
    "Bubbling red Korean soft tofu stew in a stone pot with an egg on top, "
    "spring onion, steam rising, dramatic"))

R.append(recipe(
    "bibimbap-protein-bowl", "Beef Bibimbap",
    "Etli Bibimbap", "dinner", "korean", 35,
    ["high_protein", "bulking"], ALL, 42, 68, 20,
    [ing(150, "g", "lean ground beef", "yağsız dana kıyma"),
     ing(85, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(100, "g", "spinach", "ıspanak"),
     ing(80, "g", "carrot", "havuç"),
     ing(1, None, "egg", "yumurta"),
     ing(1, "yemek kaşığı", "gochujang", "gochujang"),
     ing(1, "yemek kaşığı", "sesame oil", "susam yağı")],
    ["Cook the rice.",
     "Brown the beef with half the sesame oil.",
     "Blanch the spinach and julienne the carrot, dressing each "
     "separately — bibimbap keeps its components apart until the table.",
     "Arrange everything over the rice, top with a fried egg and the "
     "gochujang."],
    ["Pirinci pişirin.",
     "Kıymayı susam yağının yarısıyla kavurun.",
     "Ispanağı haşlayın, havucu jülyen doğrayın ve her birini ayrı ayrı "
     "tatlandırın — bibimbap malzemelerini sofraya kadar ayrı tutar.",
     "Hepsini pilavın üzerine dizin, sahanda yumurta ve gochujang ekleyin."],
    "Bibimbap bowl with separate sections of beef, spinach and carrot over "
    "rice, fried egg centre, red gochujang, overhead"))

R.append(recipe(
    "korean-chicken-lettuce-wraps", "Korean Chicken Lettuce Wraps",
    "Kore Usulü Tavuklu Marul Sarma", "lunch", "korean", 20,
    ["high_protein", "low_calorie"], ALL, 40, 18, 14,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(8, "yaprak", "lettuce leaves", "marul yaprağı"),
     ing(1, "yemek kaşığı", "gochujang", "gochujang"),
     ing(1, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "çay kaşığı", "grated ginger", "zencefil rende"),
     ing(1, "çay kaşığı", "sesame oil", "susam yağı"),
     ing(1, "çay kaşığı", "sesame seeds", "susam")],
    ["Dice the chicken and toss it with the gochujang, soy sauce and "
     "ginger.",
     "Sear it in the sesame oil over high heat for 7 minutes.",
     "Spoon into lettuce leaves and scatter the sesame seeds."],
    ["Tavuğu küp doğrayıp gochujang, soya sosu ve zencefille harmanlayın.",
     "Susam yağında yüksek ateşte 7 dakika kızartın.",
     "Marul yapraklarına doldurup susam serpin."],
    "Spicy Korean chicken in crisp lettuce cups with sesame seeds, "
    "vibrant red glaze, fresh clean styling"))

R.append(recipe(
    "kimchi-fried-rice-protein", "Kimchi Fried Rice with Egg",
    "Yumurtalı Kimchi Pilavı", "lunch", "korean", 15,
    ["budget_friendly", "bulking"], ALL, 22, 62, 18,
    [ing(200, "g", "cooked rice", "pişmiş pirinç"),
     ing(120, "g", "kimchi", "kimchi", "fermented cabbage",
         "fermente lahana"),
     ing(2, None, "eggs", "yumurta"),
     ing(1, "yemek kaşığı", "sesame oil", "susam yağı"),
     ing(1, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(2, "yemek kaşığı", "spring onion", "yeşil soğan")],
    ["Fry the chopped kimchi in the sesame oil for 3 minutes.",
     "Add the rice — day-old is better, fresh rice steams instead of "
     "frying — and stir-fry for 4 minutes.",
     "Push it aside, scramble the eggs in the space, then fold everything "
     "together.",
     "Finish with soy sauce and spring onion."],
    ["Doğranmış kimchiyi susam yağında 3 dakika kavurun.",
     "Pilavı ekleyin — bir günlük pilav daha iyidir, taze pilav kızarmak "
     "yerine buharlanır — ve 4 dakika soteleyin.",
     "Kenara itip boşlukta yumurtaları karıştırın, sonra hepsini "
     "birleştirin.",
     "Soya sosu ve yeşil soğanla bitirin."],
    "Kimchi fried rice with scrambled egg folded through, spring onion on "
    "top, orange-red tones, wok styling"))

R.append(recipe(
    "korean-beef-bulgogi", "Beef Bulgogi",
    "Bulgogi Dana Eti", "dinner", "korean", 25,
    ["high_protein", "bulking"], ALL, 44, 58, 20,
    [ing(180, "g", "beef sirloin", "dana bonfile"),
     ing(85, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(2, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, None, "pear", "armut", "the tenderiser; do not skip it",
         "eti yumuşatır; atlamayın"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "sesame oil", "susam yağı"),
     ing(1, "çay kaşığı", "sesame seeds", "susam")],
    ["Grate the pear and mix it with the soy sauce, garlic and sesame oil.",
     "Slice the beef paper-thin and marinate it for 20 minutes.",
     "Cook the rice.",
     "Sear the beef in a screaming-hot pan for 2 minutes — any longer and "
     "it stews.",
     "Serve over the rice with sesame seeds."],
    ["Armudu rendeleyip soya sosu, sarımsak ve susam yağıyla karıştırın.",
     "Eti kâğıt inceliğinde dilimleyip 20 dakika marine edin.",
     "Pirinci pişirin.",
     "Eti çok kızgın tavada 2 dakika mühürleyin — daha uzunu haşlar.",
     "Susamla birlikte pilavın üzerinde servis edin."],
    "Caramelised bulgogi beef strips over rice with sesame seeds and "
    "spring onion, glossy dark glaze, korean bbq styling"))

# ─── Thai (4) ───────────────────────────────────────────────────────

R.append(recipe(
    "thai-basil-chicken", "Thai Basil Chicken",
    "Tayland Usulü Fesleğenli Tavuk", "dinner", "thai", 20,
    ["high_protein", "bulking"], ALL, 44, 60, 18,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(85, "g", "jasmine rice", "yasemin pirinci", "dry weight",
         "kuru ölçü"),
     ing(1, "avuç", "basil", "fesleğen"),
     ing(2, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "sesame oil", "susam yağı"),
     ing(None, None, "chilli flakes", "pul biber")],
    ["Cook the rice.",
     "Chop the chicken small rather than slicing it — the texture is the "
     "point of this dish.",
     "Fry the garlic and chilli in the oil for 30 seconds.",
     "Add the chicken and soy sauce and stir-fry for 6 minutes.",
     "Kill the heat and fold the basil through so it wilts rather than "
     "cooks."],
    ["Pirinci pişirin.",
     "Tavuğu dilimlemek yerine ufak doğrayın — bu yemeğin özü dokusudur.",
     "Sarımsak ve pul biberi yağda 30 saniye kavurun.",
     "Tavuğu ve soya sosunu ekleyip 6 dakika soteleyin.",
     "Ateşi kapatıp fesleğeni pişmeden solacak şekilde karıştırın."],
    "Thai basil chicken over jasmine rice with fresh basil leaves wilting "
    "on top, chilli flakes, street food wok styling"))

R.append(recipe(
    "thai-green-curry-tofu", "Thai Green Curry with Tofu",
    "Tayland Yeşil Köri ve Tofu", "dinner", "thai", 25,
    ["toning", "budget_friendly"], ALL, 24, 56, 28,
    [ing(250, "g", "firm tofu", "katı tofu"),
     ing(80, "g", "jasmine rice", "yasemin pirinci", "dry weight",
         "kuru ölçü"),
     ing(200, "ml", "coconut milk", "hindistan cevizi sütü"),
     ing(2, "yemek kaşığı", "green curry paste", "yeşil köri ezmesi"),
     ing(100, "g", "green beans", "taze fasulye"),
     ing(1, None, "lime", "misket limonu"),
     ing(1, "avuç", "basil", "fesleğen")],
    ["Fry the curry paste in a splash of the coconut milk for 2 minutes "
     "until it smells of the spices.",
     "Add the rest of the coconut milk and bring it to a simmer.",
     "Add the cubed tofu and green beans and cook for 8 minutes.",
     "Finish with lime juice and basil off the heat."],
    ["Köri ezmesini bir miktar hindistan cevizi sütünde 2 dakika, "
     "baharatların kokusu çıkana kadar kavurun.",
     "Kalan hindistan cevizi sütünü ekleyip kaynama noktasına getirin.",
     "Küp doğranmış tofu ve taze fasulyeyi ekleyip 8 dakika pişirin.",
     "Ateşten aldıktan sonra misket limonu suyu ve fesleğenle bitirin."],
    "Green Thai curry with tofu cubes and green beans in coconut broth, "
    "fresh basil and lime, vibrant green tones"))

R.append(recipe(
    "thai-beef-salad", "Thai Beef Salad",
    "Tayland Usulü Etli Salata", "lunch", "thai", 20,
    ["high_protein", "low_calorie"], ALL, 42, 16, 18,
    [ing(180, "g", "beef sirloin", "dana bonfile"),
     ing(120, "g", "cucumber", "salatalık"),
     ing(80, "g", "cherry tomatoes", "cherry domates"),
     ing(1, None, "lime", "misket limonu"),
     ing(1, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "avuç", "mint", "nane"),
     ing(None, None, "chilli flakes", "pul biber")],
    ["Sear the beef 3 minutes a side and rest it for 5.",
     "Whisk the lime juice, soy sauce and chilli into a dressing.",
     "Slice the beef thinly against the grain.",
     "Toss it with the cucumber, tomatoes and mint in the dressing."],
    ["Eti her yüzü 3 dakika mühürleyip 5 dakika dinlendirin.",
     "Misket limonu suyu, soya sosu ve pul biberi çırparak sos yapın.",
     "Eti liflerine dik ince dilimleyin.",
     "Salatalık, domates ve naneyle birlikte sosta harmanlayın."],
    "Thai beef salad with pink sliced steak, cucumber, tomato and mint, "
    "lime dressing, fresh vibrant styling"))

R.append(recipe(
    "thai-mango-sticky-protein", "Mango Coconut Protein Rice",
    "Mangolu Hindistan Cevizli Protein Pirinç", "dessert", "thai", 30,
    ["high_protein", "bulking"], ALL, 20, 72, 14,
    [ing(80, "g", "rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(150, "ml", "coconut milk", "hindistan cevizi sütü"),
     ing(150, "g", "mango", "mango"),
     ing(20, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(1, "yemek kaşığı", "honey", "bal"),
     ing(1, "çay kaşığı", "sesame seeds", "susam")],
    ["Cook the rice, then stir most of the coconut milk and the honey "
     "through it while it is hot.",
     "Let it cool to warm, then stir the protein powder in — hot liquid "
     "makes it grainy.",
     "Slice the mango and lay it alongside.",
     "Pour the remaining coconut milk over and scatter the sesame seeds."],
    ["Pirinci pişirip sıcakken hindistan cevizi sütünün çoğunu ve balı "
     "içine karıştırın.",
     "Ilıyana kadar bekletip protein tozunu ekleyin — sıcak sıvı tozu "
     "topaklandırır.",
     "Mangoyu dilimleyip yanına dizin.",
     "Kalan hindistan cevizi sütünü gezdirip susam serpin."],
    "Coconut sticky rice with fanned mango slices and sesame seeds, "
    "coconut cream drizzle, thai dessert styling"))

# ─── Italian / Mediterranean (3) ────────────────────────────────────

R.append(recipe(
    "tuscan-white-bean-soup", "Tuscan White Bean Soup",
    "Toskana Beyaz Fasulye Çorbası", "lunch", "italian", 30,
    ["budget_friendly", "toning"], ALL, 20, 52, 12,
    [ing(300, "g", "white beans", "haşlanmış kuru fasulye"),
     ing(600, "ml", "vegetable stock", "sebze suyu"),
     ing(1, None, "carrot", "havuç"),
     ing(1, None, "onion", "kuru soğan"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(2, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "dal", "rosemary", "taze biberiye")],
    ["Soften the diced onion, carrot and garlic in the oil for 8 minutes.",
     "Add the beans, stock and rosemary and simmer for 18 minutes.",
     "Blend a third of the soup and stir it back in — that is what makes "
     "it creamy without cream.",
     "Finish with a hard drizzle of olive oil."],
    ["Doğranmış soğan, havuç ve sarımsağı yağda 8 dakika yumuşatın.",
     "Fasulye, sebze suyu ve biberiyeyi ekleyip 18 dakika pişirin.",
     "Çorbanın üçte birini blenderdan geçirip geri karıştırın — kremasız "
     "kremamsılık buradan gelir.",
     "Bolca zeytinyağı gezdirerek bitirin."],
    "Rustic Tuscan white bean soup with rosemary and a swirl of olive oil, "
    "crusty bread beside, warm tuscan tones"))

R.append(recipe(
    "caprese-protein-plate", "Caprese Protein Plate",
    "Proteinli Caprese Tabağı", "snack", "italian", 8,
    ["high_protein", "low_calorie"], ALL, 28, 12, 22,
    [ing(150, "g", "mozzarella", "mozzarella peyniri"),
     ing(200, "g", "tomatoes", "domates"),
     ing(1, "avuç", "basil", "fesleğen"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "çay kaşığı", "balsamic vinegar", "balzamik sirke"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Slice the tomatoes and mozzarella to the same thickness.",
     "Alternate them on a plate with basil leaves between.",
     "Dress with the olive oil and balsamic and season generously."],
    ["Domates ve mozzarellayı aynı kalınlıkta dilimleyin.",
     "Aralarına fesleğen yaprakları koyarak tabağa sırayla dizin.",
     "Zeytinyağı ve balzamik sirkeyle tatlandırıp bolca baharatlayın."],
    "Caprese plate with alternating tomato and mozzarella slices, fresh "
    "basil, balsamic drizzle, clean italian styling"))

R.append(recipe(
    "mediterranean-tuna-salad", "Mediterranean Tuna Salad",
    "Akdeniz Ton Balıklı Salata", "lunch", "mediterranean", 12,
    ["high_protein", "low_calorie"], ALL, 34, 22, 18,
    [ing(150, "g", "canned tuna", "ton balığı", "drained", "suyu süzülmüş"),
     ing(150, "g", "white beans", "haşlanmış kuru fasulye"),
     ing(100, "g", "cherry tomatoes", "cherry domates"),
     ing(50, "g", "olives", "zeytin"),
     ing(1, None, "red onion", "kırmızı soğan"),
     ing(2, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, None, "lemon", "limon")],
    ["Slice the red onion thinly and soak it in the lemon juice for "
     "5 minutes to take the bite out.",
     "Halve the tomatoes and combine everything.",
     "Dress with the olive oil and the lemon the onion soaked in."],
    ["Kırmızı soğanı ince dilimleyip keskinliği gitsin diye limon suyunda "
     "5 dakika bekletin.",
     "Domatesleri ikiye bölüp hepsini birleştirin.",
     "Zeytinyağı ve soğanın beklediği limon suyuyla harmanlayın."],
    "Mediterranean tuna and white bean salad with olives, cherry tomatoes "
    "and red onion, olive oil, bright aegean styling"))

emit(R, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "international.json"))
