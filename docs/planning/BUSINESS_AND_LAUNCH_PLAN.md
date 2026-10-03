# xT — Business & Launch Plan

**Prepared for:** Starla Cortes
**Date:** August 2026
**Status:** Working draft — revisit monthly as decisions land

---

## 1. Where xT actually stands

This isn't a napkin-sketch app idea. Between the pharmacokinetic modeling (ester-specific Bateman curves fit against real published PK literature — Bi 2018 for cypionate, Ichihara 2020 for enanthate, Pastuszak 2021 for undecanoate), the blood-test calibration engine, the anatomical injection-site rotation system, and the persona-validation study you wrote testing seven synthetic HRT regimens against live model output, xT is closer to a clinical-grade tracking tool than the average tracker app. That rigor is your moat — most competitors are simple log books with reminders bolted on. Nobody else in this space appears to be citing population-PK papers in their source comments.

The immediate job isn't "build more features." It's turning a genuinely sophisticated MVP into something real people can download, trust, and pay for (or something a funder will back), while deciding what kind of entity should own it.

---

## 2. Competitive landscape

A handful of apps already occupy this space, and it's worth knowing exactly how xT compares before you write any marketing copy:

**Regimen** is the closest direct competitor — ester-specific half-life curves for cypionate, enanthate, and propionate, visual injection-site rotation, and lab tracking (Total T, Free T, E2, SHBG, hematocrit) correlated against a "Signals" feature that ties mood/energy check-ins to protocol changes. This is the app to study feature-by-feature.

**DoneDose** targets injectable HRT broadly (estradiol valerate and testosterone cypionate) with a visual body map for site rotation as its standout feature.

**Transcapsule** and **TRACE** position as general transition-tracking apps for the trans community — broader scope (photos, voice, mental health) but shallower on the pharmacokinetics side.

**Hormone Helper** and **TRT Tracker: Injections Log** are lighter-weight loggers, closer to a diary than a model.

Your wedge: xT is the only one (as far as this research found) that's publishing its own PK research memos and running empirical persona validation against the model. That's a credibility story a solo trans founder can tell that a VC-backed competitor can't necessarily match — "built by someone who needed it, validated like a clinical tool." Lean into that in every piece of copy: App Store description, landing page, grant applications, pitch deck.

Sources: [Best HRT Tracker Apps (Done Dose)](https://www.donedose.com/guides/best-hrt-tracker-app), [How to Choose a TRT Tracker (Regimen)](https://helloregimen.com/blog/how-to-choose-trt-tracker), [Transcapsule](https://www.transcapsule.com/), [Health Trackers for HRT (TransVitae)](https://www.transvitae.com/health-trackers-hrt-transition/)

---

## 3. Branding & positioning

You're based in Columbus with an Ohio State / Central Ohio tech ecosystem around you, and the product itself is intimate, medical, and trans-specific. A few positioning calls to make deliberately rather than by default:

**Name and voice.** "xT" is short, clinical-adjacent, and gender-neutral enough to work for trans men on testosterone too, not just trans women on estrogen/anti-androgens — worth deciding now whether you're scoping to one hormone protocol or building a multi-protocol platform, because it changes your total addressable market significantly (masc and femme HRT communities are both sizeable and both underserved by "real" software).

**Tone.** The existing design language (glass cards, soft rose/lavender palette, honest data presentation — e.g., showing "uncalibrated" rather than faking precision on propionate) already signals "made with care, not hype." Keep marketing copy in that register: calm, precise, non-clinical-cold but not cutesy either. Avoid the two failure modes common in this space — either sterile medical-app blandness or overly twee "girl math" branding that undersells the actual rigor you've built.

**Trust as the core message.** Because HIPAA does not apply to a consumer app like this (more in section 5), trust has to be earned through transparency, not regulatory badge-dropping. A visible, plain-language privacy page — what's collected, what's never sold, whether data leaves the device — will do more for conversion and retention in this community than almost any other single asset, given how much (justified) wariness trans users have about health data.

---

## 4. Target market

Primary: trans and gender-diverse adults in the US on hormone therapy (injectable, oral, or transdermal), currently using spreadsheets, phone reminders, or general-purpose trackers. Within that, early adopters are likely to be people already active in trans health online communities (r/MtF, r/FtM, r/asktransgender, Discord servers, informational sites like TransVitae) — these communities are also where competitor apps are getting discovered, per the search results above, so that's a validated acquisition channel, not a guess.

Secondary, longer-term: cisgender HRT/TRT users (a much larger, less community-concentrated market already served by Regimen and TRT Tracker) and eventually clinicians or informed-consent clinics who might want a patient-facing companion tool.

Don't chase the secondary market yet. The MVP's identity and your credibility both come from being unmistakably built for and by the trans community first.

---

## 5. Regulatory reality check (read before you market anything)

A few facts worth internalizing so you don't over- or under-claim in your marketing or grant materials:

HIPAA does not apply to xT. HIPAA only binds healthcare providers, health plans, clearinghouses, and their business associates — a standalone consumer app you sell directly to users falls outside that regardless of how sensitive the data is. What *does* apply: FTC Act unfair/deceptive practices enforcement, and the FTC's Health Breach Notification Rule, which requires you to notify users (and sometimes the FTC/media) if you have a breach of identifiable health data. If you take users from any state with a consumer health data law (Washington's My Health My Data Act is the most aggressive so far, and other states are following), you'll need consent flows, a data-minimization posture, and user rights to access/delete their data — build that in now, it's much cheaper than retrofitting.

App Store review will scrutinize a health app more than a typical app: expect close review of your privacy policy, any health claims (don't imply xT diagnoses, dictates dosing, or replaces a clinician — frame consistently as a tracking/estimation tool), and HealthKit permission requests (ask contextually, not all at onboarding, and only for data types you actually use). As of spring 2026 Apple also lets Health & Fitness / Medical category apps declare regulatory status by region in their listing — worth checking whether that's relevant once you're closer to submission.

None of this should slow down building. It should shape two concrete deliverables before public launch: a real privacy policy (a lawyer or a service like Termly/Iubenda can get you a defensible one cheaply) and a one-line disclaimer baked into onboarding and the app itself ("xT estimates hormone levels from a pharmacokinetic model; it does not replace bloodwork or medical advice").

Sources: [HIPAA Doesn't Protect Health App Data (HIPAA Journal)](https://www.hipaajournal.com/americans-mistakenly-believe-health-app-hipaa/), [App Users Beware — Dickinson Wright](https://www.dickinson-wright.com/news-alerts/app-users-beware), [FTC Mobile Health Apps Tool](https://www.ftc.gov/business-guidance/resources/mobile-health-apps-interactive-tool), [App Store Requirements for Health Apps](https://blog.dashsdk.com/app-store-requirements-for-health-apps/), [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

## 6. Business structure: LLC vs. nonprofit

Your own project docs already flag this as an open decision, and it genuinely depends on which of your three pillars (user product, research, scale) you want to fund first.

**LLC** is the pragmatic default for the app itself. In Ohio it's a $99 one-time filing with the Secretary of State, no annual report fee, and it lets you sell subscriptions, raise from angels/VCs (Pipeline Angels and Gaingels both explicitly back trans and LGBTQ+ founders), and apply to LGBTQ+ business grant programs that require for-profit status. Start here if your near-term goal is a sustainable subscription product.

**Nonprofit (501(c)(3))** fits the "Research Advancement" pillar better — the anonymized-data research mission, grant eligibility from health foundations and NIH, and alignment with an academic-adjacent identity (you're already writing research memos and empirical validation papers, which reads very "nonprofit research lab"). It costs more to set up ($474–$999 all-in for Ohio state filing plus IRS 1023-EZ/1023) and comes with governance overhead (board, restrictions on private benefit) that's real friction for a solo founder just out of school.

A common and reasonable path: start as an Ohio LLC now so you can ship, charge, and raise quickly; consider spinning up a nonprofit research arm later once the research pillar has enough momentum (data, papers, partnerships) to justify the governance cost. Don't let the nonprofit decision block shipping the app.

Sources: [Ohio LLC Cost (BusinessRocket)](https://www.businessrocket.com/business-corner/start/llc/ohio-cost/), [How to Start a Nonprofit in Ohio (Foundation Group)](https://www.501c3.org/state-nonprofit-guide/how-to-start-a-nonprofit-in-ohio/), [Ohio SOS Business Filing Fees](https://www.ohiosos.gov/business/business-filing-forms)

---

## 7. Grants & funding to look at

Roughly in order of fastest-to-access:

**LGBTQ+-specific microgrants and accelerators** are the lowest-friction entry point for a brand-new solo founder: the Pride Fund (Founders First CDC, $1,000 grants), the Transform Business Grant (microgrant + year-long planning program, explicitly named for queer/trans founders), and Queer to Stay (HRC + Showtime, aimed at LGBTQ+ businesses serving people of color, women, and trans communities) are all worth applying to now, before you have revenue. StartOut's Growth Lab (a six-month accelerator with mentorship, funding access, free legal consults) is a strong next step once you have a working product to show.

**Certification, not funding directly, but unlocks funding:** NGLCC LGBT Business Enterprise (LGBTBE) certification, done locally through the Diversity Chamber of Central Ohio (DCCO — Columbus's NGLCC affiliate), opens supplier-diversity contracts, some grant eligibility, and networking with corporate partners actively trying to spend with certified LGBTQ+ businesses.

**Trans-health-specific philanthropy:** The Fund for Trans Generations funds leaders and organizations improving trans/nonbinary life outcomes on a rolling, year-round basis — a good fit once you can frame xT's research pillar (anonymized aggregate insights into HRT protocols) as a community benefit, not just a product.

**Health-tech-specific:** 360 Venture Collective funds pre-seed/seed tech-enabled health-tech founders from underestimated backgrounds. Further out, NIH's SBIR/STTR program (recently reauthorized for five more years) funds small businesses doing health-relevant R&D — a realistic target once you have preliminary data suggesting your PK model or calibration approach produces genuinely novel research value, not before. NIMH specifically has standing interest in digital mental-health technologies, which could apply if the journal/mood-tracking side of xT gets developed further.

Sources: [16 Grants for LGBTQ+ Owned Businesses (HubSpot)](https://blog.hubspot.com/marketing/grants-for-lgbtq-entrepreneurs), [Pride Fund — Founders First CDC](https://foundersfirstcdc.org/pride-grant), [13 Funding Ideas for LGBTQ+ Wellness Startups](https://www.lgbtqandall.com/funding-lgbtq-wellness-startups/), [NGLCC LGBTBE Scholarships and Grants](https://nglcc.org/nglcc-lgbtbe-scholarships-and-grants/), [SBIR/STTR is Back — NIH](https://grants.nih.gov/news-events/nih-extramural-nexus-news/2026/04/its-official-nihs-small-business-program-is-back), [NIMH SBIR/STTR FOAs](https://www.nimh.nih.gov/funding/sbir/sbir-sttr-funding-opportunity-announcements)

---

## 8. Columbus / Ohio resources to plug into

You're in a genuinely good city for this. Concretely:

**Diversity Chamber of Central Ohio (DCCO)** — Columbus's LGBTQ+ chamber of commerce, and your local path to NGLCC certification, networking, and sponsorship opportunities specific to Central Ohio's queer business community. This is probably your first phone call.

**Rev1 Ventures** — Columbus's venture studio/incubator hybrid (not a traditional accelerator, more hands-on), with a track record of over 1,400 supported startups and a new downtown Columbus innovation hub. Worth applying to Rev1Labs once you're ready to talk seriously about funding and scaling; they also have relationships with JobsOhio and Ohio State that matter for a Columbus-based health-tech company.

**City of Columbus LGBTQ+ business certification program** — the city itself launched a certification track to help LGBTQ-owned businesses access economic opportunity; check current status and eligibility.

**Ohio Small Business Development Center (SBDC)** network — free/low-cost business counseling, useful for the unglamorous parts (entity setup, bookkeeping, basic legal questions) before you're ready to pay a lawyer.

Sources: [Diversity Chamber of Central Ohio](https://stonewallcolumbus.org/diversity-chamber/), [Rev1 Ventures](https://www.rev1ventures.com/), [Columbus Launches LGBTQ+ Business Certification](https://www.nbc4i.com/news/local-news/columbus/columbus-launches-lgbtq-business-certification-program/), [SBDC Incubator/Accelerator Ohio](https://patentpc.com/blog/sbdc-incubator-accelerator-for-startup-founder-in-ohio)

---

## 9. Marketing & launch plan

**Pre-launch (now through App Store submission).** Build in public, carefully. A landing page (even a single page) with an email waitlist, screenshots of the actual UI (the glass-card home screen and body-diagram site picker are genuinely differentiated visuals — use them), and a short, honest description of what makes xT different from a spreadsheet. Start posting build progress and design decisions in trans HRT communities where you're already a member in good standing — r/MtF, r/asktransgender, relevant Discords — but as a community member sharing something you built for yourself first, not as an advertiser. This community is allergic to extractive marketing and receptive to "I built this because I needed it."

**Launch.** App Store listing optimized around the terms people actually search — "testosterone tracker," "HRT tracker," "injection tracker trans," "hormone level tracker" — informed by what DoneDose/Regimen/Transcapsule rank for. A simple explainer (video or GIF) showing the PK curve and site-rotation map, since those are the two features that visually prove "this is more serious than a log book." Consider a soft launch to your existing community contacts for bug reports and testimonials before the wide push.

**Post-launch.** Testimonials and word of mouth will matter more than paid acquisition in this space — trans health communities trust peer recommendation far more than ads, and paid health-app advertising on major platforms is also more restricted/expensive than typical categories. Budget your early effort toward: responsive support (this is health-adjacent software, bugs feel high-stakes to users), a changelog that shows active development, and partnerships with informational sites like TransVitae or trans health educators/creators who could organically recommend a tool this well-built.

**Monetization.** A freemium model (basic tracking free, PK visualization / blood-test calibration / advanced insights behind a modest subscription, e.g. $3–6/mo) matches what competitors appear to be doing and keeps the core safety-relevant features (reminders, logging) accessible to anyone regardless of ability to pay — important both ethically and for App Store review optics in a health category.

---

## 10. First 90 days

**Days 1–14:** File the Ohio LLC ($99, same-day online). Draft and publish a real privacy policy. Write the one-line in-app medical disclaimer. Set up a landing page + waitlist. Reach out to DCCO to start the NGLCC certification conversation.

**Days 15–45:** Finish MVP polish toward App Store submission (reminders, core logging, the home screen redesign already spec'd in `SPEC.md`). Apply to at least two of the fast microgrants (Pride Fund, Transform Business Grant) — they're low-effort applications and free money doesn't require a working app yet in most cases. Start soft-sharing progress in one or two trans HRT communities.

**Days 46–75:** Submit to App Store. Run a soft launch with 20–50 early users from your community contacts; collect structured feedback (a short in-app or Typeform survey beats scattered DMs). Begin the StartOut Growth Lab application if the six-month timing fits your bandwidth.

**Days 76–90:** Public launch push. First outreach to Rev1 Ventures once you have real usage numbers to show. Reassess: is the near-term story "profitable indie app" or "fundable startup"? That answer should drive whether you spend month 4 on growth or on fundraising materials.

---

## Open questions worth deciding deliberately (not by default)

Are you scoping xT to trans-specific HRT only, or to the broader HRT/TRT market where more competitors already exist? Do you want outside investment at all, or is a sustainable solo/small-team subscription business the actual goal? How much of the "research platform" pillar do you want to pursue now versus after the product has real users and data — it's a strong grant narrative but real scope, and it's fine to defer it.
