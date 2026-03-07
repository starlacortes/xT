//
//  GraphView.swift
//  xT
//
//  Created by starrrr on 8/5/25.
//

import SwiftUI
import Charts

struct GraphView: View {
    @Environment(\.medicationManager) private var medicationManager

    @State private var rangeInDays: Int = 90

    private var series: [MedicationManager.EstimatedPoint] {
        medicationManager.estimatedRecentLevels(days: rangeInDays)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Estimated Hormone Levels")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 8)

                if medicationManager.selectedMedication == nil || medicationManager.selectedAdministrationMethod == nil {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Selection")
                            .font(.headline)
                        Text("Select a medication type and method to view estimated levels.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                } else {
                    // Controls
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Range")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Range", selection: $rangeInDays) {
                            Text("30d").tag(30)
                            Text("90d").tag(90)
                            Text("180d").tag(180)
                            Text("1y").tag(365)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Chart
                    Chart(series) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Level", point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Level", point.value)
                        )
                        .symbolSize(60)
                        .foregroundStyle(.blue)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, style: .date)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 300)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Graph")
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    NavigationStack {
        GraphView()
    }
}
