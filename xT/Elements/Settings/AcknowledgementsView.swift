//
//  AcknowledgementsView.swift
//  xT
//
//  Open-source acknowledgements (element F8). Credits the three bundled OFL typefaces
//  and shows each license text, read from the bundled copies in xT/Resources/Licenses/.
//  Reached from the Settings footer (wired in the Settings tier, element ST10).
//

import SwiftUI

/// One credited open-source component and the bundle resource holding its license.
private struct Acknowledgement: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    /// Base name of the license file in the bundle (without extension).
    let licenseResource: String

    static let all: [Acknowledgement] = [
        .init(title: "IBM Plex Serif & Mono",
              detail: "Display and monospace type. © IBM Corp.",
              licenseResource: "IBM-Plex-OFL"),
        .init(title: "Atkinson Hyperlegible Next",
              detail: "Body type. © The Atkinson Hyperlegible Next Project Authors.",
              licenseResource: "Atkinson-Hyperlegible-Next-OFL"),
    ]
}

struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                ForEach(Acknowledgement.all) { ack in
                    NavigationLink {
                        LicenseTextView(title: ack.title, resource: ack.licenseResource)
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(ack.title).font(Theme.Fonts.body)
                            Text(ack.detail)
                                .font(Theme.Fonts.detail)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            } header: {
                Text("TYPEFACES").eyebrow()
            } footer: {
                Text("All three families are licensed under the SIL Open Font License 1.1.")
                    .font(Theme.Fonts.detail)
            }
        }
        .paperList()
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Renders a bundled license .txt verbatim in a mono face.
private struct LicenseTextView: View {
    let title: String
    let resource: String

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "License text unavailable."
        }
        return text
    }

    var body: some View {
        ScrollView {
            Text(licenseText)
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(Theme.Spacing.lg)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AcknowledgementsView() }
}
