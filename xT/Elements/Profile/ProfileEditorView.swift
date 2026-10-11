//
//  ProfileEditorView.swift
//  xT
//
//  Created by Cline on 4/5/2026.
//  Dedicated profile editing interface
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
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    avatarHeader
                    nameSection
                    photoSection
                }
                .padding(.horizontal, Theme.Spacing.Gutter.screen)
                .padding(.vertical, Theme.Spacing.xl)
            }
            .background(Color(.systemGroupedBackground))
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
                    Image(uiImage: profileManager.getCurrentProfileImage())
                        .resizable()
                        .scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.Colors.accent, lineWidth: 3))

                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.OnAccent.primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.Colors.accent))
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 3))
                }
            }
            .buttonStyle(.plain)

            Text(name.isEmpty ? "Your Profile" : name)
                .font(Theme.Fonts.headline)
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
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(Theme.Colors.appBackground)
                )
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
                photoSourceRow(
                    icon: "photo",
                    tint: Theme.Colors.accent,
                    title: "Photo Library",
                    subtitle: "Choose from your photos"
                ) {
                    profileManager.showImagePicker = true
                }

                HairlineDivider()

                photoSourceRow(
                    icon: "camera",
                    tint: Theme.Colors.accentSecondary,
                    title: "Take Photo",
                    subtitle: "Use your camera"
                ) {
                    profileManager.showCamera = true
                }

                HairlineDivider()

                photoSourceRow(
                    icon: "person.crop.circle.badge.xmark",
                    tint: Theme.Colors.error,
                    title: "Remove Photo",
                    subtitle: "Use the default avatar",
                    showsChevron: false
                ) {
                    removePhoto()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.appBackground)
            )
        }
    }

    private func photoSourceRow(icon: String, tint: Color, title: String, subtitle: String,
                                showsChevron: Bool = true,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.card) {
                SettingsIconTile(icon: icon, background: tint.opacity(0.15), color: tint)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
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
    NavigationStack {
        ProfileEditorView()
            .environment(\.profileManager, ProfileManager.shared)
    }
}
#endif
