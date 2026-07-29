//
//  PharmacokineticConstants.swift
//  xT
//
//  Extracted from MedicationManager.swift — Step 4 of refactor-proposal-v2.
//  Contains the medication ester enums and their pharmacokinetic properties.
//

import Foundation

// MARK: - Estrogen Esters

enum MedicationEster: String, CaseIterable {
    case valerate = "Valerate (EV)"
    case cypionate = "Cypionate (EC)"
    case oral = "Oral"
    case transdermal = "Transdermal"

    var halfLifeDays: Double {
        switch self {
        case .valerate: return 2.0
        case .cypionate: return 8.5
        case .oral: return 0.5
        case .transdermal: return 1.5
        }
    }

    /// Terminal half-life (days) is the effective clinical half-life.
    /// Under flip-flop kinetics for depot esters, this ≈ ln(2) / ka (absorption-limited).
    /// For oral/transdermal, this is the elimination-dominated half-life.

    /// Elimination half-life of free estradiol (hours) — used for Bateman ke parameter.
    /// Free E2 is cleared rapidly; the depot ester's slow absorption dominates the terminal slope.
    var eliminationHalfLifeHours: Double {
        switch self {
        case .valerate: return 3.0
        case .cypionate: return 3.0
        case .oral: return 3.0
        case .transdermal: return 3.0
        }
    }

    /// Ester Weight Factor (EWF) — mg of active estradiol per mg of ester.
    /// Calculated from molecular weights: E2 base = 272.4 g/mol.
    /// EV = 356.5 g/mol → EWF = 272.4/356.5 ≈ 0.764
    /// EC = 396.6 g/mol → EWF = 272.4/396.6 ≈ 0.687
    var esterWeightFactor: Double {
        switch self {
        case .valerate: return 0.764
        case .cypionate: return 0.687
        case .oral: return 1.0      // oral is already base E2 (no ester cleavage needed)
        case .transdermal: return 1.0 // transdermal is base E2
        }
    }

    /// Route-specific bioavailability (fraction of administered dose reaching systemic circulation).
    /// Injectable depot: near-complete absorption from oil depot → F ≈ 1.0
    /// Oral: extensive first-pass metabolism → F ≈ 0.05
    /// Transdermal: skin barrier limits absorption → F ≈ 0.10–0.20
    var bioavailability: Double {
        switch self {
        case .valerate: return 1.0
        case .cypionate: return 1.0
        case .oral: return 0.05
        case .transdermal: return 0.15
        }
    }

    /// Combined effective dose factor = EWF × bioavailability.
    /// Converts administered mg of ester → systemic mg of active estradiol.
    var effectiveDoseFactor: Double {
        return esterWeightFactor * bioavailability
    }

    /// Pre‑tuned scaling constant F/Vd (arbitrary units) that produces clinically
    /// expected peak levels for a reference dose. Calibrated from published PK data
    /// (Düsterberg et al., Tiong et al.) so that a 2 mg dose yields the clinically
    /// observed peak E2 concentration. Recalibrated 2026‑06‑30.
    ///   - EV 2 mg → peak E2 ~250 pg/mL  (S = 3150)
    ///   - EC 2 mg → peak E2 ~180 pg/mL  (S = 2700)
    ///   - Oral 2 mg → peak E2 ~60 pg/mL (S = 1250)
    ///   - TD 1 mg → steady E2 ~50 pg/mL (S = 155)
    ///
    /// Re‑recalibrated 2026‑07‑28 (QA pass): `.oral` and `.transdermal` were
    /// previously 12000 / 8000. Those values were never actually validated end
    /// to end — a separate bug in `estimatedLevels()` routed all non‑injectable
    /// dose contributions through a code path that ignored `scalingConstant`
    /// entirely, so oral/transdermal predictions were silently flat at
    /// baseline regardless of dose. Now that the routing bug is fixed
    /// (MedicationManager+Pharmacokinetics.swift), the old constants would
    /// overshoot the documented targets by ~9.6× (oral) and ~52× (transdermal).
    /// These values were re‑derived numerically so the documented targets above
    /// are actually reproduced by the corrected code path. See
    /// `.pk_analysis/run_scenarios.py` for the derivation.
    var scalingConstant: Double {
        switch self {
        case .valerate: return 3150.0
        case .cypionate: return 2700.0
        case .oral: return 1250.0
        case .transdermal: return 155.0
        }
    }

    /// DEPRECATED — kept for backward compatibility during migration.
    /// Use effectiveDoseFactor instead.
    var potencyFactor: Double {
        return effectiveDoseFactor
    }
}

// MARK: - Testosterone Esters

enum TestosteroneEster: String, CaseIterable {
    case cypionate = "Cypionate (TC)"
    case enanthate = "Enanthate (TE)"
    case propionate = "Propionate (TP)"
    case undecanoate = "Undecanoate (TU)"

    var halfLifeDays: Double {
        switch self {
        case .cypionate: return 8.0
        case .enanthate: return 7.0
        case .propionate: return 1.0
        case .undecanoate: return 20.0
        }
    }

    /// Terminal half-life (days) is the effective clinical half-life.
    /// Under flip-flop kinetics for depot esters, this ≈ ln(2) / ka (absorption-limited).

    /// Elimination half-life of free testosterone (hours) — used for Bateman ke parameter.
    /// Free T is cleared rapidly (~2 hrs); depot absorption dominates the terminal slope.
    var eliminationHalfLifeHours: Double {
        switch self {
        case .cypionate: return 2.0
        case .enanthate: return 2.0
        case .propionate: return 2.0
        case .undecanoate: return 2.0
        }
    }

    /// Ester Weight Factor (EWF) — mg of active testosterone per mg of ester.
    /// Calculated from molecular weights: T base = 288.4 g/mol.
    /// TC = 412.6 g/mol → EWF = 288.4/412.6 ≈ 0.699
    /// TE = 400.6 g/mol → EWF = 288.4/400.6 ≈ 0.720
    /// TP = 344.5 g/mol → EWF = 288.4/344.5 ≈ 0.837
    /// TU = 456.7 g/mol → EWF = 288.4/456.7 ≈ 0.631
    var esterWeightFactor: Double {
        switch self {
        case .cypionate: return 0.699
        case .enanthate: return 0.720
        case .propionate: return 0.837
        case .undecanoate: return 0.631
        }
    }

    /// Route-specific bioavailability for injectable testosterone esters.
    /// Depot injection → near-complete systemic absorption, F ≈ 1.0
    var bioavailability: Double {
        return 1.0  // all T esters here are injectable
    }

    /// Combined effective dose factor = EWF × bioavailability.
    var effectiveDoseFactor: Double {
        return esterWeightFactor * bioavailability
    }

    /// Pre‑tuned scaling constant F/Vd (arbitrary units) that produces clinically
    /// expected peak levels for a reference dose. Calibrated from published PK data:
    ///   - TC 100 mg → peak T ~600–900 ng/dL
    ///   - TE 100 mg → peak T ~600–900 ng/dL
    ///   - TP 50 mg  → peak T ~800–1200 ng/dL
    ///   - TU 1000 mg → peak T ~400–700 ng/dL (very flat profile)
    /// Used in the Bateman biexponential to convert mg → concentration.
    ///
    /// Recalibrated 2026‑07‑28 (QA pass): the previous values (11 / 11 / 18 / 5)
    /// were miscalibrated by ~20–98×. Under flip‑flop kinetics the Bateman
    /// "shape factor" ka/(ka−ke)·(e^(−ke·t) − e^(−ka·t)) evaluated at t_max is
    /// small (~0.01 for these esters) — the estrogen esters' constants correctly
    /// account for this, but these testosterone constants did not, so a 100 mg
    /// TC dose previously produced a peak of ~8 ng/dL instead of ~750 ng/dL
    /// (>99% below both the target above and this file's own unit tests in
    /// xTTests/PharmacokineticTests.swift, which assert 400–1200 ng/dL for a
    /// 100 mg TC dose). Values re‑derived numerically to reproduce the targets
    /// above; see `.pk_analysis/run_scenarios.py` for the derivation.
    var scalingConstant: Double {
        switch self {
        case .cypionate: return 1081.0
        case .enanthate: return 923.0
        case .propionate: return 359.0
        case .undecanoate: return 214.0
        }
    }

    /// DEPRECATED — kept for backward compatibility during migration.
    /// Use effectiveDoseFactor instead.
    var potencyFactor: Double {
        return effectiveDoseFactor
    }
}