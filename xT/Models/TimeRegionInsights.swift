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
//
// Fact entries carry per-entry month ranges. Eight per region are eligible at
// every month and two are scoped to the first five years, so the long-tail
// reader — who draws from this bank nearly every month — gets an eight-month
// cycle before anything recurs. See §10.

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
    /// has nothing eligible. A region that is moving gets the pathway behind the
    /// movement; a region being maintained gets a fact, because there is no news
    /// to narrate and filler is what this system exists to remove.
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
    //
    // Fact copy is written as tissue state, never as a population comparison —
    // "in any estrogen-maintained skeleton", not "the same as in". Naming a
    // comparison group makes the reader the exception to it. See §9.

    static let estrogen: [String: RegionInsightBank] = [
        "pfc": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "ER-α and ER-β sit densely in prefrontal tissue, where estradiol modulates dopamine release. Executive function runs on that dopaminergic tone."),
                InsightEntry(0...600, "Estradiol raises cerebral blood flow to the prefrontal cortex. More perfusion means more glucose reaching the tissue doing working-memory work."),
                InsightEntry(0...600, "Estrogen's fast effects here are non-genomic — membrane-bound receptors changing neuron excitability within minutes, before any gene is transcribed."),
                InsightEntry(0...600, "The prefrontal cortex is the last brain region to finish developing and the most plastic in adulthood. That is why hormonal signals reshape it at all."),
                InsightEntry(0...600, "Estradiol tunes GABAergic interneurons in the prefrontal cortex, adjusting how strongly the region inhibits itself. Emotional top-down control is largely an inhibition problem."),
            ],
            fact: [
                InsightEntry(0...600, "The prefrontal cortex is about a tenth of the brain by volume and takes a far larger share of its glucose."),
                InsightEntry(0...600, "Estradiol's effect on prefrontal performance follows an inverted U. Too little and too much both reduce it."),
                InsightEntry(0...600, "Working memory holds roughly four items at once. Dopaminergic tone sets how stably they are held against distraction."),
                InsightEntry(0...600, "Verbal fluency is one of the few cognitive measures sensitive enough to shift across a single dose cycle."),
                InsightEntry(0...600, "Cortical estrogen receptors sit at the synapse as well as in the nucleus. Some effects land in minutes, others take weeks."),
                InsightEntry(0...600, "The prefrontal cortex finishes myelinating in the mid-twenties, later than any other region, and stays the most plastic tissue in the adult brain."),
                InsightEntry(0...600, "Regional cerebral blood flow rises measurably under estradiol. Imaging detects it before anyone reports feeling different."),
                InsightEntry(0...600, "Sleep is when prefrontal glucose reserves are restored. No hormone level compensates for losing it."),
                InsightEntry(0...59, "The first cognitive changes people notice are usually about how decisions feel rather than how well they are made."),
                InsightEntry(0...59, "Neurochemical change runs ahead of subjective change. Receptors respond within weeks; noticing takes longer."),
            ]
        ),
        "hippocampus": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Estradiol upregulates BDNF transcription in the hippocampus. BDNF is the growth factor keeping dendritic spines alive, so the signal is structural, not only chemical."),
                InsightEntry(0...600, "The dentate gyrus is one of two adult brain regions that make new neurons. Estrogen raises how many of those cells survive, not how many are born."),
                InsightEntry(0...600, "CA1 pyramidal neurons carry estrogen receptors on the dendrites themselves. Spine density there tracks estradiol closely enough to shift within a single cycle."),
                InsightEntry(0...600, "Estrogen enhances long-term potentiation — the strengthening of a synapse that fires repeatedly. That is the cellular event underneath forming a memory."),
                InsightEntry(0...600, "Estradiol supports mitochondrial function in hippocampal tissue and lowers oxidative stress. Neuroprotection here is metabolic before it is anything else."),
            ],
            fact: [
                InsightEntry(0...600, "The hippocampus is named for its resemblance to a seahorse. Each hemisphere carries one, and they specialise differently."),
                InsightEntry(0...600, "BDNF is the most abundant growth factor in the brain, and estradiol is among the strongest regulators of its transcription."),
                InsightEntry(0...600, "Spine density on CA1 dendrites can shift by roughly a third as estradiol changes. Structural, and measurable."),
                InsightEntry(0...600, "Taxi drivers show enlarged posterior hippocampi from navigation alone. This tissue rebuilds itself in response to use."),
                InsightEntry(0...600, "Aerobic exercise raises BDNF through a pathway separate from the hormonal one. The two effects add."),
                InsightEntry(0...600, "Memory consolidation happens largely during slow-wave sleep, in this tissue. Estradiol supports the machinery; sleep supplies the opportunity."),
                InsightEntry(0...600, "The hippocampus is unusually perfusion-sensitive, which is why blood pressure control appears so often in memory research."),
                InsightEntry(0...600, "In any estrogen-maintained brain, hippocampal volume tracks sustained estradiol. The relationship holds across decades of exposure."),
                InsightEntry(0...59, "Dendritic spines begin forming on CA1 neurons within the first weeks. Structural brain change starts before anything visible does."),
                InsightEntry(0...59, "Verbal memory benchmarks are often the first cognitive measure to move, within a few months of starting."),
            ]
        ),
        "amygdala": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "The amygdala is dense in ER-β, the receptor subtype tied to emotional salience and anxiety rather than to reproductive signalling."),
                InsightEntry(0...600, "Estradiol changes how strongly the amygdala couples to the prefrontal cortex. Emotional experience is set by that connection, not by either region alone."),
                InsightEntry(0...600, "Neurosteroids made in the brain itself act on GABA-A receptors in the amygdala, and their supply tracks circulating hormone. That is why a trough can be felt as mood."),
                InsightEntry(0...600, "Estrogen modulates serotonin transporter density in limbic tissue — the same target SSRIs act on is being retuned by the dose."),
                InsightEntry(0...600, "The amygdala tags an experience with emotional weight before the cortex has interpreted it. Shifting its reactivity changes what registers as significant."),
            ],
            fact: [
                InsightEntry(0...600, "The amygdala responds to a face before the visual cortex has resolved what it is. It tags salience ahead of recognition."),
                InsightEntry(0...600, "Emotional memories are encoded more strongly than neutral ones because the amygdala modulates hippocampal consolidation directly."),
                InsightEntry(0...600, "Tear thresholds are partly hormonal. Estradiol and prolactin both influence them, which is one reason the threshold can move."),
                InsightEntry(0...600, "The amygdala is about the size of an almond, which is where its name comes from. Its reach across the brain is far larger."),
                InsightEntry(0...600, "Neurosteroids are synthesised inside the brain rather than delivered to it. Their supply still tracks what is circulating."),
                InsightEntry(0...600, "Difficulty naming emotions eases for some people under estradiol. The change is in access rather than in the feelings themselves."),
                InsightEntry(0...600, "The amygdala-to-prefrontal connection matures later than either region alone. Emotional regulation is a connectivity property."),
                InsightEntry(0...600, "In any estrogen-maintained brain, limbic reactivity tracks circulating levels closely enough to follow a dose cycle."),
                InsightEntry(0...59, "Emotional intensity often rises before it settles. The amygdala is recalibrating its thresholds, and recalibration is not smoothness."),
                InsightEntry(0...59, "The earliest reported change on feminising therapy is usually emotional rather than physical. It is also the fastest to arrive."),
            ]
        ),
        "synaptic": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Estradiol upregulates NMDA receptor expression. Those receptors are the coincidence detectors that decide which synapses get strengthened."),
                InsightEntry(0...600, "Spine formation runs through CREB-mediated transcription: the hormone reaches the nucleus and changes which proteins the neuron builds."),
                InsightEntry(0...600, "A dendritic spine can form in under an hour. The remodelling is fast per synapse; what takes years is accumulating it across billions of them."),
                InsightEntry(0...600, "Estrogen acts on synapses by two routes at once — slow genomic transcription, and fast membrane signalling that alters excitability within minutes."),
                InsightEntry(0...600, "Synaptic plasticity is maintained, not banked. The trophic signal has to keep arriving for the remodelled architecture to hold."),
            ],
            fact: [
                InsightEntry(0...600, "The adult brain holds on the order of a hundred trillion synapses. Estradiol acts on a large share of them at once."),
                InsightEntry(0...600, "Most synapses in the adult brain are replaced or remodelled over a lifetime. Stability at the network level hides constant turnover underneath."),
                InsightEntry(0...600, "NMDA receptors open only when two conditions coincide. That is how a synapse detects that two events belong together."),
                InsightEntry(0...600, "Long-term potentiation was first demonstrated in 1973 and remains the best cellular model of memory formation."),
                InsightEntry(0...600, "Synapses are among the most metabolically expensive structures in the body. Maintaining them is most of what the brain spends energy on."),
                InsightEntry(0...600, "Dendritic spines come in several shapes, and the shape tracks how strong and how stable the synapse is."),
                InsightEntry(0...600, "Plasticity is capacity, not improvement. It is what makes new learning possible, and it does not choose what gets learned."),
                InsightEntry(0...600, "In any estrogen-maintained brain, synaptic density depends on the signal continuing to arrive. The architecture is rented, not owned."),
                InsightEntry(0...59, "NMDA receptor expression rises within the first weeks. Circuits are primed to remodel before any remodelling shows."),
                InsightEntry(0...59, "The first year produces more synaptic change than any later year, and has the least externally visible to show for it."),
            ]
        ),
        "hips": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Gluteofemoral adipocytes carry more ER-α than abdominal ones. Estrogen raises lipoprotein lipase activity there, so circulating fat is captured at the hip rather than the waist."),
                InsightEntry(0...600, "Lipoprotein lipase sits on the capillary wall and clips fatty acids out of the blood for the fat cell behind it. Where the enzyme is active is where fat lands."),
                InsightEntry(0...600, "Estrogen suppresses lipolysis in gluteofemoral depots. Fat here is not only stored more readily — it is released more reluctantly."),
                InsightEntry(0...600, "An adipocyte lives roughly ten years, and the population turns over at 8% annually. Redistribution is limited by that rate, not by dose."),
                InsightEntry(0...600, "Subcutaneous gluteofemoral fat is metabolically protective: it traps lipids that would otherwise reach the liver and the visceral compartment."),
            ],
            fact: [
                InsightEntry(0...600, "An adipocyte lives about ten years, and one in twelve is replaced each year. Redistribution is capped by that rate."),
                InsightEntry(0...600, "Fat cell number is largely fixed after adolescence. What changes is how much lipid each cell holds."),
                InsightEntry(0...600, "Estrogen receptors in fat come in two subtypes with opposite effects on storage. Which one dominates varies by depot."),
                InsightEntry(0...600, "Hip width in imaging is measured bone to bone, so the number moves far less than the silhouette does."),
                InsightEntry(0...600, "Hip-to-waist ratio predicts metabolic risk better than weight does, because it describes where fat sits rather than how much there is."),
                InsightEntry(0...600, "The greater trochanter and iliac crest are the two anatomical anchors of the gynoid pattern. Both are bone, and both stay put."),
                InsightEntry(0...600, "In any estrogen-maintained skeleton, the pelvis is a primary site of bone remodelling. Estradiol sets where resorption and rebuilding balance."),
                InsightEntry(0...600, "Weight loss empties fat cells without removing them. The pattern reasserts itself when weight returns."),
                InsightEntry(0...59, "The enzyme change comes first and the visible change comes later. Lipoprotein lipase shifts within weeks; the silhouette takes years."),
                InsightEntry(0...59, "Hip change is limited by cell turnover rather than by hormone level. More estradiol does not speed it up."),
            ]
        ),
        "thighs": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Lipoprotein lipase activity rises in thigh fat under estradiol while falling in visceral depots. One enzyme, regulated in opposite directions by site."),
                InsightEntry(0...600, "Thigh adipocytes respond to estrogen by expanding rather than dividing. Existing cells enlarge well before new ones are recruited."),
                InsightEntry(0...600, "Alpha-2 adrenergic receptors outnumber beta receptors in gluteofemoral fat, which biases these depots toward storage and away from release."),
                InsightEntry(0...600, "Estrogen slows lipolysis in the thigh depot. That resistance to mobilisation is why lower-body fat is the last to move on any deficit."),
                InsightEntry(0...600, "Fat cell number is largely set in adolescence; what changes is how much lipid each cell holds. Distribution is a filling pattern, not a counting one."),
            ],
            fact: [
                InsightEntry(0...600, "The thigh holds the largest continuous subcutaneous fat sheet in the body. Change here shows as contour before it shows as circumference."),
                InsightEntry(0...600, "Thigh circumference is associated with lower cardiovascular risk, independent of overall body weight."),
                InsightEntry(0...600, "Inner-thigh fat pads are a distinct anatomical depot, not simply more of the same subcutaneous layer."),
                InsightEntry(0...600, "Muscle and fat in the thigh answer to different signals. One responds to load within weeks, the other to hormones across years."),
                InsightEntry(0...600, "Cellulite is a structural feature of subcutaneous fat under a particular collagen architecture. It appears in any estrogen-maintained tissue."),
                InsightEntry(0...600, "The quadriceps is the largest muscle group in the body by volume, and the fastest to lose mass with disuse."),
                InsightEntry(0...600, "Estradiol slows lipolysis here specifically. This depot resists mobilisation by design rather than by accident."),
                InsightEntry(0...600, "Fat distribution is strongly genetically influenced. Two people on identical regimens can land in visibly different places."),
                InsightEntry(0...59, "Pants fit changes before a tape measure does. The earliest thigh change is usually detected by clothing."),
                InsightEntry(0...59, "Thigh deposition starts later than abdominal change. The depots do not move on the same clock."),
            ]
        ),
        "abdomen": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Visceral adipocytes carry a higher density of androgen receptors and respond quickly when testosterone falls. That is why the belly moves before the hips do."),
                InsightEntry(0...600, "Visceral fat drains through the portal vein straight into the liver. Reducing it changes hepatic lipid exposure, not only silhouette."),
                InsightEntry(0...600, "Estrogen lowers lipoprotein lipase activity in visceral depots while raising it at the hip. The redistribution is one enzyme read two ways."),
                InsightEntry(0...600, "Visceral fat is metabolically active tissue that secretes inflammatory cytokines. Losing it is a systemic change as much as a shape one."),
                InsightEntry(0...600, "Subcutaneous abdominal fat and visceral fat sit millimetres apart and answer to different signals. Only one of the two is androgen-driven."),
            ],
            fact: [
                InsightEntry(0...600, "The abdominal wall holds several distinct fat layers. Only the deepest of them sits inside the muscle and around the organs."),
                InsightEntry(0...600, "Visceral fat is an endocrine organ in its own right. It secretes inflammatory signalling molecules continuously."),
                InsightEntry(0...600, "Aromatase in adipose tissue converts androgens to estrogens on site. Fat participates in the hormonal environment rather than only storing energy."),
                InsightEntry(0...600, "Waist circumference at the navel predicts metabolic risk better than body mass index does."),
                InsightEntry(0...600, "Visceral fat responds faster than any other depot to hormonal change, in both directions."),
                InsightEntry(0...600, "A softer belly can appear before the tape measure moves. Visceral loss changes shape before it changes circumference."),
                InsightEntry(0...600, "In any estrogen-maintained body, visceral fat sits lower than in an androgen-maintained one. The difference is enzymatic."),
                InsightEntry(0...600, "Sleep deprivation raises visceral fat storage independently of calories. This depot is unusually sensitive to cortisol."),
                InsightEntry(0...59, "The belly is often the first region to change and the first one people stop noticing. Visceral loss shows early and quietly."),
                InsightEntry(0...59, "Abdominal softening usually arrives before hip gain. The depots run on different timescales from the start."),
            ]
        ),
        "glutes": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Gluteal adipocytes hold among the highest ER-α densities of any fat depot in the body. Estrogen's storage signal lands hardest here."),
                InsightEntry(0...600, "Estrogen alters collagen crosslinking in pelvic ligaments. Posture shifts as they loosen, and the posterior profile changes with it."),
                InsightEntry(0...600, "Lipoprotein lipase activity in gluteal fat rises under estradiol, capturing circulating triglyceride at this site preferentially."),
                InsightEntry(0...600, "The gluteal depot is slow to fill and slow to empty. Alpha-2 adrenergic dominance makes fat stored here resistant to mobilisation."),
                InsightEntry(0...600, "Adipocyte turnover runs on a multi-year cycle. Development here is limited by that biology, not by how much estradiol is circulating."),
            ],
            fact: [
                InsightEntry(0...600, "Gluteal fat has among the highest estrogen receptor densities of any depot in the body."),
                InsightEntry(0...600, "The gluteus maximus is the largest single muscle in the body. The fat pad sits on top of it, not instead of it."),
                InsightEntry(0...600, "Subcutaneous fat here sits in fibrous chambers separated by septa. That architecture, not the fat itself, sets the surface texture."),
                InsightEntry(0...600, "This depot fills first and empties last. That ordering is set by receptor density rather than by anything you do."),
                InsightEntry(0...600, "Gluteofemoral fat is associated with better lipid profiles independent of total body fat."),
                InsightEntry(0...600, "The femoral neck is a standard DEXA measurement site. Bone and fat at the hip are tracked by the same appointment."),
                InsightEntry(0...600, "In any estrogen-maintained skeleton, hip bone density depends on estradiol continuing to arrive. It is not banked."),
                InsightEntry(0...600, "Prolonged sitting reduces gluteal muscle activation measurably. The fat pad is hormonal; the muscle under it is not."),
                InsightEntry(0...59, "Seat fit changes before the mirror does. Gluteal deposition is detected by clothing well before it is visible."),
                InsightEntry(0...59, "Gluteal change runs on the slowest clock of any region. Development here is still moving at year four."),
            ]
        ),
        "chest": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Breast tissue is one of the few adult tissues that can still run a full developmental program. It is the same ductal branching as endogenous puberty, on the same signal."),
                InsightEntry(0...600, "Estrogen drives ductal elongation; progesterone drives lobular branching. The two arms of breast development answer to different hormones."),
                InsightEntry(0...600, "Terminal duct lobular units are the functional endpoint of breast development, and they take years to form. Most of that work is invisible from outside."),
                InsightEntry(0...600, "Areolar tissue carries a dense supply of estrogen receptors. Sensitivity changes there are receptor-level events, not a side effect of growth."),
                InsightEntry(0...600, "Growth is driven by tissue-level receptor density, which varies between people far more than serum estradiol does. The lab number does not predict the outcome."),
            ],
            fact: [
                InsightEntry(0...600, "Breast tissue can run a complete developmental program in adulthood. Few adult tissues retain that capacity."),
                InsightEntry(0...600, "Tanner staging was published in 1969 and still describes the sequence. It was never a schedule, only an order."),
                InsightEntry(0...600, "A documented minority reach Tanner stage 3 or 4 and hold there. That is a recognised outcome of the same process."),
                InsightEntry(0...600, "The breast is one of the few organs that does most of its development after birth. Almost nothing of it is built in the womb."),
                InsightEntry(0...600, "The breast has no muscle of its own. Its shape is carried by skin, glandular tissue, fat and the ligaments between them."),
                InsightEntry(0...600, "Montgomery glands are modified sebaceous glands on the areola. Their appearance is a staging landmark in its own right."),
                InsightEntry(0...600, "In any estrogen-maintained breast tissue, mammographic density is highest when the tissue is youngest and eases across the decades."),
                InsightEntry(0...600, "Growth is not linear. Plateaus lasting months are part of the normal sequence rather than an interruption to it."),
                InsightEntry(0...59, "Breast buds form beneath the areola before anything is visible. The tissue is palpable before it has any outline."),
                InsightEntry(0...59, "Areolar sensitivity often changes before size does. The receptors respond ahead of the volume."),
            ]
        ),
    ]

    static let testosterone: [String: RegionInsightBank] = [
        "pfc": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "The prefrontal cortex carries androgen receptors and aromatase both, so testosterone acts here directly and again after conversion to estradiol."),
                InsightEntry(0...600, "Testosterone modulates dopaminergic tone in prefrontal circuits. Risk assessment and decisiveness run on that system."),
                InsightEntry(0...600, "Androgen receptor binding is slow and long-lived: the receptor-hormone pair moves into the nucleus and stays for hours, changing transcription while it is there."),
                InsightEntry(0...600, "Prefrontal response to androgens varies widely between people because receptor sensitivity is set by a genetic repeat length, not by dose."),
                InsightEntry(0...600, "Testosterone alters GABAergic inhibition in prefrontal circuits — one route by which the register of thinking can shift."),
            ],
            fact: [
                InsightEntry(0...600, "Working memory capacity is remarkably stable across adulthood. What hormonal change alters is how effortful holding things feels."),
                InsightEntry(0...600, "The prefrontal cortex is the most metabolically expensive region per gram. Sleep and glucose availability shape it as much as hormones do."),
                InsightEntry(0...600, "An androgen receptor stays bound in the nucleus for hours. That residence time is why effects outlast the blood peak."),
                InsightEntry(0...600, "Decisiveness and impulsivity are different things that look alike from outside. Only one of them tracks dopaminergic tone."),
                InsightEntry(0...600, "Verbal fluency and spatial rotation load on different circuits. A hormonal change can move them in opposite directions."),
                InsightEntry(0...600, "The prefrontal cortex is the most plastic tissue in the adult brain, which is why hormonal signals reshape it at all."),
                InsightEntry(0...600, "Trough levels predict cognitive steadiness better than peak levels do. The low point sets the floor."),
                InsightEntry(0...600, "Aromatase in the brain means no androgen effect here is purely androgenic. Both receptor families are engaged at once."),
                InsightEntry(0...59, "Levels are least stable in the first months, so day-to-day variation is widest then. It narrows as dosing settles."),
                InsightEntry(0...59, "The earliest reported cognitive change is usually a shift in how thinking feels rather than in what it produces."),
            ]
        ),
        "hippocampus": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "The hippocampus is dense in androgen receptors, and testosterone supports dendritic spine density there directly."),
                InsightEntry(0...600, "Some of testosterone's hippocampal effect arrives as estradiol. Aromatase converts it locally, inside the brain, from the same molecule."),
                InsightEntry(0...600, "Spatial navigation and mental rotation are the tasks most consistently associated with androgen exposure across the research."),
                InsightEntry(0...600, "Androgen signalling supports hippocampal cell survival rather than birth rate. The cells are made either way; the hormone changes how many persist."),
                InsightEntry(0...600, "Receptor density, not serum level, sets how much signal hippocampal tissue actually receives. That is why individual variation here is so wide."),
            ],
            fact: [
                InsightEntry(0...600, "The hippocampus is among the first tissue affected in memory disorders, which is why it is so heavily studied."),
                InsightEntry(0...600, "The hippocampus carries dense androgen receptors and dense aromatase. It receives both signals from the same molecule."),
                InsightEntry(0...600, "Mental rotation performance can shift measurably within months of a hormonal change, in either direction."),
                InsightEntry(0...600, "Chronic stress measurably reduces hippocampal volume. It is one of the few tissues where that effect is directly visible."),
                InsightEntry(0...600, "Aerobic exercise raises BDNF through a route independent of hormones. Combining movement with navigation raises it further."),
                InsightEntry(0...600, "The hippocampus rebuilds itself in response to use. Navigation alone measurably enlarges its posterior portion."),
                InsightEntry(0...600, "Verbal and spatial memory are separable systems. A change in one does not predict a change in the other."),
                InsightEntry(0...600, "Perfusion matters more to this tissue than to most. Hematocrit management is a hippocampal concern as much as a cardiac one."),
                InsightEntry(0...59, "Spatial gains, where they appear, tend to show earlier than any other cognitive change. They also vary widely between people."),
                InsightEntry(0...59, "The first months carry the widest dose-to-dose variation. Cognitive effects are hardest to read during exactly that window."),
            ]
        ),
        "amygdala": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "The amygdala carries both androgen and estrogen receptors, and testosterone reaches both — some of it after local aromatase conversion."),
                InsightEntry(0...600, "Imaging studies of exogenous testosterone report blunted amygdala response to distressing stimuli, though the effect size varies widely between people."),
                InsightEntry(0...600, "The amygdala tags experience with emotional weight before the cortex interprets it. Changing its reactivity changes what registers as urgent."),
                InsightEntry(0...600, "Testosterone shifts amygdala-to-prefrontal coupling. Emotional containment is a connectivity change more than a reactivity one."),
                InsightEntry(0...600, "Neurosteroids made in the brain act on GABA-A receptors in limbic tissue, and their supply tracks circulating hormone. Troughs can be felt as mood."),
            ],
            fact: [
                InsightEntry(0...600, "The amygdala responds to a threatening face before the visual cortex has identified it. Speed is the point of the structure."),
                InsightEntry(0...600, "Amygdala volume differs measurably between individuals, and the variation is unrelated to how reactive the structure is."),
                InsightEntry(0...600, "Anger and fear recruit overlapping limbic circuits. A change in threshold can shift both at once."),
                InsightEntry(0...600, "Tear thresholds are partly hormonal. Testosterone raises them for many people, which is a threshold change rather than a feeling change."),
                InsightEntry(0...600, "Neurosteroids are made inside the brain, but their supply follows what is circulating. That is why troughs register."),
                InsightEntry(0...600, "Limbic tissue responds to hormonal change faster than cortical tissue does. Emotional shifts arrive before cognitive ones."),
                InsightEntry(0...600, "Emotional range and emotional expression are separable. Androgen research finds more consistent effects on the second."),
                InsightEntry(0...600, "This is an active research area with wide individual variation. The honest description is a distribution rather than a rule."),
                InsightEntry(0...59, "The shift toward feeling more contained is one of the earlier reported changes. It is also one of the most variable."),
                InsightEntry(0...59, "Early emotional change can feel abrupt because levels are least stable then. The variability is pharmacokinetic."),
            ]
        ),
        "synaptic": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Testosterone promotes dendritic spine formation through two pathways at once: direct androgen receptor activation, and local aromatization to estradiol."),
                InsightEntry(0...600, "Aromatase is expressed in the brain itself. A share of the testosterone reaching neural tissue is signalling as estrogen by the time it acts."),
                InsightEntry(0...600, "Androgen receptor binding changes gene transcription, so synaptic effects arrive on a timescale of hours to days rather than minutes."),
                InsightEntry(0...600, "Synaptic architecture is maintained by ongoing signal, not banked. Remodelled circuits need the hormone to keep arriving."),
                InsightEntry(0...600, "The two neural pathways testosterone uses can be separated pharmacologically — blocking aromatase changes some effects and leaves others intact."),
            ],
            fact: [
                InsightEntry(0...600, "Aromatase inside the brain converts part of the circulating testosterone. Some of the neural effect is estrogenic by the time it lands."),
                InsightEntry(0...600, "Glial cells outnumber neurons in much of the brain and take part in every synapse. Plasticity is not a neuron-only process."),
                InsightEntry(0...600, "The adult brain holds on the order of a hundred trillion synapses. Both pathways act across a large share of them."),
                InsightEntry(0...600, "Androgen and estrogen receptors share much of their machinery. That overlap is why one hormone can produce effects attributed to the other."),
                InsightEntry(0...600, "Plasticity is capacity, not improvement. It makes learning possible and does not choose what gets learned."),
                InsightEntry(0...600, "The brain spends about a fifth of the body's energy budget on a fiftieth of its mass. Most of that goes to synapses."),
                InsightEntry(0...600, "Long-term potentiation remains the best cellular model of memory formation, fifty years after it was first demonstrated."),
                InsightEntry(0...600, "Synaptic architecture depends on the signal continuing to arrive. It is maintained rather than banked."),
                InsightEntry(0...59, "Spine formation is fastest in the first year, which is also the year with the least externally visible to show for it."),
                InsightEntry(0...59, "Both signalling routes come online early. The dual pathway is active from the first months rather than added later."),
            ]
        ),
        "chest": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Skeletal muscle carries androgen receptors directly. Testosterone raises protein synthesis and satellite cell activation in pectoral tissue as it does anywhere else."),
                InsightEntry(0...600, "5α-reductase converts testosterone to DHT in hair follicles. DHT binds the androgen receptor several times more tightly, which is why hair responds where muscle needs training."),
                InsightEntry(0...600, "Terminal hair conversion is irreversible. Once a vellus follicle switches over, it stays switched even if androgen falls away."),
                InsightEntry(0...600, "Body hair follows a regional timetable set by follicle sensitivity — legs and abdomen before chest, chest before back."),
                InsightEntry(0...600, "Androgen receptor occupancy raises muscle protein synthesis, but hypertrophy also needs mechanical load. The hormone permits growth; training causes it."),
            ],
            fact: [
                InsightEntry(0...600, "Chest-wall follicles and scalp follicles both respond to DHT, in opposite directions. The same signal builds one and thins the other."),
                InsightEntry(0...600, "Follicles cycle independently of one another, which is why hair fills in unevenly rather than all at once."),
                InsightEntry(0...600, "Chest measurement changes come from the back as much as the front. Lat and pectoral growth both widen the same tape."),
                InsightEntry(0...600, "Chest hair density often keeps increasing past five years. It is among the slowest androgenic changes to finish arriving."),
                InsightEntry(0...600, "Muscle keeps a record of prior training as retained myonuclei. Size regained after a break returns faster than it was first built."),
                InsightEntry(0...600, "Androgen receptor density in muscle rises with training itself. Hormone and load amplify each other rather than adding."),
                InsightEntry(0...600, "Testosterone raises red cell production, which is why hematocrit is watched. The signal that builds muscle also thickens blood."),
                InsightEntry(0...600, "The pectoralis attaches to the upper arm rather than to the chest wall. Its size changes the shoulder line as much as the chest."),
                InsightEntry(0...59, "Strength moves before size does. Neural drive adapts within weeks and visible hypertrophy follows months later."),
                InsightEntry(0...59, "Chest hair arrives after the legs and abdomen. Its absence in the first year says nothing about the eventual pattern."),
            ]
        ),
        "abdomen": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Androgen receptor signalling raises lipoprotein lipase activity in visceral fat. Deposition follows the enzyme."),
                InsightEntry(0...600, "Visceral fat drains through the portal vein directly to the liver, so android distribution carries metabolic consequences separate from shape."),
                InsightEntry(0...600, "Testosterone raises lipolysis in gluteofemoral depots while favouring abdominal storage. Redistribution runs in both directions at once."),
                InsightEntry(0...600, "Adipocytes turn over at roughly 8% a year. Fat redistribution is bounded by that rate no matter what the levels look like."),
                InsightEntry(0...600, "Core muscle sits under abdominal fat and answers to the same hormone differently — anabolic in one tissue, redistributive in the other."),
            ],
            fact: [
                InsightEntry(0...600, "The abdomen is where androgenic and estrogenic fat signals meet most directly. It is the depot both hormones act on hardest."),
                InsightEntry(0...600, "Androgen receptor density differs several-fold between fat depots. Regional response is a receptor map, not a whole-body effect."),
                InsightEntry(0...600, "Waist circumference predicts metabolic risk better than body mass index does."),
                InsightEntry(0...600, "Subcutaneous abdominal fat and the visceral fat behind it change on different schedules. The deeper depot moves first."),
                InsightEntry(0...600, "Abdominal skin has fewer androgen receptors than the follicles in it. Hair pattern changes here before anything structural does."),
                InsightEntry(0...600, "Visceral fat secretes inflammatory signalling molecules continuously. It behaves as an endocrine organ rather than as storage."),
                InsightEntry(0...600, "Silhouette can change while waist circumference does not, because shoulders and chest move the ratio on their own."),
                InsightEntry(0...600, "Sleep deprivation raises visceral storage independently of calories. This depot is unusually cortisol-sensitive."),
                InsightEntry(0...59, "Redistribution starts below the visible threshold. The enzyme gradient shifts months before the shape does."),
                InsightEntry(0...59, "Core definition can improve while abdominal fat is still redistributing. The two processes overlap rather than queue."),
            ]
        ),
        "hips": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Pelvic bone geometry is fixed once growth plates fuse. No hormone repositions completed bone, so proportion changes come from the tissue around it."),
                InsightEntry(0...600, "Hip fat carries fewer androgen receptors than visceral fat, which is why it responds late and modestly to testosterone."),
                InsightEntry(0...600, "Shoulder width is set by clavicle length and deltoid mass. Only one of those two is still available to change."),
                InsightEntry(0...600, "Waist-to-shoulder ratio is a ratio: it moves when either term moves. Abdominal and upper-body change shift it without the hips doing anything."),
                InsightEntry(0...600, "Bone at the hip stays responsive to hormonal signal even though its geometry does not. Density and shape are separate properties."),
            ],
            fact: [
                InsightEntry(0...600, "Hip measurement is taken at the widest point, which is usually soft tissue rather than bone."),
                InsightEntry(0...600, "Deltoid mass is among the most androgen-responsive muscle in the upper body. It changes the outline faster than the chest does."),
                InsightEntry(0...600, "Clothing sizing is cut to hip-to-waist proportions rather than to either measurement alone. Fit changes before any number does."),
                InsightEntry(0...600, "Fat depots differ in blood supply as well as receptors. Poorly perfused depots respond slowly to anything circulating."),
                InsightEntry(0...600, "The femoral neck is a standard DEXA site. Androgens support bone there partly by aromatising to estradiol."),
                InsightEntry(0...600, "Proportion is a visual ratio, and ratios move faster than the anatomy underneath them."),
                InsightEntry(0...600, "Gluteal and hip muscle respond to load within weeks. The fat over them responds to hormones across years."),
                InsightEntry(0...600, "Bone mineral density at the hip depends on continued hormonal signalling in any body. It is maintained, not banked."),
                InsightEntry(0...59, "Hip circumference is often the measurement people expect to move first. It is usually the one that moves least."),
                InsightEntry(0...59, "The earliest proportional change comes from the abdomen and shoulders. The hips are the fixed reference."),
            ]
        ),
        "glutes": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Gluteal muscle is skeletal muscle: androgen receptors, protein synthesis, satellite cell activation. The response here is anabolic, not redistributive."),
                InsightEntry(0...600, "Testosterone binds its receptor and the pair moves into the nucleus for hours. That residence time is why protein synthesis stays elevated long after the blood level peaks."),
                InsightEntry(0...600, "Satellite cells sit dormant beside muscle fibres until called. Androgens raise how many are recruited when load arrives."),
                InsightEntry(0...600, "Muscle keeps a record of prior training as retained myonuclei. Size regained after a break comes back faster than it was first built."),
                InsightEntry(0...600, "Androgen receptor density in muscle rises with training itself. Hormone and load amplify each other rather than simply adding."),
            ],
            fact: [
                InsightEntry(0...600, "The gluteus maximus is the largest single muscle in the body, and one of the most androgen-responsive."),
                InsightEntry(0...600, "Hip extension is the strongest movement the body produces, and the gluteus maximus is the muscle that produces it."),
                InsightEntry(0...600, "Muscle fibre type ratios are largely genetic. Two people on the same programme and the same dose can build differently."),
                InsightEntry(0...600, "Gluteal muscle is deep to a fat layer that responds to hormones separately. Composition here changes on two clocks at once."),
                InsightEntry(0...600, "Hip extension strength predicts later mobility better than almost any other single measure."),
                InsightEntry(0...600, "This is a muscle response rather than a fat redistribution one. Without load, testosterone alone changes very little here."),
                InsightEntry(0...600, "Prolonged sitting reduces gluteal activation measurably. The tissue responds to use more than to tenure."),
                InsightEntry(0...600, "Muscle protein synthesis stays elevated for hours after an androgen receptor binds. The blood peak and the tissue effect do not coincide."),
                InsightEntry(0...59, "Strength gains here are usually rapid in the first year. Squat and press numbers move faster than the mirror does."),
                InsightEntry(0...59, "Without training, this region changes least of any on testosterone. The hormone permits growth rather than causing it."),
            ]
        ),
        "thighs": RegionInsightBank(
            mechanism: [
                InsightEntry(0...600, "Quadriceps and hamstrings are rich in type II fibres, which carry more androgen receptors and hypertrophy fastest under testosterone."),
                InsightEntry(0...600, "Testosterone raises erythropoiesis, so oxygen delivery to working muscle rises alongside the muscle itself. Endurance and size change together."),
                InsightEntry(0...600, "Androgen signalling increases nitrogen retention in muscle. Net protein balance shifts toward building well before any size is visible."),
                InsightEntry(0...600, "Satellite cell activation from androgen exposure is largely front-loaded. After the first year, added size tracks load rather than hormone."),
                InsightEntry(0...600, "Muscle protein synthesis stays elevated for hours after an androgen receptor binds. Strength outruns visible size because neural drive adapts first."),
            ],
            fact: [
                InsightEntry(0...600, "The hamstrings cross two joints and the quadriceps mostly one. That difference shapes how each responds to the same training."),
                InsightEntry(0...600, "The quadriceps is the largest muscle group by volume, and the fastest to lose mass with disuse."),
                InsightEntry(0...600, "Thigh muscle is where most whole-body glucose disposal happens. Building it changes metabolism as well as shape."),
                InsightEntry(0...600, "Muscle cross-sectional area predicts strength better than limb circumference does. A tape measure misses most of the change."),
                InsightEntry(0...600, "Tendon and connective tissue adapt more slowly than muscle does. Strength can outrun the structures carrying it."),
                InsightEntry(0...600, "Bone density in the femur rises with heavy lower-body loading. The skeleton adapts to the same training the muscle does."),
                InsightEntry(0...600, "Leg strength predicts later independence better than most clinical measures. It is trainable at any age or tenure."),
                InsightEntry(0...600, "Thigh muscle and thigh fat sit in the same limb and answer to different signals on different timescales."),
                InsightEntry(0...59, "Lower-body change is often the most visible in the first year. Squat and leg press numbers move quickly."),
                InsightEntry(0...59, "Measurable hypertrophy can appear within the first few months with training. Without it, the change is much smaller."),
            ]
        ),
    ]
}
