-- Roadmap Phase 7 · the one recipe that is not shaped like the others.
--
-- 291 of the 292 authored rows store their instructions as
--
--     MALZEMELER:
--     - …
--
--     HAZIRLANIŞI:
--     1. …
--
-- Three do not, and all three are among the oldest seed rows:
--
--   * `Izgara Somon & Tatlı Patates` and `Protein Omlet & Avokado` use
--     the header `YAPILIŞ:` instead of `HAZIRLANIŞI:`. The parser reads
--     both — a spelling variant is not a broken row, and rewriting the
--     content to suit the tool would be the wrong way round.
--
--   * `Yüksek Proteinli Çikolatalı Puding` has no structure at all. It
--     is one sentence:
--
--         1 ölçek çikolatalı protein tozu, yarım avokado ve biraz badem
--         sütünü blenderdan geçirin. Dolapta soğutun.
--
-- That last one is fixed here, by hand, before the parser runs — which
-- is the order the plan asks for. A parser bent to tolerate a single
-- malformed row is a parser that will silently mis-read the next one.
--
-- NOTHING IS INVENTED
--
-- Every amount below is the author's own. "yarım avokado" becomes 1/2
-- avokado because that is what the word means. "biraz badem sütü" keeps
-- the word "biraz" as its note rather than acquiring a millilitre count,
-- because the author did not state one and a shopping list is better
-- with a gap in it than with a number nobody wrote.

update public.recipes
set instructions = 'MALZEMELER:
- 1 ölçek çikolatalı protein tozu
- 1/2 avokado
- Badem sütü (biraz)

HAZIRLANIŞI:
1. Protein tozu, avokado ve badem sütünü blenderdan geçirin.
2. Dolapta soğutun.'
where id = '3d7181e0-2292-41b0-ad95-ffb2aeef7b64'
  and instructions not like '%MALZEMELER:%';
