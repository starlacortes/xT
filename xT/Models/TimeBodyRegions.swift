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

    /// Per-month factual focus sentences. Keyed by small month-bands so every
    /// month surfaces a fresh, research-backed tissue-level fact even when the
    /// phase label and tier copy are unchanged. `nil` falls back to `phaseText`.
    let monthFocus: [(ClosedRange<Int>, String)]

    /// Non-numeric phase label — replaces the old `% underway / % complete`
    /// badge. Four states keyed to the existing start/peak/complete boundaries.
    func phaseLabel(at months: Int) -> String {
        if months < startMonth {
            return String(localized: "Begins month \(startMonth)",
                          comment: "Phase label before a region's changes start")
        }
        if months < peakMonth {
            return String(localized: "Active · peak ahead",
                          comment: "Phase label during early active change before peak")
        }
        if months < completeMonth {
            return String(localized: "Maturing · peak passed",
                          comment: "Phase label after peak velocity but before maturity")
        }
        return String(localized: "Established month \(months)+",
                      comment: "Phase label once a region's changes are established")
    }

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
            monthFocus: [
                (1...2,  "ER-α and ER-β receptors in the PFC are upregulating in response to rising estradiol. Cerebral blood flow is measurably increasing — one of the earliest neural effects."),
                (3...5,  "Dopaminergic tone in the PFC is shifting. Early cognitive effects — slight changes in decision-making style and emotional regulation — are neurochemically underway even where they aren't yet consciously noticeable."),
                (6...8,  "Working-memory benchmarks typically show measurable improvement in this window as PFC circuits adapt to the new dopaminergic baseline."),
                (9...11, "Cognitive flexibility gains are typically consolidating. The PFC's adaptation to estrogen-dominant signaling is well past its initial adjustment phase."),
                (12...17,"PFC function is in the refinement phase. The major neurochemical recalibration is done; remaining change is subtle circuit-level tuning."),
                (18...23,"PFC circuits are operating in their settled configuration. Executive function and emotional top-down control reflect the new hormonal environment."),
                (24...35,"The PFC is fully adapted. Estrogen-maintained dopaminergic signaling is the steady state — no further recalibration is expected."),
                (36...59,"PFC function is stable and maintained by consistent estradiol. Cognitive health from here tracks age, not HRT duration."),
                (60...120,"Years of estrogen-dominant PFC signaling. Age-appropriate cognitive screening is what tracks brain health from this stage."),
            ]
        ),
        BodyRegion(
            key: "hippocampus",
            label: "Hippocampus",
            icon: "waveform.path.ecg",
            startMonth: 1, peakMonth: 24, completeMonth: 48,
            earlyText: "Estradiol rapidly upregulates BDNF in the hippocampus. Synaptogenesis begins — new dendritic spines are sprouting on CA1 pyramidal neurons within the first month.",
            midText: "Hippocampal volume is measurably increasing due to estrogen-driven neurogenesis in the dentate gyrus. Spine density in CA1 has increased ~30%. Verbal memory and spatial navigation show measurable improvements.",
            lateText: "The hippocampus has fully adapted. Estrogen-mediated neuroprotection is ongoing — sustained BDNF signaling, enhanced synaptic plasticity, and reduced oxidative stress.",
            monthFocus: [
                (1...2,  "Estradiol is upregulating BDNF expression in the hippocampus. New dendritic spines are forming on CA1 pyramidal neurons within the first weeks — structural brain change is already underway."),
                (3...5,  "Synaptogenesis is active. CA1 spine density is increasing measurably, and verbal-memory benchmarks can begin showing early gains in this window."),
                (6...8,  "Dentate gyrus neurogenesis is contributing to measurable hippocampal volume increase. Spatial navigation tasks often show improvement alongside verbal memory."),
                (9...11, "Hippocampal volume gain is approaching its mid-phase. BDNF signaling remains elevated, supporting continued spine formation."),
                (12...17,"Verbal-memory benchmarks are typically at their most improved in this window. The structural changes supporting them — spine density, volume — are well established."),
                (18...23,"Hippocampal adaptation is in its later phase. Volume gains are decelerating but BDNF-mediated neuroprotection is sustained."),
                (24...35,"CA1 spine density is near its peak (~30% increase). The hippocampus is operating in its near-fully-adapted state."),
                (36...47,"Hippocampal volume has plateaued. Estrogen's role from here is neuroprotective — maintaining the adapted structure rather than driving further growth."),
                (48...59,"The hippocampus is fully adapted. Ongoing BDNF signaling maintains synaptic health and plasticity as a steady state."),
                (60...120,"Years of estrogen-maintained hippocampal neuroprotection. Cognitive screening tracks age-related change from here."),
            ]
        ),
        BodyRegion(
            key: "amygdala",
            label: "Amygdala",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 12, completeMonth: 24,
            earlyText: "Estrogen begins modulating amygdala reactivity. Emotional intensity may feel heightened as the amygdala adjusts to reduced testosterone and increasing estradiol signaling.",
            midText: "Amygdala response patterns are shifting. Many report a richer emotional range — increased empathy, deeper emotional recall, and a qualitative change in how emotions are experienced.",
            lateText: "Amygdala function has stabilized. Emotional responses are well-calibrated to the new hormonal environment. The initial recalibration period is largely complete.",
            monthFocus: [
                (1...2,  "Estrogen is beginning to modulate amygdala reactivity. Emotional intensity may feel heightened — the amygdala is recalibrating to the new hormonal context."),
                (3...5,  "Amygdala response patterns are actively shifting. Many describe a richer emotional range emerging — increased empathy and deeper emotional recall are commonly reported here."),
                (6...8,  "The qualitative change in emotional experience is typically most noticeable in this window. Amygdala recalibration is well past its initial phase."),
                (9...11, "Emotional range is broadening further but the rate of change is slowing. The amygdala is approaching its recalibrated baseline."),
                (12...17,"Amygdala function is stabilizing. The initial recalibration period is largely complete — emotional responses reflect the new estrogen-dominant environment."),
                (18...23,"Emotional responses are well-calibrated. Remaining change is subtle circuit-level refinement."),
                (24...35,"Amygdala recalibration is complete. The emotional landscape is stable and maintained by consistent estradiol."),
                (36...59,"Emotional baseline is fully established. Mood variation from here tracks dose-cycle timing and life circumstances, not ongoing adaptation."),
                (60...120,"Years of stable estrogen-dominant emotional processing. The amygdala's recalibration is long complete."),
            ]
        ),
        BodyRegion(
            key: "synaptic",
            label: "Synaptic Plasticity",
            icon: "sparkles",
            startMonth: 1, peakMonth: 18, completeMonth: 60,
            earlyText: "Estrogen rapidly enhances long-term potentiation (LTP) in hippocampal and cortical synapses. NMDA receptor expression increases within the first weeks, priming circuits for remodelling.",
            midText: "Synaptic density is actively increasing across limbic and cortical regions. Estrogen promotes dendritic spine formation via CREB-mediated gene transcription — structural brain change is underway.",
            lateText: "Synaptic architecture has fully remodelled. The enhanced plasticity state is maintained through ongoing estrogen — a continuous, active process supported by consistent hormone levels.",
            monthFocus: [
                (1...2,  "NMDA receptor expression is upregulating in hippocampal and cortical synapses. Long-term potentiation (LTP) is enhanced — circuits are primed for remodelling."),
                (3...5,  "Dendritic spine formation is active via CREB-mediated gene transcription. Structural brain change is measurably underway across limbic regions."),
                (6...8,  "Synaptic density is measurably increasing. The remodelling is broad — both hippocampal and cortical circuits are being reshaped simultaneously."),
                (9...11, "Spine formation rate is high but beginning to decelerate. The architecture being laid down now is the foundation for the adapted state."),
                (12...17,"Synaptic density is approaching its plateau. The remodelling phase is giving way to the maintenance phase."),
                (18...23,"Synaptic architecture is largely remodelled. Estrogen's role shifts from building to maintaining — enhanced plasticity is now a steady-state feature."),
                (24...35,"The enhanced plasticity state is maintained through ongoing estrogen. This is a continuous, active process — consistent dosing is what sustains it."),
                (36...47,"Synaptic architecture is mature. BDNF-mediated neuroprotection is the primary ongoing mechanism."),
                (48...59,"The remodelled architecture is fully established. Estrogen maintains synaptic health and plasticity as an active steady state."),
                (60...120,"Years of estrogen-maintained synaptic architecture. The enhanced plasticity state is embedded and sustained by consistent hormone levels."),
            ]
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
            monthFocus: [
                (3...5,  "Estrogen is activating ER-α receptors in gluteofemoral adipocytes. Lipoprotein lipase (LPL) activity is rising in hip/thigh depots, directing new fat storage to gynoid pattern."),
                (6...8,  "Subcutaneous fat is actively depositing at the iliac crest and greater trochanter. Waist circumference may begin narrowing as androgenic visceral fat recedes."),
                (9...11, "Hip-to-waist ratio is shifting measurably. New gynoid-pattern adipocytes are maturing while older androgen-pattern cells continue being cleared."),
                (12...17,"Adipocyte turnover is mid-cycle. New fat cells laid down since month 3 are maturing in gynoid pattern; the 2–3 year cell turnover cycle is ~50% through its first complete pass."),
                (18...23,"The major structural shift in hip-to-waist ratio is largely done. Remaining change is refinement as the adipocyte turnover cycle completes."),
                (24...35,"Adipocyte turnover is ~80% through its first full cycle. New fat deposited from here is essentially all estrogen-pattern; remaining change is subtle."),
                (36...47,"Fat redistribution is established. The gynoid pattern is maintained by consistent estradiol — weight cycling will still deposit new fat in this pattern."),
                (48...59,"Body composition is fully estrogen-dominant. Maintenance from here depends on continued dosing, not additional time."),
                (60...120,"Years of estrogen-dominant fat distribution. The pattern is embedded; weight changes still follow gynoid deposition."),
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
            monthFocus: [
                (4...5,  "Subcutaneous fat is beginning to accumulate on outer and inner thighs. LPL activity in gluteofemoral depots is rising."),
                (6...8,  "Thigh circumference is beginning to increase measurably. Inner-thigh fat pads are starting to develop."),
                (9...11, "Inner-thigh fat pads are visibly forming — a hallmark of estrogen-dominant composition. Pants fit is likely changing."),
                (12...17,"Thigh fat distribution is in its active phase. The curve from hip to knee is becoming more defined as gynoid-pattern deposition continues."),
                (18...23,"The major change in thigh contour is largely complete. Remaining refinement tracks the adipocyte turnover cycle."),
                (24...35,"Thigh fat distribution is approaching its established pattern. The gynoid contour is well-defined."),
                (36...47,"Thigh distribution is established and maintained by consistent estradiol."),
                (48...59,"Fully estrogen-dominant thigh composition. The pattern is stable."),
                (60...120,"Years of gynoid-pattern thigh distribution. Maintained by ongoing estrogen."),
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
            monthFocus: [
                (3...5,  "Androgenic visceral fat is beginning to recede as testosterone is suppressed. The belly may soften slightly before any visible hip change."),
                (6...8,  "Visceral fat reduction is measurable. Subcutaneous abdominal fat is shifting away from the android pattern — the waistline is starting to read softer."),
                (9...11, "The android-to-gynoid shift in abdominal fat is well underway. Combined with hip gains, the waist-to-hip ratio is changing noticeably."),
                (12...17,"Abdominal fat distribution is approaching its estrogen-dominant pattern. The visceral reduction is largely complete."),
                (18...23,"Abdominal pattern is stabilizing. Remaining change is subtle refinement."),
                (24...35,"Abdominal fat distribution is established in its estrogen-dominant pattern."),
                (36...47,"The estrogen-dominant abdominal pattern is maintained by consistent hormone levels."),
                (48...59,"Stable. Weight changes from here follow estrogen-pattern deposition."),
                (60...120,"Years of estrogen-dominant abdominal distribution."),
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
            monthFocus: [
                (3...5,  "Gluteal fat deposition is beginning — often subtle. LPL activity in gluteal depots is rising as estrogen directs storage here."),
                (6...8,  "Gluteal fat pads are starting to expand. Pants fit in the seat may change before any visible profile difference."),
                (9...11, "Gluteal expansion is becoming noticeable. Combined with hip changes, the posterior profile is shifting."),
                (12...17,"Gluteal fat pads are actively expanding. The silhouette change is most visible in this window."),
                (18...23,"The rate of gluteal expansion is decelerating but still active. The major structural change is largely done."),
                (24...35,"Gluteal distribution is maturing. The adipocyte turnover cycle is still completing — subtle refinements continue."),
                (36...47,"Gluteal distribution is approaching maturity. The 2–3 year cell turnover cycle is near completion."),
                (48...59,"Gluteal distribution is mature. Remaining change is minimal."),
                (60...120,"Years of estrogen-dominant gluteal distribution. Fully established."),
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
            monthFocus: [
                (1...2,  "Breast bud formation is beginning. Ductal tissue is forming beneath the areola — the very first stage of Tanner 2."),
                (3...5,  "Tanner stage 2 is establishing. Areolar tissue is more sensitive; the breast bud is palpable. Glandular tissue is actively forming."),
                (6...8,  "Tanner stage 2–3 transition. The breast mound is expanding beyond the areola. Montgomery glands may begin developing."),
                (9...11, "Tanner stage 3 is typically reached here. The breast mound is distinctly elevated. Growth is non-linear — plateaus and spurts are normal."),
                (12...17,"Tanner stage 3–4 transition. The areola and papilla form a secondary mound (stage 4) in many people. The ductal-lobular system is actively developing."),
                (18...23,"Tanner stage 4 is typically reached. The breast mound is mature in shape; internal ductal-lobular development continues."),
                (24...35,"Breast growth's visible phase is largely complete. Internal ductal-lobular maturation continues through year 3–5 — this is slow refinement, not visible change."),
                (36...47,"Ductal-lobular system is in its final maturation phase. Breast tissue is approaching full maturity."),
                (48...59,"Breast maturation is approaching completion. Full maturity may take up to 60 months."),
                (60...120,"Breast development is complete. The ductal-lobular system is fully mature and maintained by consistent estradiol."),
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
            monthFocus: [
                (1...2,  "Androgen receptors in the PFC are activating in response to rising testosterone. Early shifts in decision-making style may be noticeable but are variable dose to dose."),
                (3...5,  "PFC circuits are actively adapting. A shift toward more direct, linear thought processing is commonly reported in this window."),
                (6...8,  "Executive processing patterns are settling into their androgen-adapted configuration. Day-to-day variability is decreasing."),
                (9...11, "PFC adaptation is approaching its settled state. The shift toward more decisive processing is typically stable by now."),
                (12...17,"PFC function is in its refinement phase. The major neural adaptation is done; remaining change is subtle."),
                (18...23,"The PFC is operating in its settled androgen-dominant configuration."),
                (24...35,"PFC function is fully adapted. Cognitive patterns reflect the androgen-dominant environment as a steady state."),
                (36...59,"Stable. Androgen-maintained executive processing is the ongoing baseline."),
                (60...120,"Years of androgen-dominant PFC signaling. Cognitive health from here tracks age."),
            ]
        ),
        BodyRegion(
            key: "hippocampus",
            label: "Hippocampus",
            icon: "waveform.path.ecg",
            startMonth: 1, peakMonth: 12, completeMonth: 24,
            earlyText: "Testosterone acts on androgen receptors densely expressed in the hippocampus. Androgen-administration research links this to measurable gains in spatial navigation and mental rotation tasks, though individual variation is wide.",
            midText: "Spatial memory and navigation performance are commonly reported to improve over this window, consistent with androgen-receptor-mediated support for hippocampal circuitry. Verbal memory shows less consistent change than the spatial gains.",
            lateText: "Hippocampal adaptation to sustained testosterone is complete. Spatial-cognition benefits associated with androgen exposure are maintained for as long as levels stay in range.",
            monthFocus: [
                (1...2,  "Androgen receptors in the hippocampus are activating. Spatial navigation and mental rotation tasks may begin showing early gains."),
                (3...5,  "Spatial memory performance is commonly reported to improve in this window. Androgen-receptor-mediated support for hippocampal circuitry is active."),
                (6...8,  "Spatial cognition gains are typically consolidating. Verbal memory shows less consistent change than the spatial gains."),
                (9...11, "Hippocampal adaptation is approaching its settled state. Spatial-cognition benefits are well established."),
                (12...17,"The hippocampus is in its refinement phase. Major adaptation is complete."),
                (18...23,"Hippocampal function is operating in its settled androgen-adapted configuration."),
                (24...35,"Hippocampal adaptation is complete. Spatial-cognition benefits are maintained by consistent testosterone."),
                (36...59,"Stable. Androgen-maintained hippocampal function is the ongoing baseline."),
                (60...120,"Years of androgen-dominant hippocampal signaling. Cognitive health from here tracks age."),
            ]
        ),
        BodyRegion(
            key: "amygdala",
            label: "Amygdala",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 9, completeMonth: 18,
            earlyText: "Testosterone begins modulating amygdala reactivity to emotionally charged and threat-related stimuli. This is an active area of neuroendocrine research, and effects on emotional reactivity vary between individuals rather than following one fixed pattern.",
            midText: "Functional imaging studies of exogenous testosterone report blunted amygdala response to distressing stimuli. Many trans masculine people describe feeling less easily moved to tears and more emotionally contained during this window — a commonly reported experience, not a guaranteed one.",
            lateText: "Amygdala reactivity has recalibrated to the androgen-dominant hormonal environment. Where a shift toward a more contained emotional response occurred, it's typically stable from here.",
            monthFocus: [
                (1...2,  "Testosterone is beginning to modulate amygdala reactivity to emotional stimuli. Effects vary between individuals rather than following one fixed pattern."),
                (3...5,  "Amygdala reactivity to distressing stimuli is shifting. Many describe feeling less easily moved to tears and more emotionally contained in this window."),
                (6...8,  "The shift toward more contained emotional response is typically stabilizing. Functional imaging shows blunted amygdala response to distressing stimuli."),
                (9...11, "Amygdala recalibration is approaching its settled state. Where a shift occurred, it's typically stable from here."),
                (12...17,"Amygdala reactivity is stable in its androgen-adapted pattern."),
                (18...23,"Fully recalibrated. The androgen-dominant emotional baseline is maintained by consistent testosterone."),
                (24...35,"Stable. Emotional processing reflects the androgen-dominant environment as a steady state."),
                (36...59,"Stable. Androgen-maintained emotional processing is the ongoing baseline."),
                (60...120,"Years of androgen-dominant amygdala signaling."),
            ]
        ),
        BodyRegion(
            key: "synaptic",
            label: "Synaptic Plasticity",
            icon: "sparkles",
            startMonth: 1, peakMonth: 12, completeMonth: 36,
            earlyText: "Androgen receptor activation begins promoting dendritic spine formation in the hippocampus and cortex — a process distinct from, but analogous to, estrogen's effect on synaptic density. Testosterone can also be locally converted to estradiol via aromatase in some brain regions, adding a second signaling pathway.",
            midText: "Spine density continues increasing in androgen-receptor-rich regions. The dual pathway — direct androgen receptor signaling plus local aromatization to estradiol — means testosterone's neural effects aren't purely androgenic; both signaling routes are active in the brain at once.",
            lateText: "Synaptic architecture has stabilized under sustained testosterone exposure. The combined androgen and local-estrogen signaling that developed over the past several years is now the steady state your brain operates on.",
            monthFocus: [
                (1...2,  "Androgen receptor activation is promoting dendritic spine formation in hippocampal and cortical circuits. Aromatase is also converting some testosterone to estradiol locally — both signaling pathways are active."),
                (3...5,  "Spine density is measurably increasing in androgen-receptor-rich regions. The dual androgen-plus-local-estrogen pathway is fully active."),
                (6...8,  "Synaptic density is approaching its plateau. The remodelling phase is well established."),
                (9...11, "Spine formation rate is decelerating. The architecture being laid down is the foundation for the adapted state."),
                (12...17,"Synaptic architecture is approaching its settled state. The remodelling phase is giving way to maintenance."),
                (18...23,"The androgen-adapted architecture is largely in place. Estrogen's role from here is maintaining, not building."),
                (24...35,"Synaptic architecture is stabilized under sustained testosterone. The combined androgen and local-estrogen signaling is the steady state."),
                (36...59,"Fully stabilized. The neural architecture is maintained by consistent testosterone."),
                (60...120,"Years of androgen-maintained synaptic architecture."),
            ]
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
            monthFocus: [
                (3...5,  "Pectoral muscle androgen receptors are activating. With resistance training, early hypertrophy is measurable. Chest-wall hair follicles are being primed by DHT but haven't yet produced terminal hair."),
                (6...8,  "Pectoral muscle mass is measurably increasing with training, broadening the chest wall. Chest hair is beginning to appear, following the body-hair timeline (legs/abdomen first)."),
                (9...11, "Chest-wall broadening is well underway. DHT-driven chest hair is typically visible by now, in the same pattern as the abdomen."),
                (12...17,"Pectoral development is approaching its training-stimulus ceiling. Chest hair continues filling in."),
                (18...23,"Chest muscle has largely matched its training stimulus. Further growth depends on progressive overload, not additional time on T."),
                (24...29,"Chest hair, where it develops, is fully in and permanent. Muscle is maintained by training and T."),
                (30...47,"Chest development is established. Muscle tracks training; hair is permanent."),
                (48...59,"Stable. Pectoral mass is maintained by T and training; hair pattern is permanent."),
                (60...120,"Years of androgen-dominant chest development. Fully established."),
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
            monthFocus: [
                (3...5,  "Fat storage is shifting toward an androgenic, abdomen-leaning pattern. Androgen receptor signaling in visceral and subcutaneous fat is redirecting deposition."),
                (6...8,  "Abdominal fat accumulation is measurable. Combined with shoulder broadening, the silhouette is shifting even where waist circumference hasn't changed much."),
                (9...11, "The androgenic fat pattern is establishing. Core muscle definition may increase with resistance training."),
                (12...17,"Abdominal composition is well into its androgenic pattern. The redistribution effect is approaching completion."),
                (18...23,"Fat distribution is settling into its androgen-dominant pattern. Remaining change is subtle."),
                (24...29,"Abdominal pattern is largely established. From here, belly size tracks diet and training, not T duration."),
                (30...47,"Androgenic fat distribution is complete. Abdominal size tracks diet, training and age."),
                (48...59,"Stable. The androgenic pattern is maintained by consistent T."),
                (60...120,"Years of androgen-dominant abdominal distribution."),
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
            monthFocus: [
                (1...2,  "Hip bone structure is fixed. The visual proportion is shifting because of what's happening around the hips — abdominal fat and shoulder broadening."),
                (3...5,  "The waistline is beginning to thicken as abdominal fat accumulates. Hip circumference itself is unchanged."),
                (6...8,  "The hip-to-shoulder ratio is shifting as shoulders and chest broaden. The hips read narrower by proportion, not by actual change."),
                (9...11, "The silhouette shift is becoming pronounced. The masculinized proportion comes from the upper body and abdomen, not from hip reduction."),
                (12...17,"Hip proportions are stabilizing. The silhouette is defined by shoulder/chest/abdominal changes around a structurally unchanged hip."),
                (18...23,"The masculinized silhouette is largely set. Remaining change is in upper body and abdominal refinement."),
                (24...29,"Hip proportions are stable and were never expected to change structurally. The silhouette comes from shoulders, chest and abdomen."),
                (30...47,"Fully established. The masculinized silhouette is maintained by consistent T."),
                (48...59,"Stable."),
                (60...120,"Years of androgen-dominant proportions."),
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
            monthFocus: [
                (3...5,  "Gluteal muscle androgen receptors are activating. With resistance training, early hypertrophy is measurable. Without training, T alone produces little change here."),
                (6...8,  "Gluteal muscle mass is measurably increasing with consistent training. This is a muscle response, not a fat redistribution response."),
                (9...11, "Gluteal hypertrophy is well underway with training. Strength gains in squats/leg press are typically rapid in this window."),
                (12...17,"Gluteal muscle is approaching its training-stimulus ceiling. Further growth depends on progressive overload."),
                (18...23,"Gluteal muscle has largely matched its training stimulus. T maintains the baseline; training drives further gain."),
                (24...29,"Gluteal development is established. Muscle mass is maintained by T and training."),
                (30...47,"Stable. Gluteal mass is maintained by consistent T and training stimulus."),
                (48...59,"Stable."),
                (60...120,"Years of androgen-maintained gluteal muscle."),
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
            monthFocus: [
                (2...5,  "Quadriceps and hamstrings are responding to testosterone's anabolic signal. With resistance training, measurable hypertrophy is common within the first few months."),
                (6...8,  "Thigh muscle growth is often the most visible lower-body change on T. Strength gains here frequently outpace upper-body gains early on."),
                (9...11, "Type II fiber hypertrophy is well established with training. The anabolic response is near its peak velocity."),
                (12...17,"Satellite-cell activation from androgen signaling is plateauing for untrained fibers. Further hypertrophy from here is driven by progressive overload, not additional time on T."),
                (18...23,"Thigh muscle has typically plateaued relative to training stimulus. Continued growth tracks training, not T duration."),
                (24...27,"Thigh development is established. Muscle mass is maintained by T and training."),
                (28...47,"Stable. Thigh mass is maintained by consistent T and progressive overload."),
                (48...59,"Stable."),
                (60...120,"Years of androgen-maintained thigh muscle."),
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

    private static func hipSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 3 { phase = "Pre-deposition" }
        else if months < 18 { phase = "Active deposition" }
        else if months < 36 { phase = "Maturing" }
        else { phase = "Established" }
        return (phase, "Hips / Waist", months < 36 ? "Gynoid pattern forming" : "Gynoid pattern stable")
    }

    private static func abdomenSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 3 { phase = "Pre-shift" }
        else if months < 12 { phase = "Visceral receding" }
        else if months < 24 { phase = "Pattern shifting" }
        else { phase = "Established" }
        return (phase, "Abdomen", months < 24 ? "Android pattern clearing" : "Estrogen-pattern stable")
    }

    private static func glutesSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 3 { phase = "Pre-deposition" }
        else if months < 24 { phase = "Depot expanding" }
        else if months < 48 { phase = "Maturing" }
        else { phase = "Established" }
        return (phase, "Glutes", months < 48 ? "Adipocyte turnover active" : "Distribution mature")
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
        let phase: String
        if months < 3 { phase = "Pre-growth" }
        else if months < 14 { phase = "Hypertrophy phase" }
        else if months < 30 { phase = "Maturing" }
        else { phase = "Established" }
        return (phase, "Chest", months < 30 ? "Pectoral + hair developing" : "Muscle + hair permanent")
    }

    private static func abdomenSignalT(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 3 { phase = "Pre-shift" }
        else if months < 18 { phase = "Androgenic depositing" }
        else if months < 36 { phase = "Pattern settling" }
        else { phase = "Established" }
        return (phase, "Abdomen Shift", months < 36 ? "Androgenic pattern forming" : "Pattern stable")
    }

    private static func thighsSignalT(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 2 { phase = "Pre-growth" }
        else if months < 14 { phase = "Hypertrophy phase" }
        else if months < 28 { phase = "Maturing" }
        else { phase = "Established" }
        return (phase, "Thighs", months < 28 ? "Type II fiber growth" : "Training-dependent")
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
        let phase: String
        if months < 1 { phase = "Pre-activation" }
        else if months < 18 { phase = "Spine formation" }
        else if months < 60 { phase = "Architecture maturing" }
        else { phase = "Established" }
        return (phase, "Synaptic Density", months < 18 ? "NMDA upregulated, spines forming" : "Remodelled and maintained")
    }

    private static func hippocampalSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 1 { phase = "Pre-activation" }
        else if months < 24 { phase = "Neurogenesis active" }
        else if months < 48 { phase = "Volume plateauing" }
        else { phase = "Fully adapted" }
        return (phase, "Hippocampal Vol.", months < 48 ? "BDNF-driven volume gain" : "Neuroprotective steady state")
    }

    private static func bdnfSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 1 { phase = "Baseline" }
        else if months < 12 { phase = "Upregulated" }
        else if months < 36 { phase = "Sustained elevation" }
        else { phase = "Maintenance" }
        return (phase, "BDNF Activity", months < 12 ? "Rising, driving neuroplasticity" : "Elevated, neuroprotective")
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
        let phase: String
        if months < 1 { phase = "Pre-activation" }
        else if months < 12 { phase = "AR upregulating" }
        else if months < 24 { phase = "Plateauing" }
        else { phase = "Established" }
        return (phase, "AR Activation", months < 12 ? "Receptors responding to T" : "Steady androgen signaling")
    }

    private static func spatialCognitionSignal(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 1 { phase = "Baseline" }
        else if months < 18 { phase = "Gains emerging" }
        else if months < 36 { phase = "Gains consolidated" }
        else { phase = "Maintained" }
        return (phase, "Spatial Cognition", months < 18 ? "Improving, AR-mediated" : "Stable, maintained by T")
    }

    private static func amygdalaReactivitySignal(_ months: Int) -> (value: String, label: String, sub: String) {
        let phase: String
        if months < 1 { phase = "Baseline" }
        else if months < 9 { phase = "Reactivity shifting" }
        else if months < 18 { phase = "Stabilizing" }
        else { phase = "Stabilized" }
        return (phase, "Amygdala Reactivity", months < 9 ? "Blunting response to stimuli" : "Androgen-adapted baseline")
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
