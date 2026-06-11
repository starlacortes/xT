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

    @Published var isAuthenticated = false
    @Published var showAuthentication = false
    @Published var lastActivityTime: Date = Date()

    @Published var requireAuthentication = true
    @Published var autoLockTimeout: TimeInterval = 300

    private var activityTimer: Timer?

    init() {
        loadSettings()
        startActivityMonitoring()
    }

    // MARK: - Authentication

    func authenticate(reason: String = "Access your health data", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.lastActivityTime = Date()
                    }
                    completion(success)
                }
            }
        } else {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.lastActivityTime = Date()
                    }
                    completion(success)
                }
            }
        }
    }

    func checkAuthenticationRequired() -> Bool {
        guard requireAuthentication else { return false }
        return Date().timeIntervalSince(lastActivityTime) > autoLockTimeout
    }

    func recordActivity() {
        if isAuthenticated { lastActivityTime = Date() }
    }

    // MARK: - Activity monitoring

    private func startActivityMonitoring() {
        activityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkActivityTimeout()
            }
        }
    }

    private func checkActivityTimeout() {
        guard requireAuthentication, isAuthenticated else { return }
        if Date().timeIntervalSince(lastActivityTime) > autoLockTimeout {
            isAuthenticated = false
            showAuthentication = true
        }
    }

    // MARK: - Settings

    private func loadSettings() {
        let defaults = UserDefaults.standard
        requireAuthentication = defaults.bool(forKey: "requireAuthentication")
        autoLockTimeout = TimeInterval(defaults.integer(forKey: "autoLockTimeout"))
        if autoLockTimeout == 0 {
            autoLockTimeout = 300
            defaults.set(300, forKey: "autoLockTimeout")
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(requireAuthentication, forKey: "requireAuthentication")
        defaults.set(Int(autoLockTimeout), forKey: "autoLockTimeout")
    }

    // MARK: - Biometrics

    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .touchID:  return .touchID
        case .faceID:   return .faceID
        case .opticID:  return .opticID
        default:        return .none
        }
    }

    func canUseBiometrics() -> Bool { biometricType() != .none }
}

// MARK: - BiometricType

enum BiometricType {
    case none, touchID, faceID, opticID

    var description: String {
        switch self {
        case .none:    return "None"
        case .touchID: return "Touch ID"
        case .faceID:  return "Face ID"
        case .opticID: return "Optic ID"
        }
    }

    var iconName: String {
        switch self {
        case .none:    return "lock"
        case .touchID: return "touchid"
        case .faceID:  return "faceid"
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
    @Environment(\.authenticationManager) var authManager
    @Environment(\.dismiss) var dismiss

    var reason: String
    @State private var showFallback = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.globalBackgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: authManager.biometricType().iconName)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 8)

                Text("Authenticate to continue")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(reason)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 40)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Theme.errorColor)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                }

                Button(action: authenticate) {
                    Text("Authenticate with \(authManager.biometricType().description)")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accentColor.opacity(0.8))
                        .cornerRadius(16)
                        .shadow(color: Theme.accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)

                if showFallback {
                    Button {
                        authManager.authenticate(reason: "Enter your passcode") { success in
                            if success { dismiss() } else { errorMessage = "Authentication failed" }
                        }
                    } label: {
                        Text("Use passcode instead")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
                
                Button { 
                    // Can't dismiss if authentication is required
                } label: {
                    Text("") // Hidden
                }
                .opacity(0)
            }
            .padding()
        }
        .onAppear { authenticate() }
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

#Preview {
    AuthenticationView(reason: "Access your health data")
        .environment(\.authenticationManager, AuthenticationManager.shared)
}

// MARK: - Environment Key

// nonisolated so the default value can be created outside the main actor
struct AuthenticationManagerKey: EnvironmentKey {
    nonisolated static let defaultValue: AuthenticationManager = {
        // Accessing a @MainActor type from a nonisolated context is safe here
        // because this is only used as a SwiftUI environment default fallback
        MainActor.assumeIsolated { AuthenticationManager.shared }
    }()
}

extension EnvironmentValues {
    var authenticationManager: AuthenticationManager {
        get { self[AuthenticationManagerKey.self] }
        set { self[AuthenticationManagerKey.self] = newValue }
    }
}