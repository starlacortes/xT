import Foundation

enum BodyType: String, CaseIterable, Identifiable {
    case neutral = "neutral"
    case feminine = "feminine"
    case masculine = "masculine"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral:   return "Neutral"
        case .feminine:  return "Feminine"
        case .masculine: return "Masculine"
        }
    }

    var subtitle: String {
        switch self {
        case .neutral:   return "An androgynous figure — works for anyone"
        case .feminine:  return "A feminine-proportioned silhouette"
        case .masculine: return "A masculine-proportioned silhouette"
        }
    }

    var usdzName: String { "body_\(rawValue)" }

    var centroidsName: String { "zone_centroids_\(rawValue)" }
}
