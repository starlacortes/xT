//
//  LastSitePreview.swift
//  xT
//
//  Compact overlay showing the last dose's administration sites.
//  Used in Step 1 of QuickDoseSheet as a tappable panel.
//

import SwiftUI

/// Non-interactive mini preview of the last dose's administration sites.
/// Tapping dismisses the overlay.
struct LastSitePreview: View {
    let injectionSites: [InjectionSite]
    let routeClass: RouteClass
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Theme.Colors.accentSecondary)
                Text("Last Dose Sites")
                    .font(.headline)
                Spacer()
            }

            // Site labels
            ForEach(injectionSites.indices, id: \.self) { i in
                HStack {
                    Text("\(i + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(injectionSites[i].lastDoseSentence)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            // Mini sketch (non-interactive)
            if let firstSite = injectionSites.first {
                miniSketchView(for: firstSite)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Tap to dismiss")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 320)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .onTapGesture { dismiss() }
    }

    /// Renders a mini silhouette with markers for each stored site coordinate.
    @ViewBuilder
    private func miniSketchView(for site: InjectionSite) -> some View {
        GeometryReader { geo in
            ZStack {
                // Silhouette
                miniSilhouette(for: site.sketchId)

                // Markers for each site
                ForEach(injectionSites, id: \.zoneLabel) { storedSite in
                    let x = CGFloat(storedSite.normalizedX) * geo.size.width
                    let y = CGFloat(storedSite.normalizedY) * geo.size.height

                    if routeClass.requiresPreciseTap {
                        // Injection → dot marker
                        Circle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    } else {
                        // Topical/patch → region fill marker
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.accentSecondary.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func miniSilhouette(for sketchId: String) -> some View {
        switch sketchId {
        case "thighsFront":    ThighsFrontSilhouette().fill(Color.gray.opacity(0.10))
        case "thighsBack":     ThighsBackSilhouette().fill(Color.gray.opacity(0.10))
        case "glutesBack":     GlutesBackSilhouette().fill(Color.gray.opacity(0.10))
        case "armsFront":      ArmsFrontSilhouette().fill(Color.gray.opacity(0.10))
        case "armsBack":       ArmsBackSilhouette().fill(Color.gray.opacity(0.10))
        case "upperBodyFront": UpperBodyFrontSilhouette().fill(Color.gray.opacity(0.10))
        default:               ThighsFrontSilhouette().fill(Color.gray.opacity(0.10))
        }
    }
}

// MARK: - Preview

#Preview {
    LastSitePreview(
        injectionSites: [
            InjectionSite(
                sketchId: "thighsFront",
                normalizedX: 0.3, normalizedY: 0.15,
                zoneLabel: "Upper Right Thigh",
                viewContext: "front", bodyRegion: "thighs",
                routeClass: "injection"
            )
        ],
        routeClass: .injection
    )
}