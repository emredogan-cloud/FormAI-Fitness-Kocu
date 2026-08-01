# Subscription pricing — what the app does, and what only you can do

**Phase 6 polish, item 7.** Written 2026-08-01 against build `1.0.0+28`.

This is the founder-side half of paywall pricing. The engineering half is
done and described in §5; everything in §2–§4 happens in Play Console and
RevenueCat, and no app release can substitute for it.

---

## 1. Read this first: app language is not billing country

This is the fact that explains almost every "the price is wrong" report,
and it is worth being certain about before changing anything.

**Google Play bills in the country of the user's Play account.** Not the
phone's language, not the app's language, not the SIM. A Turkish user who
switches FormAI to English still sees `₺` — because their Play account is
Turkish, and that is the currency Google will actually charge them. The
app is behaving correctly in that case, and any change that made it show
`$` there would be showing a price we cannot collect.

So "English users see Turkish prices" splits into two very different
situations:

| What you saw | What it means | Fix |
| --- | --- | --- |
| A **Turkish** Play account, app set to English, shows `₺` | Correct. This is the price they will be charged. | Nothing. |
| A **US** Play account shows a strange USD number like `$4.37` | Play auto-converted your `₺` price. No US price was ever set. | §2 — set US prices explicitly. |

The second is almost certainly what is happening, because the products
were created with Turkish pricing and Google's "auto-conversion"
suggestion accepted for everywhere else (`docs/MONETIZATION_LAUNCH_GUIDE.md`
§E.2). Auto-conversion produces an exchange-rate number, not a price you
chose — which is why nothing in the store matches your target.

To actually see USD yourself you need a Play account whose country is the
US. Changing the phone's language will not do it, and Google only permits
a country change once per year with a local payment method.

---

## 2. The pricing decision — **DECIDED 2026-08-01**

**Approved USD ladder. This is what to create in Play Console:**

| Plan | USD | per month | Play product ID |
| --- | --- | --- | --- |
| Weekly | **$3.99** | $17.29 | `formai_pro_weekly` |
| Monthly | **$9.99** | $9.99 | `formai_pro_monthly` |
| Yearly | **$49.99** — *Most Popular* | $4.17 | `formai_pro_annual` |

**Turkish pricing is unchanged** — ₺100 / ₺400 / ₺1200. It was already
correctly ordered (₺433 > ₺400 > ₺100 per month) and there is no
technical reason to move it. Play bills in the Play account's country, so
a Turkish account keeps seeing ₺ regardless of app language; §1 explains
why that is correct rather than a bug.

**Yearly carries the "Most Popular" badge**, which the paywall already
renders on the annual card. Nothing in the app is compiled with a price —
`price_format.dart` reads the store's own strings — so this decision
needs no app release, only the Play Console and RevenueCat steps in §3
and §4.

The reasoning that produced it is kept below, because the next person to
touch a price needs to know why $2 was rejected.

---

### Why $2/week was wrong

Your original target, and what it works out to per month:

| Plan | USD | per month | TRY | per month |
| --- | --- | --- | --- | --- |
| Weekly | $2 | **$8.67** | ₺100 | ₺433 |
| Monthly | $10 | $10.00 | ₺400 | ₺400 |
| Yearly | $50 | $4.17 | ₺1200 | ₺100 |

**The USD ladder is inverted.** At $2/week the weekly plan costs $8.67 a
month — *less* than the $10 monthly plan, and $104 a year against the
monthly plan's $120. A US user who does the arithmetic buys weekly and
never buys monthly, so the monthly tier earns nothing and the weekly tier
earns less than it should. In TRY the same ladder is correct: ₺433 > ₺400
> ₺100, monthly is genuinely cheaper than weekly, and yearly is cheapest.

The cause is that $2 ≈ ₺80 at a realistic rate but $10 ≈ ₺400, so the
weekly tier is priced for Turkey and the monthly tier for the US.

**$3.99 weekly is what fixed it.** That is $17.29/month — comfortably
above the $9.99 monthly plan — and it keeps every tier's ordering
intact:

| Plan | USD | per month | vs yearly |
| --- | --- | --- | --- |
| Weekly | $3.99 | $17.29 | 4.1× |
| Monthly | $9.99 | $9.99 | 2.4× |
| Yearly | $49.99 | $4.17 | — |

$2.99 also works ($12.96/mo) if $3.99 feels steep for a weekly impulse
buy. Anything at or below $2.30 re-inverts the ladder.

The app side renders whatever the store says — no number is compiled into
anything. A Play base plan's price can be changed later; its billing
period and product ID cannot, which is why the decision came first.

Two smaller notes, both now folded into the approved ladder above:

- **`.00` prices convert badly**, which is why the approved ladder says
  `$9.99 / $49.99` rather than `$10 / $50`. `$10.00` in a market that
  expects `$9.99` reads as a rounding error; Google's price templates
  default to charm pricing for a reason. Same money, measurably better
  conversion.
- **The yearly plan already carries a 7-day free trial** (offer
  `freetrial7d`, guide §E.4). You said "no trial" only for weekly, so I
  have left yearly's alone. Say if you want it gone.

---

## 3. Play Console — the exact changes

### 3.1 Reprice the three existing products

**Monetize → Products → Subscriptions →** each product **→** base plan
**→ Pricing → Manage prices.**

| Product | Base plan | Turkey | United States |
| --- | --- | --- | --- |
| `formai_pro_monthly` | `monthly` | ₺149 → **₺400** | auto → **$9.99** |
| `formai_pro_yearly` | `annual` | ₺799 → **₺1200** | auto → **$49.99** |
| `formai_pro_quarterly` | `quarterly` | ₺299 → leave, or retire (§3.3) | — |

For every other country, use **"Set prices automatically"** *seeded from
the US price*, not the Turkish one. Seeding from ₺ is what produced the
current strange USD number; seeding from $ gives every market a sensible
converted price, which you can then override individually.

**Price-increase rules, which apply to the Turkish repricing:**

- New subscribers pay the new price from the moment you activate it.
- **Existing** subscribers do not. ₺149 → ₺400 is a large increase, and
  Google requires either explicit opt-in or a regional opt-out flow with
  advance notice. Expect roughly 30 days before existing subscribers move
  over, and expect some to churn at the notification.
- Price *decreases* apply to everyone immediately, no consent needed.

If you have closed-test subscribers on ₺149, this is worth doing before
the open launch rather than after.

### 3.2 Create the weekly product

**Monetize → Products → Subscriptions → Create subscription.**

- **Product ID:** `formai_pro_weekly` — permanent, never editable.
- **Name:** `FormAI Premium — Haftalık`
- **Description:** `7 günlük FormAI Premium üyeliği. Tüm AI antrenman
  planları, beslenme önerileri ve gelişmiş analizler.`

Then **Add base plan:**

- **Base plan ID:** `weekly`
- **Type:** `Auto-renewing`
- **Billing period:** `1 week` — permanent, never editable.
- **Grace period:** `3 days`. The 7-day grace used on the longer plans is
  longer than the billing period itself, which Play will reject.
- **Account hold:** `30 days`
- **Resubscribe:** Enabled
- **Pricing:** Türkiye ₺100 · United States your §2 decision · everywhere
  else auto-converted from the US price.
- **Offers:** none. You asked for no trial, so do not add one.

**Activate** the base plan, then **Activate** the product.

> The name says **Premium**, not Pro. Every user-visible surface was
> renamed in this sprint; the RevenueCat *entitlement id* stays the
> literal `FormAI Pro` because it is matched against the dashboard and
> never rendered. See `docs/i18n/GLOSSARY.md`.

### 3.3 Optional: retire the quarterly plan

Your target lineup is weekly / monthly / yearly — three tiers, and the
paywall shows three cards. Once the weekly SKU is live the app stops
showing quarterly automatically (§5), so nothing breaks if you leave it
alone. But an active-and-invisible product will confuse you in six
months. When you are confident in the new lineup, **deactivate**
`formai_pro_quarterly`. Existing quarterly subscribers keep their
subscription and keep renewing; deactivation only stops new purchases.

Do not delete it. Deletion is irreversible and the product ID is gone
forever.

---

## 4. RevenueCat — one package to add

**Products →** the weekly product should appear automatically once Play
has it; if not, **+ New → Google Play →** `formai_pro_weekly:weekly`.

1. Open the product row → **Attached entitlements** → add **`FormAI
   Pro`** (exact string, capital F, capital A-I, space, capital P). This
   is the single most common thing to get wrong: a product with no
   entitlement takes the user's money and unlocks nothing.
2. **Offerings → `default` → + Add Package.**
   - **Identifier:** `$rc_weekly`
   - **Product:** `formai_pro_weekly`
3. Confirm `default` is still the **current** offering.

The app reads `Purchases.getOfferings().current` and asks it for its
`weekly` package. `$rc_weekly` is the identifier RevenueCat maps to that
slot; a custom identifier will not be found.

---

## 5. What the app already does — no release needed

Committed this sprint, `1.0.0+28`:

- **Every price on the paywall is `StoreProduct.priceString`, verbatim.**
  Nothing is compiled in, nothing is converted client-side, and there is
  a test asserting the retired hardcoded fallbacks (₺249,99 / ₺999,99 /
  ₺499,99) can never render again. Whatever you set in Play is what a
  user sees, in their own currency and their own number format.

- **The third plan card follows the store.** It shows the quarterly plan
  today and switches to the weekly plan the moment `$rc_weekly` appears
  in the current offering. **This needs no app update** — finish §3.2 and
  §4, and the next cold start of any installed build picks it up. If you
  later pull the weekly package, it reverts.

- **The savings badge and strikethrough are derived from live prices.**
  At your target the annual card will read "**58% off**" in the US and
  "**%75 İNDİRİM**" in Turkey, over a struck-through `$120.00` / `₺4.800,00`
  monthly-equivalent. Both are computed from the store's own monthly
  price at render time, so they cannot drift from what you charge, and
  they disappear entirely if the numbers ever stop supporting the claim.

- **The strikethrough now uses the store's number system.** It previously
  hardcoded Turkish separators, so a US user saw `$9.99` on one card and
  `$119,88` struck through on the next — same screen, two number systems.
  Separators are now read off the store's own string, so every market is
  correct by construction. `lib/core/utils/price_format.dart`,
  `test/core/utils/price_format_test.dart`.

- **The weekly card carries no savings framing**, deliberately. Weekly
  costs more per month than monthly does, so any "save N%" on that card
  would be false in the one direction store policy actually polices.

- **Trial copy only appears when the SKU carries a real free trial**
  (intro price == 0), read from the store. The weekly plan having no
  offer means no trial promise renders on it — automatically, not
  because anything was configured to hide it.

---

## 6. How to verify you got it right

In order. Each step catches a different failure.

1. **RevenueCat → Offerings → `default`** lists four packages and shows
   a real price beside each. A package showing "product not found" means
   Play has not finished propagating — it can take a few hours after
   activation.
2. **RevenueCat → Products → `formai_pro_weekly`** shows `FormAI Pro`
   under attached entitlements. If this is empty, a purchase will
   succeed and unlock nothing.
3. **On the device**, open the paywall. The third card reads **1 Hafta**
   with your weekly price. If it still reads **3 Ay**, the app has a
   cached offering — force-stop and reopen; RevenueCat caches offerings
   for 5 minutes.
4. **Buy the weekly plan with a licence-tester account.** Play Console →
   Setup → Licence testing. Test purchases are free and renew every few
   minutes, so you also get to watch a renewal.
5. **Check the entitlement flipped**: the profile tab shows the Premium
   badge and the locked features open.
6. **Cancel from Play → Subscriptions**, and confirm the app returns to
   the free state at the end of the (accelerated) period.

---

## 7. Still open

- **Your §2 decision on the USD weekly price.** Everything else in this
  document can be done without it; the weekly SKU cannot.
- **iOS.** App Store Connect needs the same four products under the same
  RevenueCat entitlement before an iOS release. Apple additionally
  scrutinises weekly subscriptions under Guideline 3.1.2 — the paywall
  copy should make the weekly plan's value legible as a short commitment
  rather than a cheaper drip. Not blocking Android.
