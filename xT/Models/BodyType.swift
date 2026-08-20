import Foundation

enum BodyType: String, CaseIterable, Identifiable {
    case neutral = "neutral"
    case feminine = "feminine"
    case masculine = "masculine"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral:   return String(localized: "Neutral", comment: "Body silhouette option")
        case .feminine:  return String(localized: "Feminine", comment: "Body silhouette option")
        case .masculine: return String(localized: "Masculine", comment: "Body silhouette option")
        }
    }

    var subtitle: String {
        switch self {
        case .neutral:   return String(localized: "An androgynous figure",
                                       comment: "Describes the neutral body silhouette option")
        case .feminine:  return String(localized: "A feminine-proportioned silhouette",
                                       comment: "Describes the feminine body silhouette option")
        case .masculine: return String(localized: "A masculine-proportioned silhouette",
                                       comment: "Describes the masculine body silhouette option")
        }
    }

    var usdzName: String { "body_\(rawValue)" }
}
