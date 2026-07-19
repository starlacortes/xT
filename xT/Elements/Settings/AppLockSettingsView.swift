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
    @State private var allowPasscodeFallback: Bool = true
    @State private var showTestBiometric = false
    
    func authResult(_ error: Error) -> TestResult {
        if let authErr = error as? XAuthenticationError {
            switch authErr {
            case .cancelled:
                return .cancelled
            default:
                return .failure
            }
        }
        return .failure
    }
   
    private let timeoutOptions: [(String, TimeInterval)] = [
        ("Immediately", 0),
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]
    
    private var biometricType: BiometricType {
        authManager.biometricType()
    }
    
    private var hasFaceID: Bool {
        biometricType == .faceID
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if hasFaceID {
                    faceIDSection
                } else if biometricType != .none {
                    biometricsSection
                } else {
                    noBiometricsSection
                }
                
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
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedTimeout == option.1 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.Colors.accent)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("About app lock")) {
                    infoSection
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
                    .foregroundStyle(Theme.Colors.accent)
                }
            }
            .onAppear {
                requireAuth = authManager.requireAuthentication
                selectedTimeout = authManager.autoLockTimeout
                allowPasscodeFallback = UserDefaults.standard.bool(forKey: "allowPasscodeFallback")
            }
            .fullScreenCover(isPresented: $showTestBiometric) {
                TestBiometricSheet()
            }
        }
    }
    
    // MARK: - Face ID Section
    
    private var faceIDSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.Time.mind.surface.opacity(0.3))
                    .frame(width: 64, height: 64)
                Image(systemName: "faceid")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Colors.Time.mind.base)
            }
            
            Text("Require Face ID")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("Use Face ID to quickly unlock xT. You can also set up Face ID in the Settings app if you haven't already.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Toggle("Require Face ID", isOn: $requireAuth)
            
            Toggle("Allow passcode fallback", isOn: $allowPasscodeFallback)
                .tint(Theme.Colors.accent)
            
            Button(action: { showTestBiometric = true }) {
                Label("Test Face ID", systemImage: "faceid")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Other Biometrics Section
    
    private var biometricsSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.Time.mind.surface.opacity(0.3))
                    .frame(width: 64, height: 64)
                Image(systemName: biometricType.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Colors.Time.mind.base)
            }
            
            Text("Require \(biometricType.description)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("Use \(biometricType.description.lowercased()) to unlock xT. You can also set up \(biometricType.description) in the Settings app if you haven't already.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Toggle("Require \(biometricType.description)", isOn: $requireAuth)
            
            Toggle("Allow passcode fallback", isOn: $allowPasscodeFallback)
                .tint(Theme.Colors.accent)
            
            Button(action: { showTestBiometric = true }) {
                Label("Test \(biometricType.description)", systemImage: biometricType.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - No Biometrics Section
    
    private var noBiometricsSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
            }
            
            Text("Biometrics Unavailable")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            
            Text("Your device doesn't have Face ID or Touch ID set up. You can set up Face ID or Touch ID in Settings to unlock xT with biometrics, or use the passcode option below.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                Label("Open Settings", systemImage: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
            }
            
            Toggle("Require passcode instead", isOn: $requireAuth)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy & Security")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            
            Text("App lock helps protect your sensitive health data by requiring authentication when opening xT or after a period of inactivity. Your biometric data is never stored on our servers or shared with Apple.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        authManager.requireAuthentication = requireAuth
        authManager.autoLockTimeout = selectedTimeout
        UserDefaults.standard.set(allowPasscodeFallback, forKey: "allowPasscodeFallback")
    }
}

// MARK: - Test Biometric Sheet

struct TestBiometricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authenticationManager) private var authManager
    @State private var result: TestResult?
    
    var body: some View {
        ZStack {
            Theme.Gradients.brand.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                if let result {
                    switch result {
                    case .success:
                        successView
                    case .failure:
                        failureView
                    case .cancelled:
                        cancelledView
                    }
                } else {
                    progressView
                }
                
                Spacer()
            }
        }
        .task {
            do {
                try await authManager.authenticate(reason: "Test your biometric authentication with xT")
                result = .success
            } catch {
                result = authResult(error)
            }
        }
    }
    
    func authResult(_ error: Error) -> TestResult {
        if let authErr = error as? XAuthenticationError {
            switch authErr {
            case .cancelled:
                return .cancelled
            default:
                return .failure
            }
        }
        return .failure
    }
    
    private var progressView: some View {
        VStack(spacing: 16) {
            Image(systemName: authManager.biometricType().iconName)
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.Time.mind.base)
            Text("Test your biometric authentication")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
            ProgressView().tint(.white)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Biometrics Enabled!")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
            Text("Biometric authentication is working correctly.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.accent.opacity(0.8))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
        .transition(.opacity)
        .animation(.easeIn, value: result)
    }
    
    private var failureView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("Authentication Failed")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
            Text("Your biometric data doesn't match. Please try again.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            
            Button(action: { Task { await testAgain() } }) {
                Text("Try Again")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.accent.opacity(0.8))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
        .transition(.opacity)
        .animation(.easeIn, value: result)
    }
    
    private var cancelledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Test Cancelled")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.accent.opacity(0.8))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
        .transition(.opacity)
        .animation(.easeIn, value: result)
    }
    
    private func testAgain() async {
        result = nil
        do {
            try await authManager.authenticate(reason: "Test your biometric authentication with xT")
            result = .success
        } catch {
            result = authResult(error)
        }
    }
}

enum TestResult {
    case success, failure, cancelled
}

#Preview {
    AppLockSettingsView()
        .environment(\.authenticationManager, AuthenticationManager.shared)
}
