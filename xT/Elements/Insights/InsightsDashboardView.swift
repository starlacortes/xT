//
//  InsightsDashboardView.swift
//  xT
//
//  Phase 2 Research Dashboard container.
//  Three-panel picker: Correlation / Trends / Audit.
//

import SwiftUI

struct InsightsDashboardView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Environment(\.researchInsightsManager) private var insightsManager

    @State private var selectedPanel: Panel = .correlation

    enum Panel: String, CaseIterable {
        case correlation = "Correlation"
        case trends      = "Trends"
        case audit       = "Audit"

        var icon: String {
            switch self {
            case .correlation: return "chart.scatter"
            case .trends:      return "chart.line.uptrend.xyaxis"
            case .audit:       return "shield.checkered"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel picker
            panelPicker

            // Content
            TabView(selection: $selectedPanel) {
                CorrelationView()
                    .tag(Panel.correlation)

                LongitudinalTrendView()
                    .tag(Panel.trends)

                AuditSafetyView()
                    .tag(Panel.audit)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Panel Picker

    private var panelPicker: some View {
        HStack(spacing: 0) {
            ForEach(Panel.allCases, id: \.self) { panel in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPanel = panel
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 12))
                        Text(panel.rawValue)
                            .font(Theme.Fonts.caption)
                            .fontWeight(selectedPanel == panel ? .semibold : .regular)
                    }
                    .foregroundStyle(selectedPanel == panel ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedPanel == panel
                                  ? Theme.Colors.accent
                                  : Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        InsightsDashboardView()
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.journalManager, JournalManager.shared)
            .environment(\.researchInsightsManager, ResearchInsightsManager.shared)
    }
}