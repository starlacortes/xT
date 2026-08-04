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

    func progressStatus(at months: Int) -> String {
        if months < startMonth { return "Starts M\(startMonth)" }
        if months >= completeMonth { return "Established" }
        let pct = Int(Double(months - startMonth) / Double(completeMonth - startMonth) * 100)
        return months < peakMonth ? "\(pct)% underway" : "\(pct)% complete"
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
}

// MARK: - Static Region Data

enum TimeBodyRegions {

    // MARK: Mind

    static let mindRegions: [BodyRegion] = [
        BodyRegion(
            key: "pfc",
            label: "Prefrontal Cortex",
            icon: "brain.head.profile",
            startMonth: 1, peakMonth: 18, completeMonth: 36,
            earlyText: "Estrogen receptors (ER-α, ER-β) in the PFC begin responding to rising estradiol. Cerebral blood flow increases measurably, supporting early shifts in executive function and working memory.",
            midText: "Dopaminergic signaling in the PFC is modulated by estrogen. Many report improved cognitive flexibility, enriched emotional regulation, and a qualitative shift in how decisions feel — less analytical, more integrative.",
            lateText: "PFC function has stabilized. The neural circuits governing executive function and emotional top-down control are fully adapted to the estrogen-dominant neurochemical environment."
        ),
        BodyRegion(
            key: "hippocampus",
            label: "Hippocampus",
            icon: "waveform.path.ecg",
            startMonth: 1, peakMonth: 24, completeMonth: 48,
            earlyText: "Estradiol rapidly upregulates BDNF in the hippocampus. Synaptogenesis begins — new dendritic spines are sprouting on CA1 pyramidal neurons within the first month.",
            midText: "Hippocampal volume is measurably increasing due to estrogen-driven neurogenesis in the dentate gyrus. Spine density in CA1 has increased ~30%. Verbal memory and spatial navigation show measurable improvements.",
            lateText: "The hippocampus has fully adapted. Estrogen-mediated neuroprotection is ongoing — sustained BDNF signaling, enhanced synaptic plasticity, and reduced oxidative stress."
        ),
        BodyRegion(
            key: "amygdala",
            label: "Amygdala",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 12, completeMonth: 24,
            earlyText: "Estrogen begins modulating amygdala reactivity. Emotional intensity may feel heightened as the amygdala adjusts to reduced testosterone and increasing estradiol signaling.",
            midText: "Amygdala response patterns are shifting. Many report a richer emotional range — increased empathy, deeper emotional recall, and a qualitative change in how emotions are experienced.",
            lateText: "Amygdala function has stabilized. Emotional responses are well-calibrated to the new hormonal environment. The initial recalibration period is largely complete."
        ),
        BodyRegion(
            key: "synaptic",
            label: "Synaptic Plasticity",
            icon: "sparkles",
            startMonth: 1, peakMonth: 18, completeMonth: 60,
            earlyText: "Estrogen rapidly enhances long-term potentiation (LTP) in hippocampal and cortical synapses. NMDA receptor expression increases within the first weeks, priming circuits for remodelling.",
            midText: "Synaptic density is actively increasing across limbic and cortical regions. Estrogen promotes dendritic spine formation via CREB-mediated gene transcription — structural brain change is underway.",
            lateText: "Synaptic architecture has fully remodelled. The enhanced plasticity state is maintained through ongoing estrogen — a continuous, active process supported by consistent hormone levels."
        ),
    ]

    // MARK: Body

    static let bodyRegions: [BodyRegion] = [
        BodyRegion(
            key: "hips",
            label: "Hips & Pelvis",
            icon: "figure.stand",
            startMonth: 3, peakMonth: 18, completeMonth: 36,
            earlyText: "Estrogen begins redirecting subcutaneous fat to the hip and pelvic girdle. The iliac crest and greater trochanter become primary deposition sites.",
            midText: "Hip circumference is measurably increasing as gynoid-pattern fat distribution establishes. Combined with waist narrowing, the hip-to-waist ratio is significantly shifting.",
            lateText: "Fat redistribution to the hips is largely complete. The wider iliac span and fuller trochanteric profile are maintained through continued estrogen therapy."
        ),
        BodyRegion(
            key: "thighs",
            label: "Thighs",
            icon: "figure.walk",
            startMonth: 4, peakMonth: 20, completeMonth: 36,
            earlyText: "Subcutaneous fat begins accumulating on the outer and inner thighs. Pants may fit differently around the upper leg as gynoid-pattern deposition begins.",
            midText: "Thigh circumference increases measurably. Inner-thigh fat pads develop — a hallmark of estrogen-dominant body composition.",
            lateText: "Thigh fat distribution has stabilized at its estrogen-dominant pattern. The curve from hip to knee is well-defined and maintained with consistent hormone levels."
        ),
        BodyRegion(
            key: "waist",
            label: "Waist",
            icon: "arrow.up.and.down",
            startMonth: 3, peakMonth: 12, completeMonth: 24,
            earlyText: "Androgenic visceral fat begins to decrease as testosterone is suppressed. Your waist may narrow slightly before hip expansion becomes externally visible.",
            midText: "Waist circumference is actively decreasing relative to the hips. Visceral fat loss creates a more defined waistline and amplifies the hourglass effect.",
            lateText: "Waist contours have stabilized in a typically feminine range, maintained by ongoing estrogen exposure."
        ),
        BodyRegion(
            key: "glutes",
            label: "Glutes",
            icon: "oval.fill",
            startMonth: 3, peakMonth: 24, completeMonth: 48,
            earlyText: "Fat deposition begins in the gluteal region — often subtle at first. You might notice your pants fitting differently in the seat before any visible change.",
            midText: "Gluteal fat pads are actively expanding. Combined with pelvic rotation from ligament changes, your posterior profile and posture are changing noticeably.",
            lateText: "Gluteal distribution is mature. Subtle refinements may continue through year 4–5 as the 2–3 year adipocyte cell-turnover cycle completes."
        ),
        BodyRegion(
            key: "chest",
            label: "Chest",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 36, completeMonth: 60,
            earlyText: "Breast bud formation begins within the first weeks. Areolar tissue becomes more sensitive and the chest wall starts depositing glandular and fatty tissue beneath the nipple.",
            midText: "Breast growth is progressing through Tanner stages 2–4. Montgomery glands develop; the breast mound expands. Growth is not linear — expect plateaus and spurts.",
            lateText: "Breast maturation continues through year 3–5 as the ductal-lobular system completes development. Full maturity may take up to 60 months."
        ),
    ]

    // MARK: Stats

    static func mindStats(months: Int) -> [(value: String, label: String, sub: String)] {
        let m = Double(months)
        let syn  = 1.0 + min(1.0, m / 18.0) * 0.45
        let hipp = 1.0 + min(1.0, m / 48.0) * 0.12
        let bdnf = 1.0 + min(1.0, m / 12.0) * 0.50
        return [
            (String(format: "%.1fx", syn),  "Synaptic Density",  months >= 18 ? "Peak reached" : "Rising"),
            (String(format: "%.1fx", hipp), "Hippocampal Vol.",  months >= 48 ? "Fully adapted" : "Growing"),
            (String(format: "%.1fx", bdnf), "BDNF Activity",     months >= 12 ? "Peak reached" : "Rising"),
        ]
    }

    static func bodyStats(months: Int) -> [(value: String, label: String, sub: String)] {
        func pct(start: Int, complete: Int) -> Int {
            guard months >= start else { return 0 }
            if months >= complete { return 100 }
            return Int(Double(months - start) / Double(complete - start) * 100)
        }
        return [
            ("\(pct(start: 3, complete: 36))%",  "Hips",   months >= 36 ? "Established" : "Peak M18"),
            ("\(pct(start: 3, complete: 24))%",  "Waist",  months >= 24 ? "Established" : "Peak M12"),
            ("\(pct(start: 3, complete: 48))%",  "Glutes", months >= 48 ? "Established" : "Peak M24"),
        ]
    }

    // MARK: Insights

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

    // MARK: Body Region Callout Positions

    struct BodyRegionCallout {
        let key: String
        let xFrac: Double
        let yFrac: Double
    }

    static let bodyRegionCallouts: [BodyRegionCallout] = [
        BodyRegionCallout(key: "hips",   xFrac: 0.12, yFrac: 0.68),
        BodyRegionCallout(key: "thighs", xFrac: 0.11, yFrac: 0.88),
        BodyRegionCallout(key: "waist",  xFrac: 0.12, yFrac: 0.52),
        BodyRegionCallout(key: "glutes", xFrac: 0.13, yFrac: 0.78),
        BodyRegionCallout(key: "chest",  xFrac: 0.15, yFrac: 0.38),
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
            lateText: "PFC function has adapted to the androgen-dominant environment. The shift toward more direct executive processing is typically stable by this point, reflecting a settled circuit rather than an ongoing change."
        ),
        BodyRegion(
            key: "hippocampus",
            label: "Hippocampus",
            icon: "waveform.path.ecg",
            startMonth: 1, peakMonth: 12, completeMonth: 24,
            earlyText: "Testosterone acts on androgen receptors densely expressed in the hippocampus. Androgen-administration research links this to measurable gains in spatial navigation and mental rotation tasks, though individual variation is wide.",
            midText: "Spatial memory and navigation performance are commonly reported to improve over this window, consistent with androgen-receptor-mediated support for hippocampal circuitry. Verbal memory shows less consistent change than the spatial gains.",
            lateText: "Hippocampal adaptation to sustained testosterone is complete. Spatial-cognition benefits associated with androgen exposure are maintained for as long as levels stay in range."
        ),
        BodyRegion(
            key: "amygdala",
            label: "Amygdala",
            icon: "heart.fill",
            startMonth: 1, peakMonth: 9, completeMonth: 18,
            earlyText: "Testosterone begins modulating amygdala reactivity to emotionally charged and threat-related stimuli. This is an active area of neuroendocrine research, and effects on emotional reactivity vary between individuals rather than following one fixed pattern.",
            midText: "Functional imaging studies of exogenous testosterone report blunted amygdala response to distressing stimuli. Many trans masculine people describe feeling less easily moved to tears and more emotionally contained during this window — a commonly reported experience, not a guaranteed one.",
            lateText: "Amygdala reactivity has recalibrated to the androgen-dominant hormonal environment. Where a shift toward a more contained emotional response occurred, it's typically stable from here."
        ),
        BodyRegion(
            key: "synaptic",
            label: "Synaptic Plasticity",
            icon: "sparkles",
            startMonth: 1, peakMonth: 12, completeMonth: 36,
            earlyText: "Androgen receptor activation begins promoting dendritic spine formation in the hippocampus and cortex — a process distinct from, but analogous to, estrogen's effect on synaptic density. Testosterone can also be locally converted to estradiol via aromatase in some brain regions, adding a second signaling pathway.",
            midText: "Spine density continues increasing in androgen-receptor-rich regions. The dual pathway — direct androgen receptor signaling plus local aromatization to estradiol — means testosterone's neural effects aren't purely androgenic; both signaling routes are active in the brain at once.",
            lateText: "Synaptic architecture has stabilized under sustained testosterone exposure. The combined androgen and local-estrogen signaling that developed over the past several years is now the steady state your brain operates on."
        ),
    ]

    // MARK: - Body (Testosterone)

    /// Same region keys as `bodyRegions` (`chest`, `waist`, `hips`, `glutes`,
    /// `thighs`) so `bodyRegionCallouts` and the y-band tagging in
    /// `ConstellationCloud.body(months:)` keep working unmodified — only the
    /// meaning attached to each key differs by medication.
    static let bodyRegionsT: [BodyRegion] = [
        BodyRegion(
            key: "chest",
            label: "Chest",
            icon: "figure.strengthtraining.traditional",
            startMonth: 3, peakMonth: 14, completeMonth: 30,
            earlyText: "Androgen receptors in pectoral muscle begin responding to testosterone's anabolic signal, and 5\u{03B1}-reductase converts a share of testosterone to DHT in chest-wall hair follicles, priming them for terminal hair growth. Chest hair follows the same body-hair timeline as elsewhere — later than the legs and abdomen.",
            midText: "Pectoral muscle mass is measurably increasing with resistance training, broadening the chest wall. DHT-driven chest hair is typically visible by now, in the same pattern developing on the abdomen and back.",
            lateText: "Chest muscle development has largely matched its training stimulus by this point — further growth depends more on continued training than on additional time on T. Chest hair, where it develops, is fully in and permanent."
        ),
        BodyRegion(
            key: "waist",
            label: "Waist",
            icon: "arrow.up.and.down",
            startMonth: 3, peakMonth: 18, completeMonth: 36,
            earlyText: "Testosterone shifts fat storage toward a more androgenic, abdomen-leaning pattern as visceral and subcutaneous fat distribution responds to androgen receptor signaling — the reverse of estrogen's hip-and-thigh-directed pattern. Core muscle definition can also begin increasing with resistance training.",
            midText: "Waist composition continues shifting toward an androgenic pattern. Combined with broadening shoulders, this changes the overall silhouette even where absolute waist circumference doesn't move much.",
            lateText: "Fat distribution has settled into its androgen-dominant pattern. From here, waist size tracks diet, training and age the way it does for anyone — testosterone's redistribution effect is complete."
        ),
        BodyRegion(
            key: "hips",
            label: "Hips",
            icon: "figure.stand",
            startMonth: 1, peakMonth: 14, completeMonth: 30,
            earlyText: "Hip circumference doesn't meaningfully change on testosterone — bone structure is set by puberty, and androgens don't cause fat to redistribute away from the hips the way some expect. What does shift the visual proportion is above: broadening shoulders and fat redistributing toward the abdomen rather than away from the hips.",
            midText: "As shoulders and chest continue broadening, the hip-to-shoulder ratio that defines silhouette keeps shifting even though the hips themselves are largely unchanged in circumference.",
            lateText: "Hip proportions are stable and were never expected to change structurally. The masculinized silhouette at this point comes almost entirely from the shoulders, chest and fat redistribution above the waist."
        ),
        BodyRegion(
            key: "glutes",
            label: "Glutes",
            icon: "oval.fill",
            startMonth: 3, peakMonth: 18, completeMonth: 36,
            earlyText: "Gluteal muscle responds to testosterone's anabolic signal the same way any skeletal muscle does — androgen receptor activation supports protein synthesis and hypertrophy with resistance training. Unlike hip fat, this is a muscle response, so training stimulus matters more here than time on T alone.",
            midText: "With consistent resistance training, gluteal muscle mass is measurably increasing. Without training, testosterone alone produces comparatively little change in this region.",
            lateText: "Gluteal muscle has typically matched its training stimulus by this stage. As with any muscle group, further change from here depends on continued training rather than additional time on hormone therapy."
        ),
        BodyRegion(
            key: "thighs",
            label: "Thighs",
            icon: "figure.walk",
            startMonth: 2, peakMonth: 14, completeMonth: 28,
            earlyText: "Thigh muscle — quadriceps and hamstrings — responds to testosterone's anabolic effect on skeletal muscle, amplified by resistance or lower-body training. This is measurable within the first few months for many people.",
            midText: "Thigh size from muscle growth is often the most visible lower-body change on T, particularly with squat- or leg-press-style training. Strength gains here frequently outpace upper-body gains early on.",
            lateText: "Thigh muscle development has typically plateaued relative to training stimulus. Continued growth from here tracks progressive overload in training rather than time on testosterone."
        ),
    ]

    // MARK: - Stats (Testosterone)

    static func mindStatsT(months: Int) -> [(value: String, label: String, sub: String)] {
        let m = Double(months)
        let ar          = 1.0 + min(1.0, m / 12.0) * 0.55
        let spatial     = 1.0 + min(1.0, m / 18.0) * 0.20
        let reactivity  = max(0.55, 1.0 - min(1.0, m / 9.0) * 0.45)
        return [
            (String(format: "%.1fx", ar),         "AR Activation",       months >= 12 ? "Peak reached"  : "Rising"),
            (String(format: "%.1fx", spatial),     "Spatial Cognition",  months >= 18 ? "Plateaued"      : "Rising"),
            (String(format: "%.1fx", reactivity),  "Amygdala Reactivity", months >= 9  ? "Stabilized"    : "Declining"),
        ]
    }

    static func bodyStatsT(months: Int) -> [(value: String, label: String, sub: String)] {
        func pct(start: Int, complete: Int) -> Int {
            guard months >= start else { return 0 }
            if months >= complete { return 100 }
            return Int(Double(months - start) / Double(complete - start) * 100)
        }
        return [
            ("\(pct(start: 3, complete: 30))%",  "Chest",       months >= 30 ? "Established" : "Peak M14"),
            ("\(pct(start: 3, complete: 36))%",  "Waist Shift", months >= 36 ? "Established" : "Peak M18"),
            ("\(pct(start: 2, complete: 28))%",  "Thighs",      months >= 28 ? "Established" : "Peak M14"),
        ]
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
