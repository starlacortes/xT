import SwiftUI

/// Marks a tap that landed on the body but on surface with no clinical zone.
///
/// Roughly 60% of the mesh has no zone — the head, hands, feet, everything below the knee, and
/// the back, none of which appear in the 49-label taxonomy. Before this, `ZoneHitTestEngine`
/// returned `nil` for both "missed the body" and "no zone here", so those taps produced no
/// response at all and were indistinguishable from the app being unresponsive.
///
/// A greyed-out mark says "not a site" rather than leaving the user to guess.
struct NoZoneMarkerView: View {

    /// Tap location in the parent's coordinate space.
    let location: CGPoint

    /// How long the marker stays before fading out.
    static let lifetime: TimeInterval = 0.8

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.7

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .overlay(
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.55))
            )
            .frame(width: 40, height: 40)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(location)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    opacity = 1
                    scale = 1
                }
                withAnimation(.easeOut(duration: 0.3).delay(Self.lifetime - 0.3)) {
                    opacity = 0
                }
            }
    }
}

/// Attaches no-zone markers to a view hosting `BodyModel3DView`.
///
/// Markers are keyed by an incrementing id so repeated taps in the same place each animate,
/// and they self-expire — no timer bookkeeping at the call site.
struct NoZoneMarkerOverlay: ViewModifier {

    @Binding var taps: [NoZoneTap]

    func body(content: Content) -> some View {
        content.overlay(
            ZStack {
                ForEach(taps) { tap in
                    NoZoneMarkerView(location: tap.location)
                }
            }
            .allowsHitTesting(false)
        )
    }
}

/// One no-zone tap awaiting display.
struct NoZoneTap: Identifiable, Equatable {
    let id: Int
    let location: CGPoint
}

extension View {
    func noZoneMarkers(_ taps: Binding<[NoZoneTap]>) -> some View {
        modifier(NoZoneMarkerOverlay(taps: taps))
    }
}

/// Small helper the hosting views share, so the expiry logic exists once.
@MainActor
@Observable
final class NoZoneTapTracker {
    var taps: [NoZoneTap] = []
    private var nextID = 0

    func record(at location: CGPoint) {
        let id = nextID
        nextID += 1
        taps.append(NoZoneTap(id: id, location: location))
        // Remove slightly after the marker has finished fading so it does not pop.
        DispatchQueue.main.asyncAfter(deadline: .now() + NoZoneMarkerView.lifetime + 0.15) { [weak self] in
            self?.taps.removeAll { $0.id == id }
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color(UIColor.systemBackground).ignoresSafeArea()
        NoZoneMarkerView(location: CGPoint(x: 200, y: 300))
    }
    .frame(width: 400, height: 600)
}
#endif
