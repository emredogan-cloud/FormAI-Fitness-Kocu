"""Roadmap Phase 7 §5.2 · the western bodybuilding canon, authored.

    python3 tool/recipe_pipeline/proposals/western.py

Sixty recipes an English-speaking lifter expects and would not have found
in this app: overnight oats, chicken and rice bowls, Greek yoghurt bowls,
protein pancakes, egg-white scrambles, beef and sweet potato, casein
pudding, tuna wraps.

WHY SIXTY. The app shows a daily menu of 4–5 meals. Below ~50 an English
user sees repeats inside a fortnight, which reads as an empty app rather
than as a small catalogue.

`locale_scope = ['en']` on every one: these LEAD for English readers.
They are not hidden from Turkish ones — see
`015_recipe_origin_and_diet.sql` on why that distinction is the whole
point of the column.

Turkish titles and steps are authored here too, not left for later. The
app ships both languages; a recipe that exists in one of them is a row
that renders as a gap for half the users.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _authoring import emit, ing, recipe  # noqa: E402

A = "american"
EN = ["en"]
R = []

# ─── breakfast (14) ─────────────────────────────────────────────────

R.append(recipe(
    "overnight-protein-oats", "Overnight Protein Oats",
    "Gecelik Protein Yulafı", "breakfast", A, 10,
    ["high_protein", "budget_friendly"], EN, 38, 52, 12,
    [ing(60, "g", "rolled oats", "yulaf ezmesi"),
     ing(200, "ml", "milk", "süt"),
     ing(30, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(1, "yemek kaşığı", "chia seeds", "chia tohumu"),
     ing(80, "g", "blueberries", "yaban mersini"),
     ing(1, "tatlı kaşığı", "honey", "bal")],
    ["Stir the oats, milk, protein powder and chia seeds together in a jar.",
     "Seal the jar and refrigerate overnight, or for at least 6 hours.",
     "Top with blueberries and honey before eating."],
    ["Yulaf, süt, protein tozu ve chia tohumunu bir kavanozda karıştırın.",
     "Kavanozu kapatıp bir gece, en az 6 saat buzdolabında bekletin.",
     "Yemeden önce üzerine yaban mersini ve bal ekleyin."],
    "Overnight oats in a glass jar on a bright kitchen counter, topped with "
    "fresh blueberries and a drizzle of honey, morning light, shallow depth "
    "of field, food photography"))

R.append(recipe(
    "egg-white-veggie-scramble", "Egg White Veggie Scramble",
    "Sebzeli Yumurta Akı", "breakfast", A, 12, ["high_protein", "low_calorie"],
    EN, 32, 10, 8,
    [ing(250, "ml", "egg whites", "yumurta akı"),
     ing(1, None, "whole egg", "bütün yumurta"),
     ing(60, "g", "spinach", "ıspanak"),
     ing(60, "g", "mushrooms", "mantar"),
     ing(1, "tatlı kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Warm the olive oil in a non-stick pan over medium heat.",
     "Cook the mushrooms until they release their water and start to brown.",
     "Add the spinach and cook until it wilts.",
     "Pour in the egg whites and the whole egg, then fold gently until set.",
     "Season with salt and pepper and serve straight away."],
    ["Zeytinyağını yapışmaz bir tavada orta ateşte ısıtın.",
     "Mantarları suyunu salıp hafif kızarana kadar pişirin.",
     "Ispanağı ekleyip solana kadar pişirin.",
     "Yumurta akı ve bütün yumurtayı ekleyip donana kadar yavaşça çevirin.",
     "Tuz ve karabiberle tatlandırıp hemen servis edin."],
    "Fluffy egg white scramble with spinach and mushrooms in a black skillet, "
    "overhead shot, natural window light, clean modern kitchen"))

R.append(recipe(
    "banana-protein-pancakes", "Banana Protein Pancakes",
    "Muzlu Protein Pankek", "breakfast", A, 15, ["high_protein", "bulking"],
    EN, 40, 55, 14,
    [ing(1, None, "ripe banana", "olgun muz"),
     ing(2, None, "eggs", "yumurta"),
     ing(40, "g", "rolled oats", "yulaf ezmesi"),
     ing(30, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(1, "çay kaşığı", "baking powder", "kabartma tozu"),
     ing(1, "tatlı kaşığı", "coconut oil", "hindistancevizi yağı"),
     ing(1, "yemek kaşığı", "maple syrup", "akçaağaç şurubu")],
    ["Blend the banana, eggs, oats, protein powder and baking powder smooth.",
     "Rest the batter for 5 minutes so the oats soften.",
     "Cook spoonfuls in a lightly oiled pan over medium-low heat, "
     "about 2 minutes a side.",
     "Stack and finish with maple syrup."],
    ["Muz, yumurta, yulaf, protein tozu ve kabartma tozunu pürüzsüz olana "
     "kadar blenderdan geçirin.",
     "Yulafların yumuşaması için hamuru 5 dakika dinlendirin.",
     "Hafif yağlanmış tavada kısık-orta ateşte, her yüzü yaklaşık 2 dakika "
     "olacak şekilde pişirin.",
     "Üst üste dizip akçaağaç şurubu gezdirin."],
    "Stack of golden protein pancakes with banana slices and maple syrup "
    "running down the side, warm morning light, rustic wooden table"))

R.append(recipe(
    "greek-yogurt-power-bowl", "Greek Yogurt Power Bowl",
    "Süzme Yoğurtlu Güç Kasesi", "breakfast", A, 5,
    ["high_protein", "toning"], EN, 34, 38, 14,
    [ing(200, "g", "Greek yogurt", "süzme yoğurt"),
     ing(30, "g", "mixed berries", "karışık orman meyvesi"),
     ing(20, "g", "walnuts", "ceviz"),
     ing(1, "yemek kaşığı", "chia seeds", "chia tohumu"),
     ing(1, "tatlı kaşığı", "honey", "bal")],
    ["Spoon the Greek yogurt into a wide bowl.",
     "Scatter the berries, walnuts and chia seeds across the top.",
     "Finish with honey and eat immediately."],
    ["Süzme yoğurdu geniş bir kaseye alın.",
     "Üzerine orman meyvelerini, cevizi ve chia tohumunu serpin.",
     "Balı gezdirip hemen tüketin."],
    "Thick Greek yogurt bowl topped with mixed berries, walnuts and chia "
    "seeds, overhead flat lay, bright airy styling, marble surface"))

R.append(recipe(
    "peanut-butter-protein-toast", "Peanut Butter Protein Toast",
    "Fıstık Ezmeli Protein Tost", "breakfast", A, 6,
    ["high_protein", "budget_friendly"], EN, 26, 44, 20,
    [ing(2, "dilim", "wholemeal bread", "tam buğday ekmeği"),
     ing(2, "yemek kaşığı", "peanut butter", "doğal fıstık ezmesi"),
     ing(1, None, "banana", "muz"),
     ing(2, None, "eggs", "yumurta"),
     ing(1, "çimdik", "cinnamon", "tarçın")],
    ["Toast the bread until it is golden and firm.",
     "Boil or fry the eggs to your liking while the bread toasts.",
     "Spread the peanut butter across both slices.",
     "Lay banana slices over the top, dust with cinnamon, and serve the "
     "eggs alongside."],
    ["Ekmeği altın rengi ve sert olana kadar kızartın.",
     "Ekmek kızarırken yumurtaları dilediğiniz gibi haşlayın veya pişirin.",
     "Fıstık ezmesini iki dilime de sürün.",
     "Üzerine muz dilimlerini dizin, tarçın serpin ve yumurtaları yanında "
     "servis edin."],
    "Two slices of wholemeal toast with peanut butter and banana slices, "
    "eggs on the side, morning kitchen light, casual food photography"))

R.append(recipe(
    "cottage-cheese-berry-bowl", "Cottage Cheese Berry Bowl",
    "Süzme Peynirli Meyve Kasesi", "breakfast", A, 5,
    ["high_protein", "low_calorie"], EN, 30, 22, 6,
    [ing(200, "g", "cottage cheese", "süzme peynir"),
     ing(100, "g", "strawberries", "çilek"),
     ing(1, "tatlı kaşığı", "honey", "bal"),
     ing(10, "g", "almonds", "badem")],
    ["Spoon the cottage cheese into a bowl.",
     "Halve the strawberries and arrange them over the cheese.",
     "Scatter the almonds and drizzle the honey over the top."],
    ["Süzme peyniri bir kaseye alın.",
     "Çilekleri ikiye bölüp peynirin üzerine dizin.",
     "Bademleri serpip balı gezdirin."],
    "Cottage cheese bowl with halved strawberries and sliced almonds, "
    "overhead shot, soft daylight, minimal white ceramic bowl"))

R.append(recipe(
    "savory-oats-with-egg", "Savory Oats with Egg",
    "Yumurtalı Tuzlu Yulaf", "breakfast", A, 15,
    ["high_protein", "budget_friendly"], EN, 28, 48, 16,
    [ing(60, "g", "rolled oats", "yulaf ezmesi"),
     ing(250, "ml", "vegetable stock", "sebze suyu"),
     ing(2, None, "eggs", "yumurta"),
     ing(30, "g", "cheddar cheese", "çedar peyniri"),
     ing(1, "yemek kaşığı", "spring onion", "yeşil soğan"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Simmer the oats in the stock for 6 minutes, stirring, until creamy.",
     "Stir the cheddar through until it melts.",
     "Fry the eggs in a separate pan.",
     "Top the oats with the eggs, scatter the spring onion and season."],
    ["Yulafı sebze suyunda 6 dakika, karıştırarak, kremamsı olana kadar "
     "pişirin.",
     "Çedar peynirini eriyene kadar karıştırın.",
     "Yumurtaları ayrı bir tavada pişirin.",
     "Yulafın üzerine yumurtaları koyun, yeşil soğanı serpip tatlandırın."],
    "Savory oatmeal in a deep bowl topped with two fried eggs and sliced "
    "spring onions, steam rising, moody kitchen light"))

R.append(recipe(
    "protein-french-toast", "Protein French Toast",
    "Proteinli Fransız Tostu", "breakfast", A, 12, ["high_protein", "bulking"],
    EN, 42, 50, 16,
    [ing(3, "dilim", "wholemeal bread", "tam buğday ekmeği"),
     ing(2, None, "eggs", "yumurta"),
     ing(120, "ml", "milk", "süt"),
     ing(25, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(1, "çay kaşığı", "cinnamon", "tarçın"),
     ing(1, "tatlı kaşığı", "butter", "tereyağı")],
    ["Whisk the eggs, milk, protein powder and cinnamon in a shallow dish.",
     "Soak each slice of bread for 20 seconds a side.",
     "Fry in the butter over medium heat until golden, about 2 minutes a "
     "side."],
    ["Yumurta, süt, protein tozu ve tarçını geniş bir kapta çırpın.",
     "Her ekmek dilimini iki yüzünde 20 saniye bekletin.",
     "Tereyağında orta ateşte, her yüzü yaklaşık 2 dakika, altın rengi "
     "olana kadar kızartın."],
    "Golden protein French toast dusted with cinnamon on a white plate, "
    "morning light, close-up food photography"))

R.append(recipe(
    "turkey-bacon-breakfast-wrap", "Turkey and Egg Breakfast Wrap",
    "Hindili Yumurtalı Kahvaltı Dürümü", "breakfast", A, 12,
    ["high_protein"], EN, 36, 34, 16,
    [ing(1, None, "wholemeal tortilla", "tam buğday tortilla"),
     ing(60, "g", "sliced turkey breast", "dilimli hindi göğsü"),
     ing(2, None, "eggs", "yumurta"),
     ing(30, "g", "cheddar cheese", "çedar peyniri"),
     ing(30, "g", "baby spinach", "taze ıspanak"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Scramble the eggs in a hot pan and season them.",
     "Warm the tortilla for 20 seconds a side in the same pan.",
     "Lay the turkey, eggs, cheese and spinach down the middle.",
     "Fold the ends in, roll tightly, and slice in half."],
    ["Yumurtaları kızgın tavada karıştırıp tatlandırın.",
     "Tortillayı aynı tavada her yüzü 20 saniye olacak şekilde ısıtın.",
     "Hindiyi, yumurtayı, peyniri ve ıspanağı ortaya dizin.",
     "Uçlarını kapatıp sıkıca sarın ve ikiye kesin."],
    "Breakfast wrap sliced in half showing scrambled egg, turkey and spinach "
    "filling, on parchment paper, bright natural light"))

R.append(recipe(
    "blueberry-protein-smoothie", "Blueberry Protein Smoothie",
    "Yaban Mersinli Protein Smoothie", "breakfast", A, 5,
    ["high_protein", "low_calorie"], EN, 35, 32, 8,
    [ing(30, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(250, "ml", "almond milk", "badem sütü"),
     ing(100, "g", "frozen blueberries", "dondurulmuş yaban mersini"),
     ing(100, "g", "Greek yogurt", "süzme yoğurt"),
     ing(1, "yemek kaşığı", "almond butter", "badem ezmesi")],
    ["Put every ingredient into a blender.",
     "Blend on high for 40 seconds until completely smooth.",
     "Pour into a tall glass and drink cold."],
    ["Tüm malzemeleri blendera koyun.",
     "40 saniye yüksek hızda, tamamen pürüzsüz olana kadar çekin.",
     "Uzun bir bardağa döküp soğuk için."],
    "Deep purple blueberry protein smoothie in a tall glass with condensation, "
    "scattered blueberries beside it, bright clean styling"))

R.append(recipe(
    "smoked-salmon-bagel-stack", "Smoked Salmon and Egg Plate",
    "Füme Somonlu Yumurta Tabağı", "breakfast", A, 10,
    ["high_protein", "toning"], EN, 34, 26, 18,
    [ing(80, "g", "smoked salmon", "füme somon"),
     ing(2, None, "eggs", "yumurta"),
     ing(2, "dilim", "rye bread", "çavdar ekmeği"),
     ing(30, "g", "cream cheese", "krem peynir"),
     ing(1, "yemek kaşığı", "dill", "dereotu"),
     ing(None, None, "black pepper", "karabiber")],
    ["Poach or soft-boil the eggs for 6 minutes.",
     "Toast the rye bread and spread it with the cream cheese.",
     "Lay the smoked salmon over the bread and set the eggs alongside.",
     "Finish with dill and a grind of black pepper."],
    ["Yumurtaları 6 dakika poşe edin veya rafadan haşlayın.",
     "Çavdar ekmeğini kızartıp krem peyniri sürün.",
     "Somonu ekmeğin üzerine dizin, yumurtaları yanına koyun.",
     "Dereotu ve taze çekilmiş karabiberle bitirin."],
    "Plate of smoked salmon on rye toast with soft-boiled eggs and fresh dill, "
    "overhead, cool daylight, scandinavian styling"))

R.append(recipe(
    "apple-cinnamon-protein-oatmeal", "Apple Cinnamon Protein Oatmeal",
    "Elmalı Tarçınlı Protein Yulafı", "breakfast", A, 12,
    ["high_protein", "budget_friendly"], EN, 32, 56, 10,
    [ing(60, "g", "rolled oats", "yulaf ezmesi"),
     ing(250, "ml", "milk", "süt"),
     ing(1, None, "apple", "elma"),
     ing(25, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(1, "çay kaşığı", "cinnamon", "tarçın"),
     ing(10, "g", "walnuts", "ceviz")],
    ["Dice the apple and simmer it with the oats and milk for 7 minutes.",
     "Take the pan off the heat and stir the protein powder through — "
     "adding it to boiling milk makes it grainy.",
     "Stir in the cinnamon, top with walnuts and serve warm."],
    ["Elmayı küp doğrayıp yulaf ve sütle 7 dakika pişirin.",
     "Tencereyi ateşten alın ve protein tozunu karıştırın — kaynayan süte "
     "eklemek tozu topaklandırır.",
     "Tarçını ekleyin, üzerine ceviz serpip ılık servis edin."],
    "Creamy oatmeal with diced apple, cinnamon and walnuts in a rustic bowl, "
    "warm autumn light, cozy styling"))

R.append(recipe(
    "high-protein-breakfast-burrito", "High-Protein Breakfast Burrito",
    "Yüksek Proteinli Kahvaltı Burritosu", "breakfast", A, 18,
    ["high_protein", "bulking"], EN, 44, 52, 22,
    [ing(1, None, "large wholemeal tortilla", "büyük tam buğday tortilla"),
     ing(3, None, "eggs", "yumurta"),
     ing(80, "g", "black beans", "siyah fasulye"),
     ing(60, "g", "lean ground beef", "yağsız dana kıyma"),
     ing(30, "g", "cheddar cheese", "çedar peyniri"),
     ing(2, "yemek kaşığı", "salsa", "salsa sos"),
     ing(None, None, "cumin, salt, pepper", "kimyon, tuz, karabiber")],
    ["Brown the ground beef with the cumin until no pink remains.",
     "Add the black beans and warm them through.",
     "Scramble the eggs in a second pan and season them.",
     "Warm the tortilla, load it with the beef, beans, eggs, cheese and "
     "salsa, then roll it tight."],
    ["Kıymayı kimyonla, pembelik kalmayana kadar kavurun.",
     "Siyah fasulyeyi ekleyip ısınmasını bekleyin.",
     "Yumurtaları ikinci bir tavada karıştırıp tatlandırın.",
     "Tortillayı ısıtın; kıyma, fasulye, yumurta, peynir ve salsa sosu "
     "koyup sıkıca sarın."],
    "Breakfast burrito cut open showing eggs, beef, black beans and melted "
    "cheese, wrapped in foil, warm diner lighting"))

R.append(recipe(
    "protein-chia-pudding", "Vanilla Protein Chia Pudding",
    "Vanilyalı Protein Chia Puding", "breakfast", A, 8,
    ["high_protein", "toning"], EN, 30, 26, 16,
    [ing(3, "yemek kaşığı", "chia seeds", "chia tohumu"),
     ing(250, "ml", "almond milk", "badem sütü"),
     ing(30, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(80, "g", "raspberries", "ahududu"),
     ing(1, "tatlı kaşığı", "maple syrup", "akçaağaç şurubu")],
    ["Whisk the chia seeds, almond milk and protein powder in a jar.",
     "Whisk again after 5 minutes so the seeds do not clump at the bottom.",
     "Refrigerate for at least 4 hours, then top with raspberries and "
     "maple syrup."],
    ["Chia tohumu, badem sütü ve protein tozunu bir kavanozda çırpın.",
     "5 dakika sonra tekrar çırpın; tohumlar dipte topaklanmasın.",
     "En az 4 saat buzdolabında bekletin, sonra ahududu ve akçaağaç "
     "şurubuyla servis edin."],
    "Layered chia pudding in a glass jar topped with fresh raspberries, "
    "soft natural light, clean minimal styling"))


# ─── lunch (13) ─────────────────────────────────────────────────────

R.append(recipe(
    "chicken-and-rice-bowl", "Chicken and Rice Bowl",
    "Tavuklu Pilav Kasesi", "lunch", A, 25, ["high_protein", "bulking"],
    EN, 52, 62, 14,
    [ing(180, "g", "chicken breast", "tavuk göğsü"),
     ing(80, "g", "white rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(100, "g", "broccoli", "brokoli"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "tatlı kaşığı", "paprika", "toz kırmızı biber"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Rinse the rice and simmer it in twice its volume of water for "
     "15 minutes.",
     "Season the chicken with the paprika, salt and pepper.",
     "Sear the chicken in the olive oil over medium-high heat, 5 minutes a "
     "side, then rest it for 3 minutes.",
     "Steam the broccoli for 4 minutes so it keeps its bite.",
     "Slice the chicken and build the bowl: rice, broccoli, chicken."],
    ["Pirinci yıkayıp iki katı suda 15 dakika pişirin.",
     "Tavuğu toz kırmızı biber, tuz ve karabiberle tatlandırın.",
     "Tavuğu zeytinyağında orta-yüksek ateşte her yüzü 5 dakika mühürleyin, "
     "sonra 3 dakika dinlendirin.",
     "Brokoliyi diri kalması için 4 dakika buharda pişirin.",
     "Tavuğu dilimleyip kaseyi kurun: pilav, brokoli, tavuk."],
    "Meal prep bowl with sliced grilled chicken, white rice and steamed "
    "broccoli, overhead shot, clean gym-kitchen aesthetic"))

R.append(recipe(
    "tuna-avocado-wrap", "Tuna Avocado Wrap",
    "Ton Balıklı Avokado Dürüm", "lunch", A, 10,
    ["high_protein", "budget_friendly"], EN, 38, 34, 20,
    [ing(1, None, "wholemeal tortilla", "tam buğday tortilla"),
     ing(150, "g", "canned tuna", "ton balığı", "drained", "suyu süzülmüş"),
     ing(1, None, "avocado", "avokado", None, None),
     ing(2, "yaprak", "lettuce", "marul"),
     ing(1, "yemek kaşığı", "lemon juice", "limon suyu"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Mash the avocado with the lemon juice, salt and pepper.",
     "Fold the drained tuna through the avocado.",
     "Spread the mixture down the middle of the tortilla and lay the "
     "lettuce over it.",
     "Roll it tightly and cut it on the diagonal."],
    ["Avokadoyu limon suyu, tuz ve karabiberle ezin.",
     "Suyu süzülmüş ton balığını avokadoya karıştırın.",
     "Karışımı tortillanın ortasına yayıp üzerine marulu dizin.",
     "Sıkıca sarıp çapraz kesin."],
    "Tuna avocado wrap cut on the diagonal showing the filling, on a wooden "
    "board with lemon halves, bright natural light"))

R.append(recipe(
    "beef-and-sweet-potato-bowl", "Beef and Sweet Potato Bowl",
    "Dana Etli Tatlı Patates Kasesi", "lunch", A, 30,
    ["high_protein", "bulking"], EN, 46, 58, 20,
    [ing(160, "g", "lean ground beef", "yağsız dana kıyma"),
     ing(250, "g", "sweet potato", "tatlı patates"),
     ing(80, "g", "green beans", "taze fasulye"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "diş", "garlic", "sarımsak"),
     ing(None, None, "cumin, salt, pepper", "kimyon, tuz, karabiber")],
    ["Cube the sweet potato, toss it in half the oil, and roast at "
     "200 degrees for 25 minutes.",
     "Brown the beef with the garlic and cumin in the rest of the oil.",
     "Steam the green beans for 5 minutes.",
     "Combine everything in a bowl and season to taste."],
    ["Tatlı patatesi küp doğrayın, yağın yarısıyla karıştırıp 200 derecede "
     "25 dakika fırınlayın.",
     "Kıymayı sarımsak ve kimyonla kalan yağda kavurun.",
     "Taze fasulyeyi 5 dakika buharda pişirin.",
     "Hepsini bir kasede birleştirip tuz ve karabiberle tatlandırın."],
    "Bowl of ground beef with roasted sweet potato cubes and green beans, "
    "overhead, warm rustic styling"))

R.append(recipe(
    "grilled-chicken-caesar-salad", "Grilled Chicken Caesar Salad",
    "Izgara Tavuklu Sezar Salata", "lunch", A, 20,
    ["high_protein", "toning"], EN, 44, 20, 22,
    [ing(160, "g", "chicken breast", "tavuk göğsü"),
     ing(150, "g", "romaine lettuce", "marul"),
     ing(25, "g", "parmesan cheese", "parmesan peyniri"),
     ing(2, "yemek kaşığı", "Greek yogurt", "süzme yoğurt"),
     ing(1, "çay kaşığı", "dijon mustard", "dijon hardalı"),
     ing(1, "yemek kaşığı", "lemon juice", "limon suyu"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı")],
    ["Grill the chicken for 6 minutes a side and rest it.",
     "Whisk the yogurt, mustard, lemon juice and olive oil into a dressing.",
     "Tear the lettuce into a bowl and toss it through the dressing.",
     "Slice the chicken over the top and finish with grated parmesan."],
    ["Tavuğu her yüzü 6 dakika ızgarada pişirip dinlendirin.",
     "Yoğurt, hardal, limon suyu ve zeytinyağını çırparak sos yapın.",
     "Marulu elle koparıp kaseye alın ve sosla harmanlayın.",
     "Tavuğu üzerine dilimleyip rendelenmiş parmesanla bitirin."],
    "Caesar salad with sliced grilled chicken and shaved parmesan in a wide "
    "bowl, overhead, fresh bright styling"))

R.append(recipe(
    "turkey-quinoa-power-bowl", "Turkey Quinoa Power Bowl",
    "Hindili Kinoa Güç Kasesi", "lunch", A, 25,
    ["high_protein", "toning"], EN, 45, 48, 16,
    [ing(160, "g", "ground turkey", "hindi kıyma"),
     ing(70, "g", "quinoa", "kinoa", "dry weight", "kuru ölçü"),
     ing(80, "g", "cherry tomatoes", "cherry domates"),
     ing(60, "g", "cucumber", "salatalık"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "yemek kaşığı", "lemon juice", "limon suyu"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Rinse the quinoa and simmer it for 15 minutes, then fluff it.",
     "Brown the ground turkey in the olive oil and season it.",
     "Halve the tomatoes and dice the cucumber.",
     "Toss everything together with the lemon juice."],
    ["Kinoayı yıkayıp 15 dakika haşlayın, sonra çatalla kabartın.",
     "Hindi kıymasını zeytinyağında kavurup tatlandırın.",
     "Domatesleri ikiye bölün, salatalığı küp doğrayın.",
     "Hepsini limon suyuyla harmanlayın."],
    "Quinoa bowl with ground turkey, cherry tomatoes and cucumber, overhead "
    "flat lay, fresh mediterranean colours"))

R.append(recipe(
    "salmon-poke-style-bowl", "Salmon Rice Bowl",
    "Somonlu Pirinç Kasesi", "lunch", A, 20, ["high_protein", "bulking"],
    EN, 42, 60, 22,
    [ing(160, "g", "salmon fillet", "somon fileto"),
     ing(80, "g", "sushi rice", "pirinç", "dry weight", "kuru ölçü"),
     ing(1, None, "avocado", "avokado"),
     ing(50, "g", "edamame", "edamame"),
     ing(1, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "çay kaşığı", "sesame seeds", "susam")],
    ["Cook the rice and let it cool to room temperature.",
     "Sear the salmon for 3 minutes a side, leaving the centre pink.",
     "Slice the avocado and warm the edamame.",
     "Build the bowl, pour over the soy sauce and scatter the sesame seeds."],
    ["Pirinci pişirip oda sıcaklığına gelene kadar soğutun.",
     "Somonu her yüzü 3 dakika, ortası pembe kalacak şekilde mühürleyin.",
     "Avokadoyu dilimleyin, edamameyi ısıtın.",
     "Kaseyi kurun, soya sosunu gezdirip susamı serpin."],
    "Salmon rice bowl with sliced avocado, edamame and sesame seeds, "
    "overhead, vibrant colours, dark ceramic bowl"))

R.append(recipe(
    "chicken-burrito-bowl", "Chicken Burrito Bowl",
    "Tavuklu Burrito Kasesi", "lunch", A, 25,
    ["high_protein", "budget_friendly"], EN, 48, 62, 16,
    [ing(170, "g", "chicken breast", "tavuk göğsü"),
     ing(80, "g", "brown rice", "esmer pirinç", "dry weight", "kuru ölçü"),
     ing(100, "g", "black beans", "siyah fasulye"),
     ing(60, "g", "sweetcorn", "mısır"),
     ing(2, "yemek kaşığı", "salsa", "salsa sos"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "cumin, salt, pepper", "kimyon, tuz, karabiber")],
    ["Cook the brown rice for 25 minutes.",
     "Dice the chicken, season it with cumin, and sear it in the oil.",
     "Warm the beans and sweetcorn together in a small pan.",
     "Layer the rice, beans, corn and chicken, and spoon the salsa over."],
    ["Esmer pirinci 25 dakika pişirin.",
     "Tavuğu küp doğrayın, kimyonla tatlandırıp yağda mühürleyin.",
     "Fasulye ve mısırı küçük bir tavada birlikte ısıtın.",
     "Pilavı, fasulyeyi, mısırı ve tavuğu katlayın, üzerine salsa sosu "
     "gezdirin."],
    "Burrito bowl with brown rice, black beans, corn and diced chicken, "
    "overhead, colourful and generous"))

R.append(recipe(
    "protein-pasta-bolognese", "Protein Pasta Bolognese",
    "Proteinli Makarna Bolonez", "lunch", A, 30,
    ["high_protein", "bulking"], EN, 48, 70, 16,
    [ing(90, "g", "wholemeal pasta", "tam buğday makarna", "dry weight",
         "kuru ölçü"),
     ing(160, "g", "lean ground beef", "yağsız dana kıyma"),
     ing(200, "g", "passata", "şekersiz domates sosu"),
     ing(1, None, "onion", "kuru soğan"),
     ing(1, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "oregano, salt, pepper", "kekik, tuz, karabiber")],
    ["Boil the pasta in salted water until al dente.",
     "Soften the diced onion and garlic in the olive oil.",
     "Brown the beef, then add the passata and oregano.",
     "Simmer the sauce for 12 minutes and toss the drained pasta through it."],
    ["Makarnayı tuzlu suda diri kalacak şekilde haşlayın.",
     "Doğranmış soğan ve sarımsağı zeytinyağında yumuşatın.",
     "Kıymayı kavurun, sonra domates sosu ve kekiği ekleyin.",
     "Sosu 12 dakika pişirip süzülmüş makarnayı içinde harmanlayın."],
    "Wholemeal pasta with rich bolognese sauce in a deep bowl, fresh oregano "
    "on top, warm italian-american styling"))

R.append(recipe(
    "shrimp-and-quinoa-salad", "Shrimp and Quinoa Salad",
    "Karidesli Kinoa Salatası", "lunch", A, 20,
    ["high_protein", "low_calorie"], EN, 38, 38, 12,
    [ing(160, "g", "shrimp", "karides", "peeled", "temizlenmiş"),
     ing(60, "g", "quinoa", "kinoa", "dry weight", "kuru ölçü"),
     ing(80, "g", "cucumber", "salatalık"),
     ing(60, "g", "cherry tomatoes", "cherry domates"),
     ing(1, "avuç", "parsley", "maydanoz"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, "yemek kaşığı", "lemon juice", "limon suyu")],
    ["Simmer the quinoa for 15 minutes and cool it.",
     "Sear the shrimp for 2 minutes a side until they turn opaque.",
     "Dice the cucumber, halve the tomatoes and chop the parsley.",
     "Toss everything with the olive oil and lemon juice."],
    ["Kinoayı 15 dakika haşlayıp soğutun.",
     "Karidesleri her yüzü 2 dakika, rengi dönene kadar pişirin.",
     "Salatalığı küp doğrayın, domatesleri ikiye bölün, maydanozu kıyın.",
     "Hepsini zeytinyağı ve limon suyuyla harmanlayın."],
    "Quinoa salad with seared shrimp, cucumber and cherry tomatoes, bright "
    "overhead shot, summery styling"))

R.append(recipe(
    "turkey-club-lettuce-wraps", "Turkey Club Lettuce Wraps",
    "Hindili Marul Sarma", "lunch", A, 12,
    ["high_protein", "low_calorie"], EN, 36, 12, 14,
    [ing(150, "g", "sliced turkey breast", "dilimli hindi göğsü"),
     ing(6, "yaprak", "large lettuce leaves", "büyük marul yaprağı"),
     ing(1, None, "avocado", "avokado"),
     ing(1, None, "tomato", "domates"),
     ing(2, "yemek kaşığı", "Greek yogurt", "süzme yoğurt"),
     ing(1, "çay kaşığı", "dijon mustard", "dijon hardalı")],
    ["Mix the Greek yogurt and mustard into a dressing.",
     "Lay the lettuce leaves out flat and spread the dressing across them.",
     "Layer the turkey, sliced avocado and sliced tomato inside.",
     "Fold each leaf into a parcel."],
    ["Süzme yoğurt ve hardalı karıştırarak sos yapın.",
     "Marul yapraklarını düz serip sosu üzerlerine sürün.",
     "İçine hindiyi, dilimlenmiş avokadoyu ve domatesi dizin.",
     "Her yaprağı paket gibi katlayın."],
    "Lettuce wraps filled with turkey, avocado and tomato on a white plate, "
    "fresh and light, overhead"))

R.append(recipe(
    "cottage-cheese-tuna-jacket", "Tuna and Cottage Cheese Jacket Potato",
    "Ton Balıklı Süzme Peynirli Fırın Patates", "lunch", A, 45,
    ["high_protein", "budget_friendly"], EN, 42, 58, 8,
    [ing(300, "g", "baking potato", "fırınlık patates"),
     ing(120, "g", "canned tuna", "ton balığı", "drained", "suyu süzülmüş"),
     ing(120, "g", "cottage cheese", "süzme peynir"),
     ing(1, "yemek kaşığı", "spring onion", "yeşil soğan"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Pierce the potato and bake it at 200 degrees for 45 minutes.",
     "Fold the drained tuna into the cottage cheese and season it.",
     "Split the potato open and pile the mixture in.",
     "Scatter the spring onion over the top."],
    ["Patatesi çatalla delip 200 derecede 45 dakika fırınlayın.",
     "Suyu süzülmüş ton balığını süzme peynire karıştırıp tatlandırın.",
     "Patatesi ortadan yarıp karışımı içine doldurun.",
     "Üzerine yeşil soğan serpin."],
    "Split jacket potato loaded with tuna and cottage cheese, spring onions "
    "on top, rustic plate, homely lighting"))

R.append(recipe(
    "chicken-pesto-pasta-salad", "Chicken Pesto Pasta Salad",
    "Pestolu Tavuklu Makarna Salatası", "lunch", A, 25,
    ["high_protein", "bulking"], EN, 44, 58, 22,
    [ing(90, "g", "wholemeal pasta", "tam buğday makarna", "dry weight",
         "kuru ölçü"),
     ing(160, "g", "chicken breast", "tavuk göğsü"),
     ing(2, "yemek kaşığı", "basil pesto", "fesleğen pesto"),
     ing(80, "g", "cherry tomatoes", "cherry domates"),
     ing(30, "g", "rocket", "roka"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Boil the pasta, drain it and run it under cold water.",
     "Grill the chicken for 6 minutes a side, then slice it.",
     "Toss the pasta with the pesto until every piece is coated.",
     "Fold in the halved tomatoes, rocket and chicken."],
    ["Makarnayı haşlayın, süzün ve soğuk sudan geçirin.",
     "Tavuğu her yüzü 6 dakika ızgarada pişirip dilimleyin.",
     "Makarnayı pesto ile her tanesi kaplanana kadar harmanlayın.",
     "İkiye bölünmüş domatesleri, rokayı ve tavuğu ekleyin."],
    "Cold pasta salad with pesto, sliced chicken, cherry tomatoes and rocket, "
    "overhead, fresh summer picnic styling"))

R.append(recipe(
    "steak-and-egg-plate", "Steak and Egg Plate",
    "Bonfileli Yumurta Tabağı", "lunch", A, 20,
    ["high_protein", "bulking"], EN, 54, 6, 30,
    [ing(180, "g", "beef sirloin", "dana bonfile"),
     ing(3, None, "eggs", "yumurta"),
     ing(60, "g", "rocket", "roka"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "salt and black pepper", "tuz ve karabiber")],
    ["Bring the steak to room temperature and season it heavily.",
     "Sear it in a very hot pan, 3 minutes a side for medium-rare.",
     "Rest the steak for 5 minutes — cutting it early loses the juices.",
     "Fry the eggs in the same pan and serve everything over the rocket."],
    ["Bonfileyi oda sıcaklığına getirip bolca tuzlayın.",
     "Çok kızgın tavada, orta-az pişmiş için her yüzü 3 dakika mühürleyin.",
     "Eti 5 dakika dinlendirin — erken kesmek suyunu kaybettirir.",
     "Yumurtaları aynı tavada pişirip her şeyi rokanın üzerinde servis edin."],
    "Sliced medium-rare steak with fried eggs and rocket on a dark plate, "
    "dramatic side lighting, steakhouse styling"))


# ─── dinner (13) ────────────────────────────────────────────────────

R.append(recipe(
    "baked-salmon-asparagus", "Baked Salmon with Sweet Potato and Asparagus",
    "Fırında Somon, Tatlı Patates ve Kuşkonmaz", "dinner", A, 30,
    ["high_protein", "bulking"], EN, 44, 46, 24,
    [ing(180, "g", "salmon fillet", "somon fileto"),
     ing(220, "g", "sweet potato", "tatlı patates"),
     ing(100, "g", "asparagus", "kuşkonmaz"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, None, "lemon", "limon"),
     ing(None, None, "salt, pepper, dill", "tuz, karabiber, dereotu")],
    ["Cube the sweet potato and roast at 200 degrees for 20 minutes.",
     "Add the salmon and asparagus to the tray, drizzle with oil and "
     "season.",
     "Roast for a further 12 minutes until the salmon flakes.",
     "Squeeze the lemon over everything before serving."],
    ["Tatlı patatesi küp doğrayıp 200 derecede 20 dakika fırınlayın.",
     "Somonu ve kuşkonmazı tepsiye ekleyin, yağı gezdirip tatlandırın.",
     "Somon lif lif ayrılana kadar 12 dakika daha fırınlayın.",
     "Servis etmeden önce limonu üzerine sıkın."],
    "Sheet pan with roasted salmon fillet, sweet potato cubes and asparagus, "
    "lemon wedges, overhead, warm oven-fresh lighting"))

R.append(recipe(
    "garlic-butter-chicken-thighs", "Garlic Butter Chicken and Greens",
    "Sarımsaklı Tereyağlı Tavuk ve Yeşillik", "dinner", A, 30,
    ["high_protein", "toning"], EN, 48, 16, 26,
    [ing(200, "g", "chicken thigh", "tavuk but"),
     ing(150, "g", "green beans", "taze fasulye"),
     ing(100, "g", "mushrooms", "mantar"),
     ing(15, "g", "butter", "tereyağı"),
     ing(3, "diş", "garlic", "sarımsak"),
     ing(None, None, "thyme, salt, pepper", "kekik, tuz, karabiber")],
    ["Season the chicken and sear it skin-side down for 7 minutes.",
     "Turn it, add the butter, garlic and thyme, and baste for 5 minutes.",
     "Lift the chicken out and rest it.",
     "Cook the mushrooms and green beans in the same pan for 6 minutes."],
    ["Tavuğu tatlandırıp derili tarafı altta 7 dakika mühürleyin.",
     "Çevirin, tereyağı, sarımsak ve kekiği ekleyip 5 dakika yağıyla "
     "besleyin.",
     "Tavuğu alıp dinlendirin.",
     "Mantar ve taze fasulyeyi aynı tavada 6 dakika pişirin."],
    "Golden chicken thighs in a cast iron pan with garlic butter, mushrooms "
    "and green beans, moody warm lighting"))

R.append(recipe(
    "lean-beef-stir-fry", "Lean Beef Stir Fry",
    "Yağsız Dana Etli Sote", "dinner", A, 20, ["high_protein", "bulking"],
    EN, 46, 52, 18,
    [ing(180, "g", "beef sirloin", "dana bonfile"),
     ing(80, "g", "jasmine rice", "yasemin pirinci", "dry weight",
         "kuru ölçü"),
     ing(80, "g", "bell pepper", "renkli biber"),
     ing(80, "g", "broccoli", "brokoli"),
     ing(2, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "yemek kaşığı", "sesame oil", "susam yağı"),
     ing(1, "tatlı kaşığı", "grated ginger", "zencefil rende")],
    ["Cook the rice and keep it warm.",
     "Slice the beef thinly against the grain.",
     "Sear the beef in a very hot wok for 90 seconds and lift it out.",
     "Stir-fry the vegetables with the ginger, return the beef, and add "
     "the soy sauce.",
     "Serve over the rice."],
    ["Pirinci pişirip sıcak tutun.",
     "Eti liflerine dik ince dilimleyin.",
     "Eti çok kızgın wokta 90 saniye mühürleyip çıkarın.",
     "Sebzeleri zencefille soteleyin, eti geri koyup soya sosunu ekleyin.",
     "Pilavın üzerinde servis edin."],
    "Beef stir fry with peppers and broccoli in a wok over jasmine rice, "
    "steam and wok hei, dramatic kitchen lighting"))

R.append(recipe(
    "turkey-meatballs-marinara", "Turkey Meatballs in Marinara",
    "Domates Soslu Hindi Köftesi", "dinner", A, 35,
    ["high_protein", "toning"], EN, 46, 24, 18,
    [ing(200, "g", "ground turkey", "hindi kıyma"),
     ing(1, None, "egg", "yumurta"),
     ing(20, "g", "breadcrumbs", "galeta unu"),
     ing(300, "g", "passata", "şekersiz domates sosu"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "basil, salt, pepper", "fesleğen, tuz, karabiber")],
    ["Mix the turkey, egg, breadcrumbs and seasoning and roll into balls.",
     "Brown the meatballs in the olive oil on all sides.",
     "Add the garlic and passata and simmer for 18 minutes.",
     "Finish with torn basil."],
    ["Hindi kıymasını, yumurtayı, galeta ununu ve baharatları karıştırıp "
     "köfte yapın.",
     "Köfteleri zeytinyağında her tarafı kızarana kadar mühürleyin.",
     "Sarımsağı ve domates sosunu ekleyip 18 dakika pişirin.",
     "Elle koparılmış fesleğenle bitirin."],
    "Turkey meatballs simmering in rich marinara sauce with fresh basil, "
    "cast iron skillet, rustic italian styling"))

R.append(recipe(
    "cod-with-roasted-vegetables", "Baked Cod with Roasted Vegetables",
    "Fırında Morina ve Sebzeler", "dinner", A, 30,
    ["high_protein", "low_calorie"], EN, 40, 30, 12,
    [ing(200, "g", "cod fillet", "morina fileto"),
     ing(150, "g", "courgette", "kabak"),
     ing(150, "g", "bell pepper", "renkli biber"),
     ing(100, "g", "cherry tomatoes", "cherry domates"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(1, None, "lemon", "limon"),
     ing(None, None, "oregano, salt, pepper", "kekik, tuz, karabiber")],
    ["Cut the vegetables into chunks and roast at 200 degrees for "
     "18 minutes.",
     "Lay the cod on top, season it and add the lemon slices.",
     "Return to the oven for 12 minutes until the fish is opaque."],
    ["Sebzeleri iri doğrayıp 200 derecede 18 dakika fırınlayın.",
     "Morinayı üzerine yerleştirin, tatlandırın ve limon dilimlerini ekleyin.",
     "Balık matlaşana kadar 12 dakika daha fırınlayın."],
    "Baked white fish fillet on a bed of roasted courgette, peppers and "
    "cherry tomatoes, lemon slices, mediterranean styling"))

R.append(recipe(
    "chicken-fajita-skillet", "Chicken Fajita Skillet",
    "Tavuklu Fajita Tavası", "dinner", A, 25,
    ["high_protein", "budget_friendly"], EN, 46, 34, 16,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(150, "g", "bell pepper", "renkli biber"),
     ing(1, None, "onion", "kuru soğan"),
     ing(2, None, "corn tortillas", "mısır tortilla"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(2, "çay kaşığı", "smoked paprika", "füme toz biber"),
     ing(None, None, "cumin, salt, pepper", "kimyon, tuz, karabiber")],
    ["Slice the chicken, peppers and onion into strips.",
     "Toss the chicken with the paprika and cumin.",
     "Sear the chicken in a hot skillet for 6 minutes, then lift it out.",
     "Char the peppers and onion for 5 minutes, return the chicken, and "
     "serve with warm tortillas."],
    ["Tavuğu, biberleri ve soğanı şerit şerit doğrayın.",
     "Tavuğu toz biber ve kimyonla harmanlayın.",
     "Tavuğu kızgın tavada 6 dakika mühürleyip çıkarın.",
     "Biber ve soğanı 5 dakika kavurun, tavuğu geri koyun ve ısıtılmış "
     "tortillayla servis edin."],
    "Sizzling fajita skillet with charred peppers, onions and sliced chicken, "
    "warm tortillas beside, smoky atmosphere"))

R.append(recipe(
    "shepherds-pie-protein", "Protein Shepherd's Pie",
    "Proteinli Çoban Güveci", "dinner", A, 45,
    ["high_protein", "bulking"], EN, 48, 54, 20,
    [ing(200, "g", "lean ground beef", "yağsız dana kıyma"),
     ing(300, "g", "potato", "patates"),
     ing(80, "g", "peas", "bezelye"),
     ing(1, None, "carrot", "havuç"),
     ing(1, None, "onion", "kuru soğan"),
     ing(60, "ml", "milk", "süt"),
     ing(None, None, "thyme, salt, pepper", "kekik, tuz, karabiber")],
    ["Boil the potatoes for 18 minutes, then mash them with the milk.",
     "Soften the diced onion and carrot, then brown the beef with them.",
     "Stir in the peas and thyme and spread the mixture in a baking dish.",
     "Top with the mash and bake at 200 degrees for 20 minutes."],
    ["Patatesleri 18 dakika haşlayıp sütle püre yapın.",
     "Doğranmış soğan ve havucu yumuşatın, sonra kıymayı ekleyip kavurun.",
     "Bezelye ve kekiği karıştırıp karışımı fırın kabına yayın.",
     "Üzerini püreyle kapatıp 200 derecede 20 dakika pişirin."],
    "Golden-topped shepherd's pie in a ceramic baking dish, one portion "
    "served, homely warm lighting"))

R.append(recipe(
    "blackened-chicken-quinoa", "Blackened Chicken with Quinoa",
    "Baharatlı Tavuk ve Kinoa", "dinner", A, 25,
    ["high_protein", "toning"], EN, 50, 44, 14,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(70, "g", "quinoa", "kinoa", "dry weight", "kuru ölçü"),
     ing(100, "g", "spinach", "ıspanak"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(2, "çay kaşığı", "cajun spice", "cajun baharatı"),
     ing(1, None, "lemon", "limon")],
    ["Simmer the quinoa for 15 minutes and fluff it.",
     "Coat the chicken heavily in the cajun spice.",
     "Sear it in a very hot pan for 5 minutes a side until the crust is "
     "dark.",
     "Wilt the spinach in the same pan and serve with the quinoa and lemon."],
    ["Kinoayı 15 dakika haşlayıp kabartın.",
     "Tavuğu bolca cajun baharatına bulayın.",
     "Çok kızgın tavada her yüzü 5 dakika, kabuk koyulaşana kadar pişirin.",
     "Ispanağı aynı tavada soldurup kinoa ve limonla servis edin."],
    "Blackened chicken breast sliced over quinoa with wilted spinach, "
    "lemon wedge, dark dramatic plating"))

R.append(recipe(
    "tofu-teriyaki-rice", "Teriyaki Tofu Rice Bowl",
    "Teriyaki Tofulu Pirinç Kasesi", "dinner", A, 25,
    ["high_protein", "budget_friendly"], EN, 30, 66, 16,
    [ing(200, "g", "firm tofu", "katı tofu"),
     ing(80, "g", "jasmine rice", "yasemin pirinci", "dry weight",
         "kuru ölçü"),
     ing(100, "g", "broccoli", "brokoli"),
     ing(2, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "yemek kaşığı", "maple syrup", "akçaağaç şurubu"),
     ing(1, "yemek kaşığı", "sesame oil", "susam yağı"),
     ing(1, "çay kaşığı", "sesame seeds", "susam")],
    ["Press the tofu for 10 minutes to drive the water out, then cube it.",
     "Cook the rice and steam the broccoli.",
     "Fry the tofu in the sesame oil until every side is golden.",
     "Add the soy sauce and maple syrup and let them reduce onto the tofu.",
     "Serve over the rice with the sesame seeds."],
    ["Tofuyu suyunu vermesi için 10 dakika presleyin, sonra küp doğrayın.",
     "Pirinci pişirin, brokoliyi buharda haşlayın.",
     "Tofuyu susam yağında her yüzü altın rengi olana kadar kızartın.",
     "Soya sosu ve akçaağaç şurubunu ekleyip tofunun üzerinde koyulaştırın.",
     "Pilavın üzerinde susamla servis edin."],
    "Glazed teriyaki tofu cubes over rice with broccoli and sesame seeds, "
    "glossy sauce, overhead, vibrant"))

R.append(recipe(
    "stuffed-peppers-turkey", "Turkey Stuffed Peppers",
    "Hindi Kıymalı Biber Dolması", "dinner", A, 45,
    ["high_protein", "low_calorie"], EN, 40, 34, 14,
    [ing(3, None, "bell peppers", "dolmalık biber"),
     ing(180, "g", "ground turkey", "hindi kıyma"),
     ing(60, "g", "brown rice", "esmer pirinç", "dry weight", "kuru ölçü"),
     ing(150, "g", "passata", "şekersiz domates sosu"),
     ing(1, None, "onion", "kuru soğan"),
     ing(None, None, "cumin, salt, pepper", "kimyon, tuz, karabiber")],
    ["Cook the rice for 20 minutes.",
     "Brown the turkey with the diced onion and cumin.",
     "Fold the rice and half the passata through the meat.",
     "Fill the hollowed peppers, pour the rest of the passata around them, "
     "and bake at 190 degrees for 30 minutes."],
    ["Pirinci 20 dakika pişirin.",
     "Hindi kıymasını doğranmış soğan ve kimyonla kavurun.",
     "Pirinci ve domates sosunun yarısını etin içine karıştırın.",
     "İçi boşaltılmış biberleri doldurun, kalan sosu etrafına dökün ve "
     "190 derecede 30 dakika pişirin."],
    "Stuffed bell peppers in a baking dish with tomato sauce, one cut open "
    "showing the filling, warm rustic lighting"))

R.append(recipe(
    "chili-con-carne-protein", "High-Protein Chili con Carne",
    "Yüksek Proteinli Chili con Carne", "dinner", A, 40,
    ["high_protein", "bulking"], EN, 46, 52, 16,
    [ing(200, "g", "lean ground beef", "yağsız dana kıyma"),
     ing(150, "g", "kidney beans", "kırmızı barbunya"),
     ing(300, "g", "chopped tomatoes", "doğranmış domates"),
     ing(1, None, "onion", "kuru soğan"),
     ing(2, "diş", "garlic", "sarımsak"),
     ing(2, "çay kaşığı", "chili powder", "toz acı biber"),
     ing(None, None, "cumin, salt, pepper", "kimyon, tuz, karabiber")],
    ["Soften the onion and garlic, then brown the beef with them.",
     "Add the chili powder and cumin and cook for 1 minute to bloom them.",
     "Add the tomatoes and beans and simmer for 25 minutes.",
     "Season and serve — it is better the next day."],
    ["Soğan ve sarımsağı yumuşatın, sonra kıymayı ekleyip kavurun.",
     "Toz acı biber ve kimyonu ekleyip kokusu çıkması için 1 dakika pişirin.",
     "Domates ve barbunyayı ekleyip 25 dakika kısık ateşte pişirin.",
     "Tatlandırıp servis edin — ertesi gün daha lezzetlidir."],
    "Deep bowl of chili con carne with kidney beans, steam rising, rustic "
    "wooden table, warm hearty lighting"))

R.append(recipe(
    "sheet-pan-chicken-veg", "Sheet Pan Chicken and Vegetables",
    "Tek Tepsi Tavuk ve Sebze", "dinner", A, 35,
    ["high_protein", "budget_friendly"], EN, 46, 40, 18,
    [ing(200, "g", "chicken breast", "tavuk göğsü"),
     ing(200, "g", "potato", "patates"),
     ing(120, "g", "courgette", "kabak"),
     ing(120, "g", "carrot", "havuç"),
     ing(1, "yemek kaşığı", "olive oil", "zeytinyağı"),
     ing(None, None, "rosemary, salt, pepper", "biberiye, tuz, karabiber")],
    ["Cut the potato and carrot into chunks and roast at 200 degrees for "
     "15 minutes.",
     "Add the chicken and courgette, drizzle with oil and season.",
     "Roast for a further 20 minutes, turning once."],
    ["Patates ve havucu iri doğrayıp 200 derecede 15 dakika fırınlayın.",
     "Tavuğu ve kabağı ekleyin, yağı gezdirip tatlandırın.",
     "Bir kez çevirerek 20 dakika daha fırınlayın."],
    "Sheet pan of roasted chicken breast with potatoes, carrots and "
    "courgette, herbs scattered, overhead, homely"))

R.append(recipe(
    "seared-tuna-steak-greens", "Seared Tuna Steak with Greens",
    "Mühürlenmiş Ton Balığı ve Yeşillikler", "dinner", A, 15,
    ["high_protein", "low_calorie"], EN, 48, 14, 14,
    [ing(200, "g", "tuna steak", "ton balığı bifteği"),
     ing(120, "g", "rocket", "roka"),
     ing(80, "g", "cucumber", "salatalık"),
     ing(1, "yemek kaşığı", "soy sauce", "soya sosu"),
     ing(1, "yemek kaşığı", "sesame oil", "susam yağı"),
     ing(1, "çay kaşığı", "sesame seeds", "susam")],
    ["Rub the tuna with half the sesame oil and season it.",
     "Sear it in a screaming-hot pan for 90 seconds a side — the centre "
     "should stay ruby.",
     "Rest it for 2 minutes, then slice it thinly.",
     "Dress the rocket and cucumber with the soy sauce and remaining oil, "
     "and lay the tuna over."],
    ["Ton balığını susam yağının yarısıyla ovup tatlandırın.",
     "Çok kızgın tavada her yüzü 90 saniye mühürleyin — ortası pembe "
     "kalmalı.",
     "2 dakika dinlendirip ince dilimleyin.",
     "Roka ve salatalığı soya sosu ve kalan yağla harmanlayıp balığı "
     "üzerine dizin."],
    "Sliced seared tuna steak with ruby centre over rocket salad, sesame "
    "seeds, dark slate plate, elegant plating"))


# ─── snack (12) ─────────────────────────────────────────────────────

R.append(recipe(
    "casein-protein-pudding", "Casein Protein Pudding",
    "Kazeinli Protein Puding", "snack", A, 5, ["high_protein", "toning"],
    EN, 32, 14, 6,
    [ing(35, "g", "casein protein powder", "kazein protein tozu"),
     ing(180, "ml", "milk", "süt"),
     ing(1, "tatlı kaşığı", "cocoa powder", "kakao tozu"),
     ing(10, "g", "almonds", "badem")],
    ["Whisk the casein, milk and cocoa until it thickens — casein sets on "
     "its own, no gelatine needed.",
     "Chill for 20 minutes.",
     "Top with chopped almonds."],
    ["Kazeini, sütü ve kakaoyu koyulaşana kadar çırpın — kazein kendi "
     "başına kıvam alır, jelatine gerek yok.",
     "20 dakika buzdolabında bekletin.",
     "Üzerine doğranmış badem serpin."],
    "Thick chocolate casein pudding in a small glass, chopped almonds on "
    "top, moody dark styling"))

R.append(recipe(
    "protein-energy-balls", "Peanut Protein Energy Balls",
    "Fıstık Ezmeli Protein Topları", "snack", A, 15,
    ["high_protein", "budget_friendly"], EN, 20, 34, 18,
    [ing(60, "g", "rolled oats", "yulaf ezmesi"),
     ing(60, "g", "peanut butter", "doğal fıstık ezmesi"),
     ing(25, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(2, "yemek kaşığı", "maple syrup", "akçaağaç şurubu"),
     ing(1, "yemek kaşığı", "chia seeds", "chia tohumu")],
    ["Mix everything in a bowl until it holds together.",
     "Roll into 10 balls with wet hands so the mixture does not stick.",
     "Refrigerate for 30 minutes before eating."],
    ["Tüm malzemeleri bir kapta topaklanana kadar karıştırın.",
     "Islak elle 10 top yapın; böylece karışım elinize yapışmaz.",
     "Yemeden önce 30 dakika buzdolabında bekletin."],
    "Peanut protein energy balls on parchment paper, one bitten open showing "
    "texture, natural light, homely"))

R.append(recipe(
    "cottage-cheese-crackers", "Cottage Cheese and Rye Crackers",
    "Süzme Peynirli Çavdar Kraker", "snack", A, 5,
    ["high_protein", "budget_friendly"], EN, 22, 24, 8,
    [ing(150, "g", "cottage cheese", "süzme peynir"),
     ing(4, None, "rye crackers", "çavdar kraker"),
     ing(1, None, "tomato", "domates"),
     ing(None, None, "black pepper", "karabiber")],
    ["Spoon the cottage cheese onto the crackers.",
     "Lay a slice of tomato on each one.",
     "Grind black pepper over the top."],
    ["Süzme peyniri krakerlerin üzerine koyun.",
     "Her birinin üzerine bir dilim domates yerleştirin.",
     "Üzerine taze çekilmiş karabiber öğütün."],
    "Rye crackers topped with cottage cheese and tomato slices on a wooden "
    "board, simple clean styling"))

R.append(recipe(
    "greek-yogurt-protein-dip", "Greek Yogurt Protein Dip with Veg",
    "Yoğurtlu Protein Dip ve Sebzeler", "snack", A, 8,
    ["high_protein", "low_calorie"], EN, 22, 16, 6,
    [ing(200, "g", "Greek yogurt", "süzme yoğurt"),
     ing(1, "diş", "garlic", "sarımsak"),
     ing(1, "yemek kaşığı", "lemon juice", "limon suyu"),
     ing(1, "yemek kaşığı", "dill", "dereotu"),
     ing(100, "g", "carrot sticks", "havuç çubukları"),
     ing(100, "g", "cucumber sticks", "salatalık çubukları")],
    ["Crush the garlic and stir it into the yogurt with the lemon juice.",
     "Chop the dill finely and fold it through.",
     "Cut the vegetables into sticks and serve them alongside."],
    ["Sarımsağı ezip limon suyuyla birlikte yoğurda karıştırın.",
     "Dereotunu ince kıyıp karışıma ekleyin.",
     "Sebzeleri çubuk çubuk doğrayıp yanında servis edin."],
    "Bowl of herbed yogurt dip surrounded by carrot and cucumber sticks, "
    "overhead, fresh bright styling"))

R.append(recipe(
    "tuna-cucumber-boats", "Tuna Cucumber Boats",
    "Ton Balıklı Salatalık Kayıkları", "snack", A, 10,
    ["high_protein", "low_calorie"], EN, 28, 8, 10,
    [ing(120, "g", "canned tuna", "ton balığı", "drained", "suyu süzülmüş"),
     ing(1, None, "cucumber", "salatalık"),
     ing(2, "yemek kaşığı", "Greek yogurt", "süzme yoğurt"),
     ing(1, "yemek kaşığı", "lemon juice", "limon suyu"),
     ing(None, None, "salt and pepper", "tuz ve karabiber")],
    ["Halve the cucumber lengthways and scoop out the seeds.",
     "Mix the tuna with the yogurt, lemon juice and seasoning.",
     "Spoon the mixture into the hollowed cucumber and cut into lengths."],
    ["Salatalığı uzunlamasına ikiye bölüp çekirdeklerini kaşıkla çıkarın.",
     "Ton balığını yoğurt, limon suyu ve baharatlarla karıştırın.",
     "Karışımı salatalığın içine doldurup parçalara ayırın."],
    "Cucumber halves filled with tuna salad, cut into portions, on a white "
    "plate, fresh light styling"))

R.append(recipe(
    "hard-boiled-eggs-hummus", "Boiled Eggs with Hummus",
    "Haşlanmış Yumurta ve Humus", "snack", A, 12,
    ["high_protein", "budget_friendly"], EN, 24, 18, 20,
    [ing(3, None, "eggs", "yumurta"),
     ing(80, "g", "hummus", "humus"),
     ing(1, "çay kaşığı", "paprika", "toz kırmızı biber"),
     ing(1, "tatlı kaşığı", "olive oil", "zeytinyağı")],
    ["Boil the eggs for 8 minutes, then cool them in cold water.",
     "Peel and halve them.",
     "Spread the hummus on a plate, arrange the eggs on it and finish with "
     "the paprika and olive oil."],
    ["Yumurtaları 8 dakika haşlayıp soğuk suda soğutun.",
     "Kabuklarını soyup ikiye bölün.",
     "Humusu tabağa yayın, yumurtaları üzerine dizin ve toz kırmızı biber "
     "ile zeytinyağıyla bitirin."],
    "Halved boiled eggs on a swoosh of hummus dusted with paprika, drizzle "
    "of olive oil, overhead, mediterranean styling"))

R.append(recipe(
    "protein-rice-cakes", "Rice Cakes with Almond Butter",
    "Badem Ezmeli Pirinç Patlağı", "snack", A, 4,
    ["budget_friendly", "toning"], EN, 12, 34, 16,
    [ing(3, None, "rice cakes", "pirinç patlağı"),
     ing(2, "yemek kaşığı", "almond butter", "badem ezmesi"),
     ing(1, None, "banana", "muz"),
     ing(1, "çimdik", "cinnamon", "tarçın")],
    ["Spread the almond butter over the rice cakes.",
     "Lay banana slices across each one.",
     "Dust with cinnamon."],
    ["Badem ezmesini pirinç patlaklarına sürün.",
     "Her birinin üzerine muz dilimleri dizin.",
     "Tarçın serpin."],
    "Rice cakes topped with almond butter and banana slices, dusted with "
    "cinnamon, bright minimal styling"))

R.append(recipe(
    "turkey-cheese-roll-ups", "Turkey and Cheese Roll-Ups",
    "Hindili Peynirli Rulo", "snack", A, 5, ["high_protein", "low_calorie"],
    EN, 30, 4, 14,
    [ing(120, "g", "sliced turkey breast", "dilimli hindi göğsü"),
     ing(60, "g", "cheddar cheese", "çedar peyniri"),
     ing(4, "yaprak", "lettuce", "marul"),
     ing(1, "çay kaşığı", "dijon mustard", "dijon hardalı")],
    ["Lay the turkey slices out flat and spread them with the mustard.",
     "Put a strip of cheese and a lettuce leaf on each.",
     "Roll them up tightly and pin with a cocktail stick if needed."],
    ["Hindi dilimlerini düz serip üzerlerine hardalı sürün.",
     "Her birine bir şerit peynir ve bir marul yaprağı koyun.",
     "Sıkıca sarın, gerekirse kürdanla tutturun."],
    "Turkey and cheese roll-ups arranged on a plate, cross-section visible, "
    "clean simple styling"))

R.append(recipe(
    "chocolate-protein-shake", "Chocolate Protein Shake",
    "Çikolatalı Protein Shake", "snack", A, 3, ["high_protein", "bulking"],
    EN, 40, 32, 12,
    [ing(35, "g", "chocolate whey protein powder",
         "çikolatalı whey protein tozu"),
     ing(300, "ml", "milk", "süt"),
     ing(1, None, "banana", "muz"),
     ing(1, "yemek kaşığı", "peanut butter", "doğal fıstık ezmesi")],
    ["Put everything in a blender with a handful of ice.",
     "Blend for 30 seconds until smooth and frothy.",
     "Drink within 10 minutes — it separates as it sits."],
    ["Her şeyi bir avuç buzla birlikte blendera koyun.",
     "Pürüzsüz ve köpüklü olana kadar 30 saniye çekin.",
     "10 dakika içinde için — beklerse ayrışır."],
    "Chocolate protein shake in a shaker glass with frothy top, banana and "
    "peanut butter beside it, gym-kitchen styling"))

R.append(recipe(
    "edamame-sea-salt", "Sea Salt Edamame",
    "Deniz Tuzlu Edamame", "snack", A, 8, ["high_protein", "low_calorie"],
    EN, 18, 16, 8,
    [ing(200, "g", "edamame", "edamame", "in the pod", "kabuklu"),
     ing(1, "tatlı kaşığı", "sesame oil", "susam yağı"),
     ing(None, None, "sea salt", "deniz tuzu")],
    ["Boil the edamame in salted water for 5 minutes.",
     "Drain and toss them with the sesame oil.",
     "Scatter sea salt over and eat them straight from the pod."],
    ["Edamameyi tuzlu suda 5 dakika haşlayın.",
     "Süzüp susam yağıyla harmanlayın.",
     "Üzerine deniz tuzu serpip kabuğundan yiyin."],
    "Bowl of glistening edamame pods with sea salt flakes, dark ceramic "
    "bowl, izakaya styling"))

R.append(recipe(
    "protein-trail-mix", "Protein Trail Mix",
    "Proteinli Kuruyemiş Karışımı", "snack", A, 3,
    ["bulking", "budget_friendly"], EN, 16, 28, 26,
    [ing(30, "g", "almonds", "badem"),
     ing(20, "g", "walnuts", "ceviz"),
     ing(20, "g", "pumpkin seeds", "kabak çekirdeği"),
     ing(25, "g", "raisins", "kuru üzüm"),
     ing(15, "g", "dark chocolate", "bitter çikolata")],
    ["Chop the dark chocolate into rough pieces.",
     "Mix everything together in a jar.",
     "Portion it out before eating — trail mix is easy to over-eat from "
     "the bag."],
    ["Bitter çikolatayı iri parçalar hâlinde doğrayın.",
     "Hepsini bir kavanozda karıştırın.",
     "Yemeden önce porsiyonlayın — karışım paketten yenince fazla kaçar."],
    "Trail mix of almonds, walnuts, pumpkin seeds, raisins and dark "
    "chocolate in a glass jar, warm natural light"))

R.append(recipe(
    "apple-almond-butter-slices", "Apple with Almond Butter",
    "Badem Ezmeli Elma Dilimleri", "snack", A, 4,
    ["low_calorie", "budget_friendly"], EN, 8, 30, 16,
    [ing(1, None, "apple", "elma"),
     ing(2, "yemek kaşığı", "almond butter", "badem ezmesi"),
     ing(1, "çay kaşığı", "chia seeds", "chia tohumu"),
     ing(1, "çimdik", "cinnamon", "tarçın")],
    ["Core the apple and cut it into rounds.",
     "Spread the almond butter over each slice.",
     "Sprinkle the chia seeds and cinnamon over the top."],
    ["Elmanın çekirdek evini çıkarıp halka halka dilimleyin.",
     "Her dilime badem ezmesi sürün.",
     "Üzerine chia tohumu ve tarçın serpin."],
    "Apple rounds spread with almond butter and sprinkled with chia seeds, "
    "overhead on a light board, fresh and clean"))

# ─── dessert (8) ────────────────────────────────────────────────────

R.append(recipe(
    "protein-brownie-bites", "Protein Brownie Bites",
    "Protein Brownie Topları", "dessert", A, 25, ["high_protein", "toning"],
    EN, 22, 30, 14,
    [ing(60, "g", "oat flour", "yulaf unu"),
     ing(30, "g", "chocolate whey protein powder",
         "çikolatalı whey protein tozu"),
     ing(20, "g", "cocoa powder", "kakao tozu"),
     ing(2, None, "eggs", "yumurta"),
     ing(60, "g", "Greek yogurt", "süzme yoğurt"),
     ing(2, "yemek kaşığı", "maple syrup", "akçaağaç şurubu")],
    ["Whisk the eggs, yogurt and maple syrup together.",
     "Fold in the oat flour, protein powder and cocoa without overmixing.",
     "Spoon into a lined tin and bake at 175 degrees for 18 minutes.",
     "Let them cool fully before cutting — protein bakes are fragile hot."],
    ["Yumurta, yoğurt ve akçaağaç şurubunu birlikte çırpın.",
     "Yulaf ununu, protein tozunu ve kakaoyu fazla karıştırmadan ekleyin.",
     "Yağlı kâğıt serili kaba döküp 175 derecede 18 dakika pişirin.",
     "Kesmeden önce tamamen soğutun — proteinli hamurlar sıcakken dağılır."],
    "Fudgy protein brownie bites cut into squares on parchment, dusted with "
    "cocoa, moody dark food photography"))

R.append(recipe(
    "frozen-yogurt-bark", "Frozen Protein Yogurt Bark",
    "Donmuş Protein Yoğurt Kırığı", "dessert", A, 10,
    ["high_protein", "low_calorie"], EN, 24, 20, 8,
    [ing(300, "g", "Greek yogurt", "süzme yoğurt"),
     ing(25, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(80, "g", "mixed berries", "karışık orman meyvesi"),
     ing(15, "g", "dark chocolate", "bitter çikolata"),
     ing(1, "yemek kaşığı", "honey", "bal")],
    ["Stir the protein powder and honey through the yogurt.",
     "Spread it 1 cm thick on a lined tray.",
     "Scatter the berries and chopped chocolate over the surface.",
     "Freeze for 4 hours, then snap into shards."],
    ["Protein tozunu ve balı yoğurda karıştırın.",
     "Yağlı kâğıt serili tepsiye 1 cm kalınlığında yayın.",
     "Yüzeye orman meyvelerini ve doğranmış çikolatayı serpin.",
     "4 saat dondurup parçalara kırın."],
    "Frozen yogurt bark broken into shards with berries and chocolate "
    "pieces, on a cold marble slab, bright styling"))

R.append(recipe(
    "protein-cheesecake-jar", "No-Bake Protein Cheesecake Jar",
    "Pişirmesiz Protein Cheesecake", "dessert", A, 15,
    ["high_protein", "toning"], EN, 30, 26, 14,
    [ing(150, "g", "cottage cheese", "süzme peynir"),
     ing(80, "g", "Greek yogurt", "süzme yoğurt"),
     ing(25, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(2, None, "rye crackers", "çavdar kraker"),
     ing(1, "tatlı kaşığı", "butter", "tereyağı"),
     ing(60, "g", "strawberries", "çilek")],
    ["Blend the cottage cheese, yogurt and protein powder completely "
     "smooth — cottage cheese has to lose its texture entirely.",
     "Crush the crackers and mix them with the melted butter for the base.",
     "Layer the base and the filling in a jar.",
     "Chill for 2 hours and top with sliced strawberries."],
    ["Süzme peynir, yoğurt ve protein tozunu tamamen pürüzsüz olana kadar "
     "blenderdan geçirin — peynirin dokusu tamamen kaybolmalı.",
     "Krakerleri ezip erimiş tereyağıyla karıştırarak taban yapın.",
     "Kavanozda tabanı ve kremayı katmanlayın.",
     "2 saat soğutup üzerine dilimlenmiş çilek koyun."],
    "Layered protein cheesecake in a glass jar with biscuit base and "
    "strawberries on top, soft natural light"))

R.append(recipe(
    "banana-protein-ice-cream", "Banana Protein Ice Cream",
    "Muzlu Protein Dondurma", "dessert", A, 5, ["high_protein", "low_calorie"],
    EN, 28, 44, 6,
    [ing(2, None, "frozen bananas", "dondurulmuş muz"),
     ing(30, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(60, "ml", "almond milk", "badem sütü"),
     ing(1, "yemek kaşığı", "peanut butter", "doğal fıstık ezmesi")],
    ["Blend the frozen banana, protein powder and almond milk until it "
     "turns creamy.",
     "Add the almond milk slowly — too much and it becomes a smoothie.",
     "Swirl the peanut butter through and eat immediately."],
    ["Dondurulmuş muzu, protein tozunu ve badem sütünü kremamsı olana kadar "
     "blenderdan geçirin.",
     "Badem sütünü yavaş ekleyin — fazlası karışımı smoothie yapar.",
     "Fıstık ezmesini içinde dalgalandırıp hemen tüketin."],
    "Scoops of creamy banana protein ice cream in a bowl with a peanut "
    "butter swirl, frosty texture, bright styling"))

R.append(recipe(
    "chocolate-avocado-mousse", "Chocolate Avocado Mousse",
    "Çikolatalı Avokado Mus", "dessert", A, 10, ["toning", "low_calorie"],
    EN, 8, 30, 22,
    [ing(1, None, "ripe avocado", "olgun avokado"),
     ing(25, "g", "cocoa powder", "kakao tozu"),
     ing(3, "yemek kaşığı", "maple syrup", "akçaağaç şurubu"),
     ing(60, "ml", "almond milk", "badem sütü"),
     ing(1, "çimdik", "sea salt", "deniz tuzu")],
    ["Blend the avocado, cocoa, maple syrup and almond milk until glossy.",
     "Add the pinch of salt — it is what stops it tasting flat.",
     "Chill for 30 minutes before serving."],
    ["Avokado, kakao, akçaağaç şurubu ve badem sütünü parlak bir kıvam "
     "alana kadar çekin.",
     "Bir tutam tuz ekleyin — tadın yavan kalmasını engelleyen budur.",
     "Servis etmeden önce 30 dakika soğutun."],
    "Glossy dark chocolate avocado mousse in a small glass with a mint "
    "leaf, dramatic dark styling"))

R.append(recipe(
    "protein-mug-cake", "Chocolate Protein Mug Cake",
    "Çikolatalı Protein Kupa Kek", "dessert", A, 5,
    ["high_protein", "budget_friendly"], EN, 28, 28, 12,
    [ing(30, "g", "chocolate whey protein powder",
         "çikolatalı whey protein tozu"),
     ing(20, "g", "oat flour", "yulaf unu"),
     ing(1, None, "egg", "yumurta"),
     ing(60, "ml", "milk", "süt"),
     ing(1, "çay kaşığı", "baking powder", "kabartma tozu"),
     ing(1, "tatlı kaşığı", "cocoa powder", "kakao tozu")],
    ["Whisk everything directly in a large mug until no lumps remain.",
     "Microwave on high for 60 seconds.",
     "Stop at 60 seconds even if it looks wet — protein cake goes rubbery "
     "the moment it is overcooked."],
    ["Her şeyi doğrudan büyük bir kupada topak kalmayana kadar çırpın.",
     "Mikrodalgada yüksek ayarda 60 saniye pişirin.",
     "Islak görünse bile 60 saniyede durun — proteinli kek fazla pişince "
     "anında lastikleşir."],
    "Chocolate protein mug cake risen above the rim of a white mug, spoon "
    "beside it, cozy kitchen lighting"))

R.append(recipe(
    "protein-rice-pudding", "Cinnamon Protein Rice Pudding",
    "Tarçınlı Protein Sütlaç", "dessert", A, 30,
    ["high_protein", "budget_friendly"], EN, 24, 56, 8,
    [ing(70, "g", "rice", "pirinç"),
     ing(400, "ml", "milk", "süt"),
     ing(25, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(1, "yemek kaşığı", "honey", "bal"),
     ing(1, "çay kaşığı", "cinnamon", "tarçın")],
    ["Simmer the rice in the milk for 25 minutes, stirring often.",
     "Take it off the heat and let it cool for 5 minutes.",
     "Stir the protein powder in off the heat — boiling it makes it "
     "grainy.",
     "Finish with honey and cinnamon."],
    ["Pirinci sütte 25 dakika, sık sık karıştırarak pişirin.",
     "Ateşten alıp 5 dakika soğumaya bırakın.",
     "Protein tozunu ateşten uzakta karıştırın — kaynatmak tozu "
     "topaklandırır.",
     "Bal ve tarçınla bitirin."],
    "Creamy rice pudding in a bowl dusted with cinnamon, warm comforting "
    "lighting, rustic ceramic"))

R.append(recipe(
    "berry-protein-parfait", "Berry Protein Parfait",
    "Meyveli Protein Parfe", "dessert", A, 8,
    ["high_protein", "low_calorie"], EN, 26, 30, 8,
    [ing(200, "g", "Greek yogurt", "süzme yoğurt"),
     ing(20, "g", "vanilla whey protein powder", "vanilyalı whey protein tozu"),
     ing(100, "g", "mixed berries", "karışık orman meyvesi"),
     ing(20, "g", "rolled oats", "yulaf ezmesi"),
     ing(1, "tatlı kaşığı", "honey", "bal")],
    ["Stir the protein powder through the yogurt until smooth.",
     "Toast the oats in a dry pan for 3 minutes until they smell nutty.",
     "Layer the yogurt, berries and oats twice over in a glass.",
     "Finish with honey."],
    ["Protein tozunu yoğurda pürüzsüz olana kadar karıştırın.",
     "Yulafı kuru tavada 3 dakika, kokusu çıkana kadar kavurun.",
     "Bardağa yoğurt, meyve ve yulafı iki kat hâlinde dizin.",
     "Balla bitirin."],
    "Layered berry parfait in a tall glass showing distinct yogurt, berry "
    "and oat layers, bright airy styling"))


emit(R, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "western.json"))
