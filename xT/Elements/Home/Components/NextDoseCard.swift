//
//  NextDoseCard.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Next dose card component
//

import SwiftUI

struct NextDoseCard: View {
    let nextDose: Date

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("next dose")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.tertiaryLabel))

                Text(nextDose, style: .date)
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("in")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                let daysUntilNextDose = Calendar.current.dateComponents([.day], from: Date(), to: nextDose).day ?? 0
                Text("\(daysUntilNextDose) day\(daysUntilNextDose == 1 ? "" : "s")")
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.Bloom.mind.base)
            }

            // Calendar icon
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.Colors.Bloom.mind.surface)
                    .frame(width: 32, height: 40)

                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.Bloom.mind.base)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    NextDoseCard(nextDose: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date())
}