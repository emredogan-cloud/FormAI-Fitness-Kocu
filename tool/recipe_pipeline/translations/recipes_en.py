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
    "Bonfileli Salata": ("Beef Fillet Salad", [
        "Combine the rocket, tomato and cucumber in a bowl.",
        "Lay the beef fillet over the top.",
        "Add the olive oil and lemon juice.",
        "Season with salt and serve.",
    ]),
    "Karadeniz Kuymak": ("Black Sea Kuymak", [
        "Melt the butter in a pan.",
        "Add the cornflour and toast for 3 minutes.",
        "Add the water a little at a time, stirring until it thickens.",
        "Add the cheese and serve once it pulls into strands.",
    ]),
    "Karamel Soslu Yoğurt": ("Yogurt with Caramel Sauce", [
        "Caramelise the sugar in a pan over medium heat.",
        "Add the butter, milk and salt and stir until smooth.",
        "Let the sauce cool.",
        "Drizzle it over the yogurt and serve.",
    ]),
    "Karides Stir-Fry ve Yasemin Pirinci": (
        "Shrimp Stir Fry with Jasmine Rice", [
            "Cook the rice for 12 minutes according to the packet.",
            "Sauté the shrimp with the garlic and ginger for 2 minutes.",
            "Add the vegetables and toss over high heat for 3 minutes.",
            "Add the soy sauce and sesame oil and cook for 1 minute more.",
            "Spoon over the rice and serve.",
        ]),
    "Karışık Zeytin ve Peynir Tabağı": ("Mixed Olive and Cheese Plate", [
        "Arrange the olives on a plate.",
        "Set the beyaz peynir to one side.",
        "Scatter olive oil and oregano over the top.",
        "Serve.",
    ]),
    "Karpuzlu Beyaz Peynir": ("Watermelon with Beyaz Peynir", [
        "Arrange the watermelon cubes on a plate.",
        "Set the cubes of beyaz peynir to one side.",
        "Garnish with mint and serve.",
    ]),
    "Kaşar Peynirli Tava Tost": ("Kaşar Pan Toastie", [
        "Lay the kaşar cheese between the bread slices.",
        "Grease one side of the pan with butter.",
        "Cook in a covered pan for 3 minutes until both sides are golden.",
        "Serve with black pepper.",
    ]),
    "Kırmızı Mercimek Çorbası ve Tam Buğday Ekmeği": (
        "Red Lentil Soup with Wholemeal Bread", [
            "Fry the onion and garlic in the olive oil for 2 minutes.",
            "Add the grated carrot and cook for 2 minutes more.",
            "Add the lentils and vegetable stock and simmer over low heat "
            "for 20 minutes.",
            "Blend it smooth and season with cumin and salt.",
            "Serve hot with the bread.",
        ]),
    "Kıymalı Patates Yemeği": ("Beef and Potato Stew", [
        "Fry the ground beef in the olive oil for 4 minutes.",
        "Add the onion and potato and cook for 4 minutes more.",
        "Add the tomato paste and 150 ml of hot water.",
        "Cover, cook for 6 minutes, season with salt and serve.",
    ]),
    "Kıymalı Sade Makarna": ("Simple Pasta with Ground Beef", [
        "Boil the pasta in salted water and drain it.",
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the beef and cook for 4 minutes until it changes colour, "
        "then add the tomato paste.",
        "Toss the pasta through the sauce and serve.",
    ]),
    "Kıymalı Yüksek Protein Makarna": ("High-Protein Beef Pasta", [
        "Boil the pasta according to the packet.",
        "Fry the onion and garlic in the olive oil.",
        "Add the beef and cook until it changes colour.",
        "Add the tomato sauce and simmer over low heat for 10 minutes.",
        "Toss the pasta through the sauce, scatter parmesan and basil "
        "over and serve.",
    ]),
    "Kıymalı Yumurta Tava": ("Pan Eggs with Ground Beef", [
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the beef and cook for 4 minutes until it changes colour, "
        "then add the tomato paste.",
        "Crack the eggs over the top and season with salt.",
        "Cook for 4 minutes more until the eggs set.",
    ]),
    "Klasik Mercimek Çorbası": ("Classic Lentil Soup", [
        "Sauté the onion and carrot in the butter for 3 minutes.",
        "Add the lentils and 500 ml of water and bring to the boil.",
        "Blend it smooth and add the salt.",
        "Finish with chilli flakes and serve.",
    ]),
    "Kuru Kayısı Yulaflı Süt": ("Oats with Milk and Dried Apricots", [
        "Bring the oats and milk to the boil in a pan over medium heat.",
        "Add the apricots and cook for 4 minutes more.",
        "Transfer to a bowl and drizzle the honey over.",
        "Finish with cinnamon and serve hot.",
    ]),
    "Levrek Tava": ("Pan-Fried Sea Bass", [
        "Season the sea bass with salt and dust it in flour.",
        "Warm the olive oil in a pan.",
        "Fry the sea bass for 4 minutes until both sides are golden.",
        "Serve with lemon and parsley.",
    ]),
    "Limon Soslu Roka Salatası": ("Rocket Salad with Lemon Dressing", [
        "Put the rocket in a bowl.",
        "Whisk the lemon, olive oil and salt together.",
        "Drizzle the dressing over the rocket.",
        "Finish with walnuts and mint and serve.",
    ]),
    "Limon-Bal Yoğurt": ("Lemon Honey Yogurt", [
        "Add the lemon juice to the yogurt and whisk.",
        "Stir the honey through.",
        "Finish with grated lemon zest and serve.",
    ]),
    "Limonlu Bal Sıcak Süt": ("Hot Milk with Honey and Lemon", [
        "Warm the milk over medium heat without letting it boil.",
        "Add the honey and lemon juice.",
        "Stir and pour into a glass.",
        "Finish with cinnamon and serve hot.",
    ]),
    "Limonlu Yoğurt Bar": ("Frozen Lemon Yogurt Bars", [
        "Stir the lemon zest, juice and honey through the yogurt.",
        "Spread it into a flat dish.",
        "Scatter the granola over the top.",
        "Freeze for 5 minutes and serve as bars.",
    ]),
    "Lor Peynirli Bal Ekmek": ("Lor Cheese and Honey on Bread", [
        "Mash the lor cheese in a bowl with a fork.",
        "Add the honey and cinnamon and mix.",
        "Spread the mixture over the bread slices.",
        "Serve immediately.",
    ]),
    "Lor Peynirli Domates Tabağı": ("Tomato and Lor Cheese Plate", [
        "Arrange the tomato slices on a plate.",
        "Set the lor cheese in the middle.",
        "Add the olives and drizzle olive oil over.",
        "Serve with oregano and salt.",
    ]),
    "Mantarlı Sade Omlet": ("Simple Mushroom Omelette", [
        "Sauté the mushrooms in the butter for 3 minutes.",
        "Beat the eggs with the milk and add the seasoning.",
        "Pour the mixture over the mushrooms.",
        "Cook for 3 minutes until the eggs set.",
    ]),
    "Mantarlı Tavuk Sote": ("Chicken and Mushroom Sauté", [
        "Fry the chicken in the olive oil for 4 minutes.",
        "Add the onion and mushrooms and cook for 4 minutes more.",
        "Add the tomato paste and 50 ml of water.",
        "Cover, cook for 4 minutes, season with salt and serve.",
    ]),
    "Maydanozlu Sade Omlet": ("Simple Parsley Omelette", [
        "Beat the eggs with the milk and add the seasoning and parsley.",
        "Warm the olive oil in a pan.",
        "Pour the mixture in, drawing the set edges into the middle as "
        "they cook.",
        "Fold in half once the eggs have set and serve.",
    ]),
    "Maydanozlu Yumurta Salatası": ("Egg Salad with Parsley", [
        "Put the eggs in a bowl.",
        "Add the yogurt, vinegar, olive oil and salt and mix.",
        "Fold the parsley through.",
        "Serve cold.",
    ]),
    "Menemen Klasik": ("Classic Menemen", [
        "Sauté the onion and pepper in the olive oil for 2 minutes.",
        "Add the grated tomato and cook for 4 minutes until the liquid "
        "reduces.",
        "Crack the eggs in without beating them and scatter the "
        "seasoning.",
        "Serve immediately once the eggs have set.",
    ]),
    "Mercimek Köftesi Wrap": ("Lentil Köfte Wrap", [
        "Warm the lavash lightly in a pan.",
        "Spread a layer of hummus over each one.",
        "Lay out the lettuce, tomato, onion and lentil köfte.",
        "Finish with parsley and lemon juice, roll tightly and serve.",
    ]),
    "Mercimekli Erişte": ("Erişte with Lentils", [
        "Boil the erişte in salted water and drain it.",
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the lentils and warm for 2 minutes, then fold in the "
        "erişte.",
        "Season with mint and serve.",
    ]),
    "Meyveli Süzme Yoğurt": ("Strained Yogurt with Fruit", [
        "Spread the yogurt over the base of a wide bowl.",
        "Arrange the fruit over the yogurt.",
        "Drizzle the honey in a thin ribbon.",
        "Scatter the oats over and serve immediately.",
    ]),
    "Meyveli Vegan Smoothie Kasesi": ("Vegan Fruit Smoothie Bowl", [
        "Blend the banana, blackberries, almond milk and protein powder "
        "until smooth.",
        "Transfer to a wide bowl.",
        "Scatter the chia seeds, granola and coconut over the top.",
        "Add more fresh fruit if you like and serve immediately.",
    ]),
    "Mikrodalgada Çikolatalı Kek": ("Microwave Chocolate Mug Cake", [
        "Mix all the ingredients in a mug.",
        "Work it into a smooth batter.",
        "Microwave at 800 W for 2 minutes.",
        "Rest for 1 minute and serve.",
    ]),
    "Mikrodalgada Tarçınlı Elma": ("Microwave Cinnamon Apple", [
        "Put the apple cubes in a microwave-safe bowl.",
        "Add the honey, cinnamon and butter.",
        "Cook at 800 W for 4 minutes.",
        "Stir and serve.",
    ]),
    "Mısır Gevrekli Süt": ("Corn Flakes with Milk", [
        "Put the corn flakes in a bowl.",
        "Pour the cold milk over.",
        "Add the banana slices and serve immediately.",
    ]),
    "Mücver Tava": ("Courgette Fritters", [
        "Squeeze the liquid out of the grated courgette.",
        "Knead it with the flour, egg, cheese and dill.",
        "Spoon the batter into an oiled pan and shape the fritters.",
        "Cook each side for 3 minutes and serve.",
    ]),
    "Muz-Tahin Sandviç": ("Banana Tahini Sandwich", [
        "Spread the tahini over the bread slices.",
        "Lay the banana slices on.",
        "Drizzle the grape molasses over.",
        "Close, cut in half and serve.",
    ]),
    "Muzlu Sıcak Yulaf Lapası": ("Hot Banana Porridge", [
        "Bring the oats and milk to the boil in a pan over medium heat.",
        "Stir for 3 minutes until it thickens.",
        "Transfer to a bowl and lay the banana on top.",
        "Finish with honey and cinnamon and serve hot.",
    ]),
    "Muzlu Vegan Dondurma": ("Vegan Banana Ice Cream", [
        "Blend the frozen banana slices until creamy.",
        "Add the cocoa powder and vanilla and blend for 15 seconds more.",
        "Transfer to a serving bowl.",
        "Scatter the desiccated coconut over and serve immediately.",
    ]),
    "Muzlu Yoğurt Tatlısı": ("Banana Yogurt Dessert", [
        "Spoon the yogurt into a bowl.",
        "Lay the banana slices on top.",
        "Add the honey and walnuts.",
        "Finish with cinnamon and serve cold.",
    ]),
    "Nohutlu Kinoa Buddha Kasesi": ("Chickpea Quinoa Buddha Bowl", [
        "Boil the quinoa and cool it.",
        "Make a dressing with the tahini, lemon juice and 2 tbsp of "
        "water.",
        "Layer the quinoa, chickpeas, carrot, cabbage and avocado in a "
        "bowl.",
        "Drizzle the tahini dressing over and serve.",
    ]),
    "Patates Çorbası": ("Potato Soup", [
        "Fry the onion and carrot in the butter for 2 minutes.",
        "Add the potato and water and simmer for 10 minutes.",
        "Blend it smooth.",
        "Season with salt and serve.",
    ]),
    "Patates Pofuduk": ("Fluffy Potato Cakes", [
        "Knead the potato, flour, egg, onion and salt together.",
        "Shape the mixture into small rounds.",
        "Cook each side for 4 minutes in a non-stick pan.",
        "Serve hot.",
    ]),
    "Pekmezli Hurma Pudingi": ("Date Pudding with Grape Molasses", [
        "Slake the rice flour with 50 ml of cold milk.",
        "Bring the remaining milk to the boil and add the dates.",
        "Add the rice flour mixture and stir for 6 minutes until it "
        "thickens.",
        "Divide between bowls and finish with grape molasses and "
        "walnuts.",
    ]),
    "Pekmezli Süt Tatlısı": ("Milk Pudding with Grape Molasses", [
        "Slake the cornstarch with 50 ml of cold milk.",
        "Bring the remaining milk to the boil in a pan, add the starch "
        "mixture and cook for 4 minutes until it thickens.",
        "Divide between bowls and drizzle the grape molasses over.",
        "Finish with walnuts and cinnamon.",
    ]),
    "Pekmezli Yoğurt Mousse": ("Yogurt Mousse with Grape Molasses", [
        "Add the sugar to the yogurt and whisk.",
        "Fold the grape molasses through.",
        "Marble it in the bowl.",
        "Finish with walnuts and serve cold.",
    ]),
    "Pırasa Köftesi": ("Leek Fritters", [
        "Squeeze the liquid out of the leek.",
        "Knead it with the flour, egg, cheese and salt.",
        "Spoon the batter into an oiled pan and shape the fritters.",
        "Cook each side for 3 minutes and serve.",
    ]),
    "Pırasalı Pilav": ("Leek Pilaf", [
        "Sauté the leek in the butter for 4 minutes.",
        "Add the rice with the olive oil and fry for 1 minute.",
        "Add 200 ml of hot water and the salt and cover.",
        "Cook over low heat for 12 minutes and serve with black pepper.",
    ]),
    "Pratik Aşure": ("Quick Aşure", [
        "Put all the ingredients in a pan with 200 ml of water.",
        "Add the sugar and simmer over medium heat for 8 minutes.",
        "Divide between bowls.",
        "Finish with cinnamon and serve once cooled.",
    ]),
    "Pratik İmam Bayıldı": ("Quick İmam Bayıldı", [
        "Fry the aubergines in the olive oil for 4 minutes and lift them "
        "out.",
        "Sauté the onion and garlic in the same pan for 3 minutes and add "
        "the tomato.",
        "Return the aubergines and cook for 4 minutes more.",
        "Garnish with parsley and serve.",
    ]),
    "Pratik Karnıyarık": ("Quick Karnıyarık", [
        "Fry the ground beef in the olive oil for 4 minutes.",
        "Add the onion and tomato paste and cook for 3 minutes more.",
        "Split the aubergines open and fill them with the mixture.",
        "Cook covered in 200 ml of hot water for 5 minutes and serve with "
        "parsley.",
    ]),
    "Pratik Muhallebi": ("Quick Muhallebi", [
        "Slake the rice flour with 50 ml of cold milk.",
        "Warm the remaining milk in a pan and add the sugar.",
        "Add the rice flour mixture and stir for 6 minutes until it "
        "thickens.",
        "Add the vanilla, divide between bowls and finish with cinnamon.",
    ]),
    "Pratik Nohut Yemeği": ("Quick Chickpea Stew", [
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the tomato paste and fry for 1 minute.",
        "Add the chickpeas and 200 ml of hot water and simmer for "
        "8 minutes.",
        "Season with cumin and salt and serve.",
    ]),
    "Pratik Patates Köftesi": ("Quick Potato Patties", [
        "Knead the potato, flour, egg and onion together.",
        "Shape the mixture into walnut-sized patties.",
        "Cook in an oiled pan for 5 minutes until golden all over.",
        "Serve hot.",
    ]),
    "Pratik Sütlaç": ("Quick Sütlaç", [
        "Bring the rice and milk to the boil in a pan over medium heat.",
        "Slake the rice flour with a little water and add it.",
        "Add the sugar and stir for 6 minutes until it thickens.",
        "Divide between bowls and finish with cinnamon.",
    ]),
    "Pratik Yoğurtlu Mantı": ("Quick Mantı with Yogurt", [
        "Boil the mantı in salted water according to the packet.",
        "Stir the garlic and salt through the yogurt.",
        "Melt the butter and bloom the chilli flakes in it.",
        "Plate the mantı and pour the yogurt and butter sauce over.",
    ]),
    "Pratik Yumurtalı Pişi": ("Quick Pişi with Egg", [
        "Cook the pişi dough in an oiled pan for 4 minutes until both "
        "sides are golden.",
        "Crack the eggs into the same pan and season with salt.",
        "Split the pişi open and fill it with the cheese and egg.",
        "Serve hot.",
    ]),
    "Pratik Yumurtalı Salata": ("Quick Egg Salad", [
        "Put the lettuce and tomato in a bowl.",
        "Lay the egg slices over the top.",
        "Add the olive oil, lemon and salt.",
        "Toss lightly and serve.",
    ]),
    "Protein Omlet & Avokado": ("Protein Omelette with Avocado", [
        "Beat the eggs.",
        "Add the spinach and cheese and make an omelette.",
        "Serve with sliced avocado alongside.",
    ]),
    "Protein Pankek Yığını": ("Protein Pancake Stack", [
        "Blend all the ingredients until smooth.",
        "Cook each pancake in a non-stick pan over medium heat for "
        "2 minutes a side.",
        "Stack the pancakes.",
        "Top with blueberries and honey and serve.",
    ]),
    "Reçelli Tam Buğday Tost": ("Wholemeal Toast with Jam", [
        "Toast the bread slices.",
        "Spread the butter on while they are hot.",
        "Spread the jam over and serve immediately.",
    ]),
    "Reçelli Yoğurt Kasesi": ("Yogurt Bowl with Jam", [
        "Spoon the yogurt into a bowl.",
        "Set the jam on top.",
        "Scatter the granola over and serve immediately.",
    ]),
    "Roka Salatası ve Izgara Tavuk": ("Rocket Salad with Grilled Chicken", [
        "Season the chicken with salt and black pepper.",
        "Cook each side for 4 minutes in a hot griddle pan.",
        "Arrange the rocket and tomato on a plate.",
        "Slice the chicken over the top and serve with olive oil and "
        "lemon.",
    ]),
    "Roka ve Ceviz Salatası": ("Rocket and Walnut Salad", [
        "Put the rocket in a bowl.",
        "Add the walnuts and cheese on top.",
        "Drizzle the olive oil and lemon over.",
        "Season with salt and serve.",
    ]),
    "Sade Bonfile Sote": ("Simple Beef Fillet Sauté", [
        "Fry the beef fillet in the olive oil for 4 minutes.",
        "Add the onion and cook for 2 minutes more.",
        "Add the tomato paste and fry for 1 minute.",
        "Season with salt and black pepper and serve.",
    ]),
    "Sade Bulgurlu Salata": ("Simple Bulgur Salad", [
        "Soak the bulgur in hot water for 10 minutes and drain it.",
        "Combine the vegetables and parsley in a bowl.",
        "Add the bulgur and toss with the olive oil.",
        "Season with salt and serve.",
    ]),
    "Sade Domates Salatası": ("Simple Tomato Salad", [
        "Combine the tomato and onion in a bowl.",
        "Add the olive oil and the seasoning.",
        "Toss lightly and serve.",
    ]),
    "Sade Hindi Etli Pilav": ("Simple Turkey Pilaf", [
        "Fry the turkey in the olive oil for 4 minutes, add the onion and "
        "cook for 2 minutes more.",
        "Fry the rice in the butter for 1 minute.",
        "Add 200 ml of hot water and the salt and cover.",
        "Cook over low heat for 12 minutes and let it rest.",
    ]),
    "Sade İncir Tatlısı": ("Simple Fig Dessert", [
        "Simmer the figs in the milk for 6 minutes.",
        "Lift the figs onto a plate.",
        "Reduce the milk for 2 minutes more and pour it over the figs.",
        "Finish with walnuts, honey and cinnamon and serve.",
    ]),
    "Sade Izgara Köfte": ("Simple Grilled Köfte", [
        "Knead the ground beef, onion and spices together.",
        "Shape the köfte.",
        "Grease a hot griddle pan with the olive oil.",
        "Cook each side for 4 minutes and serve.",
    ]),
    "Sade Köfte Tava": ("Simple Pan Köfte", [
        "Roll the köfte and toss them in the spices.",
        "Cook each side for 4 minutes in an oiled pan.",
        "Cover and rest for 2 minutes.",
        "Serve hot.",
    ]),
    "Sade Köy Ekmeği ve Tereyağı": ("Village Bread with Butter", [
        "Warm the bread slices lightly.",
        "Spread the butter on while they are hot.",
        "Scatter a pinch of salt over and serve.",
    ]),
    "Sade Mercimek Yemeği": ("Simple Lentil Stew", [
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the tomato paste and fry for 1 minute more.",
        "Add the lentils and 200 ml of water and simmer for 8 minutes.",
        "Season with cumin and salt.",
    ]),
    "Sade Mıhlama": ("Simple Mıhlama", [
        "Melt the butter in a pan, add the cornflour and toast for "
        "2 minutes.",
        "Add the water slowly, stirring constantly.",
        "Add the cheese and cook for 3 minutes more until it melts.",
        "Serve hot.",
    ]),
    "Sade Mısır Salatası": ("Simple Sweetcorn Salad", [
        "Combine the sweetcorn, pepper and onion in a bowl.",
        "Add the olive oil and lemon juice.",
        "Toss with salt.",
        "Serve cold.",
    ]),
    "Sade Pancar Salatası": ("Simple Beetroot Salad", [
        "Arrange the beetroot slices on a plate.",
        "Lay the onions over them.",
        "Drizzle the olive oil and lemon over.",
        "Serve with parsley and salt.",
    ]),
    "Sade Patates Püresi": ("Simple Mashed Potato", [
        "Boil the potatoes and drain them.",
        "Add the butter and milk.",
        "Mash until smooth.",
        "Serve with salt and black pepper.",
    ]),
    "Sade Patates Tavası": ("Simple Pan-Fried Potatoes", [
        "Fry the potatoes in an oiled pan for 8 minutes.",
        "Turn them and cook for 4 minutes more.",
        "Scatter salt, chilli flakes and oregano over.",
        "Serve hot.",
    ]),
    "Sade Pirinç Sütü Tatlısı": ("Simple Rice Milk Pudding", [
        "Bring the rice and milk to the boil in a pan over medium heat.",
        "Add the sugar and vanilla.",
        "Stir for 8 minutes until it thickens.",
        "Divide between bowls and finish with cinnamon.",
    ]),
    "Sade Sucuklu Krep": ("Simple Sucuk Crêpes", [
        "Whisk the eggs, flour, milk and salt together.",
        "Fry the sucuk slices in a pan for 1 minute and lift them out.",
        "Cook the crêpes in an oiled pan and lay the sucuk on top.",
        "Roll the crêpe up and serve.",
    ]),
    "Sade Süt Helvası": ("Simple Milk Halva", [
        "Toast the flour in the butter for 5 minutes until golden.",
        "Warm the milk and sugar in a separate pan and add them to the "
        "flour.",
        "Stir for 4 minutes until it thickens.",
        "Press into a mould, scatter walnuts over and serve.",
    ]),
    "Sade Tahin Mousse": ("Simple Tahini Mousse", [
        "Whisk the tahini into the yogurt.",
        "Fold the grape molasses through and marble it.",
        "Transfer to a bowl.",
        "Finish with walnuts and cinnamon and serve.",
    ]),
    "Sade Tahıl Bar": ("Simple Grain Bars", [
        "Combine all the ingredients in a bowl.",
        "Spread the mixture onto a flat dish and press it to 1 cm thick.",
        "Rest in the fridge for 5 minutes.",
        "Cut into bars and serve.",
    ]),
    "Sade Un Helvası": ("Simple Flour Halva", [
        "Toast the pine nuts in the butter for 1 minute.",
        "Add the flour and toast for 5 minutes until golden.",
        "Warm the water and sugar in a separate pan and stir them into "
        "the halva.",
        "Rest once it thickens, press into a mould and serve.",
    ]),
    "Sade Yumurtalı Ekmek": ("Simple Eggs with Bread", [
        "Melt the butter in a pan.",
        "Crack the eggs in and cook over medium heat for 3 minutes.",
        "Scatter the salt and black pepper.",
        "Serve with the bread.",
    ]),
    "Sade Yumurtalı Süt Tatlısı": ("Simple Egg Custard", [
        "Whisk the egg with the sugar and vanilla.",
        "Warm the milk and add it slowly to the egg mixture.",
        "Return it to the pan and stir over medium heat for 6 minutes "
        "until it thickens.",
        "Divide between bowls and finish with cinnamon.",
    ]),
    "Salam ve Sade Tabak": ("Salami Plate", [
        "Arrange the salami and cheese on a plate.",
        "Slice the tomato and set it to one side.",
        "Add the olives and put the slice of bread in the middle.",
        "Serve immediately.",
    ]),
    "Salatalık Sticks ve Yoğurt Sosu": ("Cucumber Sticks with Yogurt Dip", [
        "Stir the garlic, mint and salt through the yogurt.",
        "Arrange the cucumber sticks on a plate.",
        "Put the dip in the middle and serve immediately.",
    ]),
    "Salatalık ve Beyaz Peynir": ("Cucumber and Beyaz Peynir", [
        "Arrange the cucumber slices on a plate.",
        "Set the beyaz peynir to one side.",
        "Drizzle the olive oil over.",
        "Garnish with mint and serve.",
    ]),
    "Salçalı Tavada Yumurta": ("Pan Eggs in Tomato Paste Sauce", [
        "Fry the onion in the olive oil for 2 minutes.",
        "Add the tomato paste and 50 ml of water and cook for 2 minutes "
        "more.",
        "Crack the eggs over the top and scatter the seasoning.",
        "Cover, cook for 3 minutes and serve.",
    ]),
    "Salçalı Yumurtalı Köfte": ("Köfte and Eggs in Tomato Sauce", [
        "Roll the köfte into balls and fry them in a pan for 4 minutes.",
        "Add the onion and tomato paste and cook with 100 ml of water.",
        "Crack the eggs onto the sauce and season.",
        "Cover and cook for 3 minutes until the eggs set.",
    ]),
    "Sarımsaklı Cacık": ("Garlic Cacık", [
        "Drain the liquid from the cucumber.",
        "Stir the cucumber, garlic, cold water, mint and salt through the "
        "yogurt.",
        "Rest in the fridge for 5 minutes.",
        "Serve cold.",
    ]),
    "Sebzeli Bulgur Pilavı": ("Bulgur Pilaf with Vegetables", [
        "Sauté the vegetables in the olive oil for 3 minutes.",
        "Add the bulgur and fry for 1 minute.",
        "Add 200 ml of hot water and the salt and cover.",
        "Cook over low heat for 12 minutes and let it rest.",
    ]),
    "Sebzeli Ev Çorbası": ("Homestyle Vegetable Soup", [
        "Sauté the onion and garlic in the olive oil for 2 minutes until "
        "they colour.",
        "Add the diced carrot, courgette and celery and fry for "
        "3 minutes more.",
        "Add the vegetable stock and cook over low heat for 20 minutes.",
        "Add the thyme, salt and black pepper and serve hot.",
    ]),
    "Sebzeli Mercimek Çorbası": ("Lentil Soup with Vegetables", [
        "Fry the onion and garlic in the olive oil for 2 minutes.",
        "Add the diced carrot and courgette and cook for 3 minutes.",
        "Add the lentils and vegetable stock and simmer over low heat for "
        "25 minutes.",
        "Blend it smooth, season with cumin and salt and serve hot.",
    ]),
    "Sebzeli Pratik Köfte": ("Quick Vegetable Köfte", [
        "Knead the köfte mix and the vegetables together.",
        "Shape into balls and cook in the olive oil for 6 minutes.",
        "Turn them and cook for 4 minutes more.",
        "Serve hot.",
    ]),
    "Şehriye Çorbası Yumurtalı": ("Orzo Soup with Egg", [
        "Toast the orzo in the butter for 1 minute.",
        "Add 600 ml of water and simmer for 8 minutes.",
        "Beat the egg with the lemon juice and add it to the soup in a "
        "thin stream, stirring constantly.",
        "Season with salt and mint and serve.",
    ]),
    "Şekersiz Çikolatalı Yoğurt Mousse": (
        "Sugar-Free Chocolate Yogurt Mousse", [
            "Whisk the cocoa and protein powder into the yogurt.",
            "Fold the banana through.",
            "Transfer to a bowl.",
            "Finish with cinnamon and serve cold.",
        ]),
    "Şerbetli Yulaf Topları": ("Syrup-Soaked Oat Balls", [
        "Make a light syrup with the water and sugar and let it cool to "
        "warm.",
        "Knead the oats, tahini and honey together.",
        "Roll into balls and dip them in the syrup.",
        "Coat in desiccated coconut and serve.",
    ]),
    "Soğan-Domates Çorbası": ("Onion and Tomato Soup", [
        "Fry the onions in the butter for 5 minutes until caramelised.",
        "Add the tomatoes and water and simmer for 7 minutes.",
        "Add the salt and divide between bowls.",
        "Set the croutons on top and serve.",
    ]),
    "Soğanlı Etli Sote": ("Beef Sauté with Onions", [
        "Fry the beef in the olive oil for 4 minutes.",
        "Add the onions and cook for 5 minutes more until caramelised.",
        "Add the tomato paste, chilli flakes and 50 ml of water.",
        "Cover, cook for 4 minutes, season with salt and serve.",
    ]),
    "Soğanlı Hızlı Tavuk Sote": ("Quick Chicken Sauté with Onions", [
        "Fry the onions in the olive oil for 4 minutes until "
        "caramelised.",
        "Add the chicken and cook for 5 minutes until it is no longer "
        "pink.",
        "Add the tomato paste and 50 ml of hot water.",
        "Cover, cook for 5 minutes more and serve.",
    ]),
    "Soğanlı Köfte": ("Köfte with Onions", [
        "Roll the köfte into balls and fry them in a pan for 4 minutes.",
        "Add the onions and cook for 4 minutes more until caramelised.",
        "Add the tomato paste and 100 ml of water and simmer for "
        "4 minutes.",
        "Season with cumin and salt and serve.",
    ]),
    "Soğanlı Marul Salatası": ("Lettuce and Onion Salad", [
        "Gather the lettuce, onion and tomato in a bowl.",
        "Add the olive oil, lemon and salt.",
        "Toss lightly and serve.",
    ]),
    "Soğanlı Patates Kavurma": ("Fried Potatoes with Onion", [
        "Cook the potatoes in the olive oil over medium heat for "
        "8 minutes.",
        "Add the onion and fry for 3 minutes more, stirring.",
        "Scatter the salt and chilli flakes.",
        "Serve hot.",
    ]),
    "Soğuk Tavuk Göğsü Dilimleri": ("Cold Sliced Chicken Breast", [
        "Arrange the chicken slices on a plate.",
        "Set the peppers to one side.",
        "Drizzle the olive oil and lemon juice over.",
        "Serve with salt and parsley.",
    ]),
    "Sucuklu Sade Patates": ("Simple Potatoes with Sucuk", [
        "Fry the potatoes in the olive oil for 7 minutes.",
        "Add the sucuk slices and cook for 2 minutes more.",
        "Add the onion and fry for 3 minutes.",
        "Serve with salt and chilli flakes.",
    ]),
    "Sucuklu Yumurtalı Bulgur": ("Bulgur with Sucuk and Egg", [
        "Chop the onion and fry it in the olive oil, add the sucuk slices "
        "and fry for 1 minute more.",
        "Add the bulgur and stir, then pour in 180 ml of hot water and "
        "the salt.",
        "Cover and cook for 12 minutes, take it off the heat and let it "
        "steam for 5 minutes.",
        "Set the quickly fried eggs on top and serve with black pepper.",
    ]),
    "Sütlü Yulaf Ezmesi": ("Oats with Milk", [
        "Bring the oats and milk to the boil in a pan over medium heat.",
        "Cook for 4 minutes more, stirring as it thickens.",
        "Transfer to a bowl and add the honey and cinnamon.",
        "Serve hot.",
    ]),
    "Süzme Peynir ve Böğürtlen": ("Cottage Cheese with Blackberries", [
        "Spoon the cottage cheese into a bowl.",
        "Scatter the blackberries over it.",
        "Drizzle the honey in a thin ribbon.",
        "Scatter the flaked almonds over and serve immediately.",
    ]),
    "Süzme Peynirli Avokado": ("Avocado with Cottage Cheese", [
        "Hollow out the avocado around the stone.",
        "Fill the hollow with the cottage cheese.",
        "Drizzle the lemon and olive oil over.",
        "Serve with salt and mint.",
    ]),
    "Süzme Peynirli Tost": ("Cottage Cheese Toastie", [
        "Spread the cottage cheese over the inner faces of the bread.",
        "Add the tomato and mint and season with salt.",
        "Grease the pan with butter.",
        "Cook in a covered pan for 3 minutes until both sides are "
        "golden.",
    ]),
    "Süzme Yoğurtlu Beyaz Peynir Tabağı": (
        "Strained Yogurt and Beyaz Peynir Plate", [
            "Spoon the yogurt into a bowl.",
            "Set the beyaz peynir to one side.",
            "Add the walnuts and honey.",
            "Finish with cinnamon and serve.",
        ]),
    "Süzme Yoğurtlu Çilek Kasesi": ("Strained Yogurt Strawberry Bowl", [
        "Spoon the yogurt into a bowl.",
        "Lay the strawberries on top.",
        "Scatter the granola.",
        "Drizzle the honey and serve cold.",
    ]),
    "Süzme Yoğurtlu Frozen Bar": ("Frozen Strained Yogurt Bars", [
        "Mix the yogurt, strawberries and honey together.",
        "Spread it into a flat dish 1 cm thick.",
        "Scatter the granola over the top.",
        "Freeze for 5 minutes, cut into bars and serve.",
    ]),
    "Süzme Yoğurtlu Meyve Parfe": ("Strained Yogurt Fruit Parfait", [
        "Put a layer of strained yogurt in the bottom of a tall glass.",
        "Add a layer of granola.",
        "Scatter the strawberries and raspberries.",
        "Repeat the layers, drizzle a ribbon of honey on top and serve.",
    ]),
    "Süzme Yoğurtlu Protein Kasesi": ("Strained Yogurt Protein Bowl", [
        "Stir the protein powder through the strained yogurt until "
        "smooth.",
        "Spread the mixture over the base of a wide bowl.",
        "Arrange the fruit, almonds and chia seeds on top.",
        "Drizzle a thin ribbon of honey over last and serve immediately.",
    ]),
    "Süzme Yoğurtlu Protein Smoothie": (
        "Strained Yogurt Protein Smoothie", [
            "Put all the ingredients in a blender.",
            "Blend on high for 60 seconds until smooth.",
            "Pour into a tall glass.",
            "Drink immediately.",
        ]),
    "Süzme Yoğurtlu Yer Fıstığı": ("Strained Yogurt with Peanuts", [
        "Spoon the yogurt into a bowl.",
        "Lay the peanuts on top.",
        "Drizzle the honey over.",
        "Scatter cinnamon and serve.",
    ]),
    "Tahin Pekmez Ekmek": ("Tahini and Grape Molasses on Bread", [
        "Warm the bread slices lightly.",
        "Mix the tahini and grape molasses in a bowl until smooth.",
        "Spread the mixture over the bread slices.",
        "Scatter cinnamon over and serve immediately.",
    ]),
    "Tahin Soslu Havuç Sticks": ("Carrot Sticks with Tahini Dip", [
        "Mix the tahini, grape molasses and water until smooth.",
        "Cut the carrots into fingers.",
        "Arrange them on a plate and set the dip beside them in a bowl.",
        "Serve immediately.",
    ]),
    "Tahin Soslu Marul Salatası": ("Lettuce Salad with Tahini Dressing", [
        "Whisk the tahini, lemon, water, garlic and salt together.",
        "Stir until the dressing is smooth.",
        "Put the lettuce in a bowl.",
        "Drizzle the dressing over, toss and serve.",
    ]),
    "Tahin-Pekmez Topları": ("Tahini and Grape Molasses Balls", [
        "Knead the oats, tahini and grape molasses together.",
        "Rest the mixture for 1 minute.",
        "Roll into walnut-sized balls and coat them in desiccated "
        "coconut.",
        "Chill for 5 minutes and serve.",
    ]),
    "Tahinli Sade Yoğurt": ("Simple Yogurt with Tahini", [
        "Spoon the yogurt into a bowl.",
        "Spread the tahini and honey over it.",
        "Finish with cinnamon and serve.",
    ]),
    "Tarçınlı Süzme Yoğurt": ("Cinnamon Strained Yogurt", [
        "Spoon the yogurt into a bowl.",
        "Add the honey and walnuts on top.",
        "Finish with cinnamon and serve cold.",
    ]),
    "Tarçınlı Yulaf Tatlısı": ("Cinnamon Oat Dessert", [
        "Bring the oats and milk to the boil in a pan over medium heat.",
        "Add the cinnamon and cook for 3 minutes more.",
        "Transfer to a bowl and drizzle the honey over.",
        "Finish with walnuts and serve hot.",
    ]),
    "Tarçınlı Yumurta Tostu": ("Cinnamon Egg Toast", [
        "Whisk the eggs, milk and cinnamon together.",
        "Dip the bread slices in the mixture.",
        "Fry in the butter for 2 minutes until both sides are golden.",
        "Drizzle the honey over and serve.",
    ]),
    "Tava Pırasası Yumurtalı": ("Pan-Fried Leek with Eggs", [
        "Fry the onion and leek in the olive oil for 5 minutes.",
        "Add 50 ml of water, cover and cook for 4 minutes.",
        "Crack the eggs over the top and season.",
        "Serve once the eggs have set.",
    ]),
    "Tavada Karnabahar Köftesi": ("Pan-Fried Cauliflower Patties", [
        "Knead the cauliflower, flour, egg, onion and salt together.",
        "Shape the mixture into walnut-sized patties.",
        "Cook each side for 4 minutes in an oiled pan.",
        "Drain on kitchen paper and serve.",
    ]),
    "Tavada Sade Sebze Atıştırmalığı": ("Simple Pan-Fried Vegetables", [
        "Fry the aubergine slices in the olive oil for 4 minutes.",
        "Add the courgette and pepper and sauté for 4 minutes more.",
        "Scatter the salt and oregano.",
        "Serve hot.",
    ]),
    "Tavuk Göğsü Marul Sarma": ("Chicken Lettuce Wraps", [
        "Whisk the tahini, soy sauce and lemon juice thoroughly in a "
        "bowl.",
        "Toss the chicken, carrot and onion through the dressing.",
        "Put 2 tbsp of the mixture on each lettuce leaf.",
        "Roll the leaves up and serve immediately.",
    ]),
    "Tavuk Göğsü Salatası": ("Chicken Breast Salad", [
        "Combine the lettuce, tomato and cucumber in a bowl.",
        "Lay the chicken over the top.",
        "Dress with the olive oil, lemon juice and salt.",
        "Serve immediately.",
    ]),
    "Tavuk Göğsü Tava": ("Pan-Fried Chicken Breast", [
        "Flatten the chicken breast and marinate it with the spices, "
        "garlic and lemon for 5 minutes.",
        "Cook each side for 3 minutes in a hot pan with the olive oil.",
        "Cover and rest for 2 minutes.",
        "Serve hot.",
    ]),
    "Tavuk Göğsülü Sade Sandviç": ("Simple Chicken Sandwich", [
        "Spread the yogurt over the inner faces of the bread.",
        "Lay out the lettuce, tomato and chicken.",
        "Season with salt and close it.",
        "Cut in half and serve.",
    ]),
    "Tavuk Şinitzel": ("Chicken Schnitzel", [
        "Flatten the chicken fillet and season it with salt and black "
        "pepper.",
        "Coat it in egg, then in breadcrumbs.",
        "Fry each side for 4 minutes in an oiled pan.",
        "Drain on kitchen paper and serve.",
    ]),
    "Tavuk Şiş": ("Chicken Şiş", [
        "Marinate the chicken with the olive oil, garlic and salt for "
        "5 minutes.",
        "Thread the chicken, pepper and onion onto skewers.",
        "Cook each side for 3 minutes in a hot griddle pan.",
        "Serve hot.",
    ]),
    "Tavuk Sote ve Pilav": ("Chicken Sauté with Pilaf", [
        "Cook the rice in a pan with 200 ml of hot water for 12 minutes, "
        "without butter.",
        "In the same time, fry the chicken in the olive oil for "
        "4 minutes.",
        "Add the onion and tomato paste and cook for 4 minutes more.",
        "Plate the pilaf, spoon the sauté over it and serve.",
    ]),
    "Tavuk Suyu Pirinç Çorbası": ("Chicken and Rice Soup", [
        "Rinse the rice, add it to the chicken stock and simmer for "
        "12 minutes.",
        "Beat the egg with the lemon juice and add it slowly to the "
        "soup.",
        "Add the butter while it is still hot.",
        "Season with salt and serve.",
    ]),
    "Tavuk-Patates Tencere": ("Chicken and Potato Pot", [
        "Fry the chicken in the olive oil for 4 minutes.",
        "Add the onion and potato and cook for 3 minutes more.",
        "Add the tomato paste and 200 ml of hot water.",
        "Cover and cook for 8 minutes.",
    ]),
    "Tavuklu Bulgur Pilavı": ("Chicken Bulgur Pilaf", [
        "Fry the chicken in the butter for 4 minutes.",
        "Add the onion and cook for 2 minutes more.",
        "Add the bulgur and fry for 1 minute, then add 200 ml of hot "
        "water and the spices.",
        "Cover, cook for 10 minutes and let it rest.",
    ]),
    "Tavuklu Bulgur Salatası": ("Chicken Bulgur Salad", [
        "Soak the bulgur in hot water for 10 minutes and drain it.",
        "Combine the chicken, vegetables and bulgur in a bowl.",
        "Add the olive oil and lemon juice and toss.",
        "Season with salt and serve cold.",
    ]),
    "Tavuklu Erişte Çorbası": ("Chicken Erişte Soup", [
        "Put the chicken stock in a pan, add the carrot and simmer for "
        "4 minutes.",
        "Add the erişte and cook for 6 minutes more.",
        "Add the chicken pieces and warm for 2 minutes.",
        "Season with butter and salt and serve.",
    ]),
    "Tavuklu Karnabahar Sote": ("Chicken and Cauliflower Sauté", [
        "Fry the chicken in the olive oil for 4 minutes.",
        "Add the onion and cauliflower and sauté for 4 minutes.",
        "Add the tomato paste and 100 ml of water.",
        "Cover, cook for 6 minutes, season with salt and serve.",
    ]),
    "Tavuklu Karnıyarık": ("Chicken Karnıyarık", [
        "Fry the ground chicken in the olive oil for 4 minutes.",
        "Add the onion and tomato paste and cook for 3 minutes more.",
        "Split the aubergines open and fill them with the mixture.",
        "Cook covered in 200 ml of hot water for 5 minutes.",
    ]),
    "Tavuklu Mantar Sote": ("Chicken and Mushroom Sauté", [
        "Fry the chicken in the olive oil for 4 minutes.",
        "Add the onion and mushrooms and sauté for 4 minutes.",
        "Add the tomato paste and 50 ml of water.",
        "Cover, cook for 4 minutes, season with salt and serve.",
    ]),
    "Tavuklu Patates Salatası": ("Chicken and Potato Salad", [
        "Gather the potato, chicken and onion in a bowl.",
        "Add the yogurt and salt and mix.",
        "Garnish with parsley.",
        "Serve cold.",
    ]),
    "Tavuklu Sebze Çorbası": ("Chicken and Vegetable Soup", [
        "Add the onion, carrot and potato to the chicken stock and simmer "
        "for 8 minutes.",
        "Add the chicken and cook for 4 minutes more.",
        "Season with salt.",
        "Divide between bowls and serve.",
    ]),
    "Tavuklu Yulaflı Wrap": ("Chicken and Oat Wrap", [
        "Cook the oats to a porridge with a little water and cool them.",
        "Warm the lavash lightly in a pan.",
        "Layer the hummus, oat porridge, chicken, avocado and cheese in "
        "turn.",
        "Add the vegetables, roll tightly, cut in two and serve.",
    ]),
    "Taze Fasulye Etli": ("Beef and Green Bean Stew", [
        "Fry the beef in the olive oil for 4 minutes.",
        "Add the onion and tomato paste and cook for 2 minutes more.",
        "Add the beans and 150 ml of hot water.",
        "Cover, cook for 8 minutes, season with salt and serve.",
    ]),
    "Tencerede Patates Köftesi": ("Potato Köfte in a Pot", [
        "Roll the köfte into balls and fry them in the olive oil for "
        "4 minutes.",
        "Add the potato and onion and cook for 3 minutes more.",
        "Add the tomato paste and 200 ml of hot water.",
        "Cover and cook for 8 minutes.",
    ]),
    "Tencerede Sebzeli Yumurta": ("Pot Eggs with Vegetables", [
        "Fry the potatoes in the olive oil for 6 minutes.",
        "Add the pepper and tomato and cook for 3 minutes more.",
        "Crack the eggs over the top and season.",
        "Cover, cook for 2 minutes and serve.",
    ]),
    "Tencerede Tavuk Sote": ("Chicken Sauté in a Pot", [
        "Chop the onion and pepper small and sauté them in the olive oil "
        "for 2 minutes.",
        "Add the diced chicken and fry for 4 minutes until sealed all "
        "over.",
        "Add the tomato paste, the spices and 100 ml of hot water and "
        "stir.",
        "Cover and cook over low heat for 8 minutes.",
    ]),
    "Tereyağlı Bal Ekmek": ("Bread with Butter and Honey", [
        "Toast the bread slices lightly.",
        "Spread the butter on while they are hot.",
        "Drizzle the honey over and serve.",
    ]),
    "Tereyağlı Limonlu Makarna": ("Butter and Lemon Pasta", [
        "Boil the pasta in salted water and drain it.",
        "Melt the butter in the same pan.",
        "Add the lemon juice and zest and stir.",
        "Return the pasta, season and serve.",
    ]),
    "Tofu Soteli Kahverengi Pirinç": ("Tofu Stir Fry with Brown Rice", [
        "Cook the brown rice for 25 minutes.",
        "Cube the tofu and fry it in the sesame oil until every side is "
        "golden.",
        "Add the vegetables and garlic to the pan and toss over high heat "
        "for 4 minutes.",
        "Add the soy sauce and ginger and cook for 2 minutes more.",
        "Spoon it and its sauce over the rice and serve.",
    ]),
    "Ton Balıklı Makarna Salatası": ("Tuna Pasta Salad", [
        "Combine the pasta, tuna and vegetables in a bowl.",
        "Add the olive oil and lemon juice.",
        "Season with salt and black pepper.",
        "Serve immediately.",
    ]),
    "Türlü Sebze Etli": ("Mixed Vegetable and Beef Stew", [
        "Fry the ground beef in the olive oil for 4 minutes.",
        "Add the potato and cook for 3 minutes more, then add the tomato "
        "paste.",
        "Add the aubergine and courgette with 150 ml of hot water.",
        "Cover, cook for 6 minutes, season with salt and serve.",
    ]),
    "Üzümlü Yulaf": ("Oats with Raisins", [
        "Bring the oats, milk and raisins to the boil in a pan.",
        "Cook for 4 minutes until it thickens.",
        "Transfer to a bowl.",
        "Finish with honey and cinnamon and serve.",
    ]),
    "Vejetaryen Quinoa Power Bowl": ("Vegetarian Quinoa Power Bowl", [
        "Boil the quinoa in plenty of water for 15 minutes and drain it.",
        "Whisk the tahini, lemon juice and 2 tbsp of water into a "
        "dressing.",
        "Arrange the quinoa, chickpeas, carrot, cabbage and avocado in a "
        "bowl.",
        "Drizzle the tahini dressing over and serve with parsley.",
    ]),
    "Yoğurtlu Bulgur Pilavı": ("Bulgur Pilaf with Yogurt", [
        "Chop the onion small and fry it in the butter for 2 minutes.",
        "Add the bulgur and fry for 1 minute more, then add 200 ml of hot "
        "water and the salt.",
        "Cover and cook over low heat for 12 minutes, take it off the "
        "heat and let it steam for 5 minutes.",
        "Plate the pilaf, set the yogurt beside it and scatter dried mint "
        "over the top.",
    ]),
    "Yoğurtlu Çikolata Mousse": ("Chocolate Yogurt Mousse", [
        "Sift the cocoa into the yogurt and whisk.",
        "Fold the honey through.",
        "Transfer to a bowl and scatter the chocolate over.",
        "Finish with cinnamon and serve cold.",
    ]),
    "Yoğurtlu Çilek Mousse": ("Strawberry Yogurt Mousse", [
        "Crush the strawberries with the sugar into a purée.",
        "Fold the honey and strawberry purée into the yogurt.",
        "Divide between bowls.",
        "Garnish with a whole strawberry and serve cold.",
    ]),
    "Yoğurtlu Granola Parfe": ("Yogurt Granola Parfait", [
        "Stir the vanilla extract through the yogurt.",
        "Put a layer of yogurt in the bottom of a tall glass.",
        "Add granola and strawberries and repeat the layers.",
        "Drizzle honey on top and serve immediately.",
    ]),
    "Yoğurtlu Havuç Atıştırması": ("Carrot and Yogurt Snack", [
        "Sauté the carrots in the olive oil for 3 minutes.",
        "Cool them and stir them into the yogurt.",
        "Mix in the garlic, salt and parsley.",
        "Serve cold.",
    ]),
    "Yoğurtlu Karnabahar Salatası": ("Cauliflower Yogurt Salad", [
        "Combine the cauliflower and yogurt in a bowl.",
        "Add the garlic and salt and mix.",
        "Garnish with parsley.",
        "Drizzle olive oil over and serve cold.",
    ]),
    "Yoğurtlu Mercimek Çorbası": ("Lentil Soup with Yogurt", [
        "Simmer the lentils in 400 ml of water for 6 minutes and blend "
        "smooth.",
        "Stir the garlic and salt through the yogurt.",
        "Divide the soup between bowls and spoon the yogurt into the "
        "middle.",
        "Bloom the chilli flakes in the butter and drizzle it over.",
    ]),
    "Yoğurtlu Pancar Salatası": ("Beetroot Yogurt Salad", [
        "Combine the beetroot and yogurt in a bowl.",
        "Add the garlic and salt.",
        "Drizzle olive oil over.",
        "Garnish with walnuts and serve.",
    ]),
    "Yoğurtlu Patates Salatası": ("Potato Yogurt Salad", [
        "Add the garlic, salt and olive oil to the yogurt and mix.",
        "Fold the potato through.",
        "Garnish with parsley.",
        "Serve cold.",
    ]),
    "Yoğurtlu Patlıcan Ezmesi": ("Aubergine and Yogurt Dip", [
        "Peel the roasted aubergine and mash it.",
        "Add the yogurt, garlic and salt and mix.",
        "Drizzle the olive oil over.",
        "Garnish with parsley and serve.",
    ]),
    "Yoğurtlu Pirinç Çorbası": ("Rice Soup with Yogurt", [
        "Add the rice to the water and simmer for 12 minutes.",
        "Stir the egg into the yogurt and add it to the soup in a thin "
        "stream.",
        "Melt the butter and bloom the mint in it.",
        "Drizzle it over the soup and serve.",
    ]),
    "Yoğurtlu Pirinç Salatası": ("Rice Salad with Yogurt", [
        "Combine the rice, cucumber and onion in a bowl.",
        "Add the yogurt and olive oil.",
        "Season with salt and toss with the parsley.",
        "Serve cold.",
    ]),
    "Yoğurtlu Sade Tavuk Sote": ("Simple Chicken Sauté with Yogurt", [
        "Fry the chicken in the olive oil for 5 minutes.",
        "Add the garlic and fry for 1 minute.",
        "Add 50 ml of hot water for a sauce, cover and cook for "
        "5 minutes.",
        "Stir the yogurt in after taking it off the heat and serve.",
    ]),
    "Yoğurtlu Salatalık Atıştırması": ("Cucumber Yogurt Snack", [
        "Grate the cucumber and drain it lightly.",
        "Add the crushed garlic, salt and mint to the yogurt and mix.",
        "Fold the cucumber into the yogurt.",
        "Drizzle olive oil over and serve.",
    ]),
    "Yoğurtlu Tavuk Sandviç": ("Chicken Sandwich with Yogurt", [
        "Spread the yogurt over the inner faces of the bread.",
        "Lay out the lettuce, tomato and chicken.",
        "Season with salt and close it.",
        "Cut in half and serve.",
    ]),
    "Yoğurtlu Yumurta Salatası": ("Egg Salad with Yogurt", [
        "Mash the boiled eggs with a fork.",
        "Add the strained yogurt, the seasoning and the parsley and mix.",
        "Transfer to a plate and scatter a little more parsley over if "
        "you like.",
        "Serve cold.",
    ]),
    "Yüksek Protein Cheesecake Isırıkları": (
        "High-Protein Cheesecake Bites", [
            "Press the oats and coconut oil into the base of a mini "
            "muffin tin.",
            "Blend the cottage cheese, yogurt, protein powder and honey "
            "until smooth.",
            "Spoon the mixture into the tin.",
            "Rest in the fridge for 30 minutes.",
            "Set a slice of strawberry on each bite and serve.",
        ]),
    "Yüksek Proteinli Çikolatalı Puding (Sporcu Tatlısı)": (
        "High-Protein Chocolate Pudding", [
            "Blend the protein powder, avocado and almond milk together.",
            "Chill in the fridge.",
        ]),
    "Yüksek Proteinli Yoğurt Mousse": ("High-Protein Yogurt Mousse", [
        "Whisk the protein powder into the yogurt.",
        "Fold the honey through to a thick mousse.",
        "Transfer to a bowl and scatter the granola.",
        "Finish with cinnamon and serve cold.",
    ]),
    "Yulaflı Çikolata Cookie": ("Oat Chocolate Cookies", [
        "Knead all the ingredients together in a bowl.",
        "Spoon cookie shapes onto non-stick baking paper.",
        "Bake at 180°C for 10 minutes (or 3 minutes a side in a pan).",
        "Serve once cooled.",
    ]),
    "Yulaflı Muzlu Cookie": ("Oat Banana Cookies", [
        "Mix all the ingredients in a bowl.",
        "Spoon onto non-stick baking paper.",
        "Bake at 180°C for 10 minutes (or 4 minutes on one side in a "
        "pan).",
        "Serve once cooled.",
    ]),
    "Yulaflı Süt Çorbası": ("Oat Milk Soup", [
        "Bring the milk and oats to the boil in a pan.",
        "Add the butter and cook for 4 minutes more.",
        "Transfer to a bowl and drizzle the honey over.",
        "Finish with cinnamon and serve hot.",
    ]),
    "Yulaflı Tarçınlı Smoothie": ("Oat and Cinnamon Smoothie", [
        "Put all the ingredients in a blender.",
        "Blend for 60 seconds until smooth.",
        "Pour into a glass.",
        "Scatter a little cinnamon over and drink.",
    ]),
    "Yumurta Akı Omleti ve Hindi Eti": (
        "Egg White Omelette with Turkey", [
            "Beat the egg whites with the whole egg and add the salt and "
            "black pepper.",
            "Sauté the turkey in a non-stick pan for 1 minute.",
            "Add the egg mixture and cook over medium heat until the "
            "edges set.",
            "Scatter the pepper and parsley, fold the omelette in half "
            "and serve.",
        ]),
    "Yumurta Akı ve Sebze Tabağı": ("Egg White and Vegetable Plate", [
        "Cook the egg whites in a non-stick pan over medium heat for "
        "4 minutes.",
        "Plate them and arrange the tomato and cucumber alongside.",
        "Scatter the salt and mint.",
        "Drizzle olive oil over and serve.",
    ]),
    "Yumurta-Avokado Tabağı": ("Egg and Avocado Plate", [
        "Peel the eggs and cut them in half.",
        "Arrange the avocado slices and olives on a plate.",
        "Add the eggs and drizzle olive oil over.",
        "Serve with a slice of bread and mint.",
    ]),
    "Yumurta-Peynirli Sandviç": ("Egg and Cheese Sandwich", [
        "Crumble the cheese and spread it over the inner faces of the "
        "bread.",
        "Lay out the egg slices and tomato.",
        "Add the lettuce leaf and close it.",
        "Season with salt and serve.",
    ]),
    "Yumurtalı Domates Sandviç": ("Egg and Tomato Sandwich", [
        "Brush the inner faces of the bread with olive oil.",
        "Lay out the egg and tomato.",
        "Season with salt and garnish with mint.",
        "Close, cut in half and serve.",
    ]),
    "Yumurtalı Erişte": ("Erişte with Egg", [
        "Boil the erişte in salted water for 8 minutes and drain it.",
        "Fry the onion in the butter for 2 minutes.",
        "Crack the eggs in and cook them, stirring, with the onion.",
        "Fold in the erişte, season and serve.",
    ]),
    "Yumurtalı Patates Salatası": ("Potato and Egg Salad", [
        "Gather the potato, egg and onion in a bowl.",
        "Add the yogurt and olive oil and toss lightly.",
        "Add the salt and garnish with parsley.",
        "Serve cold.",
    ]),
    "Yumurtalı Patates Tava": ("Pan-Fried Potatoes with Eggs", [
        "Fry the potatoes in the olive oil for 7 minutes.",
        "Add the onion and cook for 2 minutes more.",
        "Crack the eggs over the top and scatter the seasoning.",
        "Cook for 3 minutes until the eggs set.",
    ]),
    "Yumurtalı Peynirli Roll": ("Egg and Cheese Roll", [
        "Lay the lavash out flat and spread the cheese over it.",
        "Lay out the egg slices and parsley.",
        "Add the olive oil and salt.",
        "Roll it tightly, cut in half and serve.",
    ]),
    "Yumurtalı Sade Krep": ("Simple Egg Crêpes", [
        "Whisk the eggs, flour and milk until smooth.",
        "Pour a little batter into an oiled pan and cook the crêpes.",
        "Fry each side for 1 minute.",
        "Plate, roll up and serve.",
    ]),
    "Yumurtalı Sebze Sote": ("Vegetable Sauté with Eggs", [
        "Fry the aubergine in the olive oil for 4 minutes.",
        "Add the pepper and tomato and cook for 3 minutes more.",
        "Crack the eggs over the top and season with salt.",
        "Cook for 2 minutes until the eggs set and serve.",
    ]),
    "Yumurtalı Sucuklu Tava": ("Sucuk and Eggs", [
        "Fry the sucuk slices in a pan over medium heat for 1 minute.",
        "Crack the eggs over them and scatter the salt and black pepper.",
        "Cook for 3-4 minutes without stirring.",
        "Serve with wholemeal bread.",
    ]),
    "Yumurtalı Tarhana Çorbası": ("Tarhana Soup with Egg", [
        "Slake the tarhana with 100 ml of cold water and bring the rest "
        "of the water to the boil.",
        "Add the loosened tarhana to the boiling water and simmer for "
        "8 minutes.",
        "Beat the egg and add it to the soup in a thin stream, stirring "
        "constantly.",
        "Bloom the chilli flakes in the butter and drizzle it over.",
    ]),
}
