"""Roadmap Phase 7 §6 · the ingredient glossary, Turkish → English.

    python3 tool/recipe_pipeline/translations/ingredients_en.py > out.sql

Every distinct `recipe_ingredients.name_tr` in the authored catalogue,
translated once. 297 entries covering 1,642 rows — this is the leverage
in the whole translation pass, because an ingredient list repeats and a
method step does not.

## The rules, from §6.2 of the plan

**Quantities and units are not here.** They are separate columns and this
file cannot reach them, which is the entire reason migration 014 split
them out. A translator handed "50g sucuk" can return "2 oz sucuk"; a
translator handed "sucuk" cannot.

**A proper noun stays, and gets a note.** `sucuk` is `sucuk` in English —
it is a proper noun like chorizo — with a `note_en` that says what to buy
instead. Translating it to "Turkish sausage" loses the dish and still
does not tell an American shopper what to pick up.

**Nothing is invented.** Where the Turkish is vague ("Birkaç yaprak taze
nane"), the English is equally vague ("a few fresh mint leaves"). Where
it is precise, so is the English.

## The `NOTE` column

Only for ingredients an English-speaking shopper cannot find or would not
recognise. Not a description of the obvious — "tomato" needs no note, and
a glossary full of them is a glossary nobody reads.
"""
import sys

# name_tr → (name_en, note_en or None)
GLOSSARY = {
    # ─── proper nouns that stay, with what to buy instead ────────────
    "sucuk": ("sucuk", "Turkish beef sausage; chorizo or any cured spiced "
                       "sausage works"),
    "sucuk dilimleri": ("sucuk slices", "Turkish beef sausage; chorizo "
                                        "works"),
    "pastırma": ("pastırma", "air-dried spiced beef; bresaola is the "
                             "closest substitute"),
    "tarhana": ("tarhana", "Turkish fermented soup base of wheat, yoghurt "
                           "and vegetables; sold dried"),
    "lor peyniri": ("lor cheese", "fresh Turkish whey cheese; ricotta is "
                                  "the closest substitute"),
    "beyaz peynir": ("beyaz peynir", "Turkish brined white cheese; feta "
                                     "works"),
    "az yağlı beyaz peynir": ("low-fat beyaz peynir", "Turkish brined "
                                                      "white cheese; "
                                                      "light feta works"),
    "light beyaz peynir": ("light beyaz peynir", "Turkish brined white "
                                                 "cheese; light feta "
                                                 "works"),
    "kaşar peyniri": ("kaşar cheese", "Turkish semi-hard yellow cheese; "
                                      "mild cheddar or gouda works"),
    "hellim peyniri": ("halloumi", None),
    "süzme yoğurt": ("strained yogurt", "Turkish süzme; Greek yogurt is "
                                        "the same thing"),
    "yağsız yoğurt": ("fat-free yogurt", None),
    "süzme peynir": ("cottage cheese", None),
    "yağsız süzme peynir": ("fat-free cottage cheese", None),
    "taze peynir": ("fresh cheese", None),
    "pekmez": ("grape molasses", "Turkish pekmez; date or pomegranate "
                                 "molasses substitute"),
    "nar ekşisi": ("pomegranate molasses", None),
    "bazlama": ("bazlama", "Turkish flatbread; pita or naan works"),
    "lavaş": ("lavash", "thin Turkish flatbread; a large tortilla works"),
    "tam buğday lavaş": ("wholemeal lavash", "thin flatbread; a wholemeal "
                                             "tortilla works"),
    "büyük tam buğday lavaş": ("large wholemeal lavash", "thin flatbread; "
                                                         "a large "
                                                         "wholemeal "
                                                         "tortilla works"),
    "köy ekmeği": ("village bread", "rustic sourdough-style loaf"),
    "pilavlık bulgur": ("coarse bulgur", None),
    "ince bulgur": ("fine bulgur", None),
    "hazır köfte harcı": ("köfte mix", "packet seasoning mix for Turkish "
                                       "meatballs"),
    "hazır çiğ köfte karışımı": ("çiğ köfte mix", "packet bulgur-and-spice "
                                                  "mix; no raw meat in the "
                                                  "modern version"),
    "ev yapımı mercimek köftesi": ("homemade lentil köfte", "Turkish "
                                                            "lentil-and-"
                                                            "bulgur patties"),
    "hazır pişmiş mantı": ("cooked mantı", "small Turkish meat dumplings; "
                                           "any small filled pasta works"),
    "hazır pişi hamuru": ("pişi dough", "Turkish fried-bread dough; any "
                                        "enriched bread dough works"),
    "önceden haşlanmış aşurelik buğday": ("cooked wheat berries", None),
    "irmik": ("semolina", None),
    "galeta unu": ("breadcrumbs", None),
    "tam buğday ekmek kırıntısı": ("wholemeal breadcrumbs", None),
    "arpa şehriye": ("orzo", None),
    "erişte": ("erişte", "Turkish egg noodles; tagliatelle works"),

    # ─── dairy and eggs ──────────────────────────────────────────────
    "süt": ("milk", None),
    "yağsız süt": ("skimmed milk", None),
    "az yağlı süt": ("semi-skimmed milk", None),
    "tereyağı": ("butter", None),
    "yoğurt": ("yogurt", None),
    "parmesan peyniri": ("parmesan cheese", None),
    "çedar peyniri": ("cheddar cheese", None),
    "yumurta": ("eggs", None),
    "bütün yumurta": ("whole egg", None),
    "yumurta akı": ("egg whites", None),
    "haşlanmış yumurta": ("boiled egg", None),
    "vanilyalı whey protein tozu": ("vanilla whey protein powder", None),
    "çikolatalı whey protein tozu": ("chocolate whey protein powder", None),
    "bitkisel protein tozu": ("plant protein powder", None),
    "vanilyalı protein tozu": ("vanilla protein powder", None),
    "çikolatalı protein tozu": ("chocolate protein powder", None),

    # ─── meat and fish ───────────────────────────────────────────────
    "tavuk göğsü": ("chicken breast", None),
    "tavuk göğsü fileto": ("chicken breast fillet", None),
    "tavuk göğsü kuşbaşı": ("diced chicken breast", None),
    "pişmiş tavuk göğsü": ("cooked chicken breast", None),
    "haşlanmış tavuk göğsü": ("poached chicken breast", None),
    "ızgara tavuk göğsü": ("grilled chicken breast", None),
    "tavuk fileto": ("chicken fillet", None),
    "tavuk pirzola": ("chicken cutlet", None),
    "tavuk kıyma": ("ground chicken", None),
    "tavuk suyu": ("chicken stock", None),
    "et suyu": ("beef stock", None),
    "sebze suyu": ("vegetable stock", None),
    "dana kıyma": ("ground beef", None),
    "yağsız dana kıyma": ("lean ground beef", None),
    "dana kuşbaşı": ("diced beef", None),
    "dana bonfile": ("beef fillet", None),
    "sığır bonfile": ("beef sirloin", None),
    "pişmiş bonfile": ("cooked beef fillet", None),
    "ızgara bonfile": ("grilled beef fillet", None),
    "hindi göğsü": ("turkey breast", None),
    "hindi göğsü fileto": ("turkey breast fillet", None),
    "dilimli hindi göğsü": ("sliced turkey breast", None),
    "pişmiş hindi göğsü": ("cooked turkey breast", None),
    "hindi kıyma": ("ground turkey", None),
    "hindi salam": ("turkey salami", None),
    "somon": ("salmon", None),
    "somon fileto": ("salmon fillet", None),
    "levrek fileto": ("sea bass fillet", None),
    "hamsi": ("anchovies", "fresh Black Sea anchovies; sardines work"),
    "ton balığı": ("tuna", None),
    "suyu süzülmüş ton balığı konservesi": ("drained canned tuna", None),
    "temizlenmiş karides": ("peeled shrimp", None),

    # ─── vegetables ──────────────────────────────────────────────────
    "kuru soğan": ("onion", None),
    "küçük kuru soğan": ("small onion", None),
    "büyük kuru soğan": ("large onion", None),
    "soğan": ("onion", None),
    "kırmızı soğan": ("red onion", None),
    "küçük mor soğan": ("small red onion", None),
    "yeşil soğan": ("spring onion", None),
    "sarımsak": ("garlic", None),
    "sarımsak, taze zencefil": ("garlic and fresh ginger", None),
    "domates": ("tomato", None),
    "olgun domates": ("ripe tomato", None),
    "büyük olgun domates": ("large ripe tomato", None),
    "cherry domates": ("cherry tomatoes", None),
    "kiraz domates": ("cherry tomatoes", None),
    "domates salçası": ("tomato paste", None),
    "şekersiz domates sosu": ("unsweetened passata", None),
    "salatalık": ("cucumber", None),
    "havuç": ("carrot", None),
    "küçük havuç": ("small carrot", None),
    "patates": ("potato", None),
    "haşlanmış patates": ("boiled potato", None),
    "orta boy patates": ("medium potato", None),
    "tatlı patates": ("sweet potato", None),
    "marul": ("lettuce", None),
    "marul yaprağı": ("lettuce leaf", None),
    "büyük marul yaprağı": ("large lettuce leaf", None),
    "iri marul yaprağı": ("large lettuce leaf", None),
    "büyük avuç marul": ("large handful of lettuce", None),
    "Marul, domates ve salatalık": ("lettuce, tomato and cucumber", None),
    "roka": ("rocket", "arugula"),
    "ıspanak": ("spinach", None),
    "Ispanak": ("spinach", None),
    "taze ıspanak": ("baby spinach", None),
    "taze ıspanak yaprağı": ("baby spinach leaves", None),
    "brokoli": ("broccoli", None),
    "küçük brokoli": ("small head of broccoli", None),
    "karnabahar": ("cauliflower", None),
    "pişmiş karnabahar": ("cooked cauliflower", None),
    "kabak": ("courgette", "zucchini"),
    "büyük kabak": ("large courgette", "zucchini"),
    "ızgara kabak": ("grilled courgette", "zucchini"),
    "patlıcan": ("aubergine", "eggplant"),
    "küçük patlıcan": ("small aubergine", "eggplant"),
    "közlenmiş patlıcan": ("roasted aubergine", "eggplant, charred over "
                                                "flame"),
    "yeşil biber": ("green pepper", None),
    "küçük yeşil biber": ("small green pepper", None),
    "yeşil sivri biber": ("long green pepper", "Turkish sivri; any mild "
                                               "long pepper works"),
    "kırmızı biber": ("red pepper", None),
    "ızgara kırmızı biber": ("roasted red pepper", None),
    "mantar": ("mushrooms", None),
    "mor lahana": ("red cabbage", None),
    "pişmiş pancar": ("cooked beetroot", None),
    "bezelye": ("peas", None),
    "taze fasulye": ("green beans", None),
    "haşlanmış kuru fasulye": ("cooked white beans", None),
    "kırmızı barbunya": ("kidney beans", None),
    "haşlanmış nohut": ("cooked chickpeas", None),
    "kırmızı mercimek": ("red lentils", None),
    "haşlanmış kırmızı mercimek": ("cooked red lentils", None),
    "küçük kavanoz haşlanmış kırmızı mercimek": ("small jar of cooked red "
                                                 "lentils", None),
    "büyük pırasa": ("large leek", None),
    "kereviz sapı": ("celery stick", None),
    "Kuşkonmaz": ("asparagus", None),
    "kuşkonmaz": ("asparagus", None),
    "mısır": ("sweetcorn", None),
    "mısır gevreği": ("corn flakes", None),
    "zeytin": ("olives", None),
    "avokado": ("avocado", None),
    "olgun avokado": ("ripe avocado", None),
    "katı tofu": ("firm tofu", None),
    "humus": ("hummus", None),
    "salsa sos": ("salsa", None),

    # ─── fruit ───────────────────────────────────────────────────────
    "muz": ("banana", None),
    "olgun muz": ("ripe banana", None),
    "dondurulmuş muz": ("frozen banana", None),
    "elma": ("apple", None),
    "orta boy elma": ("medium apple", None),
    "limon": ("lemon", None),
    "limon suyu": ("lemon juice", None),
    "limonun suyu": ("juice of one lemon", None),
    "limon kabuğu rendesi": ("grated lemon zest", None),
    "limonun kabuğu rendesi": ("grated zest of one lemon", None),
    "çilek": ("strawberries", None),
    "taze çilek": ("fresh strawberries", None),
    "yaban mersini": ("blueberries", None),
    "taze böğürtlen": ("fresh blackberries", None),
    "dondurulmuş karışık böğürtlen": ("frozen mixed berries", None),
    "ahududu": ("raspberries", None),
    "kuru üzüm": ("raisins", None),
    "hurma": ("dates", None),
    "hurma şurubu": ("date syrup", None),
    "kuru kayısı": ("dried apricots", None),
    "kuru incir": ("dried figs", None),
    "karpuz": ("watermelon", None),
    "kivi": ("kiwi", None),
    "meyve reçeli": ("fruit jam", None),
    "reçel": ("jam", None),

    # ─── nuts, seeds, fats ───────────────────────────────────────────
    "zeytinyağı": ("olive oil", None),
    "Zeytinyağı": ("olive oil", None),
    "sızma zeytinyağı": ("extra virgin olive oil", None),
    "ayçiçek yağı": ("sunflower oil", None),
    "susam yağı": ("sesame oil", None),
    "hindistancevizi yağı": ("coconut oil", None),
    "sıvı yağ": ("vegetable oil", None),
    "ceviz": ("walnuts", None),
    "ceviz içi": ("walnut halves", None),
    "çiğ ceviz": ("raw walnuts", None),
    "badem": ("almonds", None),
    "çiğ badem": ("raw almonds", None),
    "badem kırıkları": ("flaked almonds", None),
    "badem sütü": ("almond milk", None),
    "Badem sütü": ("almond milk", None),
    "şekersiz badem sütü": ("unsweetened almond milk", None),
    "yulaf sütü": ("oat milk", None),
    "hindistan cevizi sütü": ("coconut milk", None),
    "hindistan cevizi rendesi": ("desiccated coconut", None),
    "hindistancevizi rendesi": ("desiccated coconut", None),
    "toz hindistan cevizi": ("desiccated coconut", None),
    "çam fıstığı": ("pine nuts", None),
    "kavrulmuş yer fıstığı": ("roasted peanuts", None),
    "doğal fıstık ezmesi": ("natural peanut butter", None),
    "fıstık ezmesi": ("peanut butter", None),
    "tahin": ("tahini", None),
    "ayçekirdeği içi": ("sunflower seeds", None),
    "chia tohumu": ("chia seeds", None),

    # ─── grains and starches ─────────────────────────────────────────
    "yulaf ezmesi": ("rolled oats", None),
    "yulaf unu": ("oat flour", None),
    "granola": ("granola", None),
    "şekersiz granola": ("unsweetened granola", None),
    "pirinç": ("rice", None),
    "esmer pirinç": ("brown rice", None),
    "pişmiş pirinç": ("cooked rice", None),
    "yasemin pirinci": ("jasmine rice", None),
    "pirinç unu": ("rice flour", None),
    "mısır unu": ("cornflour", "cornstarch"),
    "un": ("flour", None),
    "tam buğday unu": ("wholemeal flour", None),
    "nişasta": ("cornstarch", None),
    "kinoa": ("quinoa", None),
    "kuskus": ("couscous", None),
    "makarna": ("pasta", None),
    "pişmiş makarna": ("cooked pasta", None),
    "tam buğday makarna": ("wholemeal pasta", None),
    "ekmek": ("bread", None),
    "tam buğday ekmeği": ("wholemeal bread", None),
    "tam buğday ekmek": ("wholemeal bread", None),
    "tam buğday kruton": ("wholemeal croutons", None),
    "büyük tam buğday tortilla": ("large wholemeal tortilla", None),
    "kabartma tozu": ("baking powder", None),
    "maya": ("yeast", None),

    # ─── seasonings, sweeteners, liquids ─────────────────────────────
    "Tuz": ("salt", None),
    "tuz": ("salt", None),
    "tuz ve karabiber": ("salt and black pepper", None),
    "Tuz ve karabiber": ("salt and black pepper", None),
    "Karabiber": ("black pepper", None),
    "karabiber": ("black pepper", None),
    "Tuz, karabiber": ("salt and black pepper", None),
    "Tuz, karabiber, pul biber": ("salt, black pepper and chilli flakes",
                                  None),
    "Tuz, karabiber, kekik": ("salt, black pepper and oregano", None),
    "Tuz, karabiber, kimyon": ("salt, black pepper and cumin", None),
    "Tuz, karabiber, sarımsak tozu": ("salt, black pepper and garlic "
                                      "powder", None),
    "Tuz, karabiber, taze dereotu": ("salt, black pepper and fresh dill",
                                     None),
    "Kekik, tuz, karabiber": ("oregano, salt and black pepper", None),
    "Kekik, kimyon, tuz, karabiber": ("oregano, cumin, salt and black "
                                      "pepper", None),
    "Kimyon, tuz, karabiber": ("cumin, salt and black pepper", None),
    "Kimyon, pul biber, tuz": ("cumin, chilli flakes and salt", None),
    "Biberiye, tuz, karabiber": ("rosemary, salt and black pepper", None),
    "Fesleğen, tuz, karabiber": ("basil, salt and black pepper", None),
    "Taze dereotu, tuz, karabiber": ("fresh dill, salt and black pepper",
                                     None),
    "Taze maydanoz, tuz, karabiber": ("fresh parsley, salt and black "
                                      "pepper", None),
    "Pul biber, tuz, karabiber": ("chilli flakes, salt and black pepper",
                                  None),
    "Pul biber": ("chilli flakes", None),
    "pul biber": ("chilli flakes", None),
    "kuru kekik": ("dried oregano", None),
    "taze kekik": ("fresh thyme", None),
    "taze kekik veya maydanoz": ("fresh thyme or parsley", None),
    "kuru nane": ("dried mint", None),
    "Birkaç yaprak taze nane": ("a few fresh mint leaves", None),
    "maydanoz": ("parsley", None),
    "Taze maydanoz": ("fresh parsley", None),
    "kıyılmış maydanoz": ("chopped parsley", None),
    "Birkaç dal taze maydanoz": ("a few sprigs of fresh parsley", None),
    "Bir tutam taze maydanoz": ("a pinch of fresh parsley", None),
    "Taze maydanoz, limon suyu": ("fresh parsley and lemon juice", None),
    "Birkaç dal taze dereotu": ("a few sprigs of fresh dill", None),
    "Taze dereotu": ("fresh dill", None),
    "taze biberiye": ("fresh rosemary", None),
    "kimyon": ("cumin", None),
    "tarçın": ("cinnamon", None),
    "Tarçın": ("cinnamon", None),
    "çimdik tarçın": ("a pinch of cinnamon", None),
    "muskat": ("nutmeg", None),
    "Zencefil rende": ("grated ginger", None),
    "vanilya": ("vanilla", None),
    "vanilya özütü": ("vanilla extract", None),
    "kakao": ("cocoa", None),
    "kakao tozu": ("cocoa powder", None),
    "şekersiz kakao": ("unsweetened cocoa", None),
    "şekersiz kakao tozu": ("unsweetened cocoa powder", None),
    "bitter çikolata": ("dark chocolate", None),
    "bitter çikolata parçacığı": ("dark chocolate chips", None),
    "toz şeker": ("sugar", None),
    "bal": ("honey", None),
    "bal veya akçaağaç şurubu": ("honey or maple syrup", None),
    "akçaağaç şurubu": ("maple syrup", None),
    "hardal": ("mustard", None),
    "dijon hardalı": ("dijon mustard", None),
    "sirke": ("vinegar", None),
    "beyaz sirke": ("white vinegar", None),
    "az tuzlu soya sosu": ("low-salt soy sauce", None),
    "soya sosu": ("soy sauce", None),
    "su": ("water", None),
    "soğuk su": ("cold water", None),
    "ılık su": ("lukewarm water", None),
    "buz": ("ice", None),
}


def main():
    out = [
        "-- Roadmap Phase 7 · English ingredient names.",
        "-- Generated by tool/recipe_pipeline/translations/ingredients_en.py",
        "-- Do not hand-edit; change the glossary and re-run.",
        "--",
        "-- Quantities and units are NOT touched. They are separate columns,",
        "-- which is what migration 014 split them out for.",
        "",
        "begin;",
        "",
    ]
    for name_tr, (name_en, note_en) in sorted(GLOSSARY.items()):
        tr = name_tr.replace("'", "''")
        en = name_en.replace("'", "''")
        note = "null" if note_en is None else "'%s'" % note_en.replace("'", "''")
        out.append(
            "update public.recipe_ingredients set name_en = '%s', "
            "note_en = coalesce(note_en, %s) where name_tr = '%s';"
            % (en, note, tr)
        )
    out += ["", "commit;", ""]
    print("\n".join(out))
    print(f"-- {len(GLOSSARY)} ingredients", file=sys.stderr)


if __name__ == "__main__":
    main()
