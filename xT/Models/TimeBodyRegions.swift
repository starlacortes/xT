import Foundation
import SwiftUI

// MARK: - BodyRegion

struct BodyRegion: Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let icon: String
    let startMonth: Int
    let peakMonth: Int
    let completeMonth: Int
    let earlyText: String
    let midText: String
    let lateText: String
    /// General 2-sentence context shown in the region detail screen above the
    /// phase copy. Authored for clinical sign-off per TIME_TIERS_DESIGN.md §7.
    let overview: String

    /// Per-month factual focus sentences. Keyed by small month-bands so every
    /// month surfaces a fresh, research-backed tissue-level fact even when the
    /// phase label and tier copy are unchanged. `nil` falls back to `phaseText`.
    let monthFocus: [(ClosedRange<Int>, String)]

    /// Which register this region's phase labels are named in. Tissue remodels;
    /// neural circuits adapt. Set once per array — see `PhaseVocabulary`.
    var vocabulary: PhaseVocabulary = .tissue

    func phaseText(at months: Int) -> String {
        if months < startMonth {
            return String(localized: "Changes to the \(label.lowercased()) are about to begin as hormone levels rise and receptors activate.")
        } else if months < peakMonth {
            return earlyText
        } else if months < completeMonth {
            return midText
        } else {
            return lateText
        }
    }

    /// A short factual sentence for the current month, or `nil` if no specific
    /// focus is authored for this month (caller falls back to `phaseText`).
    func focusText(at months: Int) -> String? {
        for (range, text) in monthFocus where range.contains(months) {
            return text
        }
        return nil
    }
}

// MARK: - Static Region Data

enum TimeBodyRegions {

    // MARK: Mind (Estrogen)

    static let mindRegions: [BodyRegion] = [
        BodyRegion(
            key: "pfc",
            label: "Prefrontal Cortex",
            icon: "brain.head.profile",
            startMonth: 1, peakMonth: 18, completeMonth: 36,
            earlyText: "Estrogen receptors (ER-α, ER-β) in the PFC begin responding to rising estradiol. Cerebral blood flow increases measurably, supporting early shifts in executive function and working memory.",
            midText: "Dopaminergic signaling in the PFC is modulated by estrogen. Many report improved cognitive flexibility, enriched emotional regulation, and a qualitative shift in how decisions feel — less analytical, more integrative.",
            lateText: "PFC function has stabilized. The neural circuits governing executive function and emotional top-down control are fully adapted to the estrogen-dominant neurochemical environment.",
            overview: "The prefrontal cortex is densely expressed with estrogen receptors that govern executive function, decision-making style, and emotional top-down control. Estrogen-driven shifts in dopaminergic signaling here produce some of the earliest and most noticeable cognitive effects of feminizing HRT.",
            monthFocus: [
                (1...1,     "ER-α and ER-β in the prefrontal cortex are switching on. Cerebral blood flow here rises within the first weeks — the earliest measurable neural effect."),
                (2...3,     "Dopaminergic tone in the prefrontal cortex is shifting. Changes in decision-making style are underway neurochemically before they are noticeable."),
                (4...6,     "Prefrontal circuits are adjusting to a new dopaminergic baseline. Emotional regulation often starts to feel less effortful in this window."),
                (7...9,     "Working-memory benchmarks typically show measurable improvement here as prefrontal circuits settle into the new signalling environment."),
                (10...13,   "Cognitive flexibility gains are consolidating. The adjustment phase is behind you; what continues is slower circuit-level change."),
                (14...17,   "Prefrontal adaptation is at its most active. Executive function and emotional top-down control are both tracking the new hormonal baseline."),
                (18...20,   "The heavy recalibration is done. Remaining change in prefrontal circuits is fine tuning rather than restructuring."),
                (21...26,   "Executive function reflects the estrogen-dominant environment. Refinement continues at a pace measurable over years, not months."),
                (27...35,   "Prefrontal signalling is close to its adapted configuration. Changes from here are small and slow."),
                (36...47,   "Prefrontal function is adapted and maintained by consistent estradiol. Cognitive health tracks age and lifestyle from here."),
                (48...59,   "Four to five years of estrogen-maintained prefrontal signalling. Dopaminergic tone is a stable baseline that consistent dosing sustains."),
                (60...71,   "Five-plus years of estrogen-dominant PFC signaling. Dopaminergic tone is a stable baseline — cognitive health at this stage tracks age and lifestyle, not HRT duration."),
                (72...95,   "Seven-plus years. Estrogen's role is neuroprotective — preserving grey matter volume and dopaminergic function that declines more steeply without sustained hormone levels. Dose stability is the key input."),
                (96...120,  "Eight-to-ten years. Research tracking long-term HRT users shows no adverse cognitive signal at this tenure. Lifestyle factors — sleep, physical activity, and social engagement — are the primary additional levers."),
                (121...168, "A decade-plus. PFC neuroprotection continues as an active, ongoing process maintained by consistent dosing. Annual HRT reviews track cognitive health and hormone levels together."),
                (169...240, "Long-term estrogen users show preserved executive function and prefrontal grey matter volume compared to untreated populations. The benefit is cumulative — consistent dosing over years sustains it."),
            ],
            vocabulary: .neural
        ),
        BodyRegion(
            key: "hippocampus",
            label: "Hippocampus",
            icon: "waveform.path.ecg",
            startMonth: 1, peakMonth: 24, completeMonth: 48,
            earlyText: "Estradiol rapidly upregulates BDNF in the hippocampus. Synaptogenesis begins — new dendritic spines are sprouting on CA1 pyramidal neurons within the first month.",
            midText: "Hippocampal volume is measurably increasing due to estrogen-driven neurogenesis in the dentate gyrus. Spine density in CA1 has increased ~30%. Verbal memory and spatial navigation show measurable improvements.",
            lateText: "The hippocampus has fully adapted. Estrogen-mediated neuroprotection is ongoing — sustained BDNF signaling, enhanced synaptic plasticity, and reduced oxidative stress.",
            overview: "The hippocampus is estrogen's primary site of structural neuroprotection — BDNF upregulation drives measurable volume growth through new synapse formation and neurogenesis over the first several years. Verbal memory, emotional recall, and spatial orientation all strengthen as the region adapts to the new hormonal environment.",
            monthFocus: [
                (1...1,     "Estradiol is upregulating BDNF in the hippocampus. New dendritic spines are forming on CA1 neurons within the first weeks — structural change, already."),
                (2...3,     "Synaptogenesis is active. CA1 spine density is climbing, and verbal-memory benchmarks can show early gains this soon."),
                (4...6,     "Neurogenesis in the dentate gyrus is contributing to measurable volume increase. Spatial navigation often improves alongside verbal memory."),
                (7...11,    "Hippocampal volume gain is well underway. BDNF signalling stays elevated, supporting continued spine formation."),
                (12...17,   "Verbal-memory performance is typically at its most improved here. The spine density and volume supporting it are established."),
                (18...23,   "Volume gain continues but is decelerating. BDNF-mediated neuroprotection runs at full strength throughout."),
                (24...27,   "CA1 spine density is near its maximum, roughly 30% above baseline. The hippocampus is operating close to its adapted state."),
                (28...35,   "Structural growth is giving way to maintenance. Estrogen's job here shifts from building tissue to protecting it."),
                (36...47,   "Hippocampal volume has plateaued. Sustained BDNF signalling maintains the structure the first years built."),
                (48...59,   "The hippocampus is fully adapted. Ongoing BDNF signalling holds synaptic health and plasticity as a steady state."),
                (60...71,   "Five-plus years of BDNF-maintained hippocampal neuroprotection. The structural changes from the first years are a stable foundation — verbal memory and spatial orientation are maintained by consistent dosing."),
                (72...95,   "Seven-plus years. Long-term estrogen exposure is associated with preserved hippocampal volume and lower dementia risk compared to untreated populations — a benefit that accrues with continued dosing."),
                (96...120,  "Eight-to-ten years. Hippocampal neuroprotection is ongoing and requires consistent hormone levels to sustain. Dose gaps allow gradual reversal over the same multi-year timescale."),
                (121...168, "A decade-plus. Hippocampal BDNF signaling continues as an active maintenance process. Physical activity amplifies estrogen's hippocampal effects at this stage — it's the most potent lifestyle adjunct."),
                (169...240, "Long-term estrogen-maintained hippocampal architecture. The adaptive changes from the first years are sustained by ongoing dosing — an active biological requirement, not a one-time structural change."),
            ],
            vocabulary: .neural
        ),
        BodyRegion(
            key: "amygdala",
            label: "Amygdala",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 12, completeMonth: 24,
            earlyText: "Estrogen begins modulating amygdala reactivity. Emotional intensity may feel heightened as the amygdala adjusts to reduced testosterone and increasing estradiol signaling.",
            midText: "Amygdala response patterns are shifting. Many report a richer emotional range — increased empathy, deeper emotional recall, and a qualitative change in how emotions are experienced.",
            lateText: "Amygdala function has stabilized. Emotional responses are well-calibrated to the new hormonal environment. The initial recalibration period is largely complete.",
            overview: "The amygdala governs emotional salience — how intensely and broadly you register feelings — and estrogen shifts its responsiveness toward a richer, wider emotional range. Many describe this as gaining access to emotional depth that previously felt muted or blocked.",
            monthFocus: [
                (1...1,     "Estrogen is starting to modulate amygdala reactivity. Emotional intensity can feel heightened while the region recalibrates."),
                (2...3,     "Amygdala response patterns are shifting quickly. A wider emotional range and deeper emotional recall are commonly reported this early."),
                (4...5,     "Recalibration is at its most active. Empathy and emotional access often change noticeably in this window."),
                (6...8,     "The qualitative shift in how emotions are experienced is typically clearest here. The initial adjustment is well past."),
                (9...11,    "Emotional range is still broadening but the rate is easing. The amygdala is approaching its recalibrated baseline."),
                (12...13,   "Amygdala function is stabilising. Emotional responses reflect the estrogen-dominant environment rather than the transition into it."),
                (14...17,   "Responses are well calibrated. What continues is subtle circuit-level refinement rather than further recalibration."),
                (18...23,   "The emotional baseline established over the past year is holding. Variation now tracks life and dose timing."),
                (24...35,   "Recalibration is complete. The emotional landscape is maintained by consistent estradiol."),
                (36...47,   "Emotional baseline is fully established. Mood variation tracks dose-cycle timing and circumstances, not ongoing adaptation."),
                (48...59,   "Four to five years of estrogen-dominant emotional processing. Trough days remain the main pharmacokinetic influence on mood."),
                (60...71,   "Five-plus years of estrogen-dominant emotional processing. Emotional patterns are your stable baseline — dose-cycle timing and life circumstances are the primary day-to-day influences."),
                (72...95,   "Seven-plus years. The amygdala's initial recalibration is deeply embedded. Trough days before your next dose remain the main pharmacokinetic influence on mood."),
                (96...120,  "Eight-to-ten years. Emotional baseline is stable and requires no further adjustment from HRT tenure. Sleep quality and stress are the primary modulators at this stage."),
                (121...168, "A decade-plus. Amygdala function is maintained by consistent estradiol as an ongoing steady state. Any significant mood shift warrants attention to dosing schedule."),
                (169...240, "Long-term estrogen-dominant emotional processing — fully established and maintained by consistent hormone levels. Dose stability is what preserves the emotional baseline."),
            ],
            vocabulary: .neural
        ),
        BodyRegion(
            key: "synaptic",
            label: "Synaptic Plasticity",
            icon: "sparkles",
            startMonth: 1, peakMonth: 18, completeMonth: 60,
            earlyText: "Estrogen rapidly enhances long-term potentiation (LTP) in hippocampal and cortical synapses. NMDA receptor expression increases within the first weeks, priming circuits for remodelling.",
            midText: "Synaptic density is actively increasing across limbic and cortical regions. Estrogen promotes dendritic spine formation via CREB-mediated gene transcription — structural brain change is underway.",
            lateText: "Synaptic architecture has fully remodelled. The enhanced plasticity state is maintained through ongoing estrogen — a continuous, active process supported by consistent hormone levels.",
            overview: "Synaptic plasticity is the brain's capacity to form and strengthen connections, and estrogen is among its most powerful promoters — upregulating NMDA receptors, BDNF, and dendritic spine density across limbic and cortical circuits. This is the neurological substrate for the cognitive and emotional changes experienced across the first few years of HRT.",
            monthFocus: [
                (1...1,     "NMDA receptor expression is rising in hippocampal and cortical synapses. Long-term potentiation is enhanced — circuits are primed to remodel."),
                (2...3,     "Dendritic spine formation is active through CREB-mediated transcription. Structural change is measurably underway across limbic regions."),
                (4...6,     "Synaptic density is climbing. The remodelling is broad — hippocampal and cortical circuits are reshaping at the same time."),
                (7...9,     "Spine formation is running at high rate. The architecture laid down now becomes the foundation of the adapted state."),
                (10...13,   "Density gains continue but are beginning to decelerate. Remodelling is shifting gradually toward maintenance."),
                (14...17,   "Synaptic density is approaching its plateau. The building phase is handing over to the sustaining one."),
                (18...20,   "Architecture is largely remodelled. Estrogen's role shifts from constructing synapses to keeping them."),
                (21...26,   "The enhanced plasticity state is maintained by ongoing estrogen. This is continuous work, not a finished result."),
                (27...34,   "Synaptic architecture is mature. BDNF-mediated neuroprotection is the main ongoing mechanism."),
                (35...45,   "The remodelled architecture is established. Estrogen sustains synaptic health as an active steady state."),
                (46...59,   "Four to five years of maintained plasticity. Consistent dosing is what holds the remodelled architecture in place."),
                (60...71,   "Five-plus years of estrogen-maintained synaptic architecture. The enhanced plasticity state is sustained by ongoing BDNF signaling — an active process that requires consistent dosing to maintain."),
                (72...95,   "Seven-plus years. Synaptic density is maintained at its remodelled level. This is a continuous biological requirement — estrogen as an ongoing trophic signal, not a completed process."),
                (96...120,  "Eight-to-ten years. Cognitively stimulating activity and physical exercise amplify estrogen-maintained synaptic plasticity at this stage."),
                (121...168, "A decade-plus. Sustained synaptic plasticity continues to be maintained by consistent hormone levels. Dose disruptions produce neurosteroid gaps that can affect cognitive and emotional function."),
                (169...240, "Long-term estrogen-maintained synaptic health — an active process that requires consistent dosing to sustain. The architecture is embedded through years of maintained signaling."),
            ],
            vocabulary: .neural
        ),
    ]

    // MARK: Body (Estrogen)

    static let bodyRegions: [BodyRegion] = [
        BodyRegion(
            key: "hips",
            label: "Hips & Waist",
            icon: "figure.stand",
            startMonth: 3, peakMonth: 18, completeMonth: 36,
            earlyText: "Estrogen begins redirecting subcutaneous fat to the hip and pelvic girdle while androgenic abdominal-waist fat recedes. The iliac crest and greater trochanter become primary deposition sites.",
            midText: "Hip circumference is measurably increasing as gynoid-pattern fat distribution establishes, while the waist narrows — the hip-to-waist ratio is significantly shifting.",
            lateText: "Fat redistribution to the hips and waist band is largely complete. The wider iliac span and narrower waistline are maintained through continued estrogen therapy.",
            overview: "Estrogen redirects subcutaneous fat toward a gynoid pattern — depositing primarily at the hips, iliac crest, and greater trochanter — while androgenic visceral fat at the waist gradually recedes. The resulting shift in hip-to-waist ratio takes the full 2–3 year adipocyte turnover cycle to complete.",
            monthFocus: [
                (3...3,     "ER-α receptors in gluteofemoral fat are activating. Lipoprotein lipase activity is rising in the hip depots, directing new storage there."),
                (4...5,     "Subcutaneous fat is beginning to deposit at the iliac crest and greater trochanter. Nothing is visible yet; the enzyme work is."),
                (6...8,     "Deposition at the hip is measurable. The waist may start narrowing as androgenic visceral fat recedes."),
                (9...11,    "Hip-to-waist ratio is shifting. New gynoid adipocytes are filling while older androgen-pattern cells are cleared."),
                (12...14,   "Adipocyte turnover is mid-cycle. Fat laid down since month three is maturing in the gynoid pattern."),
                (15...17,   "Deposition is at its fastest. The hip-to-waist shift reads more clearly over a season than over a month."),
                (18...20,   "The major structural shift is largely done. What continues is refinement as the turnover cycle completes."),
                (21...26,   "Redistribution is slowing. Roughly two-thirds of the first full adipocyte cycle is behind you."),
                (27...35,   "Turnover is about 80% through its first complete pass. New fat is essentially all estrogen-pattern now."),
                (36...47,   "Distribution is established and maintained by consistent estradiol. Weight changes still deposit in this pattern."),
                (48...59,   "Body composition is fully estrogen-dominant. Maintenance depends on continued dosing rather than additional time."),
                (60...71,   "Five-plus years of gynoid fat distribution. The pattern is established through multiple adipocyte turnover cycles — weight gain and loss still follow the estrogen-established deposition pathway."),
                (72...95,   "Seven-plus years. The gynoid fat pattern is deeply embedded. Dose cessation would allow gradual androgenic redistribution over the same multi-year adipocyte cycle."),
                (96...120,  "Eight-to-ten years. Body shape is stable. Age-related effects on fat — modest visceral accumulation — track general aging, not your dosing history."),
                (121...168, "A decade-plus. Gynoid fat distribution is your established body composition. Consistent dosing maintains the pattern; disruptions allow gradual reversal through the adipocyte turnover cycle."),
                (169...240, "Long-term estrogen-dominant fat distribution. The pattern persists for as long as hormone levels stay in range — an ongoing hormonal requirement, not a completed permanent change."),
            ]
        ),
        BodyRegion(
            key: "thighs",
            label: "Thighs",
            icon: "figure.walk",
            startMonth: 4, peakMonth: 20, completeMonth: 36,
            earlyText: "Subcutaneous fat begins accumulating on the outer and inner thighs. Pants may fit differently around the upper leg as gynoid-pattern deposition begins.",
            midText: "Thigh circumference increases measurably. Inner-thigh fat pads develop — a hallmark of estrogen-dominant body composition.",
            lateText: "Thigh fat distribution has stabilized at its estrogen-dominant pattern. The curve from hip to knee is well-defined and maintained with consistent hormone levels.",
            overview: "Thigh fat accumulation is a hallmark of estrogen-dominant body composition, driven by rising lipoprotein lipase activity in gluteofemoral depots under estradiol's direction. Inner-thigh fat pads and the curve from hip to knee develop over 2–3 years as fat cells turn over into the gynoid pattern.",
            monthFocus: [
                (4...4,     "Lipoprotein lipase activity is rising in thigh depots. Subcutaneous fat is starting to accumulate on the outer and inner thigh."),
                (5...6,     "Deposition is underway but below the threshold of visible change. Pants fit is usually the first signal."),
                (7...9,     "Thigh circumference is beginning to increase measurably. Inner-thigh fat pads are starting to form."),
                (10...12,   "Inner-thigh pads are visibly developing — a hallmark of estrogen-dominant composition."),
                (13...15,   "The curve from hip to knee is becoming more defined as gynoid deposition continues."),
                (16...19,   "Thigh deposition is at its most active. This is the window where change reads clearest month to month."),
                (20...22,   "The major change in thigh contour is largely complete. Refinement tracks the adipocyte turnover cycle from here."),
                (23...27,   "Deposition is slowing. The gynoid contour is well defined and continues to fill gradually."),
                (28...35,   "Thigh distribution is approaching its established pattern. Remaining change is subtle."),
                (36...47,   "Thigh distribution is established and maintained by consistent estradiol."),
                (48...59,   "Fully estrogen-dominant thigh composition. Weight changes deposit in this established pattern."),
                (60...71,   "Five-plus years of gynoid-pattern thigh distribution — fully established and maintained by consistent estradiol. Weight changes deposit new fat in this established pattern."),
                (72...95,   "Seven-plus years. Thigh fat distribution is stable. Age-related lean mass decline and modest fat gain track general aging, not HRT tenure."),
                (96...120,  "Eight-to-ten years. Thigh composition is your stable baseline. Resistance training maintains lean mass in the thighs — estrogen does not substitute for physical activity."),
                (121...168, "A decade-plus. Gynoid thigh distribution is maintained by ongoing estrogen as a continuous requirement. The pattern is deeply embedded through many completed adipocyte cycles."),
                (169...240, "Long-term estrogen-dominant thigh composition. The established fat pattern is maintained by consistent hormone levels — an active ongoing requirement, not a permanent structural change."),
            ]
        ),
        BodyRegion(
            key: "abdomen",
            label: "Abdomen",
            icon: "arrow.up.and.down",
            startMonth: 3, peakMonth: 12, completeMonth: 24,
            earlyText: "Androgenic visceral fat — the kind stored around the abdominal organs — begins to decrease as testosterone is suppressed. The belly may soften or slim slightly before hip changes become externally visible.",
            midText: "Abdominal fat keeps shifting away from the visceral android pattern. Combined with gynoid gain at the hips, the belly and waistline read noticeably softer.",
            lateText: "Abdominal fat distribution has stabilized in its estrogen-dominant pattern, maintained by ongoing hormone levels.",
            overview: "While estrogen builds fat at the hips and thighs, it simultaneously draws down androgenic visceral fat around the abdominal organs — reversing the android fat pattern. This belly softening is often one of the earliest externally visible changes because visceral fat responds more quickly than the slower gynoid deposition at the hips.",
            monthFocus: [
                (3...3,     "Androgenic visceral fat is beginning to recede as testosterone falls. The belly often softens before any hip change shows."),
                (4...5,     "Visceral reduction is underway. This depot responds faster than the hips because it is the one androgens were driving."),
                (6...7,     "Visceral fat loss is measurable. Subcutaneous abdominal fat is shifting off the android pattern and the waistline reads softer."),
                (8...9,     "The android-to-gynoid shift is well underway. Combined with hip gain, the waist-to-hip ratio is moving noticeably."),
                (10...11,   "Abdominal change is at its fastest. Most of the visceral reduction available to estrogen happens across this stretch."),
                (12...13,   "The visceral reduction is largely complete. Abdominal fat is approaching its estrogen-dominant distribution."),
                (14...17,   "The abdominal pattern is stabilising. What remains is subtle refinement rather than further redistribution."),
                (18...23,   "Distribution is settling. Remaining change tracks the tail of the adipocyte turnover cycle."),
                (24...35,   "Abdominal fat is established in its estrogen-dominant pattern."),
                (36...47,   "The pattern is maintained by consistent hormone levels. Weight changes follow estrogen-pattern deposition."),
                (48...59,   "Four to five years in, abdominal composition tracks diet, activity and sleep alongside continued dosing."),
                (60...71,   "Five-plus years of estrogen-dominant abdominal distribution. Visceral fat levels are in the gynoid range and maintained by consistent estradiol — a stable baseline."),
                (72...95,   "Seven-plus years. Age-related modest visceral fat accumulation is normal across all adults; estrogen slows this but doesn't eliminate it. Annual wellness checks track this separately from HRT."),
                (96...120,  "Eight-to-ten years. Abdominal composition is stable. Diet, physical activity, and sleep quality are the primary levers alongside continued dosing."),
                (121...168, "A decade-plus. Estrogen-dominant abdominal distribution continues to be maintained by consistent hormone levels. Dose cessation allows gradual reversion toward androgenic distribution."),
                (169...240, "Long-term estrogen-dominant abdominal fat pattern — established and maintained by ongoing hormone levels. This is a continuous hormonal requirement, not a completed adaptation."),
            ]
        ),
        BodyRegion(
            key: "glutes",
            label: "Glutes",
            icon: "oval.fill",
            startMonth: 3, peakMonth: 24, completeMonth: 48,
            earlyText: "Fat deposition begins in the gluteal region — often subtle at first. You might notice your pants fitting differently in the seat before any visible change.",
            midText: "Gluteal fat pads are actively expanding. Combined with pelvic rotation from ligament changes, your posterior profile and posture are changing noticeably.",
            lateText: "Gluteal distribution is mature. Subtle refinements may continue through year 4–5 as the 2–3 year adipocyte cell-turnover cycle completes.",
            overview: "Gluteal fat pads expand as estrogen redirects storage toward the gynoid pattern, combining with ligament laxity changes to reshape the posterior profile and posture. Development here unfolds on the 2–3 year adipocyte turnover cycle, reaching maturity around year 4–5.",
            monthFocus: [
                (3...3,     "Gluteal deposition is beginning, usually below the threshold of notice. LPL activity in gluteal depots is rising."),
                (4...5,     "Fat pads in the gluteal region are starting to expand. Pants fit in the seat changes before the profile does."),
                (6...8,     "Gluteal expansion is becoming noticeable. Combined with hip deposition, the posterior profile is starting to shift."),
                (9...13,    "Fat pads are actively expanding. Ligament changes are rotating the pelvis slightly, which alters posture along with shape."),
                (14...18,   "Gluteal development is at its most active. The silhouette change reads clearest across this window."),
                (19...23,   "Expansion is decelerating but still running. The major structural change is largely done."),
                (24...27,   "Development is maturing. The adipocyte turnover cycle is still completing, so subtle refinement continues."),
                (28...35,   "The 2–3 year turnover cycle is nearing its first full pass. Change from here is slow and small."),
                (36...47,   "Gluteal distribution is approaching maturity. Refinements continue through year four or five."),
                (48...59,   "Gluteal distribution is mature and maintained by consistent estradiol."),
                (60...71,   "Five-plus years of estrogen-dominant gluteal fat distribution — fully established through multiple adipocyte turnover cycles. The pattern is a stable baseline maintained by consistent dosing."),
                (72...95,   "Seven-plus years. Gluteal shape is maintained by estrogen. Without consistent dosing, the gynoid deposition pattern gradually gives way to androgenic redistribution over the adipocyte cycle."),
                (96...120,  "Eight-to-ten years. Gluteal shape is stable. Age-related effects — modest muscle and skin changes — respond to lifestyle factors alongside continued dosing."),
                (121...168, "A decade-plus. Gynoid gluteal distribution is maintained by ongoing estrogen as a continuous requirement. The established pattern is deeply embedded through many completed fat cell cycles."),
                (169...240, "Long-term estrogen-dominant gluteal distribution. Consistent dosing is what sustains the pattern — an active ongoing hormonal requirement across decades."),
            ]
        ),
        BodyRegion(
            key: "chest",
            label: "Chest",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 18, completeMonth: 60,
            earlyText: "Breast bud formation begins within the first weeks. Areolar tissue becomes more sensitive and the chest wall starts depositing glandular and fatty tissue beneath the nipple.",
            midText: "Breast growth is progressing through Tanner stages 2–4. Montgomery glands develop; the breast mound expands. Growth is not linear — expect plateaus and spurts.",
            lateText: "Breast maturation continues through year 3–5 as the ductal-lobular system completes development. Full maturity may take up to 60 months.",
            overview: "Breast development on estrogen follows the same Tanner staging process as endogenous puberty, beginning with glandular bud formation under the areola and progressing through ductal-lobular expansion over several years. The visible growth phase typically spans years 1–3; internal ductal maturation continues through year 5.",
            monthFocus: [
                (1...1,     "Breast bud formation is beginning. Ductal tissue is forming beneath the areola — the first stage of Tanner 2."),
                (2...3,     "Tanner stage 2 is establishing. Areolar tissue is more sensitive and the bud is palpable. Glandular tissue is forming actively."),
                (4...6,     "The breast mound is expanding beyond the areola. Montgomery glands may begin developing."),
                (7...9,     "Tanner stage 3 is typically reached here. The mound is distinctly elevated. Growth is non-linear — plateaus and spurts are both normal."),
                (10...13,   "Tanner stage 3 to 4. The areola and papilla form a secondary mound in many people; the ductal-lobular system is developing."),
                (14...17,   "Growth is at its fastest. Tanner stage 4 is typically reached across this window."),
                (18...20,   "The breast mound is mature in shape. Internal ductal-lobular development continues well past the visible phase."),
                (21...26,   "Visible growth is slowing. The work continuing is internal — ducts branching and lobules forming."),
                (27...34,   "The visible phase is largely complete. Ductal-lobular maturation continues through years three to five."),
                (35...45,   "The ductal-lobular system is in its final maturation phase. Tissue is approaching full maturity."),
                (46...59,   "Maturation is approaching completion. Full development can take the whole 60 months."),
                (60...71,   "Breast development is complete. The ductal-lobular system is fully mature — maintained by consistent estradiol as a structural baseline. No further development is expected from HRT duration alone."),
                (72...95,   "Seven-plus years. Breast tissue is maintained by estrogen. Without consistent dosing, tissue volume can gradually decline as the trophic signal is removed."),
                (96...120,  "Eight-to-ten years. Breast health from here follows the same pattern as for any person with estrogen-maintained breast tissue: age-appropriate screening is the key health behavior."),
                (121...168, "A decade-plus. Breast tissue is maintained by ongoing estrogen. Health monitoring — including breast examination — is part of standard HRT care at this tenure."),
                (169...240, "Long-term estrogen-maintained breast tissue. Development is complete and has been for years; ongoing dosing preserves the tissue baseline as a continuous hormonal requirement."),
            ]
        ),
    ]

    // MARK: Body Region Callout Positions

    struct BodyRegionCallout {
        let key: String
        let xFrac: Double
        let yFrac: Double
    }

    static let bodyRegionCallouts: [BodyRegionCallout] = [
        BodyRegionCallout(key: "hips",    xFrac: 0.12, yFrac: 0.68),
        BodyRegionCallout(key: "thighs",  xFrac: 0.11, yFrac: 0.88),
        BodyRegionCallout(key: "abdomen", xFrac: 0.12, yFrac: 0.52),
        BodyRegionCallout(key: "glutes",  xFrac: 0.13, yFrac: 0.78),
        BodyRegionCallout(key: "chest",   xFrac: 0.15, yFrac: 0.38),
    ]

    // MARK: - Mind (Testosterone)

    /// Same region keys as `mindRegions` (`pfc`, `hippocampus`, `amygdala`,
    /// `synaptic`) so the brain point-cloud's geometric tagging in
    /// `ConstellationCloud.brain(months:)` — which assigns a region by position,
    /// not by medication — keeps working unmodified.
    static let mindRegionsT: [BodyRegion] = [
        BodyRegion(
            key: "pfc",
            label: "Prefrontal Cortex",
            icon: "brain.head.profile",
            startMonth: 1, peakMonth: 12, completeMonth: 24,
            earlyText: "Androgen receptors in the prefrontal cortex begin responding to rising testosterone. Some report an early shift toward more direct, decisive thinking — though these first weeks are also when levels are least stable dose to dose, so day-to-day variation is normal.",
            midText: "Testosterone and its metabolite DHT continue modulating PFC circuits involved in risk assessment and executive control. Verbal fluency patterns can shift, and many describe a more linear thought process alongside growing decisiveness.",
            lateText: "PFC function has adapted to the androgen-dominant environment. The shift toward more direct executive processing is typically stable by this point, reflecting a settled circuit rather than an ongoing change.",
            overview: "The prefrontal cortex contains androgen receptors that respond to rising testosterone, influencing executive processing, risk assessment, and verbal thought patterns. Many describe a shift toward more direct, linear cognitive processing as PFC circuits adapt to the androgen-dominant environment over the first year or two.",
            monthFocus: [
                (1...1,     "Androgen receptors in the prefrontal cortex are activating. Early shifts in decision-making style vary a lot dose to dose this early."),
                (2...3,     "Prefrontal circuits are adapting. A shift toward more direct, linear processing is commonly reported this early."),
                (4...5,     "Adaptation is active. Verbal fluency patterns can shift alongside the change in decisiveness."),
                (6...8,     "Executive processing is settling into its androgen-adapted configuration. Day-to-day variability is decreasing."),
                (9...11,    "Adaptation is approaching its settled state. The shift toward more decisive processing is typically stable by now."),
                (12...13,   "The major neural adaptation is done. What continues is subtle refinement of the same circuits."),
                (14...17,   "Prefrontal function is in its refinement phase. Executive processing reflects the androgen-dominant environment."),
                (18...23,   "The prefrontal cortex is operating in its adapted configuration. Change from here is slow."),
                (24...35,   "Fully adapted. Cognitive patterns reflect the androgen-dominant environment as a steady state."),
                (36...47,   "Stable. Androgen-maintained executive processing is the ongoing baseline."),
                (48...59,   "Four to five years of androgen-dominant prefrontal signalling. Dose stability is the key hormonal input."),
                (60...71,   "Five-plus years of androgen-dominant PFC signaling. Cognitive processing patterns are a stable baseline — cognitive health from here tracks age and lifestyle, not HRT duration."),
                (72...95,   "Seven-plus years. Testosterone continues to maintain the PFC's androgen-adapted configuration. Dose stability is the key factor — dose gaps can produce transient executive processing dips."),
                (96...120,  "Eight-to-ten years. PFC function is fully adapted and stable. Research tracking long-term testosterone HRT users shows no adverse cognitive signal at this tenure."),
                (121...168, "A decade-plus. Androgen-maintained prefrontal function continues as a stable state. Annual HRT reviews include cognitive wellness alongside hormone levels."),
                (169...240, "Long-term androgen-dominant PFC signaling — a stable, established state maintained by consistent testosterone levels. Cognitive health responds to lifestyle factors and dosing continuity."),
            ],
            vocabulary: .neural
        ),
        BodyRegion(
            key: "hippocampus",
            label: "Hippocampus",
            icon: "waveform.path.ecg",
            startMonth: 1, peakMonth: 12, completeMonth: 24,
            earlyText: "Testosterone acts on androgen receptors densely expressed in the hippocampus. Androgen-administration research links this to measurable gains in spatial navigation and mental rotation tasks, though individual variation is wide.",
            midText: "Spatial memory and navigation performance are commonly reported to improve over this window, consistent with androgen-receptor-mediated support for hippocampal circuitry. Verbal memory shows less consistent change than the spatial gains.",
            lateText: "Hippocampal adaptation to sustained testosterone is complete. Spatial-cognition benefits associated with androgen exposure are maintained for as long as levels stay in range.",
            overview: "The hippocampus is richly expressed with androgen receptors, and exogenous testosterone research consistently links sustained exposure to measurable gains in spatial navigation and mental rotation tasks. These spatial-cognition benefits are maintained for as long as levels remain in range.",
            monthFocus: [
                (1...1,     "Androgen receptors in the hippocampus are activating. Spatial navigation and mental rotation may show early gains."),
                (2...3,     "Spatial memory performance is commonly reported to improve this early. Androgen-receptor support for hippocampal circuitry is active."),
                (4...5,     "Spatial cognition gains are building. Verbal memory shows less consistent change than the spatial gains do."),
                (6...8,     "Gains are consolidating. Individual variation here is wide — receptor density differs more between people than serum levels do."),
                (9...11,    "Adaptation is approaching its settled state. Spatial-cognition benefits are well established."),
                (12...13,   "Major adaptation is complete. The hippocampus is in its refinement phase."),
                (14...17,   "Hippocampal function is operating in its androgen-adapted configuration."),
                (18...23,   "Adaptation is settled. Spatial-cognition benefits are maintained by consistent testosterone."),
                (24...35,   "Complete. The benefits persist for as long as levels stay in range."),
                (36...47,   "Stable. Androgen-maintained hippocampal function is the ongoing baseline."),
                (48...59,   "Four to five years in. Exercise involving spatial navigation or motor learning amplifies the maintained benefit."),
                (60...71,   "Five-plus years of androgen-maintained hippocampal function. Spatial cognition benefits are fully established and maintained by consistent testosterone levels."),
                (72...95,   "Seven-plus years. Spatial memory and navigation performance are maintained by ongoing testosterone. These benefits persist for as long as levels remain in range."),
                (96...120,  "Eight-to-ten years. Hippocampal function is stable. Physical activity — especially exercise involving spatial navigation or motor learning — amplifies the androgen-maintained cognitive benefit."),
                (121...168, "A decade-plus. Androgen-maintained hippocampal function continues as a stable, ongoing state. Cognitive health from here tracks general aging and lifestyle alongside dosing consistency."),
                (169...240, "Long-term androgen-dominant hippocampal signaling — maintained by consistent testosterone as an active ongoing requirement. Spatial cognition benefits persist through continued dosing."),
            ],
            vocabulary: .neural
        ),
        BodyRegion(
            key: "amygdala",
            label: "Amygdala",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 9, completeMonth: 18,
            earlyText: "Testosterone begins modulating amygdala reactivity to emotionally charged and threat-related stimuli. This is an active area of neuroendocrine research, and effects on emotional reactivity vary between individuals rather than following one fixed pattern.",
            midText: "Functional imaging studies of exogenous testosterone report blunted amygdala response to distressing stimuli. Many trans masculine people describe feeling less easily moved to tears and more emotionally contained during this window — a commonly reported experience, not a guaranteed one.",
            lateText: "Amygdala reactivity has recalibrated to the androgen-dominant hormonal environment. Where a shift toward a more contained emotional response occurred, it's typically stable from here.",
            overview: "Testosterone modulates amygdala reactivity to emotionally charged stimuli — an active area of neuroendocrine research where individual variation is wide. Many trans masculine people describe feeling more emotionally contained and less easily moved to tears, though this is a commonly reported experience rather than a guaranteed outcome.",
            monthFocus: [
                (1...1,     "Testosterone is beginning to modulate amygdala reactivity to emotional stimuli. Effects vary between individuals rather than following one pattern."),
                (2...3,     "Reactivity to distressing stimuli is shifting. Many describe feeling less easily moved to tears and more emotionally contained."),
                (4...5,     "The shift is at its most active. Imaging of exogenous testosterone shows blunted amygdala response to distressing stimuli."),
                (6...8,     "The move toward a more contained emotional response is typically stabilising here."),
                (9...10,    "Recalibration is approaching its settled state. Where a shift occurred, it is usually stable from this point."),
                (11...13,   "Amygdala reactivity is stable in its androgen-adapted pattern."),
                (14...17,   "Fully recalibrated. The androgen-dominant emotional baseline is maintained by consistent testosterone."),
                (18...31,   "Stable. Emotional processing reflects the androgen-dominant environment; variation tracks dose timing and circumstances."),
                (32...45,   "The emotional baseline established in the first eighteen months is holding. Sleep and stress are the primary modulators."),
                (46...59,   "Four to five years of androgen-adapted emotional processing. Dose gaps can produce transient shifts — pharmacokinetics, not regression."),
                (60...71,   "Five-plus years of androgen-adapted amygdala function. Emotional reactivity patterns are fully calibrated and stable — any variation now tracks dose-cycle timing, not ongoing adaptation."),
                (72...95,   "Seven-plus years. The androgen-adapted emotional baseline is deeply embedded. Dose gaps can produce transient shifts in emotional reactivity — a pharmacokinetic effect, not a regression."),
                (96...120,  "Eight-to-ten years. Emotional baseline is your stable, established state. Life circumstances and sleep quality are the primary modulators at this tenure."),
                (121...168, "A decade-plus. Amygdala function is maintained by consistent testosterone. The androgen-adapted emotional baseline is well established through years of sustained hormone exposure."),
                (169...240, "Long-term androgen-dominant amygdala signaling — a fully established and maintained state. Dose consistency is what preserves the emotional baseline across decades."),
            ],
            vocabulary: .neural
        ),
        BodyRegion(
            key: "synaptic",
            label: "Synaptic Plasticity",
            icon: "sparkles",
            startMonth: 1, peakMonth: 12, completeMonth: 36,
            earlyText: "Androgen receptor activation begins promoting dendritic spine formation in the hippocampus and cortex — a process distinct from, but analogous to, estrogen's effect on synaptic density. Testosterone can also be locally converted to estradiol via aromatase in some brain regions, adding a second signaling pathway.",
            midText: "Spine density continues increasing in androgen-receptor-rich regions. The dual pathway — direct androgen receptor signaling plus local aromatization to estradiol — means testosterone's neural effects aren't purely androgenic; both signaling routes are active in the brain at once.",
            lateText: "Synaptic architecture has stabilized under sustained testosterone exposure. The combined androgen and local-estrogen signaling that developed over the past several years is now the steady state your brain operates on.",
            overview: "Testosterone promotes synaptic plasticity through two simultaneous pathways: direct androgen receptor activation in hippocampal and cortical circuits, and local conversion to estradiol via aromatase within the brain itself. This dual mechanism means testosterone's neural effects aren't purely androgenic — both signaling routes are active at once.",
            monthFocus: [
                (1...1,     "Androgen receptor activation is promoting dendritic spine formation. Aromatase is converting some testosterone to estradiol locally — both pathways are live."),
                (2...3,     "Spine density is measurably increasing in androgen-receptor-rich regions. The dual pathway is fully active."),
                (4...5,     "Remodelling is at its fastest. Both direct androgen signalling and local estradiol are contributing."),
                (6...8,     "Synaptic density is approaching its plateau. The remodelling phase is well established."),
                (9...11,    "Spine formation is decelerating. The architecture being laid down is the foundation of the adapted state."),
                (12...15,   "Remodelling is handing over to maintenance. The androgen-adapted architecture is largely in place."),
                (16...23,   "The architecture is settling. Signalling from here maintains rather than builds."),
                (24...35,   "Stabilised under sustained testosterone. Combined androgen and local-estrogen signalling is the steady state."),
                (36...47,   "Fully stabilised. Neural architecture is maintained by consistent testosterone."),
                (48...59,   "Four to five years of dual-pathway maintenance. Dose stability is the key hormonal input."),
                (60...71,   "Five-plus years of androgen-maintained synaptic architecture. The combined androgen-receptor and local-aromatization signaling is a stable, ongoing state maintained by consistent testosterone."),
                (72...95,   "Seven-plus years. The dual-pathway neural maintenance — direct androgen receptor activation plus local estradiol from aromatase — continues as an active biological process requiring consistent dosing."),
                (96...120,  "Eight-to-ten years. Cognitively stimulating activities and physical exercise provide the most meaningful additional benefit at this stage."),
                (121...168, "A decade-plus. Androgen-maintained synaptic architecture continues as an active maintenance process. Dose stability is the key hormonal input — fluctuations produce neurosteroid changes."),
                (169...240, "Long-term androgen-dominant synaptic maintenance — an ongoing, active process sustained by consistent testosterone levels. The architecture established in the first years is maintained through continued dosing."),
            ],
            vocabulary: .neural
        ),
    ]

    // MARK: - Body (Testosterone)

    /// Same region keys as `bodyRegions` (`chest`, `abdomen`, `hips`, `glutes`,
    /// `thighs`) so `bodyRegionCallouts` and the y-band tagging in
    /// `ConstellationCloud.body(months:)` keep working unmodified — only the
    /// meaning attached to each key differs by medication. The `hips` key
    /// covers the merged hip/waist band; `abdomen` (the belly) is the
    /// androgenic fat-deposition story on T.
    static let bodyRegionsT: [BodyRegion] = [
        BodyRegion(
            key: "chest",
            label: "Chest",
            icon: "figure.strengthtraining.traditional",
            startMonth: 3, peakMonth: 14, completeMonth: 30,
            earlyText: "Androgen receptors in pectoral muscle begin responding to testosterone's anabolic signal, and 5\u{03B1}-reductase converts a share of testosterone to DHT in chest-wall hair follicles, priming them for terminal hair growth. Chest hair follows the same body-hair timeline as elsewhere — later than the legs and abdomen.",
            midText: "Pectoral muscle mass is measurably increasing with resistance training, broadening the chest wall. DHT-driven chest hair is typically visible by now, in the same pattern developing on the abdomen and back.",
            lateText: "Chest muscle development has largely matched its training stimulus by this point — further growth depends more on continued training than on additional time on T. Chest hair, where it develops, is fully in and permanent.",
            overview: "Testosterone drives pectoral muscle hypertrophy through androgen receptor activation, while DHT from 5α-reductase conversion primes chest-wall hair follicles for terminal hair growth. With consistent resistance training, chest broadening is measurable within the first months; chest hair follows the body-hair timeline and typically appears after the legs and abdomen.",
            monthFocus: [
                (3...3,     "Pectoral androgen receptors are activating. With resistance training, early hypertrophy is measurable. DHT is priming chest-wall follicles but no terminal hair yet."),
                (4...5,     "Pectoral protein synthesis is elevated. Strength usually moves before size does."),
                (6...7,     "Chest-wall broadening is measurable with training. Chest hair is beginning to appear, following the legs and abdomen."),
                (8...10,    "Pectoral mass is increasing with training. DHT-driven chest hair is filling in on the same pattern as the abdomen."),
                (11...13,   "Muscle gain is at its fastest with consistent training. Chest hair continues converting from vellus to terminal."),
                (14...16,   "Pectoral development is approaching its training-stimulus ceiling. Hair continues filling in."),
                (17...21,   "Chest muscle has largely matched its training stimulus. Further growth depends on progressive overload, not more time on T."),
                (22...29,   "Chest hair, where it develops, is fully in and permanent. Muscle is maintained by training and testosterone together."),
                (30...39,   "Development is established. Muscle tracks training; the hair pattern is permanent."),
                (40...49,   "Stable. Pectoral mass is maintained by testosterone and training; hair needs no maintenance."),
                (50...59,   "Four to five years in. Progressive overload is the remaining lever on pectoral size."),
                (60...71,   "Five-plus years. Pectoral muscle is fully developed relative to training stimulus, and chest hair pattern is permanent. Muscle tracks training and T; hair requires no additional time."),
                (72...95,   "Seven-plus years. Chest development is stable. Muscle mass maintenance depends on continued resistance training and testosterone; detraining or dose cessation both lead to loss over time."),
                (96...120,  "Eight-to-ten years. Pectoral muscle responds to training just as it has throughout — testosterone is the hormonal foundation, but progressive overload is the stimulus for any further gain."),
                (121...168, "A decade-plus. Chest hair pattern is permanent and requires no maintenance. Pectoral muscle is maintained by T and training — testosterone's role is to support, not substitute for, resistance training."),
                (169...240, "Long-term androgen-dominant chest — permanent hair pattern, training-dependent muscle. Testosterone maintains the anabolic environment; muscle mass responds to how it's used."),
            ]
        ),
        BodyRegion(
            key: "abdomen",
            label: "Abdomen",
            icon: "arrow.up.and.down",
            startMonth: 3, peakMonth: 18, completeMonth: 36,
            earlyText: "Testosterone shifts fat storage toward a more androgenic, abdomen-leaning pattern as visceral and subcutaneous fat distribution responds to androgen receptor signaling — the reverse of estrogen's hip-and-thigh-directed pattern. Core muscle definition can also begin increasing with resistance training.",
            midText: "Abdominal fat continues accumulating and belly composition shifts toward the androgenic pattern. Combined with broadening shoulders, this changes the overall silhouette even where absolute waist circumference doesn't move much.",
            lateText: "Fat distribution has settled into its androgen-dominant pattern. From here, abdominal size tracks diet, training and age the way it does for anyone — testosterone's redistribution effect is complete.",
            overview: "Testosterone shifts fat storage toward an androgenic pattern, directing deposition toward the abdomen and visceral compartments — the reverse of estrogen's gynoid effect. Combined with broadening shoulders and chest, this produces a masculinized silhouette even where absolute waist circumference changes minimally.",
            monthFocus: [
                (3...3,     "Fat storage is shifting toward an androgenic, abdomen-leaning pattern. Androgen receptor signalling is redirecting deposition."),
                (4...5,     "Redistribution is underway below the visible threshold. Core definition may improve with training before any pattern change shows."),
                (6...8,     "Abdominal accumulation is measurable. With shoulder broadening, the silhouette shifts even where waist circumference does not."),
                (9...11,    "The androgenic pattern is establishing. Visceral and subcutaneous depots are responding at different rates."),
                (12...14,   "Redistribution is at its most active. The android pattern is becoming the default for new storage."),
                (15...17,   "Composition is well into its androgenic pattern. The redistribution effect is approaching completion."),
                (18...20,   "Distribution is settling into its androgen-dominant pattern. Remaining change is subtle."),
                (21...26,   "The pattern is largely established. From here, belly size tracks diet and training more than testosterone."),
                (27...35,   "Androgenic fat distribution is complete. Abdominal size tracks diet, training and age."),
                (36...47,   "Stable. The androgenic pattern is maintained by consistent testosterone."),
                (48...59,   "Four to five years in. Core composition responds to diet and resistance training alongside continued dosing."),
                (60...71,   "Five-plus years of androgenic abdominal fat distribution — fully established. Abdominal size from here tracks diet, training, and aging, not T duration. Testosterone's redistribution effect is complete."),
                (72...95,   "Seven-plus years. Abdominal composition is your established baseline. Age-related modest visceral fat accumulation is separate from testosterone's initial redistribution — it tracks general aging."),
                (96...120,  "Eight-to-ten years. Core composition responds to diet and resistance training — testosterone maintains the androgenic environment but doesn't substitute for lifestyle choices."),
                (121...168, "A decade-plus. Androgenic abdominal distribution is your established body composition. Diet, physical activity, and sleep are the primary levers for abdominal health at this tenure."),
                (169...240, "Long-term androgenic fat distribution — fully established and maintained by consistent testosterone. Abdominal changes from here track lifestyle and aging, not HRT tenure."),
            ]
        ),
        BodyRegion(
            key: "hips",
            label: "Hips / Waist",
            icon: "figure.stand",
            startMonth: 1, peakMonth: 14, completeMonth: 30,
            earlyText: "Hip circumference doesn't meaningfully change on testosterone — bone structure is set by puberty, and androgens don't cause fat to redistribute away from the hips the way some expect. What does shift the visual proportion is around it: fat redistributing toward the abdomen and broadening shoulders.",
            midText: "The waistline thickens as abdominal gain continues, and as shoulders and chest broaden the hip-to-shoulder ratio that defines silhouette keeps shifting — even though the hips themselves are largely unchanged in circumference.",
            lateText: "Hip proportions are stable and were never expected to change structurally. The masculinized silhouette at this point comes almost entirely from the shoulders, chest and abdominal gain around the waist band.",
            overview: "Hip bone structure is fixed by puberty and doesn't meaningfully change on testosterone — no hormone repositions completed bone. The masculinized proportion comes from the surrounding anatomy: abdominal fat accumulating and shoulders and chest broadening to create a narrower relative hip appearance.",
            monthFocus: [
                (1...1,     "Hip bone structure is fixed and will not change. What shifts the proportion is everything around it — abdominal fat and shoulder width."),
                (2...3,     "The waistline is beginning to thicken as abdominal fat accumulates. Hip circumference itself is unchanged."),
                (4...6,     "The hip-to-shoulder ratio is shifting as shoulders and chest broaden. The hips read narrower by proportion, not by loss."),
                (7...8,     "Upper-body mass is the term that is moving. Hip fat carries fewer androgen receptors and responds late and modestly."),
                (9...10,    "The silhouette shift is becoming pronounced. It comes from the upper body and abdomen, not from hip reduction."),
                (11...13,   "Proportional change is at its fastest. Shoulder and chest development is doing most of the work."),
                (14...16,   "Hip proportions are stabilising. The silhouette is defined by change around a structurally unchanged hip."),
                (17...21,   "The masculinised silhouette is largely set. Remaining change is upper-body and abdominal refinement."),
                (22...29,   "Proportions are stable and were never expected to change structurally."),
                (30...39,   "Fully established. The silhouette is maintained by consistent testosterone and training."),
                (40...49,   "Stable. Upper-body and core training are the primary levers on proportion from here."),
                (50...59,   "Four to five years in. Hip structure is unchanged; the proportion around it is maintained by dosing and training."),
                (60...71,   "Five-plus years. Hip proportions are stable — they were never expected to change structurally. The masculinized silhouette comes from shoulders, chest, and abdominal composition around an unchanged hip structure."),
                (72...95,   "Seven-plus years. The proportional masculinization is your stable baseline. Age-related changes to body composition track general aging, not T tenure."),
                (96...120,  "Eight-to-ten years. Silhouette is established and maintained by continued T. Resistance training for upper body and core is the primary lever for further proportion refinement from here."),
                (121...168, "A decade-plus. Masculinized proportions are fully established. Hip structure is unchanged — the silhouette is maintained by consistent testosterone and training-dependent upper body and abdominal composition."),
                (169...240, "Long-term androgen-dominant proportions — established and stable. The silhouette reflects years of T-maintained composition changes, maintained by continued dosing and training."),
            ]
        ),
        BodyRegion(
            key: "glutes",
            label: "Glutes",
            icon: "oval.fill",
            startMonth: 3, peakMonth: 18, completeMonth: 36,
            earlyText: "Gluteal muscle responds to testosterone's anabolic signal the same way any skeletal muscle does — androgen receptor activation supports protein synthesis and hypertrophy with resistance training. Unlike hip fat, this is a muscle response, so training stimulus matters more here than time on T alone.",
            midText: "With consistent resistance training, gluteal muscle mass is measurably increasing. Without training, testosterone alone produces comparatively little change in this region.",
            lateText: "Gluteal muscle has typically matched its training stimulus by this stage. As with any muscle group, further change from here depends on continued training rather than additional time on hormone therapy.",
            overview: "Gluteal muscle responds to testosterone's anabolic signal the same way all skeletal muscle does — androgen receptor activation supports protein synthesis and hypertrophy with resistance training. This is a muscle response, not a fat redistribution effect: training stimulus matters considerably more than time on T alone.",
            monthFocus: [
                (3...3,     "Gluteal androgen receptors are activating. With resistance training, early hypertrophy is measurable; without it, testosterone alone does little here."),
                (4...5,     "Protein synthesis in gluteal muscle is elevated. This is a muscle response, not a fat redistribution one."),
                (6...8,     "Gluteal mass is measurably increasing with consistent training."),
                (9...11,    "Hypertrophy is well underway with training. Strength gains in squats and leg press are typically rapid here."),
                (12...14,   "Muscle gain is at its fastest. Satellite-cell recruitment from androgen exposure is near its peak."),
                (15...17,   "Gluteal muscle is approaching its training-stimulus ceiling. Further growth depends on progressive overload."),
                (18...20,   "Muscle has largely matched its training stimulus. Testosterone maintains the baseline; training drives further gain."),
                (21...26,   "Development is established. Mass is maintained by testosterone and training together."),
                (27...35,   "Stable. Gluteal mass tracks training stimulus rather than time on T."),
                (36...47,   "Stable. Maintained by consistent testosterone and continued lower-body training."),
                (48...59,   "Four to five years in. Compound lower-body work — squats, hinges, deadlifts — is the remaining lever."),
                (60...71,   "Five-plus years. Gluteal muscle is at its training-dependent ceiling — maintained by T and training, not by additional time on hormone therapy. Progressive overload is what drives further gain."),
                (72...95,   "Seven-plus years. Gluteal strength and size track training stimulus. Testosterone maintains the anabolic environment; the response to that environment is training-dependent."),
                (96...120,  "Eight-to-ten years. Glute maintenance responds to compound lower-body training — squats, hip hinges, and deadlifts. Testosterone provides the foundation; training provides the stimulus."),
                (121...168, "A decade-plus. Gluteal muscle is maintained by consistent T and training. Without regular lower-body training, muscle mass declines gradually even with stable hormone levels."),
                (169...240, "Long-term androgen-maintained gluteal muscle — sustained by T and training stimulus. The muscle responds to how it's used; testosterone is the hormonal foundation, not a substitute for training."),
            ]
        ),
        BodyRegion(
            key: "thighs",
            label: "Thighs",
            icon: "figure.walk",
            startMonth: 2, peakMonth: 14, completeMonth: 28,
            earlyText: "Thigh muscle — quadriceps and hamstrings — responds to testosterone's anabolic effect on skeletal muscle, amplified by resistance or lower-body training. This is measurable within the first few months for many people.",
            midText: "Thigh size from muscle growth is often the most visible lower-body change on T, particularly with squat- or leg-press-style training. Strength gains here frequently outpace upper-body gains early on.",
            lateText: "Thigh muscle development has typically plateaued relative to training stimulus. Continued growth from here tracks progressive overload in training rather than time on testosterone.",
            overview: "Quadriceps and hamstrings are among the most androgen-responsive muscle groups, producing rapid strength and size gains with resistance or lower-body training — often the most visible lower-body change on T within the first year. Satellite-cell activation from androgen signaling plateaus within 12–18 months; continued hypertrophy from here depends on progressive overload.",
            monthFocus: [
                (2...2,     "Quadriceps and hamstrings are responding to testosterone's anabolic signal. With training, measurable hypertrophy comes early here."),
                (3...4,     "Nitrogen retention in thigh muscle is elevated. Net protein balance has shifted toward building before size is visible."),
                (5...7,     "Thigh growth is often the most visible lower-body change on T. Strength gains here frequently outpace upper-body gains."),
                (8...9,     "Type II fibre hypertrophy is well established with training. The anabolic response is near peak velocity."),
                (10...11,   "Growth is at its fastest. Satellite-cell activation from androgen exposure is front-loaded into this window."),
                (12...13,   "Hypertrophy is still strong but the androgen-driven component is beginning to plateau."),
                (14...15,   "Satellite-cell activation is plateauing for untrained fibres. Further growth is driven by progressive overload."),
                (16...20,   "Thigh muscle has largely plateaued relative to training stimulus. Continued growth tracks training, not T duration."),
                (21...27,   "Development is established. Mass is maintained by testosterone and training."),
                (28...37,   "Stable. Thigh mass is maintained by consistent testosterone and progressive overload."),
                (38...48,   "Stable. Strength gains remain available through progressive overload in squats and leg press."),
                (49...59,   "Four to five years in. Age-related lean mass decline begins gradually; lower-body training offsets it."),
                (60...71,   "Five-plus years. Thigh muscle mass is at its training-dependent ceiling — maintained by T and lower-body training. Strength gains are still achievable with progressive overload in squats and leg press."),
                (72...95,   "Seven-plus years. Thigh strength and size track training stimulus. Testosterone provides the anabolic environment; muscle responds to how it's challenged."),
                (96...120,  "Eight-to-ten years. Thigh composition tracks training and aging. Age-related lean mass decline begins gradually — regular lower-body resistance training partially offsets this."),
                (121...168, "A decade-plus. Thigh muscle is maintained by consistent T and training. Without ongoing resistance stimulus, testosterone alone is insufficient to fully prevent age-related lean mass decline."),
                (169...240, "Long-term androgen-maintained thigh muscle — sustained by T and training. Testosterone provides the anabolic foundation; muscle health from here responds most to how it's used."),
            ]
        ),
    ]

    // MARK: - Factual Signal Stats (Estrogen)

    /// Per-region factual signals replacing the old percent-complete rows.
    /// Each entry returns a tissue-level fact that genuinely changes with time,
    /// not a synthetic percentage.
    static func bodyStats(months: Int) -> [(value: String, label: String, sub: String)] {
        return [
            hipSignal(months),
            abdomenSignal(months),
            glutesSignal(months),
        ]
    }

    /// Shared ladder for the signal stat rows: one four-band phase window plus a
    /// two-state sublabel. Twelve hand-written copies of this if/else chain used
    /// to sit one-per-signal, and three of them had drifted into picking a band
    /// boundary different from the sublabel cutoff (e.g. synaptic: phase at 60,
    /// sub at 18) — the ladder and the cutoff are now chosen at one call each,
    /// with all authored strings unchanged.
    private static func phaseBand(_ months: Int,
                                  _ t1: Int, _ t2: Int, _ t3: Int,
                                  _ p1: String, _ p2: String, _ p3: String, _ p4: String) -> String {
        if months < t1 { return p1 }
        if months < t2 { return p2 }
        if months < t3 { return p3 }
        return p4
    }

    /// Two-state sublabel for a signal row: `active` before `activeUntil`,
    /// `established` at/after. The cutoff is intentionally separate from the
    /// phase ladder's last boundary — several signals switch sublabel earlier.
    private static func signalSub(_ months: Int, activeUntil: Int,
                                  _ active: String, _ established: String) -> String {
        months < activeUntil ? active : established
    }

    private static func hipSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 3, 18, 36, "Pre-deposition", "Active deposition", "Maturing", "Established"),
         "Hips / Waist",
         signalSub(months, activeUntil: 36, "Gynoid pattern forming", "Gynoid pattern stable"))
    }

    private static func abdomenSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 3, 12, 24, "Pre-shift", "Visceral receding", "Pattern shifting", "Established"),
         "Abdomen",
         signalSub(months, activeUntil: 24, "Android pattern clearing", "Estrogen-pattern stable"))
    }

    private static func glutesSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 3, 24, 48, "Pre-deposition", "Depot expanding", "Maturing", "Established"),
         "Glutes",
         signalSub(months, activeUntil: 48, "Adipocyte turnover active", "Distribution mature"))
    }

    // MARK: - Factual Signal Stats (Testosterone)

    static func bodyStatsT(months: Int) -> [(value: String, label: String, sub: String)] {
        return [
            chestSignalT(months),
            abdomenSignalT(months),
            thighsSignalT(months),
        ]
    }

    private static func chestSignalT(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 3, 14, 30, "Pre-growth", "Hypertrophy phase", "Maturing", "Established"),
         "Chest",
         signalSub(months, activeUntil: 30, "Pectoral + hair developing", "Muscle + hair permanent"))
    }

    private static func abdomenSignalT(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 3, 18, 36, "Pre-shift", "Androgenic depositing", "Pattern settling", "Established"),
         "Abdomen Shift",
         signalSub(months, activeUntil: 36, "Androgenic pattern forming", "Pattern stable"))
    }

    private static func thighsSignalT(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 2, 14, 28, "Pre-growth", "Hypertrophy phase", "Maturing", "Established"),
         "Thighs",
         signalSub(months, activeUntil: 28, "Type II fiber growth", "Training-dependent"))
    }

    // MARK: - Factual Signal Stats (Mind, Estrogen)

    static func mindStats(months: Int) -> [(value: String, label: String, sub: String)] {
        return [
            synapticSignal(months),
            hippocampalSignal(months),
            bdnfSignal(months),
        ]
    }

    private static func synapticSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 1, 18, 60, "Pre-activation", "Spine formation", "Architecture maturing", "Established"),
         "Synaptic Density",
         signalSub(months, activeUntil: 18, "NMDA upregulated, spines forming", "Remodelled and maintained"))
    }

    private static func hippocampalSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 1, 24, 48, "Pre-activation", "Neurogenesis active", "Volume plateauing", "Fully adapted"),
         "Hippocampal Vol.",
         signalSub(months, activeUntil: 48, "BDNF-driven volume gain", "Neuroprotective steady state"))
    }

    private static func bdnfSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 1, 12, 36, "Baseline", "Upregulated", "Sustained elevation", "Maintenance"),
         "BDNF Activity",
         signalSub(months, activeUntil: 12, "Rising, driving neuroplasticity", "Elevated, neuroprotective"))
    }

    // MARK: - Factual Signal Stats (Mind, Testosterone)

    static func mindStatsT(months: Int) -> [(value: String, label: String, sub: String)] {
        return [
            arActivationSignal(months),
            spatialCognitionSignal(months),
            amygdalaReactivitySignal(months),
        ]
    }

    private static func arActivationSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 1, 12, 24, "Pre-activation", "AR upregulating", "Plateauing", "Established"),
         "AR Activation",
         signalSub(months, activeUntil: 12, "Receptors responding to T", "Steady androgen signaling"))
    }

    private static func spatialCognitionSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 1, 18, 36, "Baseline", "Gains emerging", "Gains consolidated", "Maintained"),
         "Spatial Cognition",
         signalSub(months, activeUntil: 18, "Improving, AR-mediated", "Stable, maintained by T"))
    }

    private static func amygdalaReactivitySignal(_ months: Int) -> (value: String, label: String, sub: String) {
        (phaseBand(months, 1, 9, 18, "Baseline", "Reactivity shifting", "Stabilizing", "Stabilized"),
         "Amygdala Reactivity",
         signalSub(months, activeUntil: 9, "Blunting response to stimuli", "Androgen-adapted baseline"))
    }

    // MARK: - Insights (Estrogen)

    static func mindInsight(months: Int) -> String {
        if months < 3  { return "Neurochemical recalibration is beginning as estradiol rises. Your brain's estrogen receptors in the hippocampus, amygdala, and prefrontal cortex are activating for the first time in this hormonal context." }
        if months < 12 { return "Estrogen is actively remodelling your neural circuits. Synaptic density is measurably increasing — new dendritic spines are sprouting in the hippocampus and PFC. BDNF is upregulated, supporting neuroplasticity." }
        if months < 36 { return "Hippocampal volume is increasing due to estrogen-driven neurogenesis. Amygdala reactivity patterns have shifted, contributing to a richer emotional range. Synaptic architecture continues to be refined." }
        if months < 60 { return "Synaptic architecture is stabilizing. Your neural circuits are well-adapted to the estrogen-dominant environment. Estrogen continues to provide neuroprotection through sustained BDNF signaling." }
        return String(localized: "Your brain's neural architecture is fully adapted. Consistent hormone levels maintain ongoing neuroprotection, synaptic health, and emotional stability — a continuous, active state.")
    }

    static func bodyInsight(months: Int) -> String {
        if months < 3  { return "Fat redistribution hasn't begun yet. As estrogen levels rise, your body will gradually shift from android-pattern to gynoid-pattern fat storage — driven by ER-α activation in subcutaneous adipocytes." }
        if months < 12 { return "Early redistribution is underway. Estrogen is directing new fat to the hips, glutes, and thighs. Visceral fat is also beginning to decrease as testosterone is suppressed." }
        if months < 36 { return "Peak redistribution period. Your body shape is actively changing — hip circumference is increasing, waist is narrowing, and gynoid fat pads are expanding. This is the most visibly dynamic phase." }
        if months < 60 { return "Body contours are maturing. The 2–3 year adipocyte cell-turnover cycle means subtle refinements continue, but the major structural changes in fat distribution are largely complete." }
        return String(localized: "Your body composition is fully established. Fat distribution patterns are maintained through ongoing estrogen — consistent levels prevent reversion to android-pattern storage.")
    }

    // MARK: - Insights (Testosterone)

    static func mindInsightT(months: Int) -> String {
        if months < 3  { return "Androgen receptors across the hippocampus, amygdala, and prefrontal cortex are activating for the first time in this hormonal context. Levels are also still stabilizing dose to dose, so early cognitive and emotional shifts can feel inconsistent." }
        if months < 12 { return "Testosterone is actively reshaping neural circuits tied to executive function, spatial cognition, and emotional reactivity. Many report feeling more direct and less prone to emotional flooding, alongside gains in spatial-task performance." }
        if months < 36 { return "Amygdala reactivity to distressing stimuli has typically settled into its androgen-adapted pattern. Spatial-cognition gains associated with sustained testosterone exposure continue to be reflected in hippocampal function." }
        if months < 60 { return "Neural adaptation to sustained testosterone is essentially complete. Cognitive and emotional patterns tied to androgen signaling are stable rather than still shifting." }
        return String(localized: "Your brain's neural architecture has been androgen-adapted for years. The androgen receptor and local-aromatization signaling that shaped this adaptation continues to maintain it as an ongoing, active state.")
    }

    static func bodyInsightT(months: Int) -> String {
        if months < 3  { return "Muscle and fat redistribution haven't meaningfully started yet. As testosterone rises, skeletal muscle will begin responding to androgen receptor signaling, and fat storage will gradually shift toward a more androgenic, abdomen-leaning pattern." }
        if months < 12 { return "Early muscle growth is underway, especially in the upper body, and is amplified substantially by resistance training. Fat is beginning to redistribute away from a gynoid pattern toward an abdominal one." }
        if months < 36 { return "This is typically the most active window for visible change — shoulders and chest are broadening, waist-to-hip proportion is shifting, and muscle mass is climbing measurably with training." }
        if months < 60 { return "Muscle and fat-distribution changes are maturing. Further gains increasingly depend on training stimulus rather than additional time on testosterone." }
        return String(localized: "Your body composition is fully adapted to sustained testosterone. The androgenic fat-distribution pattern and elevated baseline muscle mass are maintained for as long as levels stay in range — further change from here tracks training and age, not hormone tenure.")
    }
}
