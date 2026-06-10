//
//  ProfileEditorView.swift
//  xT
//
//  Created by Cline on 4/5/2026.
//  Dedicated profile editing interface
//

import SwiftUI
import PhotosUI

struct ProfileEditorView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var showingImageSourceOptions = false
    @State private var showingSaveConfirmation = false
    @State private var originalName: String = ""
    @State private var originalImageData: Data? = nil
    @State private var hasChanges: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // Profile Preview Section
                Section(header: Text("Profile Preview")) {
                    VStack {
                        Image(uiImage: profileManager.getCurrentProfileImage())
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )
                            .onTapGesture {
                                showingImageSourceOptions = true
                            }
                            .padding(.vertical, 8)

                        Text(name.isEmpty ? "Your Profile" : name)
                            .font(.headline)
                            .padding(.bottom, 4)

                        Text(profileManager.hasProfileData ? "Profile Complete" : "Profile Incomplete")
                            .font(.subheadline)
                            .foregroundColor(profileManager.hasProfileData ? .green : .orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // Profile Information Section
                Section(header: Text("Profile Information")) {
                    // Name field with better validation
                    TextField("Your Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) {
                            checkForChanges()
                        }

                    // Image source options
                    HStack(spacing: 16) {
                        Button(action: {
                            showingImageSourceOptions = true
                        }) {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.title2)
                                Text("Library")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: {
                            profileManager.showCamera = true
                        }) {
                            VStack {
                                Image(systemName: "camera")
                                    .font(.title2)
                                Text("Camera")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: {
                            profileManager.clearProfileImage()
                            checkForChanges()
                        }) {
                            VStack {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                Text("Default")
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Actions Section
                Section {
                    Button(action: {
                        saveChanges()
                    }) {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                            Spacer()
                        }
                    }
                    .disabled(!hasChanges)
                    .foregroundColor(hasChanges ? .blue : .gray)

                    Button(role: .destructive, action: {
                        resetToOriginal()
                    }) {
                        HStack {
                            Spacer()
                            Text("Reset Changes")
                            Spacer()
                        }
                    }
                    .disabled(!hasChanges)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
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
                            checkForChanges()
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
                    set: { newData in
                        profileManager.profileImageData = newData
                        checkForChanges()
                    }
                ), sourceType: .photoLibrary)
            }
            .sheet(isPresented: Binding(
                get: { profileManager.showCamera },
                set: { profileManager.showCamera = $0 }
            )) {
                PhotoPicker(imageData: Binding(
                    get: { profileManager.profileImageData },
                    set: { newData in
                        profileManager.profileImageData = newData
                        checkForChanges()
                    }
                ), sourceType: .camera)
            }
            .onChange(of: profileManager.selectedPhotoItem) {
                profileManager.handlePhotoSelection()
                checkForChanges()
            }
            .onAppear {
                // Initialize with current profile data
                name = profileManager.profileName
                originalName = profileManager.profileName
                originalImageData = profileManager.profileImageData
                hasChanges = false
            }
            .alert("Changes Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your profile has been updated successfully.")
            }
        }
    }

    private func checkForChanges() {
        hasChanges = (name != originalName) ||
                     (profileManager.profileImageData != originalImageData)
    }

    private func saveChanges() {
        if name != profileManager.profileName {
            profileManager.updateProfileName(name)
        }

        // Image data is already updated through bindings
        originalName = name
        originalImageData = profileManager.profileImageData
        hasChanges = false
        showingSaveConfirmation = true
    }

    private func resetToOriginal() {
        name = originalName
        if let originalData = originalImageData {
            profileManager.profileImageData = originalData
            profileManager.profileImage = UIImage(data: originalData)
        } else {
            profileManager.clearProfileImage()
        }
        hasChanges = false
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ProfileEditorView()
            .environment(\.profileManager, ProfileManager.shared)
    }
}