//
//  HeatmapView.swift
//  xT
//
//  Weekday × Month missed-dose heatmap grid.
//  Color intensity scales from zero (neutral) to max (error red).
//

import SwiftUI

struct HeatmapView: View {
    let cells: [HeatmapCell]
    let title: String

    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Extract unique month labels in chronological order from cells.
    private var monthLabels: [String] {
        var seen: Set<String> = []
        return cells.compactMap { cell in
            if seen.contains(cell.monthLabel) { return nil }
            seen.insert(cell.monthLabel)
            return cell.monthLabel
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if cells.isEmpty {
                Text("No missed dose data")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                heatmapGrid
            }

            // Legend
            if !cells.isEmpty {
                legendBar
            }
        }
    }

    // MARK: - Grid

    private var heatmapGrid: some View {
        HStack(alignment: .top, spacing: 3) {
            // Row labels (weekdays)
            VStack(alignment: .trailing, spacing: 3) {
                // Spacer for alignment with month header row
                Text("")
                    .font(.system(size: 9))
                    .frame(height: 12)

                ForEach(weekdayLabels, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 20, alignment: .trailing)
                }
            }

            // Scrollable grid
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 3) {
                    // Month header row
                    HStack(spacing: 3) {
                        ForEach(monthLabels, id: \.self) { month in
                            Text(month)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 12)
                        }
                    }

                    // Data rows
                    ForEach(weekdayLabels, id: \.self) { weekday in
                        HStack(spacing: 3) {
                            ForEach(monthLabels, id: \.self) { month in
                                cellView(for: weekday, month: month)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cell

    private func cellView(for weekday: String, month: String) -> some View {
        let cell = cells.first { $0.weekdayLabel == weekday && $0.monthLabel == month }
        let count = cell?.count ?? 0
        let maxC = max(cell?.maxCount ?? 1, 1)
        let intensity = maxC > 0 ? CGFloat(count) / CGFloat(maxC) : 0

        return RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(intensity: intensity))
            .frame(width: 20, height: 20)
            .overlay(
                Text(count > 0 ? "\(count)" : "")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(intensity > 0.5 ? .white : .primary.opacity(0.6))
            )
    }

    private func cellColor(intensity: CGFloat) -> Color {
        if intensity <= 0 {
            return Color.primary.opacity(0.04)
        }
        // Interpolate: low = cool blue-gray, high = error red
        return Color(
            hue: 0.0 + 0.6 * (1 - intensity),
            saturation: 0.2 + 0.6 * intensity,
            brightness: 0.5 + (0.4 * (1 - intensity))
        )
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 6) {
            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(cellColor(intensity: CGFloat(i) / 4.0))
                    .frame(width: 16, height: 12)
            }

            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    VStack(spacing: 20) {
        HeatmapView(
            cells: [
                HeatmapCell(monthLabel: "Jan", weekdayLabel: "Mon", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Jan", weekdayLabel: "Tue", count: 1, maxCount: 5),
                HeatmapCell(monthLabel: "Jan", weekdayLabel: "Wed", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Jan", weekdayLabel: "Thu", count: 3, maxCount: 5),
                HeatmapCell(monthLabel: "Jan", weekdayLabel: "Fri", count: 2, maxCount: 5),
                HeatmapCell(monthLabel: "Jan", weekdayLabel: "Sat", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Jan", weekdayLabel: "Sun", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Feb", weekdayLabel: "Mon", count: 1, maxCount: 5),
                HeatmapCell(monthLabel: "Feb", weekdayLabel: "Tue", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Feb", weekdayLabel: "Wed", count: 2, maxCount: 5),
                HeatmapCell(monthLabel: "Feb", weekdayLabel: "Thu", count: 5, maxCount: 5),
                HeatmapCell(monthLabel: "Feb", weekdayLabel: "Fri", count: 1, maxCount: 5),
                HeatmapCell(monthLabel: "Feb", weekdayLabel: "Sat", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Feb", weekdayLabel: "Sun", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Mar", weekdayLabel: "Mon", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Mar", weekdayLabel: "Tue", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Mar", weekdayLabel: "Wed", count: 1, maxCount: 5),
                HeatmapCell(monthLabel: "Mar", weekdayLabel: "Thu", count: 4, maxCount: 5),
                HeatmapCell(monthLabel: "Mar", weekdayLabel: "Fri", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Mar", weekdayLabel: "Sat", count: 0, maxCount: 5),
                HeatmapCell(monthLabel: "Mar", weekdayLabel: "Sun", count: 0, maxCount: 5),
            ],
            title: "MISSED DOSE HEATMAP"
        )
        .padding()
    }
}