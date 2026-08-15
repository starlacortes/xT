import Foundation
import LocalAuthentication
import SwiftUI
import Observation

public enum XAuthenticationError: Error {
    case cancelled
    case failed(Error)
    case passcodeNotSet
    case biometricNotAvailable
}

// MARK: - AutoLockTimeout

/// How long the app may stay in the background before it re-locks.
///
/// The raw value is the grace period in seconds, which is what gets persisted
/// to `UserDefaults` — so this enum is source-compatible with the raw
/// `TimeInterval` the settings screen has always written.
enum AutoLockTimeout: TimeInterval, CaseIterable, Identifiable, Sendable {
    case immediately    = 0
    case oneMinute      = 60
    case fiveMinutes    = 300
    case fifteenMinutes = 900
    case thirtyMinutes  = 1800
    case oneHour        = 3600

    /// Applied when nothing has been stored yet, or when a stored value doesn't
    /// match any supported option (e.g. written by an older build).
    static let fallback: AutoLockTimeout = .fiveMinutes

    var id: TimeInterval { rawValue }

    var label: String {
        switch self {
        case .immediately:    return "Immediately"
        case .oneMinute:      return "1 minute"
        case .fiveMinutes:    return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes:  return "30 minutes"
        case .oneHour:        return "1 hour"
        }
    }

    /// Maps a persisted interval onto a supported option, falling back to
    /// ``fallback`` for values this build doesn't recognise.
    init(storedValue: TimeInterval) {
        self = AutoLockTimeout(rawValue: storedValue) ?? .fallback
    }
}

// MARK: - AuthenticationManager

@MainActor
@Observable
class AuthenticationManager {
    static let shared = AuthenticationManager()

    var isAuthenticated = false
    var showAuthentication = false

    /// The moment the app most recently entered the background, or `nil` while
    /// it is in the foreground. Drives the auto-lock grace period.
    @ObservationIgnored
    private var backgroundedAt: Date?

    private enum Keys {
        static let requireAuthentication = "requireAuthentication"
        static let autoLockTimeout = "autoLockTimeout"
        static let allowPasscodeFallback = "allowPasscodeFallback"
    }

    var requireAuthentication: Bool = UserDefaults.standard.bool(forKey: Keys.requireAuthentication) {
        didSet {
            UserDefaults.standard.set(requireAuthentication, forKey: Keys.requireAuthentication)
            backgroundedAt = nil
            if !requireAuthentication {
                isAuthenticated = true
                showAuthentication = false
            } else {
                isAuthenticated = false
                showAuthentication = true
            }
        }
    }

    var autoLockTimeout: TimeInterval = UserDefaults.standard.object(forKey: Keys.autoLockTimeout) as? Double ?? AutoLockTimeout.fallback.rawValue

    /// Type-safe view of ``autoLockTimeout`` for pickers and labels.
    var autoLockTimeoutOption: AutoLockTimeout {
        get { AutoLockTimeout(storedValue: autoLockTimeout) }
        set { autoLockTimeout = newValue.rawValue }
    }

    var allowPasscodeFallback: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.allowPasscodeFallback) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.allowPasscodeFallback) }
    }

    var timeoutLabel: String { autoLockTimeoutOption.label }

    init() {
        if requireAuthentication {
            // Require auth on cold launch
            isAuthenticated = false
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
        } else if allowPasscodeFallback {
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                throw XAuthenticationError.passcodeNotSet
            }
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            guard success else { throw XAuthenticationError.cancelled }
        } else {
            throw XAuthenticationError.biometricNotAvailable
        }

        isAuthenticated = true
        showAuthentication = false
        backgroundedAt = nil
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
        backgroundedAt = nil
    }

    @available(*, deprecated, message: "Auto-lock is driven by time spent in the background; this call is a no-op and can be removed.")
    func recordActivity() {}

    // MARK: - Auto-Lock

    /// What returning to the foreground should do to the lock state.
    enum ForegroundLockDecision: Equatable {
        /// Stay unlocked — either lock is off, or the grace period hasn't elapsed.
        case stayUnlocked
        /// Already locked; make sure the authentication cover is on screen.
        case presentExistingLock
        /// Was unlocked, but the app spent longer than the timeout in the background.
        case lock
    }

    /// Pure auto-lock policy, split out so it can be exercised without a UI.
    ///
    /// The app locks after spending `awayDuration` seconds in the background,
    /// rather than after a fixed period of "idleness" — a quick hop to another
    /// app no longer forces a re-authentication, and there is no polling loop.
    ///
    /// - Parameter awayDuration: seconds spent in the background, or `nil` when
    ///   the app hasn't been backgrounded since the last unlock (e.g. cold launch).
    static func foregroundLockDecision(
        requireAuthentication: Bool,
        isAuthenticated: Bool,
        awayDuration: TimeInterval?,
        timeout: TimeInterval
    ) -> ForegroundLockDecision {
        guard requireAuthentication else { return .stayUnlocked }
        guard isAuthenticated else { return .presentExistingLock }
        guard let awayDuration, awayDuration >= timeout else { return .stayUnlocked }
        return .lock
    }

    /// Locks the app and presents the authentication cover.
    private func lock() {
        isAuthenticated = false
        showAuthentication = true
    }

    // MARK: - Scene Phase

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            let awayDuration = backgroundedAt.map { Date().timeIntervalSince($0) }
            backgroundedAt = nil
            switch Self.foregroundLockDecision(
                requireAuthentication: requireAuthentication,
                isAuthenticated: isAuthenticated,
                awayDuration: awayDuration,
                timeout: autoLockTimeout
            ) {
            case .stayUnlocked:        break
            case .presentExistingLock: showAuthentication = true
            case .lock:                lock()
            }
        case .background:
            // Stamp when we left so the grace period can be measured on return.
            // Keep the earliest stamp if `.background` arrives more than once,
            // and don't act on `.inactive` — that also fires for the app
            // switcher and Notification Center / Control Center pulls.
            if requireAuthentication, backgroundedAt == nil {
                backgroundedAt = Date()
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
        case .none:    return "None"
        case .touchID: return "touchid"
        case .faceID:  return "faceid"
        case .opticID: return "opticid"
        }
    }
}

// MARK: - Authentication View

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

                    Image(systemName: "key")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
                
                

                if isAuthenticating {
                    ProgressView()
                        .tint(.white)
                } else {
                    if authManager.biometricType() != .none {
                        Button(action: { Task { await authenticate() } }) {
                            Text("Unlock with \(authManager.biometricType().description)")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.Colors.accent.opacity(0.8))
                                .cornerRadius(16)
                                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 12, x: 0, y: 4)
                        }
                        .frame(width: 200)
                        
                        
                    }

                    if showFallback || authManager.biometricType() == .none {
                        Button {
                            Task { await authenticateWithPasscode() }
                        } label: {
                            Text(authManager.biometricType() == .none ? "Use Passcode" : "Use passcode instead")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                    }
                }

                Spacer()
            }
            
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
            errorMessage = "Authentication cancelled"
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

#if DEBUG
#Preview {
    AuthenticationView(reason: "Access your health data")
        .environment(\.authenticationManager, AuthenticationManager.shared)
}
#endif

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
