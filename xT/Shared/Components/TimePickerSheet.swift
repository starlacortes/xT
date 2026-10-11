//
//  TimePickerSheet.swift
//  xT
//
//  Created by Cline on 6/10/2026.
//  Reusable time picker sheet for settings
//

import SwiftUI

/// A wheel time picker in a sheet, writing straight back to an `hour`/`minute` pair.
///
/// This used to keep a `@State` copy of the selection with a `didSet` that pushed the
/// components back to the bindings. `DatePicker` writes through the *projected* binding,
/// which mutates the `State` storage directly and never runs the property observer — so
/// the observer only ever fired from `onAppear`, and both reminder pickers silently
/// discarded whatever the user chose. The selection is now a computed `Binding` derived
/// from `hour`/`minute`, so there is only one copy of the value and no way for the two to
/// drift apart.
struct TimePickerSheet: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                Text(title)
                    .font(Theme.Fonts.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxHeight: 200)

                Button("Done") {
                    isPresented = false
                }
                .asAccentButton()
                .padding(.horizontal, Theme.Spacing.xxl)
            }
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.lg)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    /// The wheel's value, projected onto the `hour`/`minute` bindings.
    ///
    /// Only the time-of-day components are displayed or read back, so the date is
    /// anchored to today purely to give `DatePicker` a valid `Date` to work with.
    private var selection: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour, minute: minute, second: 0, of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents(
                    [.hour, .minute], from: newValue
                )
                hour = components.hour ?? 0
                minute = components.minute ?? 0
            }
        )
    }
}

#if DEBUG
#Preview {
    TimePickerSheet(
        title: "Dose reminder time",
        hour: .constant(9),
        minute: .constant(0),
        isPresented: .constant(true)
    )
}
#endif
