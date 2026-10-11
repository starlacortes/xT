# Time Region Copy — Clinical Sign-off Draft

> **Status:** Pending re-review  
> **Gate:** `TIME_CARD_PERSONALIZATION.md` §11, Phase F  
> **Scope:** every string the region card can render — 18 overviews, 340 NOW bands, 270 insight entries, 72 markers  
> **Reviewer:** Starla Cortes  
> **Generated from source:** 2026-08-20

The previous revision of this document signed off a corpus that no longer
ships. Phases C and E re-cut every `monthFocus` band onto each region's own
clock and rewrote the whole 60–240 range; Phase F rewrote the overviews to
the §9 caps. Those strings are replaced, so the sign-off on them does not
carry forward. This revision is generated from `TimeBodyRegions.swift`,
`TimeRegionInsights.swift` and `TimeRegionMarkers.swift` and needs review
in full.

---

## What each section is

The card renders four slots. Every string below is tagged with the slot it
lands in, because the clinical question differs by slot.

| Slot | Shown when | What to check |
|---|---|---|
| **ABOUT** | the region's clock has not started | Is this a fair introduction to the region? |
| **NOW** | always | Is this what the tissue is doing in these months? |
| **INSIGHT — mechanism** | while the region is changing quickly | Is the pathway stated correctly? |
| **INSIGHT — fact** | while it is changing slowly, and past `completeMonth` | Is the claim supported, and does it hold outside the first five years? |
| **NEXT** | a marker falls within 24 months | Is the median month defensible? |

Mechanism entries carry no month range: they describe a pathway that is
true whenever the region is active. Fact entries carry one, and at least
eight per region must remain eligible past month 60 — that is what gives a
six-year user an eight-month non-repeat cycle.

Voice rules these strings are held to are in `TIME_CARD_PERSONALIZATION.md`
§9 and enforced by `RegionStyleTests` and `RegionCopyRulesTests`.

---

## Estrogen — Mind

### Prefrontal Cortex (`pfc`)

`startMonth 1` · `peakMonth 18` · `completeMonth 36`

**ABOUT**

> The prefrontal cortex is densely expressed with estrogen receptors that govern executive function, decision-making style, and emotional top-down control. Estrogen-driven shifts in dopaminergic signaling here produce some of the earliest and most noticeable cognitive effects of feminizing HRT.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | ER-α and ER-β in the prefrontal cortex are switching on. Cerebral blood flow here rises within the first weeks — the earliest measurable neural effect. |
| 2–3 | Dopaminergic tone in the prefrontal cortex is shifting. Changes in decision-making style are underway neurochemically before they are noticeable. |
| 4–6 | Prefrontal circuits are adjusting to a new dopaminergic baseline. Emotional regulation often starts to feel less effortful in this window. |
| 7–9 | Working-memory benchmarks typically show measurable improvement here as prefrontal circuits settle into the new signalling environment. |
| 10–13 | Cognitive flexibility gains are consolidating. The adjustment phase is behind you; what continues is slower circuit-level change. |
| 14–17 | Prefrontal adaptation is at its most active. Executive function and emotional top-down control are both tracking the new hormonal baseline. |
| 18–20 | The heavy recalibration is done. Remaining change in prefrontal circuits is fine tuning rather than restructuring. |
| 21–26 | Executive function reflects the estrogen-dominant environment. Refinement continues at a pace measurable over years, not months. |
| 27–35 | Prefrontal signalling is close to its adapted configuration. Changes from here are small and slow. |
| 36–47 | Prefrontal function is adapted and maintained by consistent estradiol. Cognitive health tracks age and lifestyle from here. |
| 48–59 | Four to five years of estrogen-maintained prefrontal signalling. Dopaminergic tone is a stable baseline that consistent dosing sustains. |
| 60–71 | Prefrontal dopaminergic tone is held where estradiol sets it. The signal is read continuously; the tissue does not store it. |
| 72–83 | Every day, estradiol crossing into cortical tissue modulates dopamine release and keeps regional blood flow elevated above its untreated level. |
| 84–95 | Grey matter volume and dopaminergic function both lean on this signal. Withdrawal effects appear over months, not days, which is why gaps are easy to miss. |
| 96–119 | At this tenure the relevant measures are hormone levels and sleep quality. Both track cognitive performance more closely than years on therapy. |
| 120–143 | A decade in, cohort studies of sustained hormone therapy report no adverse cognitive signal. They are observational, so they show association rather than cause. |
| 144–179 | Cardiovascular health is the largest modifiable input to prefrontal function at this stage. Blood pressure and lipids matter to this tissue directly. |
| 180–239 | Fifteen to twenty years sits at the edge of published follow-up. What the cohorts show is stability, across a sample still smaller than anyone would like. |
| 240–1200 | Past twenty years the literature thins. Prefrontal maintenance is understood mechanistically; the long-horizon outcome data is still being gathered. |

**INSIGHT — mechanism**

- ER-α and ER-β sit densely in prefrontal tissue, where estradiol modulates dopamine release. Executive function runs on that dopaminergic tone.
- Estradiol raises cerebral blood flow to the prefrontal cortex. More perfusion means more glucose reaching the tissue doing working-memory work.
- Estrogen's fast effects here are non-genomic — membrane-bound receptors changing neuron excitability within minutes, before any gene is transcribed.
- The prefrontal cortex is the last brain region to finish developing and the most plastic in adulthood. That is why hormonal signals reshape it at all.
- Estradiol tunes GABAergic interneurons in the prefrontal cortex, adjusting how strongly the region inhibits itself. Emotional top-down control is largely an inhibition problem.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The prefrontal cortex is about a tenth of the brain by volume and takes a far larger share of its glucose. |
| all months | Estradiol's effect on prefrontal performance follows an inverted U. Too little and too much both reduce it. |
| all months | Working memory holds roughly four items at once. Dopaminergic tone sets how stably they are held against distraction. |
| all months | Verbal fluency is one of the few cognitive measures sensitive enough to shift across a single dose cycle. |
| all months | Cortical estrogen receptors sit at the synapse as well as in the nucleus. Some effects land in minutes, others take weeks. |
| all months | The prefrontal cortex finishes myelinating in the mid-twenties, later than any other region, and stays the most plastic tissue in the adult brain. |
| all months | Regional cerebral blood flow rises measurably under estradiol. Imaging detects it before anyone reports feeling different. |
| all months | Sleep is when prefrontal glucose reserves are restored. No hormone level compensates for losing it. |
| months 0–59 | The first cognitive changes people notice are usually about how decisions feel rather than how well they are made. |
| months 0–59 | Neurochemical change runs ahead of subjective change. Receptors respond within weeks; noticing takes longer. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 6 | Working memory | Gains typically become measurable around month 6. |
| 12 | Cognitive flexibility | Usually consolidates around month 12. |
| 18 | Adapted dopaminergic tone | Typically reached around month 18. |
| 36 | Maintained circuits | Prefrontal circuits typically settle here around month 36. |

---

### Hippocampus (`hippocampus`)

`startMonth 1` · `peakMonth 24` · `completeMonth 48`

**ABOUT**

> The hippocampus is estrogen's main site of structural change in the brain. BDNF upregulation drives volume growth through new synapses, and verbal memory, emotional recall and spatial orientation strengthen with it.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Estradiol is upregulating BDNF in the hippocampus. New dendritic spines are forming on CA1 neurons within the first weeks — structural change, already. |
| 2–3 | Synaptogenesis is active. CA1 spine density is climbing, and verbal-memory benchmarks can show early gains this soon. |
| 4–6 | Neurogenesis in the dentate gyrus is contributing to measurable volume increase. Spatial navigation often improves alongside verbal memory. |
| 7–11 | Hippocampal volume gain is well underway. BDNF signalling stays elevated, supporting continued spine formation. |
| 12–17 | Verbal-memory performance is typically at its most improved here. The spine density and volume supporting it are established. |
| 18–23 | Volume gain continues but is decelerating. BDNF-mediated neuroprotection runs at full strength throughout. |
| 24–27 | CA1 spine density is near its maximum, roughly 30% above baseline. The hippocampus is operating close to its adapted state. |
| 28–35 | Structural growth is giving way to maintenance. Estrogen's job here shifts from building tissue to protecting it. |
| 36–47 | Hippocampal volume is being held rather than added to. Sustained BDNF signalling maintains the structure the first years built. |
| 48–59 | The hippocampus is fully adapted. Ongoing BDNF signalling holds synaptic health and plasticity as a steady state. |
| 60–71 | Hippocampal architecture is held by ongoing BDNF signalling. Spines are maintained by a growth factor the tissue keeps reading, not by a change already made. |
| 72–83 | Each day estradiol sustains BDNF transcription, supports mitochondrial function in CA1, and keeps oxidative load below where it would otherwise sit. |
| 84–95 | Verbal memory, spatial orientation and dentate neurogenesis all lean on this signal. Its withdrawal shows over the same multi-year scale it took to build. |
| 96–119 | Physical activity is the strongest adjunct at this tenure. Aerobic exercise raises BDNF through a separate pathway that adds to the hormonal one. |
| 120–143 | A decade in, longitudinal cohorts associate sustained estrogen exposure with preserved hippocampal volume. The association is consistent; the causal question stays open. |
| 144–179 | Vascular health drives hippocampal outcomes at twelve to fifteen years. The region is perfusion-sensitive, so blood pressure control is load-bearing here. |
| 180–239 | Fifteen to twenty years is where follow-up data runs out. Volume preservation holds across that window in the cohorts that exist. |
| 240–1200 | Past twenty years the mechanism is well described and the outcome data is not. BDNF-maintained architecture is understood; its multi-decade trajectory is being studied. |

**INSIGHT — mechanism**

- Estradiol upregulates BDNF transcription in the hippocampus. BDNF is the growth factor keeping dendritic spines alive, so the signal is structural, not only chemical.
- The dentate gyrus is one of two adult brain regions that make new neurons. Estrogen raises how many of those cells survive, not how many are born.
- CA1 pyramidal neurons carry estrogen receptors on the dendrites themselves. Spine density there tracks estradiol closely enough to shift within a single cycle.
- Estrogen enhances long-term potentiation — the strengthening of a synapse that fires repeatedly. That is the cellular event underneath forming a memory.
- Estradiol supports mitochondrial function in hippocampal tissue and lowers oxidative stress. Neuroprotection here is metabolic before it is anything else.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The hippocampus is named for its resemblance to a seahorse. Each hemisphere carries one, and they specialise differently. |
| all months | BDNF is the most abundant growth factor in the brain, and estradiol is among the strongest regulators of its transcription. |
| all months | Spine density on CA1 dendrites can shift by roughly a third as estradiol changes. Structural, and measurable. |
| all months | Taxi drivers show enlarged posterior hippocampi from navigation alone. This tissue rebuilds itself in response to use. |
| all months | Aerobic exercise raises BDNF through a pathway separate from the hormonal one. The two effects add. |
| all months | Memory consolidation happens largely during slow-wave sleep, in this tissue. Estradiol supports the machinery; sleep supplies the opportunity. |
| all months | The hippocampus is unusually perfusion-sensitive, which is why blood pressure control appears so often in memory research. |
| all months | In any estrogen-maintained brain, hippocampal volume tracks sustained estradiol. The relationship holds across decades of exposure. |
| months 0–59 | Dendritic spines begin forming on CA1 neurons within the first weeks. Structural brain change starts before anything visible does. |
| months 0–59 | Verbal memory benchmarks are often the first cognitive measure to move, within a few months of starting. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 6 | Measurable volume gain | Hippocampal volume increase typically shows around month 6. |
| 12 | Verbal memory | Benchmarks are usually at their most improved around month 12. |
| 24 | Maximum spine density | CA1 density typically reaches its highest around month 24. |
| 48 | Maintained volume | Volume typically settles at its held level around month 48. |

---

### Amygdala (`amygdala`)

`startMonth 1` · `peakMonth 12` · `completeMonth 24`

**ABOUT**

> The amygdala sets emotional salience: how intensely and broadly feelings register. Estrogen shifts its responsiveness toward a wider range, which many describe as access to depth that previously felt muted.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Estrogen is starting to modulate amygdala reactivity. Emotional intensity can feel heightened while the region recalibrates. |
| 2–3 | Amygdala response patterns are shifting quickly. A wider emotional range and deeper emotional recall are commonly reported this early. |
| 4–5 | Recalibration is at its most active. Empathy and emotional access often change noticeably in this window. |
| 6–8 | The qualitative shift in how emotions are experienced is typically clearest here. The initial adjustment is well past. |
| 9–11 | Emotional range is still broadening but the rate is easing. The amygdala is approaching its recalibrated baseline. |
| 12–13 | Amygdala function is stabilising. Emotional responses reflect the estrogen-dominant environment rather than the transition into it. |
| 14–17 | Responses are well calibrated. What continues is subtle circuit-level refinement rather than further recalibration. |
| 18–23 | The emotional baseline established over the past year is holding. Variation now tracks life and dose timing. |
| 24–35 | Recalibration has run its course. The emotional landscape is held by consistent estradiol. |
| 36–47 | Emotional baseline is fully established. Mood variation tracks dose-cycle timing and circumstances, not ongoing adaptation. |
| 48–59 | Four to five years of estrogen-dominant emotional processing. Trough days remain the main pharmacokinetic influence on mood. |
| 60–71 | The amygdala's emotional calibration is held by continuous signalling. Reactivity tracks circulating estradiol, which is why a trough registers as mood. |
| 72–83 | Day to day, neurosteroids synthesised in limbic tissue act on GABA-A receptors, and their supply follows the hormone level in your blood. |
| 84–95 | Emotional range, salience and the amygdala-to-prefrontal coupling all rest on this signal, and all of them follow it within a dose cycle. |
| 96–119 | At this tenure, sleep quality and dose interval predict emotional stability better than anything else. Both are measurable and both are adjustable. |
| 120–143 | A decade in, emotional baseline is one of the most stable things about long-term therapy. Studies of mood at this tenure find variation tracks life, not tenure. |
| 144–179 | Limbic function at twelve to fifteen years is unremarkable in follow-up, which is itself the finding. The tissue asks for consistency, not adjustment. |
| 180–239 | Fifteen to twenty years is the edge of published follow-up. Emotional outcomes across it are stable and, in the cohorts, uneventful. |
| 240–1200 | Past twenty years there is little published. The neurosteroid mechanism is well characterised; how it reads across four decades of exposure is not yet. |

**INSIGHT — mechanism**

- The amygdala is dense in ER-β, the receptor subtype tied to emotional salience and anxiety rather than to reproductive signalling.
- Estradiol changes how strongly the amygdala couples to the prefrontal cortex. Emotional experience is set by that connection, not by either region alone.
- Neurosteroids made in the brain itself act on GABA-A receptors in the amygdala, and their supply tracks circulating hormone. That is why a trough can be felt as mood.
- Estrogen modulates serotonin transporter density in limbic tissue — the same target SSRIs act on is being retuned by the dose.
- The amygdala tags an experience with emotional weight before the cortex has interpreted it. Shifting its reactivity changes what registers as significant.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The amygdala responds to a face before the visual cortex has resolved what it is. It tags salience ahead of recognition. |
| all months | Emotional memories are encoded more strongly than neutral ones because the amygdala modulates hippocampal consolidation directly. |
| all months | Tear thresholds are partly hormonal. Estradiol and prolactin both influence them, which is one reason the threshold can move. |
| all months | The amygdala is about the size of an almond, which is where its name comes from. Its reach across the brain is far larger. |
| all months | Neurosteroids are synthesised inside the brain rather than delivered to it. Their supply still tracks what is circulating. |
| all months | Difficulty naming emotions eases for some people under estradiol. The change is in access rather than in the feelings themselves. |
| all months | The amygdala-to-prefrontal connection matures later than either region alone. Emotional regulation is a connectivity property. |
| all months | In any estrogen-maintained brain, limbic reactivity tracks circulating levels closely enough to follow a dose cycle. |
| months 0–59 | Emotional intensity often rises before it settles. The amygdala is recalibrating its thresholds, and recalibration is not smoothness. |
| months 0–59 | The earliest reported change on feminising therapy is usually emotional rather than physical. It is also the fastest to arrive. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 3 | Widened emotional range | Typically reported by around month 3. |
| 6 | Clearest shift | The change in emotional experience is usually clearest around month 6. |
| 12 | Recalibrated reactivity | Amygdala reactivity typically reaches its new baseline around month 12. |
| 24 | Held baseline | The emotional baseline is typically steady from around month 24. |

---

### Synaptic Plasticity (`synaptic`)

`startMonth 1` · `peakMonth 18` · `completeMonth 60`

**ABOUT**

> Synaptic plasticity is the brain's capacity to form and strengthen connections, and estrogen is among its strongest promoters. Upregulated NMDA receptors, BDNF and dendritic spine density are the substrate the cognitive and emotional changes sit on.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | NMDA receptor expression is rising in hippocampal and cortical synapses. Long-term potentiation is enhanced — circuits are primed to remodel. |
| 2–3 | Dendritic spine formation is active through CREB-mediated transcription. Structural change is measurably underway across limbic regions. |
| 4–6 | Synaptic density is climbing. The remodelling is broad — hippocampal and cortical circuits are reshaping at the same time. |
| 7–9 | Spine formation is running at high rate. The architecture laid down now becomes the foundation of the adapted state. |
| 10–13 | Density gains continue but are beginning to decelerate. Remodelling is shifting gradually toward maintenance. |
| 14–17 | Synaptic density is approaching its plateau. The building phase is handing over to the sustaining one. |
| 18–20 | Architecture is largely remodelled. Estrogen's role shifts from constructing synapses to keeping them. |
| 21–26 | The enhanced plasticity state is maintained by ongoing estrogen. This is continuous work rather than a result already banked. |
| 27–34 | Synaptic architecture is mature. BDNF-mediated neuroprotection is the main ongoing mechanism. |
| 35–45 | The remodelled architecture is established. Estrogen sustains synaptic health as an active steady state. |
| 46–59 | Four to five years of maintained plasticity. Consistent dosing is what holds the remodelled architecture in place. |
| 60–71 | Synaptic density is held, not banked. Estradiol is a trophic signal the brain reads continuously, and the remodelled architecture depends on it arriving. |
| 72–83 | Every day estrogen sustains NMDA receptor expression and CREB-mediated transcription, the two processes that keep existing spines alive. |
| 84–95 | Plasticity, memory consolidation and mood regulation all draw on this architecture. It relaxes over months if the signal drops, on the same scale it was built. |
| 96–119 | Cognitively demanding activity and aerobic exercise both raise plasticity through pathways separate from the hormonal one. At this tenure they add the most. |
| 120–143 | A decade in, the cohorts describe stable cognitive performance under sustained therapy. The sample sizes are modest and the follow-up windows are still opening. |
| 144–179 | At twelve to fifteen years, vascular and metabolic health carry more weight than hormonal variables. Synapses are expensive tissue and perfusion-dependent. |
| 180–239 | Fifteen to twenty years marks the edge of the published record. Plasticity measures across it hold steady in the available follow-up. |
| 240–1200 | Past twenty years the mechanism is characterised and the outcomes are not. Sustained plasticity is understood cell by cell; the decades-long picture is open. |

**INSIGHT — mechanism**

- Estradiol upregulates NMDA receptor expression. Those receptors are the coincidence detectors that decide which synapses get strengthened.
- Spine formation runs through CREB-mediated transcription: the hormone reaches the nucleus and changes which proteins the neuron builds.
- A dendritic spine can form in under an hour. The remodelling is fast per synapse; what takes years is accumulating it across billions of them.
- Estrogen acts on synapses by two routes at once — slow genomic transcription, and fast membrane signalling that alters excitability within minutes.
- Synaptic plasticity is maintained, not banked. The trophic signal has to keep arriving for the remodelled architecture to hold.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The adult brain holds on the order of a hundred trillion synapses. Estradiol acts on a large share of them at once. |
| all months | Most synapses in the adult brain are replaced or remodelled over a lifetime. Stability at the network level hides constant turnover underneath. |
| all months | NMDA receptors open only when two conditions coincide. That is how a synapse detects that two events belong together. |
| all months | Long-term potentiation was first demonstrated in 1973 and remains the best cellular model of memory formation. |
| all months | Synapses are among the most metabolically expensive structures in the body. Maintaining them is most of what the brain spends energy on. |
| all months | Dendritic spines come in several shapes, and the shape tracks how strong and how stable the synapse is. |
| all months | Plasticity is capacity, not improvement. It is what makes new learning possible, and it does not choose what gets learned. |
| all months | In any estrogen-maintained brain, synaptic density depends on the signal continuing to arrive. The architecture is rented, not owned. |
| months 0–59 | NMDA receptor expression rises within the first weeks. Circuits are primed to remodel before any remodelling shows. |
| months 0–59 | The first year produces more synaptic change than any later year, and has the least externally visible to show for it. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 6 | Broad remodelling | Both limbic and cortical circuits are typically remodelling by month 6. |
| 18 | Remodelled density | Synaptic density typically reaches its new level around month 18. |
| 36 | Mature architecture | The remodelled architecture is typically mature around month 36. |
| 60 | Sustained plasticity | Enhanced plasticity is typically a steady state from around month 60. |

---

## Estrogen — Body

### Hips & Waist (`hips`)

`startMonth 3` · `peakMonth 18` · `completeMonth 36`

**ABOUT**

> Estrogen redirects subcutaneous fat toward a gynoid pattern, depositing at the hips, iliac crest and greater trochanter while androgenic waist fat recedes. The hip-to-waist shift runs on the two-to-three year adipocyte turnover cycle.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 3 | ER-α receptors in gluteofemoral fat are activating. Lipoprotein lipase activity is rising in the hip depots, directing new storage there. |
| 4–5 | Subcutaneous fat is beginning to deposit at the iliac crest and greater trochanter. Nothing is visible yet; the enzyme work is. |
| 6–8 | Deposition at the hip is measurable. The waist may start narrowing as androgenic visceral fat recedes. |
| 9–11 | Hip-to-waist ratio is shifting. New gynoid adipocytes are filling while older androgen-pattern cells are cleared. |
| 12–14 | Adipocyte turnover is mid-cycle. Fat laid down since month three is maturing in the gynoid pattern. |
| 15–17 | Deposition is at its fastest. The hip-to-waist shift reads more clearly over a season than over a month. |
| 18–20 | The major structural shift is largely done. What continues is refinement as the turnover cycle completes. |
| 21–26 | Redistribution is slowing. Roughly two-thirds of the first full adipocyte cycle is behind you. |
| 27–35 | Turnover is about 80% through its first complete pass. New fat is essentially all estrogen-pattern now. |
| 36–47 | Distribution is established and maintained by consistent estradiol. Weight changes still deposit in this pattern. |
| 48–59 | Body composition is fully estrogen-dominant. Maintenance depends on continued dosing rather than additional time. |
| 60–71 | Estradiol is holding this distribution in place. Adipose tissue reads the signal continuously, so the pattern is maintained rather than memorised. |
| 72–83 | Day to day, estrogen keeps lipoprotein lipase activity high in gluteofemoral depots and suppressed in visceral ones. Every meal is sorted by that gradient. |
| 84–95 | Fat distribution, insulin sensitivity and bone density all rest on this signal. Adipose redistribution would reverse over a multi-year adipocyte cycle without it. |
| 96–119 | Bone mineral density becomes the primary measure at this tenure. DEXA every two to five years is typical, and estradiol is its principal regulator. |
| 120–143 | A decade in, cohort data links sustained estradiol with maintained bone density. Levels in range are the variable that predicts the result. |
| 144–179 | At twelve to fifteen years the picture is bone, lipids and blood pressure. In any estrogen-maintained skeleton, osteoclasts resorb and osteoblasts rebuild; estradiol sets the balance. |
| 180–239 | Fifteen to twenty years is where follow-up ends. Bone density and fat distribution both hold across it where levels stayed in range. |
| 240–1200 | Past twenty years the data thins. The remodelling mechanism is well established; what it looks like at forty years of exposure is being gathered now. |

**INSIGHT — mechanism**

- Gluteofemoral adipocytes carry more ER-α than abdominal ones. Estrogen raises lipoprotein lipase activity there, so circulating fat is captured at the hip rather than the waist.
- Lipoprotein lipase sits on the capillary wall and clips fatty acids out of the blood for the fat cell behind it. Where the enzyme is active is where fat lands.
- Estrogen suppresses lipolysis in gluteofemoral depots. Fat here is not only stored more readily — it is released more reluctantly.
- An adipocyte lives roughly ten years, and the population turns over at 8% annually. Redistribution is limited by that rate, not by dose.
- Subcutaneous gluteofemoral fat is metabolically protective: it traps lipids that would otherwise reach the liver and the visceral compartment.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | An adipocyte lives about ten years, and one in twelve is replaced each year. Redistribution is capped by that rate. |
| all months | Fat cell number is largely fixed after adolescence. What changes is how much lipid each cell holds. |
| all months | Estrogen receptors in fat come in two subtypes with opposite effects on storage. Which one dominates varies by depot. |
| all months | Hip width in imaging is measured bone to bone, so the number moves far less than the silhouette does. |
| all months | Hip-to-waist ratio predicts metabolic risk better than weight does, because it describes where fat sits rather than how much there is. |
| all months | The greater trochanter and iliac crest are the two anatomical anchors of the gynoid pattern. Both are bone, and both stay put. |
| all months | In any estrogen-maintained skeleton, the pelvis is a primary site of bone remodelling. Estradiol sets where resorption and rebuilding balance. |
| all months | Weight loss empties fat cells without removing them. The pattern reasserts itself when weight returns. |
| months 0–59 | The enzyme change comes first and the visible change comes later. Lipoprotein lipase shifts within weeks; the silhouette takes years. |
| months 0–59 | Hip change is limited by cell turnover rather than by hormone level. More estradiol does not speed it up. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 6 | Iliac deposition | Deposition at the iliac crest typically becomes measurable around month 6. |
| 12 | Ratio shift | The hip-to-waist ratio usually moves most noticeably around month 12. |
| 24 | First fat-cell cycle | Most of the first adipocyte turnover cycle is typically done by month 24. |
| 36 | Established distribution | Gynoid distribution is typically established around month 36. |

---

### Thighs (`thighs`)

`startMonth 4` · `peakMonth 20` · `completeMonth 36`

**ABOUT**

> Thigh fat accumulation is a hallmark of estrogen-dominant body composition, driven by rising lipoprotein lipase activity in gluteofemoral depots. Inner-thigh pads and the curve from hip to knee develop over two to three years.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 4 | Lipoprotein lipase activity is rising in thigh depots. Subcutaneous fat is starting to accumulate on the outer and inner thigh. |
| 5–6 | Deposition is underway but below the threshold of visible change. Pants fit is usually the first signal. |
| 7–9 | Thigh circumference is beginning to increase measurably. Inner-thigh fat pads are starting to form. |
| 10–12 | Inner-thigh pads are visibly developing — a hallmark of estrogen-dominant composition. |
| 13–15 | The curve from hip to knee is becoming more defined as gynoid deposition continues. |
| 16–19 | Thigh deposition is at its most active. This is the window where change reads clearest month to month. |
| 20–22 | The major change in thigh contour is largely complete. Refinement tracks the adipocyte turnover cycle from here. |
| 23–27 | Deposition is slowing. The gynoid contour is well defined and continues to fill gradually. |
| 28–35 | Thigh distribution is approaching its established pattern. Remaining change is subtle. |
| 36–47 | Thigh distribution is established and maintained by consistent estradiol. |
| 48–59 | Fully estrogen-dominant thigh composition. Weight changes deposit in this established pattern. |
| 60–71 | Gluteofemoral fat is held here by an active signal. Estradiol keeps storage biased toward the thigh and keeps release from it slow. |
| 72–83 | Each day, alpha-2 adrenergic dominance and estrogen-suppressed lipolysis keep this depot filling more readily than it empties. |
| 84–95 | This distribution is metabolically load-bearing: gluteofemoral fat traps lipid that would otherwise reach the liver. That protection depends on the signal continuing. |
| 96–119 | Lean mass becomes the measure worth watching at this tenure. Resistance training maintains it; estradiol does not substitute for the mechanical load. |
| 120–143 | A decade in, thigh composition is stable in follow-up. Age-related lean mass decline begins around this point and is largely training-responsive. |
| 144–179 | At twelve to fifteen years, muscle and bone in the leg move together. Loaded lower-body exercise is the input that acts on both. |
| 180–239 | Fifteen to twenty years is the edge of the published record. Fat distribution holds across it wherever hormone levels were sustained. |
| 240–1200 | Past twenty years there is little longitudinal data on limb composition specifically. The depot biology is well described; the multi-decade trajectory is not. |

**INSIGHT — mechanism**

- Lipoprotein lipase activity rises in thigh fat under estradiol while falling in visceral depots. One enzyme, regulated in opposite directions by site.
- Thigh adipocytes respond to estrogen by expanding rather than dividing. Existing cells enlarge well before new ones are recruited.
- Alpha-2 adrenergic receptors outnumber beta receptors in gluteofemoral fat, which biases these depots toward storage and away from release.
- Estrogen slows lipolysis in the thigh depot. That resistance to mobilisation is why lower-body fat is the last to move on any deficit.
- Fat cell number is largely set in adolescence; what changes is how much lipid each cell holds. Distribution is a filling pattern, not a counting one.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The thigh holds the largest continuous subcutaneous fat sheet in the body. Change here shows as contour before it shows as circumference. |
| all months | Thigh circumference is associated with lower cardiovascular risk, independent of overall body weight. |
| all months | Inner-thigh fat pads are a distinct anatomical depot, not simply more of the same subcutaneous layer. |
| all months | Muscle and fat in the thigh answer to different signals. One responds to load within weeks, the other to hormones across years. |
| all months | Cellulite is a structural feature of subcutaneous fat under a particular collagen architecture. It appears in any estrogen-maintained tissue. |
| all months | The quadriceps is the largest muscle group in the body by volume, and the fastest to lose mass with disuse. |
| all months | Estradiol slows lipolysis here specifically. This depot resists mobilisation by design rather than by accident. |
| all months | Fat distribution is strongly genetically influenced. Two people on identical regimens can land in visibly different places. |
| months 0–59 | Pants fit changes before a tape measure does. The earliest thigh change is usually detected by clothing. |
| months 0–59 | Thigh deposition starts later than abdominal change. The depots do not move on the same clock. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 9 | Inner-thigh pads | Typically become visible around month 9. |
| 16 | Defined contour | The curve from hip to knee is usually well defined around month 16. |
| 20 | Slowing deposition | Thigh deposition typically begins slowing around month 20. |
| 36 | Established distribution | Thigh distribution is typically established around month 36. |

---

### Abdomen (`abdomen`)

`startMonth 3` · `peakMonth 12` · `completeMonth 24`

**ABOUT**

> While estrogen builds fat at the hips and thighs, it draws down androgenic visceral fat around the abdominal organs, reversing the android pattern. Visceral fat responds faster than gynoid deposition, so the belly often softens first.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 3 | Androgenic visceral fat is beginning to recede as testosterone falls. The belly often softens before any hip change shows. |
| 4–5 | Visceral reduction is underway. This depot responds faster than the hips because it is the one androgens were driving. |
| 6–7 | Visceral fat loss is measurable. Subcutaneous abdominal fat is shifting off the android pattern and the waistline reads softer. |
| 8–9 | The android-to-gynoid shift is well underway. Combined with hip gain, the waist-to-hip ratio is moving noticeably. |
| 10–11 | Abdominal change is at its fastest. Most of the visceral reduction available to estrogen happens across this stretch. |
| 12–13 | The visceral reduction is largely complete. Abdominal fat is approaching its estrogen-dominant distribution. |
| 14–17 | The abdominal pattern is stabilising. What remains is subtle refinement rather than further redistribution. |
| 18–23 | Distribution is settling. Remaining change tracks the tail of the adipocyte turnover cycle. |
| 24–35 | Abdominal fat is established in its estrogen-dominant pattern. |
| 36–47 | The pattern is maintained by consistent hormone levels. Weight changes follow estrogen-pattern deposition. |
| 48–59 | Four to five years in, abdominal composition tracks diet, activity and sleep alongside continued dosing. |
| 60–71 | Visceral fat is kept low here by continuous signalling. Estradiol suppresses lipoprotein lipase in the visceral compartment for as long as it is present. |
| 72–83 | Day to day, this is where the hormone does its most metabolically consequential work: sorting incoming lipid away from the portal circulation. |
| 84–95 | Insulin sensitivity, hepatic lipid load and inflammatory tone all lean on low visceral fat. All three drift over years if the signal drops. |
| 96–119 | At this tenure the relevant measures are fasting glucose, lipids and waist circumference. They are tracked as general wellness rather than as hormone markers. |
| 120–143 | A decade in, sustained estradiol is associated with a gynoid visceral profile in follow-up. Diet and activity move the number more than dose does. |
| 144–179 | At twelve to fifteen years, modest visceral accumulation appears in any adult body. Estradiol slows the trend without removing it. |
| 180–239 | Fifteen to twenty years is the edge of published follow-up. Metabolic markers across it track lifestyle far more closely than tenure. |
| 240–1200 | Past twenty years the metabolic literature is thin for this population specifically. The mechanism generalises; the long-horizon cohort data is still accruing. |

**INSIGHT — mechanism**

- Visceral adipocytes carry a higher density of androgen receptors and respond quickly when testosterone falls. That is why the belly moves before the hips do.
- Visceral fat drains through the portal vein straight into the liver. Reducing it changes hepatic lipid exposure, not only silhouette.
- Estrogen lowers lipoprotein lipase activity in visceral depots while raising it at the hip. The redistribution is one enzyme read two ways.
- Visceral fat is metabolically active tissue that secretes inflammatory cytokines. Losing it is a systemic change as much as a shape one.
- Subcutaneous abdominal fat and visceral fat sit millimetres apart and answer to different signals. Only one of the two is androgen-driven.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The abdominal wall holds several distinct fat layers. Only the deepest of them sits inside the muscle and around the organs. |
| all months | Visceral fat is an endocrine organ in its own right. It secretes inflammatory signalling molecules continuously. |
| all months | Aromatase in adipose tissue converts androgens to estrogens on site. Fat participates in the hormonal environment rather than only storing energy. |
| all months | Waist circumference at the navel predicts metabolic risk better than body mass index does. |
| all months | Visceral fat responds faster than any other depot to hormonal change, in both directions. |
| all months | A softer belly can appear before the tape measure moves. Visceral loss changes shape before it changes circumference. |
| all months | In any estrogen-maintained body, visceral fat sits lower than in an androgen-maintained one. The difference is enzymatic. |
| all months | Sleep deprivation raises visceral fat storage independently of calories. This depot is unusually sensitive to cortisol. |
| months 0–59 | The belly is often the first region to change and the first one people stop noticing. Visceral loss shows early and quietly. |
| months 0–59 | Abdominal softening usually arrives before hip gain. The depots run on different timescales from the start. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 6 | Measurable visceral loss | Visceral fat reduction typically shows on a tape measure around month 6. |
| 10 | Fastest change | Abdominal composition usually moves fastest around month 10. |
| 12 | Visceral floor | Visceral fat typically reaches its lowest level around month 12. |
| 24 | Established pattern | The estrogen-dominant abdominal pattern is typically established around month 24. |

---

### Glutes (`glutes`)

`startMonth 3` · `peakMonth 24` · `completeMonth 48`

**ABOUT**

> Gluteal fat pads expand as estrogen redirects storage toward the gynoid pattern, combining with ligament laxity changes to reshape the posterior profile and posture. Development here unfolds on the 2–3 year adipocyte turnover cycle, reaching maturity around year 4–5.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 3 | Gluteal deposition is beginning, usually below the threshold of notice. LPL activity in gluteal depots is rising. |
| 4–5 | Fat pads in the gluteal region are starting to expand. Pants fit in the seat changes before the profile does. |
| 6–8 | Gluteal expansion is becoming noticeable. Combined with hip deposition, the posterior profile is starting to shift. |
| 9–13 | Fat pads are actively expanding. Ligament changes are rotating the pelvis slightly, which alters posture along with shape. |
| 14–18 | Gluteal development is at its most active. The silhouette change reads clearest across this window. |
| 19–23 | Expansion is decelerating but still running. The major structural change is largely done. |
| 24–27 | Development is maturing. The adipocyte turnover cycle is still completing, so subtle refinement continues. |
| 28–35 | The 2–3 year turnover cycle is nearing its first full pass. Change from here is slow and small. |
| 36–47 | Gluteal distribution is approaching maturity. Refinements continue through year four or five. |
| 48–59 | Gluteal distribution is mature and maintained by consistent estradiol. |
| 60–71 | Gluteal fat is held by an active hormonal signal. This depot has among the highest estrogen receptor densities in the body, and it reads estradiol continuously. |
| 72–83 | Each day estradiol keeps lipoprotein lipase elevated here and lipolysis suppressed, so this depot fills preferentially and empties last. |
| 84–95 | Shape, posture and pelvic ligament tone all rest on this signal. Withdrawal shifts them back over the multi-year adipocyte cycle that built them. |
| 96–119 | Hip bone mineral density is the measure that matters at this tenure. The femoral neck is a standard DEXA site and estradiol is its main regulator. |
| 120–143 | A decade in, gluteal distribution is stable in follow-up. Weight changes still deposit along the estrogen-established pathway. |
| 144–179 | At twelve to fifteen years the hip is watched for bone rather than shape. Femoral neck density and fall risk are the clinically relevant pair. |
| 180–239 | Fifteen to twenty years marks the edge of the record. Distribution holds across it in the cohorts with sustained levels. |
| 240–1200 | Past twenty years the outcome data thins while the mechanism does not. Depot biology is well described; forty-year trajectories are not yet published. |

**INSIGHT — mechanism**

- Gluteal adipocytes hold among the highest ER-α densities of any fat depot in the body. Estrogen's storage signal lands hardest here.
- Estrogen alters collagen crosslinking in pelvic ligaments. Posture shifts as they loosen, and the posterior profile changes with it.
- Lipoprotein lipase activity in gluteal fat rises under estradiol, capturing circulating triglyceride at this site preferentially.
- The gluteal depot is slow to fill and slow to empty. Alpha-2 adrenergic dominance makes fat stored here resistant to mobilisation.
- Adipocyte turnover runs on a multi-year cycle. Development here is limited by that biology, not by how much estradiol is circulating.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | Gluteal fat has among the highest estrogen receptor densities of any depot in the body. |
| all months | The gluteus maximus is the largest single muscle in the body. The fat pad sits on top of it, not instead of it. |
| all months | Subcutaneous fat here sits in fibrous chambers separated by septa. That architecture, not the fat itself, sets the surface texture. |
| all months | This depot fills first and empties last. That ordering is set by receptor density rather than by anything you do. |
| all months | Gluteofemoral fat is associated with better lipid profiles independent of total body fat. |
| all months | The femoral neck is a standard DEXA measurement site. Bone and fat at the hip are tracked by the same appointment. |
| all months | In any estrogen-maintained skeleton, hip bone density depends on estradiol continuing to arrive. It is not banked. |
| all months | Prolonged sitting reduces gluteal muscle activation measurably. The fat pad is hormonal; the muscle under it is not. |
| months 0–59 | Seat fit changes before the mirror does. Gluteal deposition is detected by clothing well before it is visible. |
| months 0–59 | Gluteal change runs on the slowest clock of any region. Development here is still moving at year four. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 9 | Profile shift | The posterior profile typically starts shifting around month 9. |
| 18 | Pelvic tilt | Ligament-driven changes in pelvic tilt usually settle around month 18. |
| 24 | Fastest expansion | Gluteal deposition typically runs fastest around month 24. |
| 48 | Mature distribution | Gluteal distribution typically reaches maturity around month 48. |

---

### Chest (`chest`)

`startMonth 1` · `peakMonth 18` · `completeMonth 60`

**ABOUT**

> Breast development on estrogen follows the same Tanner staging as endogenous puberty, starting with a glandular bud under the areola. Visible growth typically spans years one to three; ductal maturation continues through year five.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Breast bud formation is beginning. Ductal tissue is forming beneath the areola — the first stage of Tanner 2. |
| 2–3 | Tanner stage 2 is establishing. Areolar tissue is more sensitive, the bud is palpable, and glandular tissue is forming actively. |
| 4–6 | The breast mound is expanding beyond the areola. Montgomery glands may begin developing. |
| 7–9 | Tanner stage 3 is typically reached here and the mound is distinctly elevated. Growth is non-linear, so plateaus and spurts are both normal. |
| 10–13 | Tanner stage 3 to 4. The areola and papilla form a secondary mound in many people; the ductal-lobular system is developing. |
| 14–17 | Growth is at its fastest. Tanner stage 4 is typically reached across this window. |
| 18–20 | The breast mound is mature in shape. Internal ductal-lobular development continues well past the visible phase. |
| 21–26 | Visible growth is slowing. The work continuing is internal — ducts branching and lobules forming. |
| 27–34 | The visible phase is largely complete. Ductal-lobular maturation continues through years three to five. |
| 35–45 | The ductal-lobular system is in its final maturation phase. Tissue is approaching full maturity. |
| 46–59 | Tanner stage 5, where it is reached, typically arrives across this window. Full ductal-lobular maturation can take the whole sixty months. |
| 60–71 | Breast tissue is estrogen-dependent tissue. Estradiol is what holds the ductal-lobular architecture in place, reading the signal the way it did while building it. |
| 72–83 | Day to day, estradiol sustains the epithelium and the stromal fat that gives breast tissue its volume. Both respond to level, not to tenure. |
| 84–95 | Tanner stage 5 is the named endpoint of the developmental sequence. A documented minority reach stage 3 or 4 and hold there, which is a recognised outcome. |
| 96–119 | Age-appropriate breast screening is the relevant health behaviour at this tenure. Mammographic density is highest in younger, denser tissue and eases across the decades. |
| 120–143 | A decade in, breast tissue is maintained by continued estradiol. Cohort follow-up at this tenure focuses on screening cadence rather than on development. |
| 144–179 | At twelve to fifteen years, density on imaging has typically eased, which changes how a mammogram reads rather than what it looks for. |
| 180–239 | Fifteen to twenty years sits at the edge of published follow-up. Tissue volume holds across it where estradiol levels were sustained. |
| 240–1200 | Past twenty years the screening literature for this tissue is still being built. What is established is that the tissue stays estradiol-dependent throughout. |

**INSIGHT — mechanism**

- Breast tissue is one of the few adult tissues that can still run a full developmental program. It is the same ductal branching as endogenous puberty, on the same signal.
- Estrogen drives ductal elongation; progesterone drives lobular branching. The two arms of breast development answer to different hormones.
- Terminal duct lobular units are the functional endpoint of breast development, and they take years to form. Most of that work is invisible from outside.
- Areolar tissue carries a dense supply of estrogen receptors. Sensitivity changes there are receptor-level events, not a side effect of growth.
- Growth is driven by tissue-level receptor density, which varies between people far more than serum estradiol does. The lab number does not predict the outcome.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | Breast tissue can run a complete developmental program in adulthood. Few adult tissues retain that capacity. |
| all months | Tanner staging was published in 1969 and still describes the sequence. It was never a schedule, only an order. |
| all months | A documented minority reach Tanner stage 3 or 4 and hold there. That is a recognised outcome of the same process. |
| all months | The breast is one of the few organs that does most of its development after birth. Almost nothing of it is built in the womb. |
| all months | The breast has no muscle of its own. Its shape is carried by skin, glandular tissue, fat and the ligaments between them. |
| all months | Montgomery glands are modified sebaceous glands on the areola. Their appearance is a staging landmark in its own right. |
| all months | In any estrogen-maintained breast tissue, mammographic density is highest when the tissue is youngest and eases across the decades. |
| all months | Growth is not linear. Plateaus lasting months are part of the normal sequence rather than an interruption to it. |
| months 0–59 | Breast buds form beneath the areola before anything is visible. The tissue is palpable before it has any outline. |
| months 0–59 | Areolar sensitivity often changes before size does. The receptors respond ahead of the volume. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 3 | Tanner stage 2 | Typically establishes around month 3. |
| 9 | Tanner stage 3 | Typically arrives around month 9. |
| 14 | Tanner stage 4 | Typically arrives around month 14. |
| 48 | Tanner stage 5 | Where it is reached, typically arrives around month 48. |

---

## Testosterone — Mind

### Prefrontal Cortex (`pfc`)

`startMonth 1` · `peakMonth 12` · `completeMonth 24`

**ABOUT**

> The prefrontal cortex carries androgen receptors that respond to rising testosterone, influencing executive processing, risk assessment and verbal thought. Many describe a shift toward more direct, linear thinking over the first year or two.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Androgen receptors in the prefrontal cortex are activating. Early shifts in decision-making style vary a lot dose to dose this early. |
| 2–3 | Prefrontal circuits are adapting. A shift toward more direct, linear processing is commonly reported this early. |
| 4–5 | Adaptation is active. Verbal fluency patterns can shift alongside the change in decisiveness. |
| 6–8 | Executive processing is settling into its androgen-adapted configuration. Day-to-day variability is decreasing. |
| 9–11 | Adaptation is approaching its settled state. The shift toward more decisive processing is typically stable by now. |
| 12–13 | The major neural adaptation is done. What continues is subtle refinement of the same circuits. |
| 14–17 | Prefrontal function is in its refinement phase. Executive processing reflects the androgen-dominant environment. |
| 18–23 | The prefrontal cortex is operating in its adapted configuration. Change from here is slow. |
| 24–35 | Fully adapted. Cognitive patterns reflect the androgen-dominant environment as a steady state. |
| 36–47 | Stable. Androgen-maintained executive processing is the ongoing baseline. |
| 48–59 | Four to five years of androgen-dominant prefrontal signalling. Dose stability is the key hormonal input. |
| 60–71 | Prefrontal circuits are held in their androgen-adapted configuration. Testosterone is read continuously here, both directly and after local conversion to estradiol. |
| 72–83 | Day to day, androgen receptor binding shifts transcription in prefrontal tissue over hours, and aromatase supplies a second signal alongside it. |
| 84–95 | Executive processing style and its stability across a week both rest on this signal. Dose gaps show up as transient dips before anything else. |
| 96–119 | At this tenure the useful measures are trough levels and sleep. Both predict cognitive steadiness better than years on therapy. |
| 120–143 | A decade in, follow-up of long-term testosterone therapy reports no adverse cognitive signal. The cohorts are smaller and younger than the estrogen ones. |
| 144–179 | At twelve to fifteen years, cardiovascular health becomes the dominant input. Hematocrit, blood pressure and lipids all act on prefrontal perfusion. |
| 180–239 | Fifteen to twenty years is close to the edge of published follow-up for this population. What exists across that window shows stability. |
| 240–1200 | Past twenty years the record is sparse. The receptor mechanism is well described; the multi-decade cognitive picture is actively being studied. |

**INSIGHT — mechanism**

- The prefrontal cortex carries androgen receptors and aromatase both, so testosterone acts here directly and again after conversion to estradiol.
- Testosterone modulates dopaminergic tone in prefrontal circuits. Risk assessment and decisiveness run on that system.
- Androgen receptor binding is slow and long-lived: the receptor-hormone pair moves into the nucleus and stays for hours, changing transcription while it is there.
- Prefrontal response to androgens varies widely between people because receptor sensitivity is set by a genetic repeat length, not by dose.
- Testosterone alters GABAergic inhibition in prefrontal circuits — one route by which the register of thinking can shift.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | Working memory capacity is remarkably stable across adulthood. What hormonal change alters is how effortful holding things feels. |
| all months | The prefrontal cortex is the most metabolically expensive region per gram. Sleep and glucose availability shape it as much as hormones do. |
| all months | An androgen receptor stays bound in the nucleus for hours. That residence time is why effects outlast the blood peak. |
| all months | Decisiveness and impulsivity are different things that look alike from outside. Only one of them tracks dopaminergic tone. |
| all months | Verbal fluency and spatial rotation load on different circuits. A hormonal change can move them in opposite directions. |
| all months | The prefrontal cortex is the most plastic tissue in the adult brain, which is why hormonal signals reshape it at all. |
| all months | Trough levels predict cognitive steadiness better than peak levels do. The low point sets the floor. |
| all months | Aromatase in the brain means no androgen effect here is purely androgenic. Both receptor families are engaged at once. |
| months 0–59 | Levels are least stable in the first months, so day-to-day variation is widest then. It narrows as dosing settles. |
| months 0–59 | The earliest reported cognitive change is usually a shift in how thinking feels rather than in what it produces. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 3 | Direct processing | A shift toward it is typically reported by around month 3. |
| 6 | Steadier week to week | Day-to-day variability usually narrows around month 6. |
| 12 | Adapted configuration | Prefrontal circuits typically reach it around month 12. |
| 24 | Held processing style | Executive processing is typically steady from around month 24. |

---

### Hippocampus (`hippocampus`)

`startMonth 1` · `peakMonth 12` · `completeMonth 24`

**ABOUT**

> The hippocampus is densely expressed with androgen receptors, and sustained testosterone exposure is linked to gains in spatial navigation and mental rotation. Those gains hold for as long as levels stay in range.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Androgen receptors in the hippocampus are activating. Spatial navigation and mental rotation may show early gains. |
| 2–3 | Spatial memory performance is commonly reported to improve this early. Androgen-receptor support for hippocampal circuitry is active. |
| 4–5 | Spatial cognition gains are building. Verbal memory shows less consistent change than the spatial gains do. |
| 6–8 | Gains are consolidating. Individual variation here is wide — receptor density differs more between people than serum levels do. |
| 9–11 | Adaptation is approaching its settled state. Spatial-cognition benefits are well established. |
| 12–13 | Major adaptation has settled. The hippocampus is in its refinement phase. |
| 14–17 | Hippocampal function is operating in its androgen-adapted configuration. |
| 18–23 | Adaptation is settled. Spatial-cognition benefits are maintained by consistent testosterone. |
| 24–35 | Adaptation has settled. The benefits persist for as long as levels stay in range. |
| 36–47 | Stable. Androgen-maintained hippocampal function is the ongoing baseline. |
| 48–59 | Four to five years in. Exercise involving spatial navigation or motor learning amplifies the maintained benefit. |
| 60–71 | Hippocampal function is held by ongoing androgen signalling. Spatial performance tracks sustained levels rather than accumulated time on therapy. |
| 72–83 | Each day, androgen receptors in hippocampal tissue support spine density, and locally aromatised estradiol contributes through a second receptor family. |
| 84–95 | Spatial navigation and mental rotation lean on this signal. Both drift back over months if levels fall out of range. |
| 96–119 | At this tenure, activity that combines movement with navigation is the strongest adjunct. It raises BDNF through a pathway independent of hormone level. |
| 120–143 | A decade in, hippocampal outcomes under sustained testosterone are stable in follow-up. The evidence base is thinner here than for spatial performance in the short term. |
| 144–179 | At twelve to fifteen years, perfusion drives hippocampal outcomes. Hematocrit management matters to this tissue for exactly that reason. |
| 180–239 | Fifteen to twenty years approaches the limit of published data. Cognitive measures across it are unremarkable in the cohorts that exist. |
| 240–1200 | Past twenty years there is little published on this specific tissue. The androgen and aromatase mechanisms are established; the long-horizon data is not. |

**INSIGHT — mechanism**

- The hippocampus is dense in androgen receptors, and testosterone supports dendritic spine density there directly.
- Some of testosterone's hippocampal effect arrives as estradiol. Aromatase converts it locally, inside the brain, from the same molecule.
- Spatial navigation and mental rotation are the tasks most consistently associated with androgen exposure across the research.
- Androgen signalling supports hippocampal cell survival rather than birth rate. The cells are made either way; the hormone changes how many persist.
- Receptor density, not serum level, sets how much signal hippocampal tissue actually receives. That is why individual variation here is so wide.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The hippocampus is among the first tissue affected in memory disorders, which is why it is so heavily studied. |
| all months | The hippocampus carries dense androgen receptors and dense aromatase. It receives both signals from the same molecule. |
| all months | Mental rotation performance can shift measurably within months of a hormonal change, in either direction. |
| all months | Chronic stress measurably reduces hippocampal volume. It is one of the few tissues where that effect is directly visible. |
| all months | Aerobic exercise raises BDNF through a route independent of hormones. Combining movement with navigation raises it further. |
| all months | The hippocampus rebuilds itself in response to use. Navigation alone measurably enlarges its posterior portion. |
| all months | Verbal and spatial memory are separable systems. A change in one does not predict a change in the other. |
| all months | Perfusion matters more to this tissue than to most. Hematocrit management is a hippocampal concern as much as a cardiac one. |
| months 0–59 | Spatial gains, where they appear, tend to show earlier than any other cognitive change. They also vary widely between people. |
| months 0–59 | The first months carry the widest dose-to-dose variation. Cognitive effects are hardest to read during exactly that window. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 3 | Spatial gains | Where they appear, typically show by around month 3. |
| 6 | Consolidation | Spatial-cognition gains usually consolidate around month 6. |
| 12 | Adapted function | Hippocampal function typically reaches its androgen-adapted state around month 12. |
| 24 | Held benefit | Spatial-cognition benefits are typically steady from around month 24. |

---

### Amygdala (`amygdala`)

`startMonth 1` · `peakMonth 9` · `completeMonth 18`

**ABOUT**

> Testosterone modulates amygdala reactivity to emotionally charged stimuli, and individual variation here is wide. Many people report feeling more emotionally contained and less easily moved to tears, though it is not a guaranteed outcome.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Testosterone is beginning to modulate amygdala reactivity to emotional stimuli. Effects vary between individuals rather than following one pattern. |
| 2–3 | Reactivity to distressing stimuli is shifting. Many describe feeling less easily moved to tears and more emotionally contained. |
| 4–5 | The shift is at its most active. Imaging of exogenous testosterone shows blunted amygdala response to distressing stimuli. |
| 6–8 | The move toward a more contained emotional response is typically stabilising here. |
| 9–10 | Recalibration is approaching its settled state. Where a shift occurred, it is usually stable from this point. |
| 11–13 | Amygdala reactivity is stable in its androgen-adapted pattern. |
| 14–17 | Fully recalibrated. The androgen-dominant emotional baseline is maintained by consistent testosterone. |
| 18–31 | Stable. Emotional processing reflects the androgen-dominant environment; variation tracks dose timing and circumstances. |
| 32–45 | The emotional baseline established in the first eighteen months is holding. Sleep and stress are the primary modulators. |
| 46–59 | Four to five years of androgen-adapted emotional processing. Dose gaps can produce transient shifts — pharmacokinetics, not regression. |
| 60–71 | The amygdala's androgen-adapted calibration is held by continuous signalling. Reactivity follows circulating testosterone, which is why a trough can be felt. |
| 72–83 | Day to day, androgen and locally aromatised estrogen both act on limbic tissue, and neurosteroid supply tracks the hormone level in your blood. |
| 84–95 | Emotional containment and amygdala-to-prefrontal coupling both rest on this signal, and both follow it within a single dose cycle. |
| 96–119 | At this tenure, dose interval and sleep predict emotional steadiness better than any other variable. Splitting a dose flattens the curve where troughs bite. |
| 120–143 | A decade in, emotional baseline under sustained testosterone is stable in follow-up. Reported variation tracks circumstance rather than tenure. |
| 144–179 | At twelve to fifteen years, limbic findings remain unremarkable in the literature, which is the finding. The tissue asks for consistency. |
| 180–239 | Fifteen to twenty years is near the edge of published follow-up for this population. Emotional outcomes across it are stable. |
| 240–1200 | Past twenty years the record is thin. Amygdala neuroendocrinology is an active research area and the long-horizon picture is still forming. |

**INSIGHT — mechanism**

- The amygdala carries both androgen and estrogen receptors, and testosterone reaches both — some of it after local aromatase conversion.
- Imaging studies of exogenous testosterone report blunted amygdala response to distressing stimuli, though the effect size varies widely between people.
- The amygdala tags experience with emotional weight before the cortex interprets it. Changing its reactivity changes what registers as urgent.
- Testosterone shifts amygdala-to-prefrontal coupling. Emotional containment is a connectivity change more than a reactivity one.
- Neurosteroids made in the brain act on GABA-A receptors in limbic tissue, and their supply tracks circulating hormone. Troughs can be felt as mood.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The amygdala responds to a threatening face before the visual cortex has identified it. Speed is the point of the structure. |
| all months | Amygdala volume differs measurably between individuals, and the variation is unrelated to how reactive the structure is. |
| all months | Anger and fear recruit overlapping limbic circuits. A change in threshold can shift both at once. |
| all months | Tear thresholds are partly hormonal. Testosterone raises them for many people, which is a threshold change rather than a feeling change. |
| all months | Neurosteroids are made inside the brain, but their supply follows what is circulating. That is why troughs register. |
| all months | Limbic tissue responds to hormonal change faster than cortical tissue does. Emotional shifts arrive before cognitive ones. |
| all months | Emotional range and emotional expression are separable. Androgen research finds more consistent effects on the second. |
| all months | This is an active research area with wide individual variation. The honest description is a distribution rather than a rule. |
| months 0–59 | The shift toward feeling more contained is one of the earlier reported changes. It is also one of the most variable. |
| months 0–59 | Early emotional change can feel abrupt because levels are least stable then. The variability is pharmacokinetic. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 3 | More contained response | Typically reported by around month 3. |
| 6 | Stabilising shift | The change in emotional reactivity usually stabilises around month 6. |
| 9 | Recalibrated reactivity | Typically reached around month 9. |
| 18 | Held baseline | The emotional baseline is typically steady from around month 18. |

---

### Synaptic Plasticity (`synaptic`)

`startMonth 1` · `peakMonth 12` · `completeMonth 36`

**ABOUT**

> Testosterone promotes synaptic plasticity through two pathways at once: direct androgen receptor activation, and local conversion to estradiol by aromatase inside the brain. Its neural effects are therefore not purely androgenic.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Androgen receptor activation is promoting dendritic spine formation. Aromatase is converting some testosterone to estradiol locally — both pathways are live. |
| 2–3 | Spine density is measurably increasing in androgen-receptor-rich regions. The dual pathway is fully active. |
| 4–5 | Remodelling is at its fastest. Both direct androgen signalling and local estradiol are contributing. |
| 6–8 | Synaptic density is approaching its plateau. The remodelling phase is well established. |
| 9–11 | Spine formation is decelerating. The architecture being laid down is the foundation of the adapted state. |
| 12–15 | Remodelling is handing over to maintenance. The androgen-adapted architecture is largely in place. |
| 16–23 | The architecture is settling. Signalling from here maintains rather than builds. |
| 24–35 | Stabilised under sustained testosterone. Combined androgen and local-estrogen signalling is the steady state. |
| 36–47 | Fully stabilised. Neural architecture is maintained by consistent testosterone. |
| 48–59 | Four to five years of dual-pathway maintenance. Dose stability is the key hormonal input. |
| 60–71 | Synaptic architecture is held by two signals at once. Androgen receptor activation and locally aromatised estradiol both keep existing spines alive. |
| 72–83 | Every day, aromatase inside neural tissue converts part of the circulating testosterone, so the brain is running both pathways continuously. |
| 84–95 | Plasticity and memory consolidation draw on this architecture. It relaxes over months if levels drop, on the same scale that built it. |
| 96–119 | At this tenure, cognitively demanding activity and aerobic exercise add the most. Both raise plasticity through routes independent of hormone level. |
| 120–143 | A decade in, cognitive performance under sustained testosterone is stable in the available follow-up. The cohorts are modest and still maturing. |
| 144–179 | At twelve to fifteen years, metabolic and vascular health outweigh hormonal variables. Synapses are expensive tissue and depend on perfusion. |
| 180–239 | Fifteen to twenty years is around the limit of the published record. Plasticity measures across it hold steady. |
| 240–1200 | Past twenty years the dual-pathway mechanism is well characterised and the outcome data is not. That gap is where current research sits. |

**INSIGHT — mechanism**

- Testosterone promotes dendritic spine formation through two pathways at once: direct androgen receptor activation, and local aromatization to estradiol.
- Aromatase is expressed in the brain itself. A share of the testosterone reaching neural tissue is signalling as estrogen by the time it acts.
- Androgen receptor binding changes gene transcription, so synaptic effects arrive on a timescale of hours to days rather than minutes.
- Synaptic architecture is maintained by ongoing signal, not banked. Remodelled circuits need the hormone to keep arriving.
- The two neural pathways testosterone uses can be separated pharmacologically — blocking aromatase changes some effects and leaves others intact.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | Aromatase inside the brain converts part of the circulating testosterone. Some of the neural effect is estrogenic by the time it lands. |
| all months | Glial cells outnumber neurons in much of the brain and take part in every synapse. Plasticity is not a neuron-only process. |
| all months | The adult brain holds on the order of a hundred trillion synapses. Both pathways act across a large share of them. |
| all months | Androgen and estrogen receptors share much of their machinery. That overlap is why one hormone can produce effects attributed to the other. |
| all months | Plasticity is capacity, not improvement. It makes learning possible and does not choose what gets learned. |
| all months | The brain spends about a fifth of the body's energy budget on a fiftieth of its mass. Most of that goes to synapses. |
| all months | Long-term potentiation remains the best cellular model of memory formation, fifty years after it was first demonstrated. |
| all months | Synaptic architecture depends on the signal continuing to arrive. It is maintained rather than banked. |
| months 0–59 | Spine formation is fastest in the first year, which is also the year with the least externally visible to show for it. |
| months 0–59 | Both signalling routes come online early. The dual pathway is active from the first months rather than added later. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 4 | Fastest remodelling | Spine formation typically runs fastest around month 4. |
| 12 | Remodelled density | Spine density typically reaches its new level around month 12. |
| 24 | Settled architecture | The androgen-adapted architecture typically settles around month 24. |
| 36 | Sustained maintenance | Synaptic architecture is typically a steady state from around month 36. |

---

## Testosterone — Body

### Chest (`chest`)

`startMonth 3` · `peakMonth 14` · `completeMonth 30`

**ABOUT**

> Testosterone drives pectoral hypertrophy through androgen receptor activation, while DHT primes chest-wall follicles for terminal hair. Chest broadening is measurable within months with training; chest hair typically arrives after the legs and abdomen.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 3 | Pectoral androgen receptors are activating, and early hypertrophy is measurable with resistance training. DHT is priming chest-wall follicles ahead of any terminal hair. |
| 4–5 | Pectoral protein synthesis is elevated. Strength usually moves before size does. |
| 6–7 | Chest-wall broadening is measurable with training. Chest hair is beginning to appear, following the legs and abdomen. |
| 8–10 | Pectoral mass is increasing with training. DHT-driven chest hair is filling in on the same pattern as the abdomen. |
| 11–13 | Muscle gain is at its fastest with consistent training. Chest hair continues converting from vellus to terminal. |
| 14–16 | Pectoral development is approaching its training-stimulus ceiling. Hair continues filling in. |
| 17–21 | Chest muscle has largely matched its training stimulus. Further growth depends on progressive overload, not more time on T. |
| 22–29 | Chest hair, where it develops, is fully in and permanent. Muscle is maintained by training and testosterone together. |
| 30–39 | Development is established. Muscle tracks training; the hair pattern is permanent. |
| 40–49 | Stable. Pectoral mass is maintained by testosterone and training; hair needs no maintenance. |
| 50–59 | Four to five years in. Progressive overload is the remaining lever on pectoral size. |
| 60–71 | Two different things are held here. Terminal hair is permanent once converted; pectoral muscle is held only by testosterone and continued load. |
| 72–83 | Day to day, androgen receptors in pectoral muscle sustain protein synthesis, while DHT maintains the follicles that already converted. |
| 84–95 | Chest hair density often keeps increasing past five years, more slowly than before. Muscle depends on training within days, not years. |
| 96–119 | At this tenure, hematocrit is the measure that matters most. Testosterone drives red cell production, and levels that climb too high raise cardiovascular risk. |
| 120–143 | A decade in, hair pattern is settled and muscle tracks training. Cohort follow-up focuses on hematocrit, lipids and blood pressure. |
| 144–179 | At twelve to fifteen years, cardiovascular monitoring is routine. Resistance training remains the strongest single input to how this tissue looks and works. |
| 180–239 | Fifteen to twenty years is near the edge of published follow-up. Body composition holds across it where training and levels were both sustained. |
| 240–1200 | Past twenty years the data thins. Androgen physiology is well described; multi-decade cardiovascular follow-up in this population is still accruing. |

**INSIGHT — mechanism**

- Skeletal muscle carries androgen receptors directly. Testosterone raises protein synthesis and satellite cell activation in pectoral tissue as it does anywhere else.
- 5α-reductase converts testosterone to DHT in hair follicles. DHT binds the androgen receptor several times more tightly, which is why hair responds where muscle needs training.
- Terminal hair conversion is irreversible. Once a vellus follicle switches over, it stays switched even if androgen falls away.
- Body hair follows a regional timetable set by follicle sensitivity — legs and abdomen before chest, chest before back.
- Androgen receptor occupancy raises muscle protein synthesis, but hypertrophy also needs mechanical load. The hormone permits growth; training causes it.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | Chest-wall follicles and scalp follicles both respond to DHT, in opposite directions. The same signal builds one and thins the other. |
| all months | Follicles cycle independently of one another, which is why hair fills in unevenly rather than all at once. |
| all months | Chest measurement changes come from the back as much as the front. Lat and pectoral growth both widen the same tape. |
| all months | Chest hair density often keeps increasing past five years. It is among the slowest androgenic changes to finish arriving. |
| all months | Muscle keeps a record of prior training as retained myonuclei. Size regained after a break returns faster than it was first built. |
| all months | Androgen receptor density in muscle rises with training itself. Hormone and load amplify each other rather than adding. |
| all months | Testosterone raises red cell production, which is why hematocrit is watched. The signal that builds muscle also thickens blood. |
| all months | The pectoralis attaches to the upper arm rather than to the chest wall. Its size changes the shoulder line as much as the chest. |
| months 0–59 | Strength moves before size does. Neural drive adapts within weeks and visible hypertrophy follows months later. |
| months 0–59 | Chest hair arrives after the legs and abdomen. Its absence in the first year says nothing about the eventual pattern. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 6 | First chest hair | Typically starts appearing around month 6. |
| 11 | Fastest muscle gain | Pectoral gain typically runs fastest around month 11, with training. |
| 22 | Full hair pattern | Chest hair is typically fully in around month 22. |
| 30 | Training-led growth | Pectoral size typically tracks training rather than tenure from around month 30. |

---

### Abdomen (`abdomen`)

`startMonth 3` · `peakMonth 18` · `completeMonth 36`

**ABOUT**

> Testosterone shifts fat storage toward an androgenic pattern, directing deposition to the abdomen and visceral compartments. Combined with broadening shoulders and chest, this produces a masculinized silhouette even where waist circumference barely moves.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 3 | Fat storage is shifting toward an androgenic, abdomen-leaning pattern. Androgen receptor signalling is redirecting deposition. |
| 4–5 | Redistribution is underway below the visible threshold. Core definition may improve with training before any pattern change shows. |
| 6–8 | Abdominal accumulation is measurable. With shoulder broadening, the silhouette shifts even where waist circumference does not. |
| 9–11 | The androgenic pattern is establishing. Visceral and subcutaneous depots are responding at different rates. |
| 12–14 | Redistribution is at its most active. The android pattern is becoming the default for new storage. |
| 15–17 | Composition is well into its androgenic pattern. The redistribution effect is approaching completion. |
| 18–20 | Distribution is settling into its androgen-dominant pattern. Remaining change is subtle. |
| 21–26 | The pattern is largely established. From here, belly size tracks diet and training more than testosterone. |
| 27–35 | Androgenic fat distribution is established. Abdominal size tracks diet, training and age. |
| 36–47 | Stable. The androgenic pattern is maintained by consistent testosterone. |
| 48–59 | Four to five years in. Core composition responds to diet and resistance training alongside continued dosing. |
| 60–71 | The androgenic distribution here is held by continuous signalling. Androgen receptors in visceral fat keep storage biased toward this compartment. |
| 72–83 | Each day, androgen signalling raises lipolysis in gluteofemoral depots while favouring abdominal storage. Both directions run at once. |
| 84–95 | Insulin sensitivity and hepatic lipid load both respond to the visceral compartment. Diet and activity move them more than dose does. |
| 96–119 | At this tenure, fasting glucose, lipids and waist circumference are the tracked measures. They are watched as general metabolic health. |
| 120–143 | A decade in, abdominal composition is stable in follow-up. Age-related visceral accumulation appears in any adult body and tracks lifestyle. |
| 144–179 | At twelve to fifteen years, metabolic and cardiovascular markers are the clinical focus. Core training and diet act on both directly. |
| 180–239 | Fifteen to twenty years sits at the edge of the published record. Metabolic markers across it track lifestyle far more closely than tenure. |
| 240–1200 | Past twenty years the cohort data is limited. The redistribution mechanism generalises well; long-horizon metabolic outcomes are still being gathered. |

**INSIGHT — mechanism**

- Androgen receptor signalling raises lipoprotein lipase activity in visceral fat. Deposition follows the enzyme.
- Visceral fat drains through the portal vein directly to the liver, so android distribution carries metabolic consequences separate from shape.
- Testosterone raises lipolysis in gluteofemoral depots while favouring abdominal storage. Redistribution runs in both directions at once.
- Adipocytes turn over at roughly 8% a year. Fat redistribution is bounded by that rate no matter what the levels look like.
- Core muscle sits under abdominal fat and answers to the same hormone differently — anabolic in one tissue, redistributive in the other.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The abdomen is where androgenic and estrogenic fat signals meet most directly. It is the depot both hormones act on hardest. |
| all months | Androgen receptor density differs several-fold between fat depots. Regional response is a receptor map, not a whole-body effect. |
| all months | Waist circumference predicts metabolic risk better than body mass index does. |
| all months | Subcutaneous abdominal fat and the visceral fat behind it change on different schedules. The deeper depot moves first. |
| all months | Abdominal skin has fewer androgen receptors than the follicles in it. Hair pattern changes here before anything structural does. |
| all months | Visceral fat secretes inflammatory signalling molecules continuously. It behaves as an endocrine organ rather than as storage. |
| all months | Silhouette can change while waist circumference does not, because shoulders and chest move the ratio on their own. |
| all months | Sleep deprivation raises visceral storage independently of calories. This depot is unusually cortisol-sensitive. |
| months 0–59 | Redistribution starts below the visible threshold. The enzyme gradient shifts months before the shape does. |
| months 0–59 | Core definition can improve while abdominal fat is still redistributing. The two processes overlap rather than queue. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 6 | Measurable accumulation | Abdominal accumulation typically shows around month 6. |
| 12 | Fastest redistribution | Fat redistribution typically runs fastest around month 12. |
| 18 | Android default | New storage typically follows the androgenic pattern from around month 18. |
| 36 | Established distribution | Androgenic fat distribution is typically established around month 36. |

---

### Hips / Waist (`hips`)

`startMonth 1` · `peakMonth 14` · `completeMonth 30`

**ABOUT**

> Hip bone structure is set by puberty and does not meaningfully change on testosterone. The masculinized proportion comes from around it: abdominal fat accumulating, and shoulders and chest broadening.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 1 | Hip bone structure is fixed, and androgens do not reposition it. What shifts the proportion is everything around it: abdominal fat and shoulder width. |
| 2–3 | The waistline is beginning to thicken as abdominal fat accumulates. Hip circumference itself is unchanged. |
| 4–6 | The hip-to-shoulder ratio is shifting as shoulders and chest broaden. The hips read narrower by proportion, not by loss. |
| 7–8 | Upper-body mass is the term that is moving. Hip fat carries fewer androgen receptors and responds late and modestly. |
| 9–10 | The silhouette shift is becoming pronounced. It comes from the upper body and abdomen, not from hip reduction. |
| 11–13 | Proportional change is at its fastest. Shoulder and chest development is doing most of the work. |
| 14–16 | Hip proportions are stabilising. The silhouette is defined by change around a structurally unchanged hip. |
| 17–21 | The masculinised silhouette is largely set. Remaining change is upper-body and abdominal refinement. |
| 22–29 | Proportions are stable and were never expected to change structurally. |
| 30–39 | Fully established. The silhouette is maintained by consistent testosterone and training. |
| 40–49 | Stable. Upper-body and core training are the primary levers on proportion from here. |
| 50–59 | Four to five years in. Hip structure is unchanged; the proportion around it is maintained by dosing and training. |
| 60–71 | Nothing structural is held here, because nothing structural changed. The proportion is held by muscle and fat around a fixed pelvis. |
| 72–83 | Day to day, testosterone maintains upper-body muscle and abdominal storage. The hip reads the same signal and responds to it least. |
| 84–95 | The silhouette rests on tissue that responds to load. Shoulders and core lose mass within weeks of detraining, faster than any hormonal effect. |
| 96–119 | At this tenure, lean mass and bone density are the measures worth having. Both respond to loaded exercise more than to dose. |
| 120–143 | A decade in, proportion is stable in follow-up. Where it shifts, it follows training history rather than hormone tenure. |
| 144–179 | At twelve to fifteen years, bone density enters the picture. Androgens support the skeleton partly through aromatisation to estradiol. |
| 180–239 | Fifteen to twenty years is near the edge of published follow-up. Composition holds across it where training and levels were sustained. |
| 240–1200 | Past twenty years there is little on limb and girdle composition specifically. The mechanism is clear; the long-horizon data is not yet. |

**INSIGHT — mechanism**

- Pelvic bone geometry is fixed once growth plates fuse. No hormone repositions completed bone, so proportion changes come from the tissue around it.
- Hip fat carries fewer androgen receptors than visceral fat, which is why it responds late and modestly to testosterone.
- Shoulder width is set by clavicle length and deltoid mass. Only one of those two is still available to change.
- Waist-to-shoulder ratio is a ratio: it moves when either term moves. Abdominal and upper-body change shift it without the hips doing anything.
- Bone at the hip stays responsive to hormonal signal even though its geometry does not. Density and shape are separate properties.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | Hip measurement is taken at the widest point, which is usually soft tissue rather than bone. |
| all months | Deltoid mass is among the most androgen-responsive muscle in the upper body. It changes the outline faster than the chest does. |
| all months | Clothing sizing is cut to hip-to-waist proportions rather than to either measurement alone. Fit changes before any number does. |
| all months | Fat depots differ in blood supply as well as receptors. Poorly perfused depots respond slowly to anything circulating. |
| all months | The femoral neck is a standard DEXA site. Androgens support bone there partly by aromatising to estradiol. |
| all months | Proportion is a visual ratio, and ratios move faster than the anatomy underneath them. |
| all months | Gluteal and hip muscle respond to load within weeks. The fat over them responds to hormones across years. |
| all months | Bone mineral density at the hip depends on continued hormonal signalling in any body. It is maintained, not banked. |
| months 0–59 | Hip circumference is often the measurement people expect to move first. It is usually the one that moves least. |
| months 0–59 | The earliest proportional change comes from the abdomen and shoulders. The hips are the fixed reference. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 4 | Shifting ratio | The hip-to-shoulder ratio typically starts moving around month 4. |
| 11 | Fastest proportional change | Typically runs fastest around month 11. |
| 17 | Set silhouette | The masculinised silhouette is typically largely set around month 17. |
| 30 | Stable proportion | Hip proportion is typically stable from around month 30. |

---

### Glutes (`glutes`)

`startMonth 3` · `peakMonth 18` · `completeMonth 36`

**ABOUT**

> Gluteal muscle answers testosterone's anabolic signal the way all skeletal muscle does, through androgen receptor activation and protein synthesis. This is a muscle response rather than fat redistribution, so training stimulus matters more than time on T.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 3 | Gluteal androgen receptors are activating. With resistance training, early hypertrophy is measurable; without it, testosterone alone does little here. |
| 4–5 | Protein synthesis in gluteal muscle is elevated. This is a muscle response, not a fat redistribution one. |
| 6–8 | Gluteal mass is measurably increasing with consistent training. |
| 9–11 | Hypertrophy is well underway with training. Strength gains in squats and leg press are typically rapid here. |
| 12–14 | Muscle gain is at its fastest. Satellite-cell recruitment from androgen exposure is near its peak. |
| 15–17 | Gluteal muscle is approaching its training-stimulus ceiling. Further growth depends on progressive overload. |
| 18–20 | Muscle has largely matched its training stimulus. Testosterone maintains the baseline; training drives further gain. |
| 21–26 | Development is established. Mass is maintained by testosterone and training together. |
| 27–35 | Stable. Gluteal mass tracks training stimulus rather than time on T. |
| 36–47 | Stable. Maintained by consistent testosterone and continued lower-body training. |
| 48–59 | Four to five years in. Compound lower-body work like squats, hinges and deadlifts is the remaining lever. |
| 60–71 | Gluteal muscle is held by two inputs at once. Testosterone keeps the anabolic environment; mechanical load is what the tissue actually responds to. |
| 72–83 | Every day, androgen receptors in gluteal muscle sustain protein synthesis above the untreated rate. Without load, that raised rate builds nothing. |
| 84–95 | Strength, power and hip stability all rest on this tissue. It atrophies within weeks of detraining, far faster than hormone levels change. |
| 96–119 | At this tenure, lean mass and bone density are the useful measures. Loaded hip extension acts on both at once. |
| 120–143 | A decade in, gluteal mass tracks training history in follow-up. Testosterone sets the ceiling; training decides where under it you sit. |
| 144–179 | At twelve to fifteen years, the hip is watched for bone as much as muscle. Femoral neck density is a standard DEXA site. |
| 180–239 | Fifteen to twenty years is around the edge of published data. Composition holds across it where training continued. |
| 240–1200 | Past twenty years the record thins. Androgen and muscle physiology is well established; multi-decade composition data is still being collected. |

**INSIGHT — mechanism**

- Gluteal muscle is skeletal muscle: androgen receptors, protein synthesis, satellite cell activation. The response here is anabolic, not redistributive.
- Testosterone binds its receptor and the pair moves into the nucleus for hours. That residence time is why protein synthesis stays elevated long after the blood level peaks.
- Satellite cells sit dormant beside muscle fibres until called. Androgens raise how many are recruited when load arrives.
- Muscle keeps a record of prior training as retained myonuclei. Size regained after a break comes back faster than it was first built.
- Androgen receptor density in muscle rises with training itself. Hormone and load amplify each other rather than simply adding.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The gluteus maximus is the largest single muscle in the body, and one of the most androgen-responsive. |
| all months | Hip extension is the strongest movement the body produces, and the gluteus maximus is the muscle that produces it. |
| all months | Muscle fibre type ratios are largely genetic. Two people on the same programme and the same dose can build differently. |
| all months | Gluteal muscle is deep to a fat layer that responds to hormones separately. Composition here changes on two clocks at once. |
| all months | Hip extension strength predicts later mobility better than almost any other single measure. |
| all months | This is a muscle response rather than a fat redistribution one. Without load, testosterone alone changes very little here. |
| all months | Prolonged sitting reduces gluteal activation measurably. The tissue responds to use more than to tenure. |
| all months | Muscle protein synthesis stays elevated for hours after an androgen receptor binds. The blood peak and the tissue effect do not coincide. |
| months 0–59 | Strength gains here are usually rapid in the first year. Squat and press numbers move faster than the mirror does. |
| months 0–59 | Without training, this region changes least of any on testosterone. The hormone permits growth rather than causing it. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 9 | Rapid strength | Squat and leg-press numbers typically climb fastest around month 9. |
| 12 | Fastest hypertrophy | Gluteal gain typically runs fastest around month 12, with training. |
| 18 | Training ceiling | Gluteal muscle typically reaches its training-stimulus ceiling around month 18. |
| 36 | Training-led mass | Gluteal mass typically tracks training rather than tenure from around month 36. |

---

### Thighs (`thighs`)

`startMonth 2` · `peakMonth 14` · `completeMonth 28`

**ABOUT**

> Quadriceps and hamstrings are among the most androgen-responsive muscle groups, producing rapid strength and size gains with lower-body training. Satellite-cell activation plateaus within twelve to eighteen months; hypertrophy past that depends on progressive overload.

**NOW — monthFocus**

| Months | Copy |
|---|---|
| 2 | Quadriceps and hamstrings are responding to testosterone's anabolic signal. With training, measurable hypertrophy comes early here. |
| 3–4 | Nitrogen retention in thigh muscle is elevated. Net protein balance has shifted toward building before size is visible. |
| 5–7 | Thigh growth is often the most visible lower-body change on T. Strength gains here frequently outpace upper-body gains. |
| 8–9 | Type II fibre hypertrophy is well established with training. The anabolic response is near peak velocity. |
| 10–11 | Growth is at its fastest. Satellite-cell activation from androgen exposure is front-loaded into this window. |
| 12–13 | Hypertrophy is still strong but the androgen-driven component is beginning to plateau. |
| 14–15 | Satellite-cell activation is plateauing for untrained fibres. Further growth is driven by progressive overload. |
| 16–20 | Thigh muscle typically sits at its training-determined level. Continued growth tracks training, not T duration. |
| 21–27 | Development is established. Mass is maintained by testosterone and training. |
| 28–37 | Stable. Thigh mass is maintained by consistent testosterone and progressive overload. |
| 38–48 | Stable. Strength gains remain available through progressive overload in squats and leg press. |
| 49–59 | Four to five years in. Age-related lean mass decline begins gradually; lower-body training offsets it. |
| 60–71 | Thigh muscle is held by testosterone and by load together. The hormone raises the ceiling; training decides how much of it you occupy. |
| 72–83 | Each day, androgen signalling keeps nitrogen retention and protein synthesis elevated in quadriceps and hamstrings above their untreated rate. |
| 84–95 | Walking speed, stair power and fall risk all rest on this tissue. It responds to disuse within weeks. |
| 96–119 | At this tenure, lean mass and grip or leg strength are the measures that predict later function. Both are trainable at any tenure. |
| 120–143 | A decade in, thigh composition tracks training in follow-up. Age-related lean mass decline begins gradually around this stage. |
| 144–179 | At twelve to fifteen years, loaded lower-body work offsets most of the age-related decline. Testosterone supports the process without replacing it. |
| 180–239 | Fifteen to twenty years is near the edge of the published record. Leg composition holds across it where training was sustained. |
| 240–1200 | Past twenty years the longitudinal data on limb composition is sparse. The physiology is well described; the decades-long picture is being studied. |

**INSIGHT — mechanism**

- Quadriceps and hamstrings are rich in type II fibres, which carry more androgen receptors and hypertrophy fastest under testosterone.
- Testosterone raises erythropoiesis, so oxygen delivery to working muscle rises alongside the muscle itself. Endurance and size change together.
- Androgen signalling increases nitrogen retention in muscle. Net protein balance shifts toward building well before any size is visible.
- Satellite cell activation from androgen exposure is largely front-loaded. After the first year, added size tracks load rather than hormone.
- Muscle protein synthesis stays elevated for hours after an androgen receptor binds. Strength outruns visible size because neural drive adapts first.

**INSIGHT — fact**

| Eligible | Copy |
|---|---|
| all months | The hamstrings cross two joints and the quadriceps mostly one. That difference shapes how each responds to the same training. |
| all months | The quadriceps is the largest muscle group by volume, and the fastest to lose mass with disuse. |
| all months | Thigh muscle is where most whole-body glucose disposal happens. Building it changes metabolism as well as shape. |
| all months | Muscle cross-sectional area predicts strength better than limb circumference does. A tape measure misses most of the change. |
| all months | Tendon and connective tissue adapt more slowly than muscle does. Strength can outrun the structures carrying it. |
| all months | Bone density in the femur rises with heavy lower-body loading. The skeleton adapts to the same training the muscle does. |
| all months | Leg strength predicts later independence better than most clinical measures. It is trainable at any age or tenure. |
| all months | Thigh muscle and thigh fat sit in the same limb and answer to different signals on different timescales. |
| months 0–59 | Lower-body change is often the most visible in the first year. Squat and leg press numbers move quickly. |
| months 0–59 | Measurable hypertrophy can appear within the first few months with training. Without it, the change is much smaller. |

**NEXT — markers**

| Month | Landmark | Copy |
|---|---|---|
| 5 | Visible growth | Thigh muscle growth typically becomes visible around month 5, with training. |
| 10 | Fastest gain | Thigh hypertrophy typically runs fastest around month 10. |
| 14 | Satellite plateau | Androgen-driven satellite cell activation typically plateaus around month 14. |
| 28 | Training-led size | Thigh size typically tracks training rather than tenure from around month 28. |

---

## Review checklist

- [ ] 18 ABOUT strings — fair introduction, no overclaim
- [ ] 340 NOW bands — tissue state matches the months named
- [ ] 90 mechanism entries — pathway stated correctly
- [ ] 180 fact entries — claim supported, and true past year five
- [ ] 72 markers — median month defensible as a median, not a promise
- [ ] Long-tail bands (60+) — maintenance framing is accurate, not reassurance
- [ ] Anything the literature does not support at 15–20 years is marked as such in the copy

