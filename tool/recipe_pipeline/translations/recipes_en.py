"""Roadmap Phase 7 §6 · the authored catalogue's method steps, in English.

Keyed by the Turkish title, which is unique and which a reviewer can
actually read — a uuid tells nobody anything.

Only the METHOD steps are here. The ingredient list is assembled from
`recipe_ingredients.name_en` by `build_recipe_en.py`, so no quantity and
no unit ever passes through a translation. That is §6.2's first rule made
structural rather than procedural.

## The rules every entry follows

* **Imperative mood**, matching the Turkish. "Fry the onion", never "the
  onion is fried".
* **One step per entry, same count as the source.** A merged step breaks
  the step-by-step reader and the audit fails on it.
* **Every number survives, unconverted.** 180 degrees stays 180 degrees;
  `unit_system.dart` is what shows a reader Fahrenheit if they want it.
* **Proper nouns stay** — sucuk, menemen, çılbır, tarhana — because the
  dish is the dish. The ingredient glossary carries the substitution.
* **Nothing is invented.** No health claim, no technique, no ingredient
  the Turkish did not name. A translation pass is exactly where such a
  thing sneaks in.

## Cooking verbs that machine translation gets wrong

`kavurmak` is to fry off over heat until coloured, not "to burn".
`dinlendirmek` is to rest, but `hamuru dinlendirmek` is to let dough
relax and `eti dinlendirmek` is to let meat settle — different English
verbs for the same Turkish one. `sotelemek` is to sauté. `yakmak`, in
`tereyağını pul biberle yakın`, is to bloom the chilli in hot butter,
not to burn it. Each of those is a place a fluent-looking wrong
translation would have gone unnoticed.
"""

# title_tr -> (title_en, [step_en, ...])
RECIPES_EN = {
    "Acılı Domates Çorbası": ("Spicy Tomato Soup", [
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the tomatoes and simmer for 6 minutes.",
        "Add the salt, chilli flakes and 200 ml of water, then cook for "
        "4 minutes more.",
        "Stir the butter into the soup and serve.",
    ]),
    "Akdeniz Kinoa Salatası": ("Mediterranean Quinoa Salad", [
        "Boil the quinoa in plenty of water for 15 minutes, then leave it "
        "to cool.",
        "Dice all the vegetables small.",
        "Combine the quinoa, chickpeas, vegetables and cheese.",
        "Drizzle with olive oil and lemon juice and serve with parsley.",
    ]),
    "Avokadolu Tam Buğday Tost": ("Avocado Wholemeal Toast", [
        "Toast the bread in a toaster or dry pan until both sides are "
        "golden.",
        "Halve the avocado and remove the stone; mash the flesh with a "
        "fork and mix in the lemon juice, salt and black pepper.",
        "Bring water to the boil in a small pan; once it boils, lower the "
        "heat and add the vinegar.",
        "Crack each egg into a separate bowl; make a gentle whirlpool in "
        "the water and slide the egg in slowly.",
        "Poach for 2-3 minutes for a runny yolk, lift out with a slotted "
        "spoon and drain on kitchen paper.",
        "Spread the mashed avocado generously over the toast and set a "
        "poached egg on each slice.",
        "Scatter chilli flakes, olive oil and the chopped thyme over the "
        "top and serve immediately.",
    ]),
    "Avokadolu Yumurtalı Tam Buğday Tost": (
        "Avocado and Egg Wholemeal Toast", [
            "Toast the bread slices for 2 minutes.",
            "Mash the avocado with a fork and mix in the lemon juice and "
            "salt.",
            "Spread the avocado mixture over the bread.",
            "Lay the sliced egg on top and serve with chilli flakes and "
            "parsley.",
        ]),
    "Bademli Süt Pudingi": ("Almond Milk Pudding", [
        "Slake the rice flour with 50 ml of cold milk.",
        "Bring the remaining milk to the boil and add the sugar.",
        "Add the rice flour mixture and stir for 6 minutes until it "
        "thickens.",
        "Divide between bowls and finish with vanilla and almonds.",
    ]),
    "Bahçıvan Salatası": ("Gardener's Salad", [
        "Combine all the vegetables in a bowl.",
        "Add the olive oil.",
        "Season with salt and toss lightly.",
        "Serve cold.",
    ]),
    "Bal Soslu Vanilyalı Yoğurt": ("Vanilla Yogurt with Honey", [
        "Stir the vanilla through the yogurt.",
        "Spoon into a bowl and drizzle the honey over.",
        "Scatter the walnuts.",
        "Finish with cinnamon and serve.",
    ]),
    "Bal-Cevizli Lor Peyniri": ("Lor Cheese with Honey and Walnuts", [
        "Spoon the lor cheese into a bowl.",
        "Add the walnuts on top.",
        "Drizzle the honey over.",
        "Finish with cinnamon and serve with bread.",
    ]),
    "Bal-Cevizli Süzme Yoğurt": ("Strained Yogurt with Honey and Walnuts", [
        "Spoon the yogurt into a bowl.",
        "Add the honey and walnuts on top.",
        "Finish with cinnamon and serve.",
    ]),
    "Bal-Tarçınlı Ekmek Tatlısı": ("Honey Cinnamon French Toast", [
        "Whisk the eggs, milk and cinnamon together.",
        "Dip the bread slices in the mixture.",
        "Fry each side in the butter for 2 minutes.",
        "Drizzle the honey over and serve warm.",
    ]),
    "Bazlama Tava Tost": ("Bazlama Pan Toastie", [
        "Split the bazlama through the middle and spread the cheese over "
        "the cut face.",
        "Add the tomato slices and olives.",
        "Heat in a covered pan for 3 minutes.",
        "Garnish with mint and serve.",
    ]),
    "Beyaz Peynirli Bal Tatlısı": ("Beyaz Peynir with Honey", [
        "Put the beyaz peynir in a bowl and crumble it.",
        "Stir in the honey and walnuts.",
        "Finish with cinnamon.",
        "Serve alongside a slice of bread.",
    ]),
    "Beyaz Peynirli Krep": ("Beyaz Peynir Crêpes", [
        "Whisk the eggs, flour and milk until smooth.",
        "Cook thin crêpes in an oiled pan.",
        "Spread the cheese and parsley over half of each crêpe.",
        "Fold in half, heat for 1 minute more and serve.",
    ]),
    "Beyaz Peynirli Sade Makarna": ("Simple Pasta with Beyaz Peynir", [
        "Boil the pasta in salted water and drain it.",
        "Warm the olive oil in the same pan.",
        "Return the pasta, add the cheese and toss together.",
        "Garnish with mint and serve hot.",
    ]),
    "Beyaz Peynirli Tam Buğday Tost": (
        "Wholemeal Toastie with Beyaz Peynir", [
            "Brush one side of each bread slice with olive oil.",
            "Crumble the cheese and spread it evenly over the inner faces.",
            "Toast in a two-sided sandwich press for 3-4 minutes.",
            "Serve with tomato slices, olives and mint.",
        ]),
    "Beyaz Pilav ve Etli Sote": ("Rice Pilaf with Beef Sauté", [
        "Cook the rice in salted water for 12 minutes and drain.",
        "Fry the beef in the olive oil for 4 minutes.",
        "Add the onion and tomato paste and cook for 6 minutes more with "
        "100 ml of water.",
        "Plate the rice and lay the beef over it.",
    ]),
    "Beyaz Pilav ve Sade Yoğurt": ("Rice Pilaf with Yogurt", [
        "Rinse the rice and soak it in hot water for 10 minutes.",
        "Melt the butter in a pan, add the rice and fry for 1 minute.",
        "Add 200 ml of hot water and the salt, cover and cook for "
        "12 minutes.",
        "Let the pilaf rest and serve with the yogurt.",
    ]),
    "Bezelye Etli": ("Beef and Pea Stew", [
        "Fry the beef in the olive oil for 4 minutes.",
        "Add the onion and carrot and cook for 3 minutes more.",
        "Add the peas and 150 ml of hot water.",
        "Cover, cook for 6 minutes, season with salt and serve.",
    ]),
    "Bonfileli Burrito": ("Beef Fillet Burrito", [
        "Combine the rice and kidney beans in a bowl.",
        "Warm the tortilla lightly in a pan.",
        "Lay the rice and bean mixture, beef, cheese, avocado and salsa "
        "down the middle.",
        "Fold the ends in first, then roll it tightly.",
        "Fry each side in a hot pan for 1 minute until golden.",
    ]),
    "Cevizli Hurma Topları": ("Date and Walnut Balls", [
        "Blitz the dates and walnuts in a food processor.",
        "Roll the mixture into walnut-sized balls.",
        "Coat the balls first in cocoa, then in desiccated coconut.",
        "Chill for 5 minutes and serve.",
    ]),
    "Cevizli Karamelize Muz": ("Caramelised Banana with Walnuts", [
        "Melt the butter in a pan and fry the banana slices for 2 minutes "
        "a side.",
        "Drizzle the honey down the side of the pan.",
        "Lift the bananas onto a plate.",
        "Scatter the walnuts and cinnamon over and serve warm.",
    ]),
    "Cevizli Yoğurt Tatlısı": ("Yogurt Dessert with Walnuts", [
        "Spoon the yogurt into a bowl.",
        "Add the honey and walnuts on top.",
        "Scatter the cinnamon and desiccated coconut.",
        "Serve immediately.",
    ]),
    "Chia Tohumlu Vegan Pancake": ("Vegan Chia Pancakes", [
        "Soak the chia seeds in 45 ml of water for 5 minutes until they "
        "swell.",
        "Whisk the flour, baking powder, milk, maple syrup, vanilla and "
        "the chia gel until smooth.",
        "Cook each pancake in a non-stick pan over medium heat for "
        "2 minutes.",
        "Stack the pancakes, scatter the blackberries over and serve.",
    ]),
    "Chia Tohumu Pudingi": ("Chia Seed Pudding", [
        "Stir the chia seeds, almond milk, maple syrup and vanilla "
        "together in a jar.",
        "Refrigerate for at least 4 hours, preferably overnight.",
        "In the morning, loosen it with a fork and transfer to a bowl.",
        "Scatter the strawberries and almonds over and serve.",
    ]),
    "Çiğ Sebze Kahvaltı Tabağı": ("Raw Vegetable Breakfast Plate", [
        "Arrange the vegetables on a plate.",
        "Set the beyaz peynir and olives to one side.",
        "Drizzle olive oil over the top.",
        "Garnish with mint and serve.",
    ]),
    "Çiğ Sebze ve Yoğurtlu Sos": ("Crudités with Yogurt Dip", [
        "Cut the vegetables into fingers and arrange them on a plate.",
        "Stir the garlic and mint through the yogurt.",
        "Put the dip on the plate in a small bowl.",
        "Serve immediately.",
    ]),
    "Çikolatalı Chia Tohumu Pudingi": ("Chocolate Chia Pudding", [
        "Whisk the chia seeds, almond milk, cocoa, maple syrup and "
        "vanilla together in a jar.",
        "Refrigerate for at least 4 hours, preferably overnight.",
        "Loosen it with a fork before serving.",
        "Set the strawberries on top and serve.",
    ]),
    "Çikolatalı Muzlu Protein Shake": ("Chocolate Banana Protein Shake", [
        "Put all the ingredients in a blender.",
        "Blend on high for 45 seconds until smooth.",
        "Pour into a tall glass.",
        "Dust with cocoa powder if you like and drink immediately.",
    ]),
    "Çikolatalı Protein Puding": ("Chocolate Protein Pudding", [
        "Whisk the yogurt, protein powder and cocoa powder until even.",
        "Add the honey and stir again.",
        "Transfer to a serving bowl and rest in the fridge for "
        "30 minutes.",
        "Scatter the roughly chopped almonds over and serve.",
    ]),
    "Çikolatalı Yulaf Topları": ("Chocolate Oat Balls", [
        "Knead the oats, cocoa, honey and peanut butter together.",
        "Roll the mixture into walnut-sized balls.",
        "Coat them in desiccated coconut.",
        "Chill for 5 minutes and serve.",
    ]),
    "Çılbır": ("Çılbır — Poached Eggs over Garlic Yogurt", [
        "Stir the crushed garlic and salt through the yogurt and spread "
        "it over a plate.",
        "Crack the eggs into boiling water, poach for 3 minutes and "
        "drain.",
        "Set the eggs on the yogurt.",
        "Melt the butter and bloom the chilli flakes in it, then pour it "
        "over and serve.",
    ]),
    "Çırpılmış Yumurta ve Pastırma": ("Scrambled Eggs with Pastırma", [
        "Fry the pastırma in a pan for 1 minute.",
        "Beat the eggs with the milk and add the seasoning.",
        "Pour over the pastırma and scramble for 3 minutes.",
        "Plate and serve with the butter.",
    ]),
    "Çıtır Yumurtalı Sandviç": ("Crispy Fried Egg Sandwich", [
        "Fry the eggs in the butter for 3 minutes.",
        "Toast the bread slices lightly.",
        "Lay the egg, lettuce and tomato on one slice.",
        "Season with salt, close with the other slice and serve.",
    ]),
    "Domates Salçalı Bonfile Yemeği": ("Beef Fillet in Tomato Sauce", [
        "Fry the beef fillet in the olive oil for 4 minutes.",
        "Add the onion and cook for 2 minutes more.",
        "Add the tomato paste and tomatoes and simmer for 5 minutes.",
        "Season with salt and serve.",
    ]),
    "Domates Soslu Köfte": ("Köfte in Tomato Sauce", [
        "Shape the köfte mix into small balls and cook them in a pan for "
        "5 minutes.",
        "Fry the onion in olive oil in a separate pan for 2 minutes.",
        "Add the tomatoes and simmer for 5 minutes.",
        "Add the köfte to the sauce and cook for 2 minutes more.",
    ]),
    "Domates Soslu Sade Makarna": ("Simple Pasta in Tomato Sauce", [
        "Boil the pasta in salted water according to the packet.",
        "Fry the onion in the olive oil for 2 minutes, add the tomato "
        "paste and cook for 1 minute more.",
        "Loosen the sauce with 100 ml of hot water.",
        "Toss the drained pasta through the sauce, season and serve.",
    ]),
    "Domates ve Beyaz Peynir Tabağı": ("Tomato and Beyaz Peynir Plate", [
        "Arrange the tomato slices on a plate.",
        "Set the beyaz peynir to one side.",
        "Add the olives and mint.",
        "Drizzle olive oil over and serve.",
    ]),
    "Domatesli Pirinç Pilavı": ("Tomato Rice Pilaf", [
        "Fry the onion in the butter for 2 minutes.",
        "Add the tomato paste and tomatoes and cook for 2 minutes more.",
        "Add the rice and fry for 1 minute.",
        "Add 200 ml of hot water and the salt, cover and cook for "
        "12 minutes.",
    ]),
    "Domatesli Sade Tavuk": ("Simple Chicken with Tomatoes", [
        "Fry the chicken in the olive oil for 4 minutes.",
        "Add the pepper and sauté for 2 minutes.",
        "Add the tomatoes and cook for 5 minutes until they release their "
        "juice.",
        "Season and serve.",
    ]),
    "Domatesli Sahanda Yumurta": ("Fried Eggs with Tomato", [
        "Warm the olive oil in a pan.",
        "Add the chopped tomato and sauté for 2 minutes.",
        "Crack the eggs over the top and scatter the seasoning.",
        "Cook for 3 minutes until the whites set and serve hot.",
    ]),
    "Donmuş Muz Dilimleri": ("Frozen Chocolate Banana Slices", [
        "Melt the chocolate over a bain-marie.",
        "Dip the frozen banana slices in the chocolate.",
        "Coat them in desiccated coconut and walnuts.",
        "Lay them on baking paper and freeze for 3 minutes more.",
    ]),
    "Donmuş Yoğurt Topları": ("Frozen Yogurt Bites", [
        "Mix the yogurt, strawberries, honey and vanilla together.",
        "Drop small balls onto baking paper with an ice-cream scoop.",
        "Freeze for 5 minutes.",
        "Serve immediately.",
    ]),
    "Elma Dilimleri ve Fıstık Ezmesi": ("Apple Slices with Peanut Butter", [
        "Slice the apple thinly.",
        "Warm the peanut butter slightly so it runs.",
        "Arrange the apple slices on a plate and drizzle the peanut "
        "butter over.",
        "Scatter cinnamon over and eat straight away.",
    ]),
    "Etli Kabak Yemeği": ("Beef and Courgette Stew", [
        "Fry the ground beef in the olive oil for 4 minutes.",
        "Add the onion and tomato paste and cook for 2 minutes more.",
        "Add the courgette and 150 ml of hot water.",
        "Cover and cook for 6 minutes, then serve with dill.",
    ]),
    "Etli Kuru Fasulye": ("Beef and White Bean Stew", [
        "Fry the beef in the olive oil for 4 minutes.",
        "Add the onion and tomato paste and cook for 2 minutes more.",
        "Add the beans and 200 ml of hot water.",
        "Cover and simmer for 8 minutes, season with salt and serve.",
    ]),
    "Etli Nohut": ("Beef and Chickpea Stew", [
        "Fry the beef in the olive oil for 4 minutes.",
        "Add the onion and tomato paste and cook for 2 minutes more.",
        "Add the chickpeas and 200 ml of hot water.",
        "Cover and simmer for 8 minutes, season with salt and serve.",
    ]),
    "Etli Nohutlu Pilav": ("Beef and Chickpea Pilaf", [
        "Fry the beef in the butter for 4 minutes.",
        "Add the onion and cook for 2 minutes more.",
        "Add the rice and chickpeas and fry for 1 minute.",
        "Add 250 ml of hot water and the salt, cover and cook for "
        "12 minutes.",
    ]),
    "Etli Pırasa Yemeği": ("Beef and Leek Stew", [
        "Fry the ground beef in the butter for 4 minutes.",
        "Add the onion and tomato paste and cook for 2 minutes more.",
        "Add the leek and 150 ml of hot water.",
        "Cover and simmer for 8 minutes, season with salt and serve.",
    ]),
    "Etli Sebzeli Çorba": ("Beef and Vegetable Soup", [
        "Put the beef in a pan with the stock and simmer for 8 minutes.",
        "Add the onion, carrot and potato and cook for 5 minutes more.",
        "Season with salt.",
        "Serve.",
    ]),
    "Etli Tarhana Çorbası": ("Tarhana Soup with Beef", [
        "Fry the ground beef in the butter for 4 minutes and add the "
        "tomato paste.",
        "Slake the tarhana with 100 ml of cold water, add the remaining "
        "400 ml and bring it to the boil.",
        "Add the loosened tarhana to the pan with the beef.",
        "Cook for 6 minutes more, season with salt and serve.",
    ]),
    "Ev Yapımı Patates Cipsi": ("Homemade Potato Crisps", [
        "Toss the potato slices with the olive oil, salt and spices.",
        "Cook each side for 5 minutes in a non-stick pan.",
        "Turn them now and then until crisp.",
        "Serve hot.",
    ]),
    "Ev Yapımı Protein Bar": ("Homemade Protein Bars", [
        "Combine all the dry ingredients in a bowl.",
        "Add the peanut butter, honey and milk and work it into an even "
        "dough.",
        "Press it into a non-stick tin and scatter the chocolate chips "
        "over the top.",
        "Rest in the fridge for 1 hour, then cut into 4 bars to store.",
    ]),
    "Ezogelin Çorbası": ("Ezogelin Soup", [
        "Fry the onion in the butter for 2 minutes and add the tomato "
        "paste.",
        "Add the lentils, bulgur and 600 ml of water and bring to the "
        "boil.",
        "Simmer over low heat for 10 minutes.",
        "Season with mint and serve.",
    ]),
    "Fırın Somonu ve Tatlı Patates Püresi": (
        "Baked Salmon with Sweet Potato Mash", [
            "Boil the sweet potatoes in salted water for 12 minutes, "
            "drain and mash them.",
            "Rub the salmon with dill, garlic and salt and bake at "
            "180 degrees for 14 minutes.",
            "Sauté the spinach in the olive oil for 2 minutes.",
            "Bring the sweet potato mash, spinach and salmon together on "
            "the plate and serve.",
        ]),
    "Fırın Tarçınlı Elma": ("Baked Cinnamon Apples", [
        "Core the apples and cut them into 4 pieces.",
        "Lay them on baking paper and drizzle the honey and cinnamon "
        "over.",
        "Bake at 180 degrees for 15 minutes.",
        "Serve hot with the walnut pieces and nutmeg.",
    ]),
    "Fırında Hindi ve Esmer Pirinç": ("Baked Turkey with Brown Rice", [
        "Cook the rice in plenty of water for 25 minutes.",
        "Rub the turkey with thyme, garlic and the spices.",
        "Transfer to a baking tray and bake at 200 degrees for "
        "20 minutes.",
        "Add the mushrooms for the last 6 minutes and cook them "
        "together.",
        "Plate the rice and lay the turkey and mushrooms over it.",
    ]),
    "Fırında Levrek ve Kuskus": ("Baked Sea Bass with Couscous", [
        "Set the sea bass on baking paper.",
        "Top it with the garlic, dill, lemon slices and a little olive "
        "oil.",
        "Bake in a preheated 180-degree oven for 15 minutes.",
        "Steep the couscous in hot water for 5 minutes and fluff it with "
        "a fork.",
        "Bring the couscous and sea bass together on the plate and serve.",
    ]),
    "Fırında Somon ve Tatlı Patates": (
        "Oven-Baked Salmon and Sweet Potato", [
            "Toss the sweet potatoes with olive oil, salt and black "
            "pepper and bake at 200 degrees for 25 minutes.",
            "Rub the salmon with dill and crushed garlic and add it to "
            "the tray for the last 12 minutes.",
            "Steam the broccoli for 4 minutes.",
            "Set the potato and broccoli beside the salmon and serve.",
        ]),
    "Fırınlanmış Somon ve Tatlı Patates": (
        "Roasted Salmon and Sweet Potato", [
            "Preheat the oven to 200 degrees and line a tray with baking "
            "paper.",
            "Toss the sweet potato slices with half the olive oil, salt "
            "and chilli flakes and spread them in a single layer on one "
            "side of the tray; bake for 15 minutes.",
            "Take the tray out and add the asparagus to the other side; "
            "set the salmon in the middle, skin-side down.",
            "Rub the salmon with salt, black pepper and crushed garlic; "
            "lay the lemon slices and thyme sprig on top and drizzle the "
            "remaining oil over.",
            "Return the tray to the oven and bake for 12-14 minutes more "
            "(the salmon should still look faintly pink in the middle).",
            "Rest for 2 minutes, plate and serve hot.",
        ]),
    "Fıstık Ezmeli Muzlu Vegan Smoothie": (
        "Vegan Peanut Butter Banana Smoothie", [
            "Put all the ingredients in a blender.",
            "Blend on high for 60 seconds until it is a smooth drink.",
            "Pour into a tall glass.",
            "Dust a little cocoa powder over if you like and drink "
            "immediately.",
        ]),
    "Fıstık Ezmeli Muzlu Yulaf Ezmesi": (
        "Peanut Butter Banana Porridge", [
            "Cook the oats in the milk over low heat for 6-8 minutes "
            "until thick.",
            "Transfer to a bowl and lay the sliced banana on top.",
            "Swirl the peanut butter through with a spoon.",
            "Finish with chia seeds, honey and cinnamon and serve hot.",
        ]),
    "Fıstık Ezmeli Protein Yulaf Ezmesi": (
        "Peanut Butter Protein Porridge", [
            "Cook the oats in the milk over low heat for 6 minutes.",
            "Take it off the heat and stir the protein powder in once it "
            "has cooled slightly.",
            "Transfer to a bowl and top with the banana, peanut butter "
            "and chia seeds.",
            "Scatter cinnamon over and serve hot.",
        ]),
    "Fıstık Ezmeli Yulaf Lapası": ("Peanut Butter Oat Porridge", [
        "Put the oats and milk in a small pan and bring to the boil over "
        "medium heat, stirring occasionally.",
        "Once it boils, lower the heat and cook for 4-5 minutes more "
        "until creamy.",
        "Take the pan off the heat, add the chia seeds and leave it to "
        "rest for 1 minute.",
        "Transfer to a bowl; add the peanut butter while it is still warm "
        "so it melts in.",
        "Scatter the sliced banana, walnut pieces and cinnamon, sweeten "
        "with honey and serve hot.",
    ]),
    "Hamsi Tava": ("Pan-Fried Anchovies", [
        "Season the anchovies with salt and black pepper.",
        "Coat them in cornflour.",
        "Fry in hot oil for 4 minutes until both sides are golden.",
        "Serve with lemon.",
    ]),
    "Hardallı Tavuk Salatası": ("Mustard Chicken Salad", [
        "Whisk the yogurt, mustard, olive oil and salt together.",
        "Put the lettuce in a bowl and lay the chicken over it.",
        "Drizzle the dressing over.",
        "Toss lightly and serve.",
    ]),
    "Haşlanmış Yumurta ve Domates": ("Boiled Eggs and Tomato", [
        "Put the eggs in cold water and bring to the boil, then cook for "
        "8 minutes more.",
        "Cool them in cold water, peel and halve them.",
        "Slice the tomato and arrange it on a plate with the olives.",
        "Set the eggs on the plate and scatter salt, black pepper and "
        "parsley over.",
    ]),
    "Hazır Çiğ Köfte": ("Quick Çiğ Köfte", [
        "Knead the çiğ köfte mix according to the packet.",
        "Shape it into small balls.",
        "Wrap them in lettuce leaves.",
        "Serve with lemon.",
    ]),
    "Hellim Peyniri Tava": ("Pan-Fried Halloumi", [
        "Warm a pan with the olive oil.",
        "Fry the halloumi slices for 2 minutes a side until golden.",
        "Plate them alongside the bread, olives and mint.",
        "Squeeze the lemon over and serve.",
    ]),
    "Hindi Etli Marul Wrap": ("Turkey Lettuce Wrap", [
        "Mix the yogurt and mustard together.",
        "Lay the turkey, cucumber and dressing on a lettuce leaf.",
        "Season with salt.",
        "Roll the lettuce up tightly and serve.",
    ]),
    "Hindi Etli Pratik Bulgur": ("Quick Turkey Bulgur", [
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the turkey and cook for 4 minutes until it changes colour.",
        "Add the tomato paste, bulgur and 200 ml of hot water.",
        "Cover, cook for 8 minutes and serve.",
    ]),
    "Hindi Etli Yoğurtlu Köfte": ("Turkey Köfte with Yogurt", [
        "Knead the ground turkey, breadcrumbs, onion and salt together.",
        "Shape into balls and cook in the olive oil for 6 minutes.",
        "Turn them and cook for 4 minutes more.",
        "Set them on the yogurt and serve.",
    ]),
    "Hindi Göğsülü Avokadolu Wrap": ("Turkey and Avocado Wrap", [
        "Warm the tortilla lightly in a pan.",
        "Mash the avocado with the lemon juice and spread it on the "
        "tortilla.",
        "Layer the hummus, turkey, rocket and tomato in turn.",
        "Roll it tightly, cut it in half and serve immediately.",
    ]),
    "Hindi Köfte ve Izgara Kabak": (
        "Turkey Köfte with Grilled Courgette", [
            "Knead the ground turkey, breadcrumbs, onion, garlic and "
            "spices together and shape 6 köfte.",
            "Cook the köfte in a non-stick pan for 4 minutes a side.",
            "Grill the courgette slices for 3 minutes.",
            "Plate the köfte with the courgette, drizzle with olive oil "
            "and serve.",
        ]),
    "Hindi Salam Tabağı": ("Turkey Salami Plate", [
        "Arrange the turkey salami slices on a plate.",
        "Set the beyaz peynir and olives to one side.",
        "Add the tomato and bread.",
        "Serve with mint.",
    ]),
    "Hindi Salam ve Yumurta": ("Turkey Salami and Eggs", [
        "Fry the salami slices in a pan for 1 minute.",
        "Crack the eggs over the top and scatter the salt.",
        "Take the pan off the heat once the eggs have set.",
        "Serve with bread and parsley.",
    ]),
    "Hindi Soslu Makarna": ("Pasta with Turkey Sauce", [
        "Boil the pasta in salted water and drain it.",
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the turkey and cook for 4 minutes, add the tomato paste and "
        "simmer with 100 ml of water for 2 minutes.",
        "Toss the pasta through the sauce and serve.",
    ]),
    "Hindi Yoğurtlu Wrap": ("Turkey Yogurt Wrap", [
        "Lay the lavash out flat.",
        "Spread the yogurt over it and season with salt.",
        "Lay out the lettuce, tomato and turkey.",
        "Roll it up tightly, cut it in half and serve.",
    ]),
    "Hindistan Cevizli Chia Pudingi": ("Coconut Chia Pudding", [
        "Whisk the chia, milk and honey together and rest for 10 minutes.",
        "Stir again and divide between bowls.",
        "Add the banana slices and desiccated coconut.",
        "Serve cold.",
    ]),
    "Hindistan Cevizli Süt Pudingi": ("Coconut Milk Pudding", [
        "Slake the rice flour with 50 ml of cold milk.",
        "Bring the remaining milk to the boil and add the sugar and "
        "vanilla.",
        "Add the rice flour mixture and stir for 6 minutes until it "
        "thickens.",
        "Divide between bowls and scatter the coconut over the top.",
    ]),
    "Hızlı İrmik Helvası": ("Quick Semolina Halva", [
        "Toast the pine nuts in the butter for 1 minute.",
        "Add the semolina and toast for 4 minutes until it turns golden.",
        "Add the milk and sugar and stir until it thickens.",
        "Take it off the heat, rest for 5 minutes, press into a mould and "
        "serve.",
    ]),
    "Hızlı Krep ve Reçel": ("Quick Crêpes with Jam", [
        "Whisk the eggs, flour and milk until smooth.",
        "Pour a little batter into an oiled pan and cook thin crêpes "
        "(1-2 minutes each).",
        "Fill the crêpes with jam and roll them up.",
        "Plate and serve.",
    ]),
    "Hızlı Kuru Fasulye Yemeği": ("Quick White Bean Stew", [
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the tomato paste and fry for 1 minute more.",
        "Add the beans and 200 ml of hot water and simmer for 8 minutes.",
        "Season with chilli flakes and salt and serve.",
    ]),
    "Hızlı Mercimek Köftesi": ("Quick Lentil Köfte", [
        "Chop the onion very fine and sauté it in the olive oil for "
        "2 minutes.",
        "Put the hot lentils and bulgur in a bowl, add the sautéed onion "
        "and knead together.",
        "Rest the mixture for 5 minutes and shape small köfte in your "
        "hand.",
        "Scatter parsley over and serve with lemon.",
    ]),
    "Hızlı Sade Lokma": ("Quick Lokma", [
        "Mix the flour, yeast and water in a bowl and let it prove for "
        "5 minutes.",
        "Heat the oil and drop small spoonfuls of the batter in.",
        "Fry for 4 minutes until golden.",
        "Steep in the sugar and honey syrup and serve.",
    ]),
    "Hızlı Tavuk Pirzola": ("Quick Chicken Cutlets", [
        "Marinate the cutlets in the olive oil, garlic, lemon and spices "
        "for 5 minutes.",
        "Cook each side for 4 minutes in a hot griddle pan.",
        "Cover and rest for 2 minutes.",
        "Serve hot.",
    ]),
    "Hızlı Yumurtalı Mercimek Çorbası": ("Quick Lentil Soup with Egg", [
        "Put the lentils and their liquid in a pan and bring to the "
        "boil.",
        "Beat the egg and add it to the pan in a thin stream, stirring "
        "constantly.",
        "Add the salt and simmer for 2 minutes more.",
        "Melt the butter and bloom the chilli flakes in it, pour it over "
        "the soup and serve with lemon.",
    ]),
    "Ispanaklı Peynirli Omlet": ("Spinach and Cheese Omelette", [
        "Beat the eggs and add the salt and black pepper.",
        "Warm the olive oil in a non-stick pan and sauté the spinach for "
        "1 minute.",
        "Pour in the egg mixture and cook over medium heat until the "
        "edges set.",
        "Scatter the cheese and dill over, fold the omelette in half and "
        "serve hot.",
    ]),
    "Izgara Bonfile ve Brokoli": ("Grilled Beef Fillet with Broccoli", [
        "Take the beef out of the fridge 30 minutes before cooking and "
        "bring it to room temperature.",
        "Sear each side for 3 minutes over high heat in a cast-iron pan.",
        "Lower the heat; add the butter, garlic and rosemary and baste "
        "the beef with the fat.",
        "Sauté the broccoli in olive oil in a separate pan for "
        "4 minutes.",
        "Rest the beef for 5 minutes, slice it and serve with the "
        "broccoli.",
    ]),
    "Izgara Bonfile ve Közlenmiş Sebze": (
        "Grilled Beef Fillet with Roasted Vegetables", [
            "Toss the vegetables with olive oil, crushed garlic and the "
            "spices.",
            "Roast at 200 degrees for 18 minutes.",
            "Bring the beef to room temperature and sear each side for "
            "3 minutes in a cast-iron pan.",
            "Rest for 5 minutes, slice and serve with the vegetables.",
        ]),
    "Izgara Hindi ve Pirinç Kasesi": ("Grilled Turkey Rice Bowl", [
        "Cook the rice in plenty of water for 25 minutes.",
        "Marinate the turkey with garlic, thyme and the spices and grill "
        "each side for 3 minutes.",
        "Grill the courgette and pepper for 4 minutes.",
        "Combine the rice, vegetables and sliced turkey in a bowl and "
        "serve.",
    ]),
    "Izgara Karides ve Roka Salatası": ("Grilled Shrimp and Rocket Salad", [
        "Marinate the shrimp with garlic, lemon zest and chilli flakes "
        "for 10 minutes.",
        "Cook them in a dry non-stick pan for 3 minutes, turning.",
        "Arrange the rocket, sliced avocado and cherry tomatoes on a "
        "plate.",
        "Lay the shrimp over the top, drizzle with olive oil and serve.",
    ]),
    "Izgara Levrek ve Buharda Sebze": (
        "Grilled Sea Bass with Steamed Vegetables", [
            "Marinate the sea bass with lemon slices and dill.",
            "Steam the vegetables for 6 minutes.",
            "Griddle the sea bass in a non-stick pan for 3 minutes a "
            "side.",
            "Drizzle with olive oil and serve with the vegetables.",
        ]),
    "Izgara Sebzeli Ton Balığı Salatası": (
        "Tuna Salad with Grilled Vegetables", [
            "Roughly chop the lettuce, cucumber and tomato into a wide "
            "bowl.",
            "Slice the grilled vegetables and add them.",
            "Spread the tuna over the salad.",
            "Whisk the olive oil and lemon juice together, drizzle over "
            "the salad and serve.",
        ]),
    "Izgara Somon & Tatlı Patates": ("Grilled Salmon and Sweet Potato", [
        "Bake the sweet potatoes in the oven.",
        "Cook the salmon in a pan or in the oven.",
        "Sauté the asparagus.",
        "Arrange everything on the plate.",
    ]),
    "Izgara Tavuk ve Kinoa Kasesi": ("Grilled Chicken Quinoa Bowl", [
        "Boil the quinoa in three times its volume of water for "
        "15 minutes and drain.",
        "Marinate the chicken with salt, black pepper and cumin and cook "
        "each side for 3 minutes on a hot griddle.",
        "Layer the quinoa, spinach and sliced avocado in a bowl.",
        "Slice the chicken over the top, drizzle with the olive oil and "
        "lemon dressing and serve.",
    ]),
    "Izgara Tavuklu Hafif Sezar Salata": (
        "Grilled Chicken Light Caesar Salad", [
            "Marinate the chicken with garlic powder, salt and black "
            "pepper and grill each side for 4 minutes.",
            "Whisk the yogurt, mustard, olive oil and a pinch of salt "
            "into a light Caesar dressing.",
            "Toss the lettuce through the dressing and add the parmesan "
            "and croutons.",
            "Slice the rested chicken over the top and serve.",
        ]),
    "Izgara Tavuklu Kinoa Salatası": ("Grilled Chicken Quinoa Salad", [
        "Rinse the quinoa under running water and cook it in 150 ml of "
        "boiling water over low heat for 15 minutes; once the water is "
        "absorbed, cover and rest for 5 minutes more.",
        "Rub the chicken breast with salt, black pepper and thyme; cook "
        "each side for 4 minutes in a hot griddle pan and rest for "
        "2 minutes.",
        "Combine the cooked quinoa, rocket, cucumber, cherry tomatoes and "
        "cheese cubes in a wide salad bowl.",
        "Cut the chicken into thick slices on the diagonal and lay them "
        "over the salad.",
        "Whisk the olive oil and lemon juice in a small bowl and drizzle "
        "it over the salad.",
        "Scatter the sunflower seeds and serve immediately.",
    ]),
    "Kakaolu Hurma Topları": ("Cocoa Date Balls", [
        "Blitz the dates and almonds in a food processor.",
        "Add the salt and knead.",
        "Roll into walnut-sized balls and coat them first in cocoa, then "
        "in desiccated coconut.",
        "Chill for 5 minutes and serve.",
    ]),
    "Kakaolu Yulaf Lapası": ("Cocoa Oat Porridge", [
        "Put the milk and oats in a pan and bring to the boil over "
        "medium heat.",
        "Add the cocoa and stir it in without letting it clump.",
        "Cook for 3 minutes more and transfer to a bowl.",
        "Finish with honey and cinnamon and serve hot.",
    ]),
}
