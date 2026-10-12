//
//  ProfileEditorView.swift
//  xT
//
//  The profile editor, presented as a sheet from the Settings header (ST2).
//  Its own `NavigationStack` with Cancel/Save is correct now that it's a
//  sheet — it was wrong when the editor was pushed. Isocline: `AvatarView`
//  with the hairline ring (no 3pt accent ring), flush rows, and a `ghostCard`
//  for the name field. The sheet's own glass is the card surface.
//

import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var showingPhotoSourceDialog = false
    @State private var originalName: String = ""
    @State private var originalImageData: Data? = nil
    @State private var hasChanges: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    avatarHeader
                    nameSection
                    photoSection
                }
                .padding(.horizontal, Theme.Spacing.Gutter.screen)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(Theme.Colors.appBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!hasChanges)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Change Profile Photo",
                isPresented: $showingPhotoSourceDialog,
                titleVisibility: .visible
            ) {
                Button("Photo Library") { profileManager.showImagePicker = true }
                Button("Take Photo") { profileManager.showCamera = true }
                Button("Remove Photo", role: .destructive) { removePhoto() }
                Button("Cancel", role: .cancel) {}
            }
            .profilePhotoPickers(
                libraryPresented: Binding(
                    get: { profileManager.showImagePicker },
                    set: { profileManager.showImagePicker = $0 }
                ),
                cameraPresented: Binding(
                    get: { profileManager.showCamera },
                    set: { profileManager.showCamera = $0 }
                ),
                onImageChanged: checkForChanges
            )
            .onAppear {
                name = profileManager.profileName
                originalName = profileManager.profileName
                originalImageData = profileManager.profileImageData
                hasChanges = false
            }
        }
    }

    // MARK: - Avatar header

    private var avatarHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                showingPhotoSourceDialog = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(image: profileManager.profilePhoto, size: AvatarView.Size.editor)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.OnAccent.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.Colors.accent))
                        .overlay(Circle().strokeBorder(Theme.Colors.appBackground, lineWidth: 3))
                }
            }
            .buttonStyle(.plain)

            Text(verbatim: name.isEmpty ? "Your Profile" : name)
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Tap the photo to change it")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Name section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SheetSectionLabel(text: "Name")

            TextField("Your name", text: $name)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.lg)
                .ghostCard(radius: Theme.Radius.lg)
                .onChange(of: name) { _, _ in
                    checkForChanges()
                }
        }
    }

    // MARK: - Photo section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SheetSectionLabel(text: "Photo")

            VStack(spacing: 0) {
                photoSourceRow(icon: "photo",
                               title: "Photo Library",
                               subtitle: "Choose from your photos") {
                    profileManager.showImagePicker = true
                }

                HairlineDivider(inset: Theme.Spacing.card)

                photoSourceRow(icon: "camera",
                               title: "Take Photo",
                               subtitle: "Use your camera") {
                    profileManager.showCamera = true
                }

                HairlineDivider(inset: Theme.Spacing.card)

                photoSourceRow(icon: "person.crop.circle.badge.xmark",
                               title: "Remove Photo",
                               subtitle: "Use the default avatar",
                               showsChevron: false,
                               isDestructive: true) {
                    removePhoto()
                }
            }
        }
    }

    private func photoSourceRow(icon: String, title: LocalizedStringResource,
                                subtitle: LocalizedStringResource,
                                showsChevron: Bool = true,
                                isDestructive: Bool = false,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.card) {
                SettingsIconTile(icon: icon)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(isDestructive ? Theme.Colors.error : Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                if showsChevron {
                    SettingsChevron()
                }
            }
            .padding(.horizontal, Theme.Spacing.card)
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func checkForChanges() {
        hasChanges = (name != originalName) ||
                     (profileManager.profileImageData != originalImageData)
    }

    private func removePhoto() {
        profileManager.clearProfileImage()
        checkForChanges()
    }

    private func saveChanges() {
        if name != profileManager.profileName {
            profileManager.updateProfileName(name)
        }

        // Image data is already updated through the pickers' shared plumbing.
        originalName = name
        originalImageData = profileManager.profileImageData
        hasChanges = false
        dismiss()
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    ProfileEditorView()
        .environment(\.profileManager, ProfileManager.shared)
}
#endif
