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
            return "Changes to the \(label.lowercased()) are about to begin as hormone levels rise and receptors activate."
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
        return "Your brain's neural architecture is fully adapted. Consistent hormone levels maintain ongoing neuroprotection, synaptic health, and emotional stability — a continuous, active state."
    }

    static func bodyInsight(months: Int) -> String {
        if months < 3  { return "Fat redistribution hasn't begun yet. As estrogen levels rise, your body will gradually shift from android-pattern to gynoid-pattern fat storage — driven by ER-α activation in subcutaneous adipocytes." }
        if months < 12 { return "Early redistribution is underway. Estrogen is directing new fat to the hips, glutes, and thighs. Visceral fat is also beginning to decrease as testosterone is suppressed." }
        if months < 36 { return "Peak redistribution period. Your body shape is actively changing — hip circumference is increasing, waist is narrowing, and gynoid fat pads are expanding. This is the most visibly dynamic phase." }
        if months < 60 { return "Body contours are maturing. The 2–3 year adipocyte cell-turnover cycle means subtle refinements continue, but the major structural changes in fat distribution are largely complete." }
        return "Your body composition is fully established. Fat distribution patterns are maintained through ongoing estrogen — consistent levels prevent reversion to android-pattern storage."
    }
}
