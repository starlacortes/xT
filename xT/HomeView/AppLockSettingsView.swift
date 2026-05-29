//
//  AppLockSettingsView.swift
//  xT
//
//  Created by Cline on 5/28/2026.
//  Dedicated app lock and security settings
//

import SwiftUI

struct AppLockSettingsView: View {
    @Environment(\.authenticationManager) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var requireAuth: Bool = false
    @State private var selectedTimeout: TimeInterval = 300
    
    private let timeoutOptions: [(String, TimeInterval)] = [
        ("Immediately", 0),
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // Face ID / Biometrics Section
                Section(header: Text("Authentication")) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.bloomMindLightColor)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: authManager.biometricType().iconName)
                                .font(.system(size: 17))
                                .foregroundColor(Theme.bloomMindColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Require \(authManager.biometricType().description)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                            
                            if authManager.canUseBiometrics() {
                                Text("Use biometrics to unlock xT")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Biometrics not available")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $requireAuth)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Theme.accentColor))
                            .disabled(!authManager.canUseBiometrics())
                    }
                    .padding(.vertical, 4)
                }
                
                // Auto-lock Timeout Section
                if requireAuth {
                    Section(header: Text("Auto-lock timeout"), 
                           footer: Text("xT will require authentication after being inactive for the selected duration.")) {
                        ForEach(timeoutOptions, id: \.1) { option in
                            Button(action: {
                                selectedTimeout = option.1
                            }) {
                                HStack {
                                    Text(option.0)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedTimeout == option.1 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Information Section
                Section(header: Text("About app lock")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy & Security")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("App lock helps protect your sensitive health data by requiring authentication when opening xT or after a period of inactivity.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("App Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .foregroundColor(Theme.accentColor)
                }
            }
            .onAppear {
                requireAuth = authManager.requireAuthentication
                selectedTimeout = authManager.autoLockTimeout
            }
        }
    }
    
    private func saveSettings() {
        authManager.requireAuthentication = requireAuth
        authManager.autoLockTimeout = selectedTimeout
        authManager.saveSettings()
    }
}

#Preview {
    AppLockSettingsView()
        .environment(\.authenticationManager, AuthenticationManager.shared)
}
