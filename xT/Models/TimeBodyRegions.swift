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
                (60...71,   "Prefrontal dopaminergic tone is held where estradiol sets it. The signal is read continuously; the tissue does not store it."),
                (72...83,   "Every day, estradiol crossing into cortical tissue modulates dopamine release and keeps regional blood flow elevated above its untreated level."),
                (84...95,   "Grey matter volume and dopaminergic function both lean on this signal. Withdrawal effects appear over months, not days, which is why gaps are easy to miss."),
                (96...119,  "At this tenure the relevant measures are hormone levels and sleep quality. Both track cognitive performance more closely than years on therapy."),
                (120...143, "A decade in, cohort studies of sustained hormone therapy report no adverse cognitive signal. They are observational, so they show association rather than cause."),
                (144...179, "Cardiovascular health is the largest modifiable input to prefrontal function at this stage. Blood pressure and lipids matter to this tissue directly."),
                (180...239, "Fifteen to twenty years sits at the edge of published follow-up. What the cohorts show is stability, across a sample still smaller than anyone would like."),
                (240...600, "Past twenty years the literature thins. Prefrontal maintenance is understood mechanistically; the long-horizon outcome data is still being gathered."),
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
                (36...47,   "Hippocampal volume is being held rather than added to. Sustained BDNF signalling maintains the structure the first years built."),
                (48...59,   "The hippocampus is fully adapted. Ongoing BDNF signalling holds synaptic health and plasticity as a steady state."),
                (60...71,   "Hippocampal architecture is held by ongoing BDNF signalling. Spines are maintained by a growth factor the tissue keeps reading, not by a change already made."),
                (72...83,   "Each day estradiol sustains BDNF transcription, supports mitochondrial function in CA1, and keeps oxidative load below where it would otherwise sit."),
                (84...95,   "Verbal memory, spatial orientation and dentate neurogenesis all lean on this signal. Its withdrawal shows over the same multi-year scale it took to build."),
                (96...119,  "Physical activity is the strongest adjunct at this tenure. Aerobic exercise raises BDNF through a separate pathway that adds to the hormonal one."),
                (120...143, "A decade in, longitudinal cohorts associate sustained estrogen exposure with preserved hippocampal volume. The association is consistent; the causal question stays open."),
                (144...179, "Vascular health drives hippocampal outcomes at twelve to fifteen years. The region is perfusion-sensitive, so blood pressure control is load-bearing here."),
                (180...239, "Fifteen to twenty years is where follow-up data runs out. Volume preservation holds across that window in the cohorts that exist."),
                (240...600, "Past twenty years the mechanism is well described and the outcome data is not. BDNF-maintained architecture is understood; its multi-decade trajectory is being studied."),
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
                (24...35,   "Recalibration has run its course. The emotional landscape is held by consistent estradiol."),
                (36...47,   "Emotional baseline is fully established. Mood variation tracks dose-cycle timing and circumstances, not ongoing adaptation."),
                (48...59,   "Four to five years of estrogen-dominant emotional processing. Trough days remain the main pharmacokinetic influence on mood."),
                (60...71,   "The amygdala's emotional calibration is held by continuous signalling. Reactivity tracks circulating estradiol, which is why a trough registers as mood."),
                (72...83,   "Day to day, neurosteroids synthesised in limbic tissue act on GABA-A receptors, and their supply follows the hormone level in your blood."),
                (84...95,   "Emotional range, salience and the amygdala-to-prefrontal coupling all rest on this signal, and all of them follow it within a dose cycle."),
                (96...119,  "At this tenure, sleep quality and dose interval predict emotional stability better than anything else. Both are measurable and both are adjustable."),
                (120...143, "A decade in, emotional baseline is one of the most stable things about long-term therapy. Studies of mood at this tenure find variation tracks life, not tenure."),
                (144...179, "Limbic function at twelve to fifteen years is unremarkable in follow-up, which is itself the finding. The tissue asks for consistency, not adjustment."),
                (180...239, "Fifteen to twenty years is the edge of published follow-up. Emotional outcomes across it are stable and, in the cohorts, uneventful."),
                (240...600, "Past twenty years there is little published. The neurosteroid mechanism is well characterised; how it reads across four decades of exposure is not yet."),
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
                (21...26,   "The enhanced plasticity state is maintained by ongoing estrogen. This is continuous work rather than a result already banked."),
                (27...34,   "Synaptic architecture is mature. BDNF-mediated neuroprotection is the main ongoing mechanism."),
                (35...45,   "The remodelled architecture is established. Estrogen sustains synaptic health as an active steady state."),
                (46...59,   "Four to five years of maintained plasticity. Consistent dosing is what holds the remodelled architecture in place."),
                (60...71,   "Synaptic density is held, not banked. Estradiol is a trophic signal the brain reads continuously, and the remodelled architecture depends on it arriving."),
                (72...83,   "Every day estrogen sustains NMDA receptor expression and CREB-mediated transcription, the two processes that keep existing spines alive."),
                (84...95,   "Plasticity, memory consolidation and mood regulation all draw on this architecture. It relaxes over months if the signal drops, on the same scale it was built."),
                (96...119,  "Cognitively demanding activity and aerobic exercise both raise plasticity through pathways separate from the hormonal one. At this tenure they add the most."),
                (120...143, "A decade in, the cohorts describe stable cognitive performance under sustained therapy. The sample sizes are modest and the follow-up windows are still opening."),
                (144...179, "At twelve to fifteen years, vascular and metabolic health carry more weight than hormonal variables. Synapses are expensive tissue and perfusion-dependent."),
                (180...239, "Fifteen to twenty years marks the edge of the published record. Plasticity measures across it hold steady in the available follow-up."),
                (240...600, "Past twenty years the mechanism is characterised and the outcomes are not. Sustained plasticity is understood cell by cell; the decades-long picture is open."),
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
                (60...71,   "Estradiol is holding this distribution in place. Adipose tissue reads the signal continuously, so the pattern is maintained rather than memorised."),
                (72...83,   "Day to day, estrogen keeps lipoprotein lipase activity high in gluteofemoral depots and suppressed in visceral ones. Every meal is sorted by that gradient."),
                (84...95,   "Fat distribution, insulin sensitivity and bone density all rest on this signal. Adipose redistribution would reverse over a multi-year adipocyte cycle without it."),
                (96...119,  "Bone mineral density becomes the primary measure at this tenure. DEXA every two to five years is typical, and estradiol is its principal regulator."),
                (120...143, "A decade in, cohort data links sustained estradiol with maintained bone density. Levels in range are the variable that predicts the result."),
                (144...179, "At twelve to fifteen years the picture is bone, lipids and blood pressure. In any estrogen-maintained skeleton, osteoclasts resorb and osteoblasts rebuild; estradiol sets the balance."),
                (180...239, "Fifteen to twenty years is where follow-up ends. Bone density and fat distribution both hold across it where levels stayed in range."),
                (240...600, "Past twenty years the data thins. The remodelling mechanism is well established; what it looks like at forty years of exposure is being gathered now."),
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
                (60...71,   "Gluteofemoral fat is held here by an active signal. Estradiol keeps storage biased toward the thigh and keeps release from it slow."),
                (72...83,   "Each day, alpha-2 adrenergic dominance and estrogen-suppressed lipolysis keep this depot filling more readily than it empties."),
                (84...95,   "This distribution is metabolically load-bearing: gluteofemoral fat traps lipid that would otherwise reach the liver. That protection depends on the signal continuing."),
                (96...119,  "Lean mass becomes the measure worth watching at this tenure. Resistance training maintains it; estradiol does not substitute for the mechanical load."),
                (120...143, "A decade in, thigh composition is stable in follow-up. Age-related lean mass decline begins around this point and is largely training-responsive."),
                (144...179, "At twelve to fifteen years, muscle and bone in the leg move together. Loaded lower-body exercise is the input that acts on both."),
                (180...239, "Fifteen to twenty years is the edge of the published record. Fat distribution holds across it wherever hormone levels were sustained."),
                (240...600, "Past twenty years there is little longitudinal data on limb composition specifically. The depot biology is well described; the multi-decade trajectory is not."),
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
                (60...71,   "Visceral fat is kept low here by continuous signalling. Estradiol suppresses lipoprotein lipase in the visceral compartment for as long as it is present."),
                (72...83,   "Day to day, this is where the hormone does its most metabolically consequential work: sorting incoming lipid away from the portal circulation."),
                (84...95,   "Insulin sensitivity, hepatic lipid load and inflammatory tone all lean on low visceral fat. All three drift over years if the signal drops."),
                (96...119,  "At this tenure the relevant measures are fasting glucose, lipids and waist circumference. They are tracked as general wellness rather than as hormone markers."),
                (120...143, "A decade in, sustained estradiol is associated with a gynoid visceral profile in follow-up. Diet and activity move the number more than dose does."),
                (144...179, "At twelve to fifteen years, modest visceral accumulation appears in any adult body. Estradiol slows the trend without removing it."),
                (180...239, "Fifteen to twenty years is the edge of published follow-up. Metabolic markers across it track lifestyle far more closely than tenure."),
                (240...600, "Past twenty years the metabolic literature is thin for this population specifically. The mechanism generalises; the long-horizon cohort data is still accruing."),
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
                (60...71,   "Gluteal fat is held by an active hormonal signal. This depot has among the highest estrogen receptor densities in the body, and it reads estradiol continuously."),
                (72...83,   "Each day estradiol keeps lipoprotein lipase elevated here and lipolysis suppressed, so this depot fills preferentially and empties last."),
                (84...95,   "Shape, posture and pelvic ligament tone all rest on this signal. Withdrawal shifts them back over the multi-year adipocyte cycle that built them."),
                (96...119,  "Hip bone mineral density is the measure that matters at this tenure. The femoral neck is a standard DEXA site and estradiol is its main regulator."),
                (120...143, "A decade in, gluteal distribution is stable in follow-up. Weight changes still deposit along the estrogen-established pathway."),
                (144...179, "At twelve to fifteen years the hip is watched for bone rather than shape. Femoral neck density and fall risk are the clinically relevant pair."),
                (180...239, "Fifteen to twenty years marks the edge of the record. Distribution holds across it in the cohorts with sustained levels."),
                (240...600, "Past twenty years the outcome data thins while the mechanism does not. Depot biology is well described; forty-year trajectories are not yet published."),
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
                (60...71,   "Breast tissue is estrogen-dependent tissue. Estradiol is what holds the ductal-lobular architecture in place, reading the signal the way it did while building it."),
                (72...83,   "Day to day, estradiol sustains the epithelium and the stromal fat that gives breast tissue its volume. Both respond to level, not to tenure."),
                (84...95,   "Tanner stage 5 is the named endpoint of the developmental sequence. A documented minority reach stage 3 or 4 and hold there, which is a recognised outcome."),
                (96...119,  "Age-appropriate breast screening is the relevant health behaviour at this tenure. Mammographic density is highest in younger, denser tissue and eases across the decades."),
                (120...143, "A decade in, breast tissue is maintained by continued estradiol. Cohort follow-up at this tenure focuses on screening cadence rather than on development."),
                (144...179, "At twelve to fifteen years, density on imaging has typically eased, which changes how a mammogram reads rather than what it looks for."),
                (180...239, "Fifteen to twenty years sits at the edge of published follow-up. Tissue volume holds across it where estradiol levels were sustained."),
                (240...600, "Past twenty years the screening literature for this tissue is still being built. What is established is that the tissue stays estradiol-dependent throughout."),
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
                (60...71,   "Prefrontal circuits are held in their androgen-adapted configuration. Testosterone is read continuously here, both directly and after local conversion to estradiol."),
                (72...83,   "Day to day, androgen receptor binding shifts transcription in prefrontal tissue over hours, and aromatase supplies a second signal alongside it."),
                (84...95,   "Executive processing style and its stability across a week both rest on this signal. Dose gaps show up as transient dips before anything else."),
                (96...119,  "At this tenure the useful measures are trough levels and sleep. Both predict cognitive steadiness better than years on therapy."),
                (120...143, "A decade in, follow-up of long-term testosterone therapy reports no adverse cognitive signal. The cohorts are smaller and younger than the estrogen ones."),
                (144...179, "At twelve to fifteen years, cardiovascular health becomes the dominant input. Hematocrit, blood pressure and lipids all act on prefrontal perfusion."),
                (180...239, "Fifteen to twenty years is close to the edge of published follow-up for this population. What exists across that window shows stability."),
                (240...600, "Past twenty years the record is sparse. The receptor mechanism is well described; the multi-decade cognitive picture is actively being studied."),
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
            lateText: "Hippocampal adaptation to sustained testosterone has settled. Spatial-cognition benefits associated with androgen exposure are maintained for as long as levels stay in range.",
            overview: "The hippocampus is richly expressed with androgen receptors, and exogenous testosterone research consistently links sustained exposure to measurable gains in spatial navigation and mental rotation tasks. These spatial-cognition benefits are maintained for as long as levels remain in range.",
            monthFocus: [
                (1...1,     "Androgen receptors in the hippocampus are activating. Spatial navigation and mental rotation may show early gains."),
                (2...3,     "Spatial memory performance is commonly reported to improve this early. Androgen-receptor support for hippocampal circuitry is active."),
                (4...5,     "Spatial cognition gains are building. Verbal memory shows less consistent change than the spatial gains do."),
                (6...8,     "Gains are consolidating. Individual variation here is wide — receptor density differs more between people than serum levels do."),
                (9...11,    "Adaptation is approaching its settled state. Spatial-cognition benefits are well established."),
                (12...13,   "Major adaptation has settled. The hippocampus is in its refinement phase."),
                (14...17,   "Hippocampal function is operating in its androgen-adapted configuration."),
                (18...23,   "Adaptation is settled. Spatial-cognition benefits are maintained by consistent testosterone."),
                (24...35,   "Adaptation has settled. The benefits persist for as long as levels stay in range."),
                (36...47,   "Stable. Androgen-maintained hippocampal function is the ongoing baseline."),
                (48...59,   "Four to five years in. Exercise involving spatial navigation or motor learning amplifies the maintained benefit."),
                (60...71,   "Hippocampal function is held by ongoing androgen signalling. Spatial performance tracks sustained levels rather than accumulated time on therapy."),
                (72...83,   "Each day, androgen receptors in hippocampal tissue support spine density, and locally aromatised estradiol contributes through a second receptor family."),
                (84...95,   "Spatial navigation and mental rotation lean on this signal. Both drift back over months if levels fall out of range."),
                (96...119,  "At this tenure, activity that combines movement with navigation is the strongest adjunct. It raises BDNF through a pathway independent of hormone level."),
                (120...143, "A decade in, hippocampal outcomes under sustained testosterone are stable in follow-up. The evidence base is thinner here than for spatial performance in the short term."),
                (144...179, "At twelve to fifteen years, perfusion drives hippocampal outcomes. Hematocrit management matters to this tissue for exactly that reason."),
                (180...239, "Fifteen to twenty years approaches the limit of published data. Cognitive measures across it are unremarkable in the cohorts that exist."),
                (240...600, "Past twenty years there is little published on this specific tissue. The androgen and aromatase mechanisms are established; the long-horizon data is not."),
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
                (60...71,   "The amygdala's androgen-adapted calibration is held by continuous signalling. Reactivity follows circulating testosterone, which is why a trough can be felt."),
                (72...83,   "Day to day, androgen and locally aromatised estrogen both act on limbic tissue, and neurosteroid supply tracks the hormone level in your blood."),
                (84...95,   "Emotional containment and amygdala-to-prefrontal coupling both rest on this signal, and both follow it within a single dose cycle."),
                (96...119,  "At this tenure, dose interval and sleep predict emotional steadiness better than any other variable. Splitting a dose flattens the curve where troughs bite."),
                (120...143, "A decade in, emotional baseline under sustained testosterone is stable in follow-up. Reported variation tracks circumstance rather than tenure."),
                (144...179, "At twelve to fifteen years, limbic findings remain unremarkable in the literature, which is the finding. The tissue asks for consistency."),
                (180...239, "Fifteen to twenty years is near the edge of published follow-up for this population. Emotional outcomes across it are stable."),
                (240...600, "Past twenty years the record is thin. Amygdala neuroendocrinology is an active research area and the long-horizon picture is still forming."),
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
                (60...71,   "Synaptic architecture is held by two signals at once. Androgen receptor activation and locally aromatised estradiol both keep existing spines alive."),
                (72...83,   "Every day, aromatase inside neural tissue converts part of the circulating testosterone, so the brain is running both pathways continuously."),
                (84...95,   "Plasticity and memory consolidation draw on this architecture. It relaxes over months if levels drop, on the same scale that built it."),
                (96...119,  "At this tenure, cognitively demanding activity and aerobic exercise add the most. Both raise plasticity through routes independent of hormone level."),
                (120...143, "A decade in, cognitive performance under sustained testosterone is stable in the available follow-up. The cohorts are modest and still maturing."),
                (144...179, "At twelve to fifteen years, metabolic and vascular health outweigh hormonal variables. Synapses are expensive tissue and depend on perfusion."),
                (180...239, "Fifteen to twenty years is around the limit of the published record. Plasticity measures across it hold steady."),
                (240...600, "Past twenty years the dual-pathway mechanism is well characterised and the outcome data is not. That gap is where current research sits."),
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
                (60...71,   "Two different things are held here. Terminal hair is permanent once converted; pectoral muscle is held only by testosterone and continued load."),
                (72...83,   "Day to day, androgen receptors in pectoral muscle sustain protein synthesis, while DHT maintains the follicles that already converted."),
                (84...95,   "Chest hair density often keeps increasing past five years, more slowly than before. Muscle depends on training within days, not years."),
                (96...119,  "At this tenure, hematocrit is the measure that matters most. Testosterone drives red cell production, and levels that climb too high raise cardiovascular risk."),
                (120...143, "A decade in, hair pattern is settled and muscle tracks training. Cohort follow-up focuses on hematocrit, lipids and blood pressure."),
                (144...179, "At twelve to fifteen years, cardiovascular monitoring is routine. Resistance training remains the strongest single input to how this tissue looks and works."),
                (180...239, "Fifteen to twenty years is near the edge of published follow-up. Body composition holds across it where training and levels were both sustained."),
                (240...600, "Past twenty years the data thins. Androgen physiology is well described; multi-decade cardiovascular follow-up in this population is still accruing."),
            ]
        ),
        BodyRegion(
            key: "abdomen",
            label: "Abdomen",
            icon: "arrow.up.and.down",
            startMonth: 3, peakMonth: 18, completeMonth: 36,
            earlyText: "Testosterone shifts fat storage toward a more androgenic, abdomen-leaning pattern as visceral and subcutaneous fat distribution responds to androgen receptor signaling — the reverse of estrogen's hip-and-thigh-directed pattern. Core muscle definition can also begin increasing with resistance training.",
            midText: "Abdominal fat continues accumulating and belly composition shifts toward the androgenic pattern. Combined with broadening shoulders, this changes the overall silhouette even where absolute waist circumference doesn't move much.",
            lateText: "Fat distribution has settled into its androgen-dominant pattern. From here, abdominal size tracks diet, training and age the way it does for anyone; testosterone's redistribution effect has run its course.",
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
                (27...35,   "Androgenic fat distribution is established. Abdominal size tracks diet, training and age."),
                (36...47,   "Stable. The androgenic pattern is maintained by consistent testosterone."),
                (48...59,   "Four to five years in. Core composition responds to diet and resistance training alongside continued dosing."),
                (60...71,   "The androgenic distribution here is held by continuous signalling. Androgen receptors in visceral fat keep storage biased toward this compartment."),
                (72...83,   "Each day, androgen signalling raises lipolysis in gluteofemoral depots while favouring abdominal storage. Both directions run at once."),
                (84...95,   "Insulin sensitivity and hepatic lipid load both respond to the visceral compartment. Diet and activity move them more than dose does."),
                (96...119,  "At this tenure, fasting glucose, lipids and waist circumference are the tracked measures. They are watched as general metabolic health."),
                (120...143, "A decade in, abdominal composition is stable in follow-up. Age-related visceral accumulation appears in any adult body and tracks lifestyle."),
                (144...179, "At twelve to fifteen years, metabolic and cardiovascular markers are the clinical focus. Core training and diet act on both directly."),
                (180...239, "Fifteen to twenty years sits at the edge of the published record. Metabolic markers across it track lifestyle far more closely than tenure."),
                (240...600, "Past twenty years the cohort data is limited. The redistribution mechanism generalises well; long-horizon metabolic outcomes are still being gathered."),
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
                (60...71,   "Nothing structural is held here, because nothing structural changed. The proportion is held by muscle and fat around a fixed pelvis."),
                (72...83,   "Day to day, testosterone maintains upper-body muscle and abdominal storage. The hip reads the same signal and responds to it least."),
                (84...95,   "The silhouette rests on tissue that responds to load. Shoulders and core lose mass within weeks of detraining, faster than any hormonal effect."),
                (96...119,  "At this tenure, lean mass and bone density are the measures worth having. Both respond to loaded exercise more than to dose."),
                (120...143, "A decade in, proportion is stable in follow-up. Where it shifts, it follows training history rather than hormone tenure."),
                (144...179, "At twelve to fifteen years, bone density enters the picture. Androgens support the skeleton partly through aromatisation to estradiol."),
                (180...239, "Fifteen to twenty years is near the edge of published follow-up. Composition holds across it where training and levels were sustained."),
                (240...600, "Past twenty years there is little on limb and girdle composition specifically. The mechanism is clear; the long-horizon data is not yet."),
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
                (48...59,   "Four to five years in. Compound lower-body work like squats, hinges and deadlifts is the remaining lever."),
                (60...71,   "Gluteal muscle is held by two inputs at once. Testosterone keeps the anabolic environment; mechanical load is what the tissue actually responds to."),
                (72...83,   "Every day, androgen receptors in gluteal muscle sustain protein synthesis above the untreated rate. Without load, that raised rate builds nothing."),
                (84...95,   "Strength, power and hip stability all rest on this tissue. It atrophies within weeks of detraining, far faster than hormone levels change."),
                (96...119,  "At this tenure, lean mass and bone density are the useful measures. Loaded hip extension acts on both at once."),
                (120...143, "A decade in, gluteal mass tracks training history in follow-up. Testosterone sets the ceiling; training decides where under it you sit."),
                (144...179, "At twelve to fifteen years, the hip is watched for bone as much as muscle. Femoral neck density is a standard DEXA site."),
                (180...239, "Fifteen to twenty years is around the edge of published data. Composition holds across it where training continued."),
                (240...600, "Past twenty years the record thins. Androgen and muscle physiology is well established; multi-decade composition data is still being collected."),
            ]
        ),
        BodyRegion(
            key: "thighs",
            label: "Thighs",
            icon: "figure.walk",
            startMonth: 2, peakMonth: 14, completeMonth: 28,
            earlyText: "Thigh muscle — quadriceps and hamstrings — responds to testosterone's anabolic effect on skeletal muscle, amplified by resistance or lower-body training. This is measurable within the first few months for many people.",
            midText: "Thigh size from muscle growth is often the most visible lower-body change on T, particularly with squat- or leg-press-style training. Strength gains here frequently outpace upper-body gains early on.",
            lateText: "Thigh muscle typically sits at its training-determined level by now. Continued growth from here tracks progressive overload in training rather than time on testosterone.",
            overview: "Quadriceps and hamstrings are among the most androgen-responsive muscle groups, producing rapid strength and size gains with resistance or lower-body training — often the most visible lower-body change on T within the first year. Satellite-cell activation from androgen signaling plateaus within 12–18 months; continued hypertrophy from here depends on progressive overload.",
            monthFocus: [
                (2...2,     "Quadriceps and hamstrings are responding to testosterone's anabolic signal. With training, measurable hypertrophy comes early here."),
                (3...4,     "Nitrogen retention in thigh muscle is elevated. Net protein balance has shifted toward building before size is visible."),
                (5...7,     "Thigh growth is often the most visible lower-body change on T. Strength gains here frequently outpace upper-body gains."),
                (8...9,     "Type II fibre hypertrophy is well established with training. The anabolic response is near peak velocity."),
                (10...11,   "Growth is at its fastest. Satellite-cell activation from androgen exposure is front-loaded into this window."),
                (12...13,   "Hypertrophy is still strong but the androgen-driven component is beginning to plateau."),
                (14...15,   "Satellite-cell activation is plateauing for untrained fibres. Further growth is driven by progressive overload."),
                (16...20,   "Thigh muscle typically sits at its training-determined level. Continued growth tracks training, not T duration."),
                (21...27,   "Development is established. Mass is maintained by testosterone and training."),
                (28...37,   "Stable. Thigh mass is maintained by consistent testosterone and progressive overload."),
                (38...48,   "Stable. Strength gains remain available through progressive overload in squats and leg press."),
                (49...59,   "Four to five years in. Age-related lean mass decline begins gradually; lower-body training offsets it."),
                (60...71,   "Thigh muscle is held by testosterone and by load together. The hormone raises the ceiling; training decides how much of it you occupy."),
                (72...83,   "Each day, androgen signalling keeps nitrogen retention and protein synthesis elevated in quadriceps and hamstrings above their untreated rate."),
                (84...95,   "Walking speed, stair power and fall risk all rest on this tissue. It responds to disuse within weeks."),
                (96...119,  "At this tenure, lean mass and grip or leg strength are the measures that predict later function. Both are trainable at any tenure."),
                (120...143, "A decade in, thigh composition tracks training in follow-up. Age-related lean mass decline begins gradually around this stage."),
                (144...179, "At twelve to fifteen years, loaded lower-body work offsets most of the age-related decline. Testosterone supports the process without replacing it."),
                (180...239, "Fifteen to twenty years is near the edge of the published record. Leg composition holds across it where training was sustained."),
                (240...600, "Past twenty years the longitudinal data on limb composition is sparse. The physiology is well described; the decades-long picture is being studied."),
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
