import Foundation
import LocalAuthentication
import SwiftUI

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

public enum XAuthenticationError: Error {
    case cancelled
    case failed(Error)
    case passcodeNotSet
    case biometricNotAvailable
}

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isAuthenticated = false
    @Published var showAuthentication = false
    @Published var lastActivityTime: Date = Date()
    private var hasExited = false

    @UserDefault(key: "requireAuthentication", defaultValue: false)
    var requireAuthentication: Bool {
        didSet {
            if !requireAuthentication {
                isAuthenticated = true
                showAuthentication = false
                hasExited = false
            } else {
                // Require auth immediately when turned on
                isAuthenticated = false
                showAuthentication = true
            }
        }
    }

    @UserDefault(key: "autoLockTimeout", defaultValue: 300.0)
    var autoLockTimeout: TimeInterval

    var allowPasscodeFallback: Bool {
        get { UserDefaults.standard.bool(forKey: "allowPasscodeFallback") }
        set { UserDefaults.standard.set(newValue, forKey: "allowPasscodeFallback") }
    }
    
    var timeoutLabel: String {
        switch autoLockTimeout {
        case 0: return "Immediately"
        case 60: return "1 minute"
        case 300: return "5 minutes"
        case 900: return "15 minutes"
        case 1800: return "30 minutes"
        case 3600: return "1 hour"
        default: return "5 minutes"
        }
    }

    init() {
        if requireAuthentication {
            // Require auth on cold launch
            isAuthenticated = false
            hasExited = true
            showAuthentication = true
        } else {
            isAuthenticated = true
        }
    }

    // MARK: - Authentication

    func authenticate(reason: String = "Access your health data") async throws {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            guard success else { throw XAuthenticationError.cancelled }
        } else {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            guard success else { throw XAuthenticationError.cancelled }
        }

        isAuthenticated = true
        showAuthentication = false
        lastActivityTime = Date()
        hasExited = false
    }

    func authenticateWithPasscode(reason: String = "Access your health data") async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw XAuthenticationError.passcodeNotSet
        }
        let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        guard success else { throw XAuthenticationError.cancelled }
        
        isAuthenticated = true
        showAuthentication = false
        lastActivityTime = Date()
        hasExited = false
    }

    func recordActivity() {
        if isAuthenticated { lastActivityTime = Date() }
    }

    // MARK: - Scene Phase

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if requireAuthentication && hasExited {
                showAuthentication = true
            }
        case .background:
            // Only lock when auth is required; don't lock on .inactive to avoid
            // triggering on Notification Center / Control Center pulls.
            if requireAuthentication {
                isAuthenticated = false
                hasExited = true
            }
        case .inactive:
            break
        @unknown default: break
        }
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
    @Environment(\.authenticationManager) var authManager
    var reason: String = "Access your health data"

    func body(content: Content) -> some View {
        content
            .onAppear {
                authManager.recordActivity()
            }
    }
}

struct AuthenticationView: View {
    @Environment(\.authenticationManager) var authManager
    @Environment(\.dismiss) var dismiss

    var reason: String
    @State private var showFallback = false
    @State private var errorMessage: String?
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Theme.Gradients.brand
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: authManager.biometricType().iconName)
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

                Text("Authenticate to continue")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                Text(reason)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 40)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.error)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                }

                if isAuthenticating {
                    ProgressView()
                        .tint(.white)
                } else {
                    if authManager.biometricType() != .none {
                        Button(action: { Task { await authenticate() } }) {
                            Text("Authenticate with \(authManager.biometricType().description)")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.Colors.accent.opacity(0.8))
                                .cornerRadius(16)
                                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 4)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }

                    if showFallback || authManager.biometricType() == .none {
                        Button {
                            Task { await authenticateWithPasscode() }
                        } label: {
                            Text(authManager.biometricType() == .none ? "Use Passcode" : "Use passcode instead")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 8)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .task { await authenticate() }
    }

    private func authenticate() async {
        isAuthenticating = true
        errorMessage = nil
        do {
            try await authManager.authenticate(reason: reason)
            dismiss()
        } catch XAuthenticationError.cancelled {
            errorMessage = "Authentication was cancelled"
            showFallback = authManager.allowPasscodeFallback
        } catch {
            errorMessage = "Authentication failed"
            showFallback = authManager.allowPasscodeFallback
        }
        isAuthenticating = false
    }

    private func authenticateWithPasscode() async {
        isAuthenticating = true
        errorMessage = nil
        do {
            try await authManager.authenticateWithPasscode(reason: "Enter your passcode")
            dismiss()
        } catch {
            errorMessage = "Authentication failed"
        }
        isAuthenticating = false
    }
}

#Preview {
    AuthenticationView(reason: "Access your health data")
        .environment(\.authenticationManager, AuthenticationManager.shared)
}

// MARK: - Environment Key

struct AuthenticationManagerKey: EnvironmentKey {
    nonisolated static let defaultValue: AuthenticationManager = {
        MainActor.assumeIsolated { AuthenticationManager.shared }
    }()
}

extension EnvironmentValues {
    var authenticationManager: AuthenticationManager {
        get { self[AuthenticationManagerKey.self] }
        set { self[AuthenticationManagerKey.self] = newValue }
    }
}
