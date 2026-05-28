//
//  SettingsView.swift
//  xT
//
//  Created by starrrr on 8/5/25.
//

import SwiftUI
import PhotosUI
import SwiftData

struct SettingsView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingProfileSheet = false
    @State private var showingResetAlert = false
    @State private var doseRemindersEnabled = true
    @State private var journalRemindersEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with time (similar to HomeView pattern)
                    HStack {
                        Spacer()
                        Text("9:41")
                            .font(.system(size: 10))
                            .foregroundColor(Color(.systemGray))
                            .padding(.top, 4)
                            .padding(.trailing, 16)
                    }

                    // Settings title
                    HStack {
                        Text("Settings")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    // Profile Section
                    SectionCard {
                        NavigationLink(destination: ProfileEditorView()) {
                            SettingsRow {
                                // Profile avatar (similar to HomeView profile section)
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "FBEAF0"))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: "ED93B1"), lineWidth: 2)
                                        )

                                    if let profileImage = profileManager.profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Text(profileManager.profileName.prefix(1).uppercased())
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(hex: "D4537E"))
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profileManager.profileName.isEmpty ? "Your Profile" : profileManager.profileName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Edit profile & photo")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                    // Medication Section
                    SectionLabel("Medication")

                    SectionCard {
                        VStack(spacing: 0) {
                            // Type & Method
                            NavigationLink(destination: UnifiedScheduleView(isFromSettings: true)) {
                                SettingsRow {
                                    RowIcon(backgroundColor: Color(hex: "FBEAF0")) {
                                        Image(systemName: "pills.fill")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color(hex: "D4537E"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Type & method")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)

                                        Text(medicationManager.medicationDisplayInfo)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }

                            RowDivider()

                            // Dose Schedule
                            NavigationLink(destination: UnifiedScheduleView(isFromSettings: true)) {
                                SettingsRow {
                                    RowIcon(backgroundColor: Color(hex: "EEEDFE")) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color(hex: "534AB7"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Dose schedule")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)

                                         if let nextDate = medicationManager.nextDoseDate {
                                             let formattedDate = formatDate(nextDate)
                                             Text("Next: \(formattedDate)")
                                                 .font(.system(size: 12))
                                                 .foregroundColor(.secondary)
                                         } else {
                                             Text("No schedule set")
                                                 .font(.system(size: 12))
                                                 .foregroundColor(.secondary)
                                         }
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }

                            RowDivider()

                            // Record a dose
                            Button(action: {
                                medicationManager.recordDose(on: Date())
                            }) {
                                SettingsRow {
                                    RowIcon(backgroundColor: Color(hex: "E1F5EE")) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color(hex: "0F6E56"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Record a dose")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)

                                        if let lastDate = medicationManager.lastDoseDate {
                                            let formattedDate = formatDate(lastDate)
                                            Text("Last: \(formattedDate)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("No doses recorded")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Notifications Section
                    SectionLabel("Notifications")

                    SectionCard {
                        VStack(spacing: 0) {
                            // Dose reminders
                            SettingsRow {
                                RowIcon(backgroundColor: Color(hex: "FAEEDA")) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(Color(hex: "854F0B"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Dose reminders")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)

                                    Text("1 day before")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Toggle("", isOn: $doseRemindersEnabled)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "D4537E")))
                                    .frame(width: 50)
                            }

                            RowDivider()

                            // Journal reminders
                            SettingsRow {
                                RowIcon(backgroundColor: Color(hex: "FBEAF0")) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(Color(hex: "993556"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Journal reminders")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)

                                    Text("9:00 pm daily")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Toggle("", isOn: $journalRemindersEnabled)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "D4537E")))
                                    .frame(width: 50)
                            }
                        }
                    }

                    // Privacy & Security Section
                    SectionLabel("Privacy & security")

                    SectionCard {
                        NavigationLink(destination: Text("App Lock Settings")) {
                            SettingsRow {
                                RowIcon(backgroundColor: Color(hex: "F1EFE8")) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(Color(hex: "5F5E5A"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("App lock")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)

                                    Text("Face ID · 5 min timeout")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // About Section
                    SectionLabel("About")

                    SectionCard {
                        VStack(spacing: 0) {
                            // Version
                            SettingsRow {
                                RowIcon(backgroundColor: Color(hex: "F1EFE8")) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(Color(hex: "888780"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Version")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }

                                Text("1.0.0")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            RowDivider()

                            // Reset app data
                            Button(role: .destructive, action: {
                                showingResetAlert = true
                            }) {
                                SettingsRow {
                                    RowIcon(backgroundColor: Color(hex: "FCEBEB")) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color(hex: "A32D2D"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Reset app data")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "A32D2D"))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    // Spacer for bottom padding
                    Color.clear
                        .frame(height: 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
            .alert("Are you sure?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {
                    // User cancelled
                }
                Button("Reset", role: .destructive) {
                    resetAppData()
                }
            } message: {
                Text("xT will close and restart the onboarding process.")
            }
        }
    }

    private func resetAppData() {
        // Clear all UserDefaults data
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }

        // Reset managers
        profileManager.clearProfileImage()
        profileManager.updateProfileName("")
        medicationManager.clearSelection()

        // Clear SwiftData
        clearSwiftData()

        // Restart the app by setting onboarding flag to false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

        // Close the app
        exit(0)
    }

    private func clearSwiftData() {
        do {
            let container = try ModelContainer(for: JournalEntry.self)
            try container.mainContext.delete(model: JournalEntry.self)
        } catch {
            print("Error clearing SwiftData: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Custom Components (similar to HomeView pattern)

struct SectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .kerning(0.05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }
}

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

struct SettingsRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct RowIcon<Content: View>: View {
    let backgroundColor: Color
    let content: Content

    init(backgroundColor: Color, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .frame(width: 32, height: 32)

            content
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 56) // Align with content after icon
            .padding(.vertical, 0)
    }
}

// MARK: - Profile Settings Subview
struct ProfileSettingsView: View {
    @Environment(\.profileManager) private var profileManager
    @State private var name: String = ""
    @State private var showingImageSourceOptions = false

    var body: some View {
        Form {
            Section(header: Text("Profile Information")) {
                // Profile image with change option
                VStack {
                    Image(uiImage: profileManager.getCurrentProfileImage())
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .onTapGesture {
                            showingImageSourceOptions = true
                        }

                    Button(action: {
                        showingImageSourceOptions = true
                    }) {
                        Text("Change Photo")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)

                // Name field
                TextField("Your Name", text: $name)
                    .onAppear {
                        name = profileManager.profileName
                    }
                    .onChange(of: name) {
                        profileManager.updateProfileName(name)
                    }
            }

            Section {
                Button(action: {
                    profileManager.clearProfileImage()
                }) {
                    Text("Reset to Default Photo")
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    profileManager.updateProfileName("")
                    profileManager.clearProfileImage()
                } label: {
                    Text("Clear All Profile Data")
                }
            }
        }
        .navigationTitle("Profile")
        .actionSheet(isPresented: $showingImageSourceOptions) {
            ActionSheet(
                title: Text("Change Profile Photo"),
                message: Text("Choose a photo source"),
                buttons: [
                    .default(Text("Photo Library")) {
                        profileManager.showImagePicker = true
                    },
                    .default(Text("Take Photo")) {
                        profileManager.showCamera = true
                    },
                    .default(Text("Use Default")) {
                        profileManager.clearProfileImage()
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: Binding(
            get: { profileManager.showImagePicker },
            set: { profileManager.showImagePicker = $0 }
        )) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .photoLibrary)
        }
        .sheet(isPresented: Binding(
            get: { profileManager.showCamera },
            set: { profileManager.showCamera = $0 }
        )) {
            PhotoPicker(imageData: Binding(
                get: { profileManager.profileImageData },
                set: { profileManager.profileImageData = $0 }
            ), sourceType: .camera)
        }
        .onChange(of: profileManager.selectedPhotoItem) {
            profileManager.handlePhotoSelection()
        }
    }
}

// MARK: - Photo Picker Helper
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SettingsView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}