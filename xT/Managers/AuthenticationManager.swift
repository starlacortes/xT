//
//  AuthenticationManager.swift
//  xT
//
//  Created by Cline on 4/16/2026.
//  Authentication management system for app security
//

import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    // Authentication state
    @Published var isAuthenticated = false
    @Published var showAuthentication = false
    @Published var lastActivityTime: Date = Date()

    // App lock settings
    @Published var requireAuthentication = true
    @Published var autoLockTimeout: TimeInterval = 300 // 5 minutes

    // Activity monitoring timer
    private var activityTimer: Timer?

    init() {
        loadSettings()
        startActivityMonitoring()
    }

    // MARK: - Authentication Methods

    /// Authenticate user with biometrics
    func authenticate(reason: String = "Access your health data", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.lastActivityTime = Date()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        } else {
            // Fallback to device passcode if biometrics not available
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.lastActivityTime = Date()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        }
    }

    /// Check if authentication is required
    func checkAuthenticationRequired() -> Bool {
        if !requireAuthentication {
            return false
        }

        // Check if we need to re-authenticate due to inactivity
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        return timeSinceLastActivity > autoLockTimeout
    }

    /// Record user activity
    func recordActivity() {
        if isAuthenticated {
            lastActivityTime = Date()
        }
    }

    // MARK: - Activity Monitoring

    private func startActivityMonitoring() {
        activityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkActivityTimeout()
        }
    }

    @MainActor private func checkActivityTimeout() {
        if requireAuthentication && isAuthenticated {
            let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
            if timeSinceLastActivity > autoLockTimeout {
                isAuthenticated = false
                showAuthentication = true
            }
        }
    }

    // MARK: - Settings Management

    private func loadSettings() {
        let defaults = UserDefaults.standard
        requireAuthentication = defaults.bool(forKey: "requireAuthentication")
        autoLockTimeout = TimeInterval(defaults.integer(forKey: "autoLockTimeout"))

        // Set defaults if not set
        if autoLockTimeout == 0 {
            autoLockTimeout = 300 // 5 minutes
            defaults.set(300, forKey: "autoLockTimeout")
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(requireAuthentication, forKey: "requireAuthentication")
        defaults.set(Int(autoLockTimeout), forKey: "autoLockTimeout")
    }

    // MARK: - Biometric Availability

    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if #available(iOS 11.0, *) {
                switch context.biometryType {
                case .none:
                    return .none
                case .touchID:
                    return .touchID
                case .faceID:
                    return .faceID
                case .opticID:
                    return .opticID
                @unknown default:
                    return .none
                }
            } else {
                return .touchID // Assume Touch ID for older versions
            }
        }

        return .none
    }

    func canUseBiometrics() -> Bool {
        return biometricType() != .none
    }
}

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID

    var description: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "lock"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        }
    }
}

// MARK: - View Modifiers

struct AuthenticationRequiredModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthenticationManager
    var reason: String = "Access your health data"

    func body(content: Content) -> some View {
        content
            .onAppear {
                if authManager.checkAuthenticationRequired() {
                    authManager.showAuthentication = true
                } else {
                    authManager.recordActivity()
                }
            }
            .sheet(isPresented: $authManager.showAuthentication) {
                AuthenticationView(reason: reason)
                    .environmentObject(authManager)
            }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss

    var reason: String
    @State private var showFallback = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: authManager.biometricType().iconName)
                .font(.system(size: 50))
                .padding()

            Text("Authenticate to Continue")
                .font(.title2)
                .bold()

            Text(reason)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }

            Button(action: {
                authenticate()
            }) {
                Text("Authenticate with \(authManager.biometricType().description)")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            if showFallback {
                Button(action: {
                    authManager.authenticate(reason: "Enter your passcode") { success in
                        if success {
                            dismiss()
                        } else {
                            errorMessage = "Authentication failed"
                        }
                    }
                }) {
                    Text("Use Passcode Instead")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
                    .foregroundColor(.gray)
            }
            .padding(.top)
        }
        .padding()
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        authManager.authenticate(reason: reason) { success in
            if success {
                dismiss()
            } else {
                errorMessage = "Authentication failed"
                showFallback = true
            }
        }
    }
}

// MARK: - Environment Extension

struct AuthenticationManagerKey: EnvironmentKey {
    static let defaultValue = AuthenticationManager.shared
}

extension EnvironmentValues {
    var authenticationManager: AuthenticationManager {
        get { self[AuthenticationManagerKey.self] }
        set { self[AuthenticationManagerKey.self] = newValue }
    }
}