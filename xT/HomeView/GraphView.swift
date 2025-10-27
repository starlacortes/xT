//
//  GraphView.swift
//  xT
//
//  Created by starrrr on 8/5/25.
//

import SwiftUI
import Charts

struct GraphView: View {
    @StateObject private var medicationManager = MedicationManager.shared

    @State private var rangeInDays: Int = 90

    private var series: [MedicationManager.EstimatedPoint] {
        medicationManager.estimatedRecentLevels(days: rangeInDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Estimated Hormone Levels")
                    .font(.title2).bold()
                Spacer()
            }

            if medicationManager.selectedMedicationType == nil || medicationManager.selectedAdministrationMethod == nil {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Select a medication type and method to view estimated levels.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Controls
                HStack {
                    Text("Range")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Picker("Range", selection: $rangeInDays) {
                        Text("30d").tag(30)
                        Text("90d").tag(90)
                        Text("180d").tag(180)
                        Text("1y").tag(365)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }

                Chart(series) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Level", point.value)
                    )
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Level", point.value)
                    )
                    .symbolSize(20)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, style: .date)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Graph")
    }
}

#Preview {
    NavigationStack {
        GraphView()
    }
}
