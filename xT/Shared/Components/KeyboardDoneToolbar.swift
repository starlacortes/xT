import SwiftUI

extension View {
    /// A trailing "Done" button on the keyboard's input accessory bar.
    /// Four sheets hand-copied this exact ToolbarItemGroup; `QuickDoseSheet`
    /// keeps its own glass-styled variant and does not use this.
    func keyboardDoneToolbar(action: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: action)
            }
        }
    }
}
