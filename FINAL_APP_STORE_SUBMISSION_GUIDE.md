# FormAI — Final App Store Submission Guide

The last checklist before **"Submit for Review."** Work top to bottom; every
engineering box is already checked. Companion detail: `FOUNDER_MASTER_GUIDE.md`
(accounts/dashboards), `docs/ios/CODEMAGIC_SETUP.md` (pipeline),
`docs/store/APP_STORE_ANSWERS.md` (form answers).

---

## 0. One-time accounts (if not done)
- [ ] Apple Developer Program active ($99/yr, individual OK)
- [ ] **Paid Applications agreement ACTIVE** (banking+tax — takes days; start first)
- [ ] Codemagic account (GitHub sign-in, free tier suffices)

## 1. Build & upload (Mac-free, ~30 min)
- [ ] App ID `com.emredogan.formai` with **Sign in with Apple** + App Group `group.app.formai.shared`
- [ ] ASC app record (name **FormAI**, TR primary) → copy numeric Apple ID into `codemagic.yaml` (`APP_STORE_APPLE_ID`)
- [ ] ASC API key (App Manager) → Codemagic integration named **exactly** `FormAI ASC API Key`
- [ ] Codemagic env group `formai_ios_env` with the client-public keys (list in CODEMAGIC_SETUP §4; **never** OPENAI/ANTHROPIC/service-role — the guard fails the build)
- [ ] Run workflow **FormAI iOS → TestFlight** → green → build appears in ASC
- Note: Live Activities/widget intentionally absent in v1 (plist keys removed); add extension in v1.1.

## 2. App Store Connect forms
- [ ] **App Privacy** labels — exactly per `docs/store/APP_STORE_ANSWERS.md` §2 (linked: email, user id, fitness completion, purchases; opt-in analytics/crash; **tracking: none**; body metrics/camera frames NOT collected — on-device)
- [ ] **Age rating** questionnaire — fitness guidance, no medical/treatment claims; if an AI-content question appears: AI chat is coaching-scoped with medical guardrails + human-support contact; answer honestly per the live form
- [ ] Subscription group "FormAI Pro": `formai_pro_monthly` / `formai_pro_3month` / `formai_pro_annual`, TR prices, localized names WITHOUT price text, **attached to the first version submission**
- [ ] Privacy Policy URL `https://d2srybp77lgcpy.cloudfront.net/privacy.html`; Terms in description/EULA field
- [ ] Export compliance: plist already declares exempt → confirm questionnaire

## 3. Review access (reject-proofing)
- [ ] Reviewer account: sign up `reviewer@…` in the app → Supabase SQL: `update auth.users set raw_app_meta_data = raw_app_meta_data || '{"role":"reviewer"}' where email='…';` (unlocks Pro, no purchase)
- [ ] Review notes — paste from `docs/store/APP_STORE_ANSWERS.md` §6 (on-device camera analysis explanation + "person 2-3 m in frame" + guest mode note)
- [ ] Demo video (60-90 s, unlisted): dashboard → workout start → camera permission → live rep counting + voice → complete → link in notes
- [ ] Screenshots: current UI (post-RC-1 onboarding + coach), 6.9-inch set; regenerate via device captures + `tool/format_play_store_assets.py`

## 4. TestFlight (the "iPhone appears" moment)
- [ ] Internal testing: add yourself + testers (≤100, instant)
- [ ] **Tester guide** — paste into TestFlight "What to Test":
  > FormAI'ye hoş geldin! 🎉 Test etmeni istediklerimiz:
  > 1) Tanışma akışını bitir (Form ile sohbet gerçek AI — adınla cevap verir).
  > 2) Dashboard'da Form kartından koça bir şey sor (ör. "bugün ne yapmalıyım?").
  > 3) Bir antrenman başlat, kamerayı 2-3 m uzağa koy, tüm vücudun kadrajda olsun — tekrar sayımını ve sesli koçu izle.
  > 4) Beslenme sekmesini gez; hedefini ve tarifleri gör.
  > 5) Uygulamayı kapatıp aç — koç seni hatırlıyor mu?
  > Sorun görürsen ekran görüntüsüyle bildir: support@formai.app
- [ ] Known issues to declare: Live Activity/widget yok (v1.1); Google ile giriş iOS'ta ilk sürümde kapalı olabilir (SIWA + e-posta çalışır); koç yanıtları çevrimdışıyken kural-tabanlı moda düşer (tasarım gereği)
- [ ] External TestFlight (optional wider beta): needs Beta App Review (~1 day)

## 5. Final sanity before Submit
- [ ] Fresh install on a real iPhone: onboarding end-to-end, LLM greeting lands, camera flow, purchase sandbox → restore → cancel
- [ ] Anthropic console: spend limit set (coach runs on your key)
- [ ] Supabase: project ACTIVE (free tier pauses after ~1 week idle — consider Pro before launch); custom SMTP if inviting many testers
- [ ] `support@formai.app` monitored
- [ ] Version/build number matches ASC; release option = **manual**

## 6. Submit
- [ ] Add reviewer notes + demo link → **Submit for Review**
- [ ] Play Store mirror: the same checklist's Android half is already live in `FOUNDER_MASTER_GUIDE.md` §6 (internal → closed 12×14 gün → production)

*Everything in this list is founder-side by nature (accounts, money, hardware).
The repository, pipeline, store answer packs, tester materials, and the app
itself are release-candidate complete.*
