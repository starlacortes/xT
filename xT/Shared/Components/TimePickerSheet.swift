//
//  TimePickerSheet.swift
//  xT
//
//  Created by Cline on 6/10/2026.
//  Reusable time picker sheet for settings
//

import SwiftUI

struct TimePickerSheet: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                HStack(spacing: 20) {
                    DatePicker("", selection: $dateSelection, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 200)
                }

                Button("Done") {
                    isPresented = false
                }
                .asAccentButton()
                .padding(.horizontal, 24)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .onAppear {
                dateSelection = Calendar.current.date(from: timeComponents) ?? Date()
            }
        }
    }

    private var timeComponents: DateComponents {
        var c = DateComponents()
        c.hour = hour
        c.minute = minute
        return c
    }

    @State private var dateSelection: Date = Date() {
        didSet {
            let components = Calendar.current.dateComponents([.hour, .minute], from: dateSelection)
            hour = components.hour ?? 0
            minute = components.minute ?? 0
        }
    }
}

#Preview {
    TimePickerSheet(
        title: "Dose reminder time",
        hour: .constant(9),
        minute: .constant(0),
        isPresented: .constant(true)
    )
}
