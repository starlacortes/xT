# byTime — Monetization, Rename & Beta Strategy

> **Superseded naming (October 2026):** the byTime rename proposed here was dropped. The product is **Isocline**; see `docs/design/BRANDING_AND_POSITIONING.html` and `docs/design/ISOCLINE_DESIGN_SYSTEM.html`. Read "byTime" below as "Isocline". The subscription, nonprofit and TestFlight guidance still stands. The byTime landing page is archived at `docs/design/archive/LANDING_PAGE_SKETCH.html`.

**Prepared for:** Starla Cortes
**Date:** August 2026
**Companion to:** `BUSINESS_AND_LAUNCH_PLAN.md`

---

## 0. Read this first: the name has a conflict

Before you invest in the byTime name, you should know what's already out there:

- **ByTime – Date Stamp** — an existing iOS app (App Store ID 1480229682), a photo date-stamping tool
- **ByTime: Time Hub** — another existing iOS app (ID 6747457512), a screen-time/attention app
- **bytimeapp.com** — already registered and in use
- There's also a `bytime` GitHub org already taken

None of these are in health or HRT, so a trademark conflict is unlikely to be fatal — trademark protection is generally scoped by category, and "hormone therapy tracker" is a very different market from "photo date stamp." But three practical problems remain regardless of the legal question:

1. **App Store search.** Someone searching "byTime" gets three apps. You'd be competing for your own brand name against two incumbents with a head start on ranking.
2. **The obvious domain is gone.** You'd be on bytime.app, getbytime.com, bytimehrt.com, or similar — all workable, none ideal.
3. **The name doesn't say what it does.** "xT" at least gestured at testosterone/hormones. "byTime" is abstract, and abstract names cost more to market because you have to teach people what they mean. That's an expensive tax for a solo founder with no ad budget.

**My honest read:** the concept behind byTime is good — time is genuinely the core of the product (pharmacokinetics is literally hormone levels as a function of time), and it's warmer and less clinical than xT. But if you're renaming anyway, this is the one cheap moment to pick something with a clear runway. Worth considering a name that's unclaimed in the App Store, has an available domain, and hints at the actual function. If you love byTime, use it — just go in knowing the tradeoff, and check the domain and App Store name reservation before you print anything.

I built the landing page with byTime as you asked. Changing the name in it later is a find-and-replace, so nothing is locked in.

Sources: [ByTime – Date Stamp](https://apps.apple.com/us/app/bytime-date-stamp/id1480229682), [ByTime: Time Hub](https://apps.apple.com/us/app/bytime-time-hub/id6747457512), [bytimeapp.com](https://bytimeapp.com/)

---

## 1. Subscription vs. donation box: Apple decides this for you

This is the question you actually asked, and the answer is more constrained than you'd expect — Apple's rules rule out one of your options outright.

### What you cannot do

**You cannot put a donation box in the app.** App Review Guideline 3.2.2(iv) is explicit: unless you are an Apple-**approved nonprofit**, collecting funds within the app for charities or fundraisers is prohibited. Apps raising money for causes must be free and may only collect funds *outside* the app — via Safari or SMS. Developers get rejected for exactly this regularly, including ones who tried to work around it with an in-app Safari view.

Since you'd be shipping as an Ohio LLC (per the earlier plan), a "donate to support trans research" button inside the app is a rejection waiting to happen. Later, once the nonprofit exists and completes Apple's nonprofit approval process, this changes — approved nonprofits *may* fundraise in-app, provided they support Apple Pay, disclose how funds are used, and provide tax receipts.

### What you can do

**A tip jar is allowed.** Apple explicitly permits apps to let customers tip the developer, via In-App Purchase (consumable products). This is the closest legal analog to what you were picturing, and it's a real option.

But be clear-eyed about the economics: tips go through IAP, so Apple takes its cut (15% for you under the Small Business Program — more on that below), and tip-jar revenue is famously unreliable. For a niche app with a devoted community it might cover hosting; it will not fund your living expenses or a nonprofit. Tip jars work as a *supplement* to a business model, not as one.

**A subscription is allowed and is the sustainable path.** Which brings us to pricing.

### So: is a donation box "ehh"?

Not ethically — the instinct behind it is good, and this community genuinely does show up for tools built with care. It's "ehh" for three practical reasons: Apple prohibits the donation version, the tip version generates unpredictable revenue that won't sustain you, and — the one worth sitting with — **free-with-tips quietly signals "hobby project."** For a health tool where users are trusting your model with real medical decisions, a paid tier can actually *increase* trust and your accountability to keep it maintained. People are wary of free health apps precisely because they wonder what's being monetized instead.

You can do both: subscription as the business, tip jar as a "you've helped me more than the sub costs" pressure valve for the users who want to give more.

Sources: [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Guideline 3.2.2 donations rejection thread](https://developer.apple.com/forums/thread/799549), [Apple allows tip jars via IAP](https://www.idownloadblog.com/2017/06/09/apple-now-allowing-developers-to-implement-digital-tip-jars-via-in-app-purchase-mechanism/)

---

## 2. Recommended subscription model

The 2026 benchmark data is unusually favorable to your category. Health & Fitness leads every App Store category at roughly **35% trial-to-paid conversion**, and Health & Fitness monthly pricing has a median of **$9.70**, with typical ranges of $4.99–$14.99/mo. Notably, **60.6% of Health & Fitness subscribers choose annual plans** — this category leans annual harder than most.

The other significant finding: hard paywalls convert at roughly **5x** the rate of freemium (median ~10.7% vs ~2.1% at Day 35) and produce about 2x the LTV per subscriber.

**But do not use a hard paywall here.** The benchmark says it converts better; your situation says don't. Locking dose logging and injection reminders behind a paywall means someone who can't afford $8/month can't reliably track their medication — that's a real harm in a population that already faces enormous barriers to care, and it will (deservedly) get you shredded in the exact communities you need on your side. The reputational cost in trans health spaces is not worth the conversion delta.

### Suggested structure

**Free forever, no account required:**
Dose logging, injection reminders, injection site rotation map, basic history. Everything that is *safety-relevant* stays free. This is both the ethical line and, practically, your best marketing — it's what gets recommended in Discord servers.

**byTime Plus — ~$4.99/mo or ~$34.99/yr (a ~40% annual discount):**
The pharmacokinetic curve and level estimation, blood-test calibration, labs-on-timeline charts, trend insights, data export, and future advanced features. These are the "power user who's optimizing their protocol" features — genuine added value, not artificial gating.

Price at the lower end of the category range rather than the $9.70 median. Your users skew young, disproportionately underemployed, and often paying out of pocket for healthcare already. A price that feels fair earns goodwill that converts into word of mouth, which is your only real acquisition channel. Lead with the annual plan given the category's annual preference, and offer a free trial on it.

**A quiet, hard-to-find "reduced price" or free-Plus request.** A one-line "if you can't afford this, email me and I'll comp it" costs you almost nothing (the marginal cost of a subscriber is zero) and is the single most on-brand thing you could do. Apple supports promo codes and offer codes for exactly this.

**Tip jar (optional, add later):** A few consumable IAP tiers ($2 / $5 / $10, "buy me a coffee"–style) for users who want to give more. Add it after launch, not at launch — leading with a tip jar muddies the pitch.

### Also: enroll in the App Store Small Business Program

It drops Apple's commission from 30% to **15%** for developers under $1M in annual proceeds. You qualify automatically as a new developer, but you have to actually enroll — it isn't retroactive and it isn't automatic. Do this as soon as your LLC and developer account are aligned. On $5/month that's the difference between keeping $3.50 and keeping $4.25 per subscriber.

Sources: [Subscription App Pricing by Category 2026 (Airbridge)](https://www.airbridge.io/en/blog/subscription-app-pricing-by-category-2026-benchmark), [In-App Subscription Benchmarks for Health & Fitness (Adapty)](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/), [State of Subscription Apps 2026 (RevenueCat)](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/), [App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/)

---

## 3. How the nonprofit fits (later, not now)

You want a nonprofit that funds trans health research, potentially taking investment from outside businesses and entities. That's a genuinely good long-term structure, and the research architecture already in the codebase makes it credible rather than aspirational. Two things to get right:

**Sequencing.** Build the for-profit first. The nonprofit's fundraising case is enormously stronger with a shipped app, real users, and demonstrated community trust behind it — "we have 4,000 people using our tool and here's what we're learning" opens doors that "we have a plan" does not. Trying to stand up a 501(c)(3) (board, bylaws, IRS Form 1023, governance, annual filings) while also shipping your first app as a solo founder is how both efforts stall.

**Structure.** The common pattern is a for-profit entity that owns and operates the product, and a separate nonprofit that funds and publishes research, with a defined, arm's-length relationship between them (data licensing or donation agreements, and importantly, *not* the nonprofit simply existing to enrich the LLC — the IRS calls that private benefit and it's the fastest way to lose exempt status). Get a nonprofit attorney involved before you file; this is the one area where the DIY path is genuinely risky. Ohio has affordable options and the SBDC network can refer you.

One nice side benefit worth noting: nonprofits can request an **Apple Developer Program fee waiver** — so the eventual nonprofit's own apps or presence wouldn't carry the annual $99.

Also note the earlier point in reverse: once the nonprofit exists and completes Apple's nonprofit approval, in-app fundraising becomes available to it. Your donation-box instinct isn't wrong, it's just early.

---

## 4. TestFlight: how the beta actually works

Short version: TestFlight is Apple's official beta channel, it's free, it's already included with your developer license, and it's the correct next step after the waitlist.

**The mechanics.** You upload a build from Xcode to App Store Connect, wait for processing, then distribute to testers who install through the TestFlight app on their devices. Builds expire after **90 days**, so plan on shipping a fresh build roughly quarterly during a long beta.

**Two kinds of testers:**

- **Internal testers** — up to 100 App Store Connect users on your team. Builds go out immediately after processing, no review. This is you and anyone you formally add to your developer account. Use this for your own testing.
- **External testers** — up to **10,000** people, invited by email or by a **public link**. The public link is the important one for you: it's a URL you can drop in your waitlist email or a Discord server, and people can join themselves.

**Beta App Review.** External builds require review before the *first* build of each new version goes out — currently running roughly **two to seven days** in 2026, longer if your app touches sensitive permissions or new SDKs. A health app requesting HealthKit access is exactly the kind that draws extra scrutiny, so budget a week and don't schedule a launch announcement against an unreviewed build. Subsequent builds within the same version typically go out without another review.

**Practical beta plan for byTime:**

Start small deliberately — 20 to 50 people from the waitlist, not 10,000. The 10,000 cap is a ceiling, not a goal, and a small beta gives you feedback you can actually act on rather than a firehose. Prepare a short structured feedback form (Tally or Google Forms) rather than relying on scattered DMs, and use TestFlight's built-in feedback and crash reporting. Recruit deliberately for regimen diversity — you already know from your persona study that transdermal routes and unconventional intervals expose model edge cases, so seek out testers on gels, creams, and odd dosing schedules, not just standard weekly injections. Those are the users who will find your real bugs.

Sources: [TestFlight — Apple Developer](https://developer.apple.com/testflight/), [TestFlight Distribution Guide](https://techconcepts.org/blog/testflight-guide), [TestFlight external review timing 2026](https://ptkd.com/journal/testflight-external-testing-approved-2026-backlog)

---

## 5. The landing page

There's a working single-file landing page at `docs/design/LANDING_PAGE_SKETCH.html` in your project. It's built in xT's existing design language — the rose/lavender palette, glass cards, and a background SVG of a superposed multi-dose hormone curve pulled straight from your own model's shape.

**To take it live, two steps:**

1. **Wire up the form.** The form currently logs to console. Set `FORM_ENDPOINT` near the bottom of the file to a real endpoint — Formspree, Buttondown, ConvertKit, and Tally all give you a free tier and a URL you can paste in. Buttondown is a good fit since you'll want to *email* the list later, not just collect addresses.
2. **Host it.** It's a single static file, so Netlify, Vercel, GitHub Pages, or Cloudflare Pages will all host it free. Drag-and-drop deploy on Netlify takes about two minutes.

Then point a domain at it. Given the name conflict in section 0, check what's actually available before committing.

**One thing to add before you drive traffic:** the page promises a privacy policy. Publish one at `/privacy` before you start collecting emails — you'll need it for App Store submission anyway, and for this audience specifically, having it up front is a trust signal worth more than any marketing copy.

---

## 6. Revised near-term sequence

**This week:** Decide the name for real (check App Store name availability in App Store Connect and domain availability the same afternoon — it's a 30-minute task and it unblocks everything else). File the Ohio LLC. Enroll in the App Store Small Business Program.

**Next two weeks:** Wire up the waitlist form and deploy the landing page. Write and publish the privacy policy. Start sharing the page in one or two trans HRT communities where you're already known — as a member, not a marketer.

**Weeks 3–6:** Finish MVP polish. Set up App Store Connect, configure the free tier plus the Plus subscription products (you can configure IAP before submitting). Prepare the first TestFlight build.

**Weeks 6–10:** Submit for Beta App Review, budget a week. Invite 20–50 waitlist signups, weighted toward regimen diversity. Collect structured feedback for 2–3 weeks.

**Weeks 10–14:** Fix what the beta surfaced. Submit to the App Store. Launch to the full waitlist.

Defer to after launch: the nonprofit, the research pillar, the tip jar, and any conversation with Rev1 Ventures. All of them get easier with real users behind you.
