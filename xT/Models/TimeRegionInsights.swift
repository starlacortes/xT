import Foundation

// MARK: - Region insight banks
//
// The second card slot. See `docs/App design/TIME_CARD_PERSONALIZATION.md` §6.
//
// NOW answers "what is this tissue doing this month" and moves on the region's
// own band grid, so it holds still for stretches at a time. INSIGHT is what
// makes month 11 differ from month 10 when the progression line has not moved:
// a pool of entries, one drawn per month by a selector that rotates.
//
// Two banks, one slot. MECHANISM is the pathway producing the change —
// receptors, enzymes, cascades. FACT is a concrete, surprising, true thing
// about the region under this hormone. `ChangeRate.prefersFact` picks between
// them, and whichever bank is empty falls through to the other.
//
// Both render in the same type at the same weight as NOW, in reading order.
// Neither is a callout, a "did you know", or an aside.

/// One entry in a region's insight bank, eligible for the months it names.
struct InsightEntry {
    let months: ClosedRange<Int>
    let text: String

    init(_ months: ClosedRange<Int>, _ text: String) {
        self.months = months
        self.text = text
    }
}

enum InsightBank {
    case mechanism
    case fact
}

struct RegionInsightBank {
    let mechanism: [InsightEntry]
    let fact: [InsightEntry]

    init(mechanism: [InsightEntry], fact: [InsightEntry] = []) {
        self.mechanism = mechanism
        self.fact = fact
    }

    func entries(_ bank: InsightBank) -> [InsightEntry] {
        switch bank {
        case .mechanism: return mechanism
        case .fact:      return fact
        }
    }
}

// MARK: - Selection

enum TimeRegionInsights {

    /// Deterministic per-region seed.
    ///
    /// FNV-1a over the region identifier, **not** `hashValue`: Swift seeds its
    /// hasher randomly per process, so a `hashValue` here would reshuffle every
    /// card on every launch. This is a pure function of the identifier and
    /// produces the same number on every device, every run.
    static func seed(track: JourneyContext.HormoneTrack, key: String) -> Int {
        var hash: UInt32 = 2_166_136_261
        for byte in identifier(track: track, key: key).utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int(hash & 0x7FFF_FFFF)
    }

    /// Draws one entry from a pool for a given month.
    ///
    /// Stable within a month — reopening the card does not reshuffle. Rotates
    /// every month, so months 10 and 11 draw different entries even where they
    /// share a NOW band. No persistence: a pure function of month and region,
    /// identical after a reinstall.
    static func select(from pool: [InsightEntry], month: Int, seed: Int) -> String? {
        let eligible = pool.filter { $0.months.contains(month) }
        guard !eligible.isEmpty else { return nil }
        return eligible[(max(0, month) &+ seed) % eligible.count].text
    }

    static func bank(track: JourneyContext.HormoneTrack, key: String) -> RegionInsightBank? {
        switch track {
        case .estrogen:     return estrogen[key]
        case .testosterone: return testosterone[key]
        }
    }

    /// The INSIGHT slot for one region at one month.
    ///
    /// Rate decides which bank is asked first; the other answers if the first
    /// has nothing eligible. The fact banks are empty until Phase D, so today
    /// every card resolves to mechanism copy.
    static func insight(
        track: JourneyContext.HormoneTrack,
        key: String,
        month: Int,
        rate: ChangeRate
    ) -> String? {
        guard let bank = bank(track: track, key: key) else { return nil }
        let order: [InsightBank] = rate.prefersFact ? [.fact, .mechanism] : [.mechanism, .fact]
        let regionSeed = seed(track: track, key: key)
        for candidate in order {
            if let text = select(from: bank.entries(candidate), month: month, seed: regionSeed) {
                return text
            }
        }
        return nil
    }

    private static func identifier(track: JourneyContext.HormoneTrack, key: String) -> String {
        switch track {
        case .estrogen:     return "e." + key
        case .testosterone: return "t." + key
        }
    }

    // MARK: Banks
    //
    // Mechanism copy describes the pathway, not the calendar, so every entry is
    // eligible at every month. That is deliberate: it keeps the register clean
    // (NOW carries the timeline, INSIGHT carries the biology) and it keeps the
    // eligible pool at full depth for a ten-year user as much as a new one.

    static let estrogen: [String: RegionInsightBank] = [
        "pfc": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "ER-α and ER-β sit densely in prefrontal tissue, where estradiol modulates dopamine release. Executive function runs on that dopaminergic tone."),
            InsightEntry(0...240, "Estradiol raises cerebral blood flow to the prefrontal cortex. More perfusion means more glucose reaching the tissue doing working-memory work."),
            InsightEntry(0...240, "Estrogen's fast effects here are non-genomic — membrane-bound receptors changing neuron excitability within minutes, before any gene is transcribed."),
            InsightEntry(0...240, "The prefrontal cortex is the last brain region to finish developing and the most plastic in adulthood. That is why hormonal signals reshape it at all."),
            InsightEntry(0...240, "Estradiol tunes GABAergic interneurons in the prefrontal cortex, adjusting how strongly the region inhibits itself. Emotional top-down control is largely an inhibition problem."),
        ]),
        "hippocampus": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Estradiol upregulates BDNF transcription in the hippocampus. BDNF is the growth factor keeping dendritic spines alive, so the signal is structural, not only chemical."),
            InsightEntry(0...240, "The dentate gyrus is one of two adult brain regions that make new neurons. Estrogen raises how many of those cells survive, not how many are born."),
            InsightEntry(0...240, "CA1 pyramidal neurons carry estrogen receptors on the dendrites themselves. Spine density there tracks estradiol closely enough to shift within a single cycle."),
            InsightEntry(0...240, "Estrogen enhances long-term potentiation — the strengthening of a synapse that fires repeatedly. That is the cellular event underneath forming a memory."),
            InsightEntry(0...240, "Estradiol supports mitochondrial function in hippocampal tissue and lowers oxidative stress. Neuroprotection here is metabolic before it is anything else."),
        ]),
        "amygdala": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "The amygdala is dense in ER-β, the receptor subtype tied to emotional salience and anxiety rather than to reproductive signalling."),
            InsightEntry(0...240, "Estradiol changes how strongly the amygdala couples to the prefrontal cortex. Emotional experience is set by that connection, not by either region alone."),
            InsightEntry(0...240, "Neurosteroids made in the brain itself act on GABA-A receptors in the amygdala, and their supply tracks circulating hormone. That is why a trough can be felt as mood."),
            InsightEntry(0...240, "Estrogen modulates serotonin transporter density in limbic tissue — the same target SSRIs act on is being retuned by the dose."),
            InsightEntry(0...240, "The amygdala tags an experience with emotional weight before the cortex has interpreted it. Shifting its reactivity changes what registers as significant."),
        ]),
        "synaptic": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Estradiol upregulates NMDA receptor expression. Those receptors are the coincidence detectors that decide which synapses get strengthened."),
            InsightEntry(0...240, "Spine formation runs through CREB-mediated transcription: the hormone reaches the nucleus and changes which proteins the neuron builds."),
            InsightEntry(0...240, "A dendritic spine can form in under an hour. The remodelling is fast per synapse; what takes years is accumulating it across billions of them."),
            InsightEntry(0...240, "Estrogen acts on synapses by two routes at once — slow genomic transcription, and fast membrane signalling that alters excitability within minutes."),
            InsightEntry(0...240, "Synaptic plasticity is maintained, not banked. The trophic signal has to keep arriving for the remodelled architecture to hold."),
        ]),
        "hips": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Gluteofemoral adipocytes carry more ER-α than abdominal ones. Estrogen raises lipoprotein lipase activity there, so circulating fat is captured at the hip rather than the waist."),
            InsightEntry(0...240, "Lipoprotein lipase sits on the capillary wall and clips fatty acids out of the blood for the fat cell behind it. Where the enzyme is active is where fat lands."),
            InsightEntry(0...240, "Estrogen suppresses lipolysis in gluteofemoral depots. Fat here is not only stored more readily — it is released more reluctantly."),
            InsightEntry(0...240, "An adipocyte lives roughly ten years, and the population turns over about 8% annually. Redistribution is limited by that rate, not by dose."),
            InsightEntry(0...240, "Subcutaneous gluteofemoral fat is metabolically protective: it traps lipids that would otherwise reach the liver and the visceral compartment."),
        ]),
        "thighs": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Lipoprotein lipase activity rises in thigh fat under estradiol while falling in visceral depots. One enzyme, regulated in opposite directions by site."),
            InsightEntry(0...240, "Thigh adipocytes respond to estrogen by expanding rather than dividing. Existing cells enlarge well before new ones are recruited."),
            InsightEntry(0...240, "Alpha-2 adrenergic receptors outnumber beta receptors in gluteofemoral fat, which biases these depots toward storage and away from release."),
            InsightEntry(0...240, "Estrogen slows lipolysis in the thigh depot. That resistance to mobilisation is why lower-body fat is the last to move on any deficit."),
            InsightEntry(0...240, "Fat cell number is largely set in adolescence; what changes is how much lipid each cell holds. Distribution is a filling pattern, not a counting one."),
        ]),
        "abdomen": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Visceral adipocytes carry a higher density of androgen receptors and respond quickly when testosterone falls. That is why the belly moves before the hips do."),
            InsightEntry(0...240, "Visceral fat drains through the portal vein straight into the liver. Reducing it changes hepatic lipid exposure, not only silhouette."),
            InsightEntry(0...240, "Estrogen lowers lipoprotein lipase activity in visceral depots while raising it at the hip. The redistribution is one enzyme read two ways."),
            InsightEntry(0...240, "Visceral fat is metabolically active tissue that secretes inflammatory cytokines. Losing it is a systemic change as much as a shape one."),
            InsightEntry(0...240, "Subcutaneous abdominal fat and visceral fat sit millimetres apart and answer to different signals. Only one of the two is androgen-driven."),
        ]),
        "glutes": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Gluteal adipocytes hold among the highest ER-α densities of any fat depot in the body. Estrogen's storage signal lands hardest here."),
            InsightEntry(0...240, "Estrogen alters collagen crosslinking in pelvic ligaments. Posture shifts as they loosen, and the posterior profile changes with it."),
            InsightEntry(0...240, "Lipoprotein lipase activity in gluteal fat rises under estradiol, capturing circulating triglyceride at this site preferentially."),
            InsightEntry(0...240, "The gluteal depot is slow to fill and slow to empty. Alpha-2 adrenergic dominance makes fat stored here resistant to mobilisation."),
            InsightEntry(0...240, "Adipocyte turnover runs on a multi-year cycle. Development here is limited by that biology, not by how much estradiol is circulating."),
        ]),
        "chest": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Breast tissue is one of the few adult tissues that can still run a complete developmental program — the same ductal branching as endogenous puberty, on the same signal."),
            InsightEntry(0...240, "Estrogen drives ductal elongation; progesterone drives lobular branching. The two arms of breast development answer to different hormones."),
            InsightEntry(0...240, "Terminal duct lobular units are the functional endpoint of breast development, and they take years to form. Most of that work is invisible from outside."),
            InsightEntry(0...240, "Areolar tissue carries a dense supply of estrogen receptors. Sensitivity changes there are receptor-level events, not a side effect of growth."),
            InsightEntry(0...240, "Growth is driven by tissue-level receptor density, which varies between people far more than serum estradiol does. The lab number does not predict the outcome."),
        ]),
    ]

    static let testosterone: [String: RegionInsightBank] = [
        "pfc": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "The prefrontal cortex carries androgen receptors and aromatase both, so testosterone acts here directly and again after conversion to estradiol."),
            InsightEntry(0...240, "Testosterone modulates dopaminergic tone in prefrontal circuits. Risk assessment and decisiveness run on that system."),
            InsightEntry(0...240, "Androgen receptor binding is slow and long-lived: the receptor-hormone pair moves into the nucleus and stays for hours, changing transcription while it is there."),
            InsightEntry(0...240, "Prefrontal response to androgens varies widely between people because receptor sensitivity is set by a genetic repeat length, not by dose."),
            InsightEntry(0...240, "Testosterone alters GABAergic inhibition in prefrontal circuits — one route by which the register of thinking can shift."),
        ]),
        "hippocampus": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "The hippocampus is dense in androgen receptors, and testosterone supports dendritic spine density there directly."),
            InsightEntry(0...240, "Some of testosterone's hippocampal effect arrives as estradiol. Aromatase converts it locally, inside the brain, from the same molecule."),
            InsightEntry(0...240, "Spatial navigation and mental rotation are the tasks most consistently associated with androgen exposure across the research."),
            InsightEntry(0...240, "Androgen signalling supports hippocampal cell survival rather than birth rate. The cells are made either way; the hormone changes how many persist."),
            InsightEntry(0...240, "Receptor density, not serum level, sets how much signal hippocampal tissue actually receives. That is why individual variation here is so wide."),
        ]),
        "amygdala": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "The amygdala carries both androgen and estrogen receptors, and testosterone reaches both — some of it after local aromatase conversion."),
            InsightEntry(0...240, "Imaging studies of exogenous testosterone report blunted amygdala response to distressing stimuli, though the effect size varies widely between people."),
            InsightEntry(0...240, "The amygdala tags experience with emotional weight before the cortex interprets it. Changing its reactivity changes what registers as urgent."),
            InsightEntry(0...240, "Testosterone shifts amygdala-to-prefrontal coupling. Emotional containment is a connectivity change more than a reactivity one."),
            InsightEntry(0...240, "Neurosteroids made in the brain act on GABA-A receptors in limbic tissue, and their supply tracks circulating hormone. Troughs can be felt as mood."),
        ]),
        "synaptic": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Testosterone promotes dendritic spine formation through two pathways at once: direct androgen receptor activation, and local aromatization to estradiol."),
            InsightEntry(0...240, "Aromatase is expressed in the brain itself. A share of the testosterone reaching neural tissue is signalling as estrogen by the time it acts."),
            InsightEntry(0...240, "Androgen receptor binding changes gene transcription, so synaptic effects arrive on a timescale of hours to days rather than minutes."),
            InsightEntry(0...240, "Synaptic architecture is maintained by ongoing signal, not banked. Remodelled circuits need the hormone to keep arriving."),
            InsightEntry(0...240, "The two neural pathways testosterone uses can be separated pharmacologically — blocking aromatase changes some effects and leaves others intact."),
        ]),
        "chest": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Skeletal muscle carries androgen receptors directly. Testosterone raises protein synthesis and satellite cell activation in pectoral tissue as it does anywhere else."),
            InsightEntry(0...240, "5α-reductase converts testosterone to DHT in hair follicles. DHT binds the androgen receptor several times more tightly, which is why hair responds where muscle needs training."),
            InsightEntry(0...240, "Terminal hair conversion is irreversible. Once a vellus follicle switches over, it stays switched even if androgen falls away."),
            InsightEntry(0...240, "Body hair follows a regional timetable set by follicle sensitivity — legs and abdomen before chest, chest before back."),
            InsightEntry(0...240, "Androgen receptor occupancy raises muscle protein synthesis, but hypertrophy also needs mechanical load. The hormone permits growth; training causes it."),
        ]),
        "abdomen": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Androgen receptor signalling raises lipoprotein lipase activity in visceral fat. Deposition follows the enzyme."),
            InsightEntry(0...240, "Visceral fat drains through the portal vein directly to the liver, so android distribution carries metabolic consequences separate from shape."),
            InsightEntry(0...240, "Testosterone raises lipolysis in gluteofemoral depots while favouring abdominal storage. Redistribution runs in both directions at once."),
            InsightEntry(0...240, "Adipocytes turn over at roughly 8% a year. Fat redistribution is bounded by that rate no matter what the levels look like."),
            InsightEntry(0...240, "Core muscle sits under abdominal fat and answers to the same hormone differently — anabolic in one tissue, redistributive in the other."),
        ]),
        "hips": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Pelvic bone geometry is fixed once growth plates fuse. No hormone repositions completed bone, so proportion changes come from the tissue around it."),
            InsightEntry(0...240, "Hip fat carries fewer androgen receptors than visceral fat, which is why it responds late and modestly to testosterone."),
            InsightEntry(0...240, "Shoulder width is set by clavicle length and deltoid mass. Only one of those two is still available to change."),
            InsightEntry(0...240, "Waist-to-shoulder ratio is a ratio: it moves when either term moves. Abdominal and upper-body change shift it without the hips doing anything."),
            InsightEntry(0...240, "Androgen receptor density differs several-fold between fat depots. Regional response is a receptor map, not a whole-body effect."),
        ]),
        "glutes": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Gluteal muscle is skeletal muscle: androgen receptors, protein synthesis, satellite cell activation. The response here is anabolic, not redistributive."),
            InsightEntry(0...240, "Testosterone binds its receptor and the pair moves into the nucleus for hours. That residence time is why protein synthesis stays elevated long after the blood level peaks."),
            InsightEntry(0...240, "Satellite cells sit dormant beside muscle fibres until called. Androgens raise how many are recruited when load arrives."),
            InsightEntry(0...240, "Muscle keeps a record of prior training as retained myonuclei. Size regained after a break comes back faster than it was first built."),
            InsightEntry(0...240, "Androgen receptor density in muscle rises with training itself. Hormone and load amplify each other rather than simply adding."),
        ]),
        "thighs": RegionInsightBank(mechanism: [
            InsightEntry(0...240, "Quadriceps and hamstrings are rich in type II fibres, which carry more androgen receptors and hypertrophy fastest under testosterone."),
            InsightEntry(0...240, "Testosterone raises erythropoiesis, so oxygen delivery to working muscle rises alongside the muscle itself. Endurance and size change together."),
            InsightEntry(0...240, "Androgen signalling increases nitrogen retention in muscle. Net protein balance shifts toward building well before any size is visible."),
            InsightEntry(0...240, "Satellite cell activation from androgen exposure is largely front-loaded. After the first year, added size tracks load rather than hormone."),
            InsightEntry(0...240, "Muscle protein synthesis stays elevated for hours after an androgen receptor binds. Strength outruns visible size because neural drive adapts first."),
        ]),
    ]
}
