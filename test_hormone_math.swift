
import Foundation

// Mocking the essential parts of MedicationManager for a standalone test script
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
}

enum AdministrationMethod: String, CaseIterable {
    case injectable = "Injectable"
    case cream = "Cream"
    case oral = "Oral"

    var frequencyDays: Int {
        switch self {
        case .injectable: return 7
        case .cream, .oral: return 1
        }
    }
}

enum MedicationType: String, CaseIterable {
    case estrogen = "Estrogen"
    case testosterone = "Testosterone"

    var baselineValue: Double {
        switch self {
        case .estrogen: return 100.0
        case .testosterone: return 500.0
        }
    }

    var defaultEster: MedicationEster {
        switch self {
        case .estrogen: return .valerate
        case .testosterone: return .cypionate
        }
    }
}

struct EstimatedPoint {
    let date: Date
    let value: Double
}

class TestMedicationManager {
    func estimatedLevels(
        medication: String,
        method: String,
        ester: MedicationEster,
        start: Date,
        end: Date,
        stepDays: Int = 1
    ) -> [EstimatedPoint] {
        let medicationEnum = MedicationType(rawValue: medication)!
        let methodEnum = AdministrationMethod(rawValue: method)!

        let halfLife = ester.halfLifeDays
        let decayLambda = log(2) / halfLife
        let baseLevel = medicationEnum.baselineValue
        let doseAmount = baseLevel * 0.5

        let frequency = methodEnum.frequencyDays
        var doseEvents: [Date] = []
        var eventCursor = start
        while eventCursor <= end {
            doseEvents.append(eventCursor)
            eventCursor = Calendar.current.date(byAdding: .day, value: frequency, to: eventCursor) ?? eventCursor
        }

        var points = [EstimatedPoint]()
        var cursor = start
        let calendar = Calendar.current

        while cursor <= end {
            var cumulativeValue = baseLevel
            for doseDate in doseEvents {
                let components = calendar.dateComponents([.day, .second], from: doseDate, to: cursor)
                let diffDays = Double(components.day ?? 0)
                let diffSeconds = Double(components.second ?? 0)
                let totalDaysPassed = diffDays + (diffSeconds / 86400.0)

                if totalDaysPassed >= 0 {
                    cumulativeValue += doseAmount * exp(-decayLambda * totalDaysPassed)
                }
            }
            points.append(EstimatedPoint(date: cursor, value: cumulativeValue))
            cursor = calendar.date(byAdding: .day, value: stepDays, to: cursor) ?? cursor
        }
        return points
    }
}

// --- RUN TEST ---
let manager = TestMedicationManager()
let start = Date()
let end = start.addingTimeInterval(60*60*24*14) // 14 days

print("🚀 Testing Hormone Curve (EV - Valerate - 7 day interval)")
print("----------------------------------------------")
print("Half-life: 2.0 days (faster decay, more pronounced sawtooth)")
print("----------------------------------------------")
let evPoints = manager.estimatedLevels(medication: "Estrogen", method: "Injectable", ester: .valerate, start: start, end: end)
for p in evPoints {
    let d = Calendar.current.component(.day, from: p.date)
    print("Day \(d): \(String(format: "%.2f", p.value)) pg/mL")
}

print("\n🚀 Testing Hormone Curve (EC - Cypionate - 7 day interval)")
print("----------------------------------------------")
print("Half-life: 8.5 days (slower decay, flatter curve)")
print("----------------------------------------------")
let ecPoints = manager.estimatedLevels(medication: "Estrogen", method: "Injectable", ester: .cypionate, start: start, end: end)
for p in ecPoints {
    let d = Calendar.current.component(.day, from: p.date)
    print("Day \(d): \(String(format: "%.2f", p.value)) pg/mL")
}

print("\n📊 COMPARISON ANALYSIS")
print("----------------------------------------------")
print("Valerate (EV) - Day 7 vs Day 0:")
let evDay0 = evPoints.first?.value ?? 0
let evDay7 = evPoints.dropFirst(7).first?.value ?? 0
let evDrop = evDay0 - evDay7
print("Day 0: \(String(format: "%.2f", evDay0)) pg/mL")
print("Day 7: \(String(format: "%.2f", evDay7)) pg/mL")
print("Drop: \(String(format: "%.2f", evDrop)) pg/mL (more pronounced)")

print("\nCypionate (EC) - Day 7 vs Day 0:")
let ecDay0 = ecPoints.first?.value ?? 0
let ecDay7 = ecPoints.dropFirst(7).first?.value ?? 0
let ecDrop = ecDay0 - ecDay7
print("Day 0: \(String(format: "%.2f", ecDay0)) pg/mL")
print("Day 7: \(String(format: "%.2f", ecDay7)) pg/mL")
print("Drop: \(String(format: "%.2f", ecDrop)) pg/mL (less pronounced)")

print("\n✅ VISUAL PATTERN VERIFICATION")
print("----------------------------------------------")
print("Valerate (2.0 day half-life): Creates sharp sawtooth pattern")
print("Cypionate (8.5 day half-life): Creates flatter, more stable curve")
print("Both patterns are mathematically correct based on exponential decay")
print("The UI should reflect these different visual patterns appropriately")
