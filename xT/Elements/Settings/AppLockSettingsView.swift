//
//  AppLockSettingsView.swift
//  xT
//
//  Dedicated app lock and security settings (ST6). Now a pushed `Form` on
//  paper: its own nested `NavigationStack` is gone (it was pushed anyway),
//  and settings persist **on change** — swiping back no longer discards the
//  lock configuration, which made "Done" unnecessary.
//

import SwiftUI

struct AppLockSettingsView: View {
    @Environment(\.authenticationManager) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var requireAuth: Bool = false
    @State private var selectedTimeout: TimeInterval = 300
    @State private var allowPasscodeFallback: Bool = true
    @State private var showTestBiometric = false
    /// Cached biometry kind — `LAContext.canEvaluatePolicy` used to run on every
    /// render through the old computed property; it is read once on appear instead.
    @State private var cachedBiometricType: BiometricType = .none

    private let timeoutOptions: [(String, TimeInterval)] = [
        ("Immediately", 0),
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]

    private var biometricType: BiometricType { cachedBiometricType }

    private var hasFaceID: Bool {
        biometricType == .faceID
    }

    var body: some View {
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
                            persist()
                        }) {
                            HStack {
                                Text(option.0)
                                    .font(Theme.Fonts.footnote)
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                Spacer()

                                if selectedTimeout == option.1 {
                                    Image(systemName: "checkmark")
                                        .font(Theme.Fonts.footnote)
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
        .paperList()
        .navigationTitle("App Lock")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            requireAuth = authManager.requireAuthentication
            selectedTimeout = authManager.autoLockTimeout
            allowPasscodeFallback = authManager.allowPasscodeFallback
            cachedBiometricType = authManager.biometricType()
        }
        .onChange(of: requireAuth) { _, _ in persist() }
        .onChange(of: allowPasscodeFallback) { _, _ in persist() }
        .fullScreenCover(isPresented: $showTestBiometric) {
            TestBiometricSheet()
        }
    }

    // MARK: - Face ID Section

    private var faceIDSection: some View {
        Section {
            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.13))
                        .frame(width: 64, height: 64)
                    Image(systemName: "faceid")
                        .font(Theme.Fonts.icon)
                        .imageScale(.large)
                        .foregroundStyle(Theme.Colors.accent)
                }

                Text("Require Face ID")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Use Face ID to quickly unlock xT. You can also set up Face ID in the Settings app if you haven't already.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Require Face ID", isOn: $requireAuth)
                    .tint(Theme.Colors.accent)

                Toggle("Allow passcode fallback", isOn: $allowPasscodeFallback)
                    .tint(Theme.Colors.accent)

                Button(action: { showTestBiometric = true }) {
                    Label("Test Face ID", systemImage: "faceid")
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
    }

    // MARK: - Other Biometrics Section

    private var biometricsSection: some View {
        Section {
            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.13))
                        .frame(width: 64, height: 64)
                    Image(systemName: biometricType.iconName)
                        .font(Theme.Fonts.icon)
                        .imageScale(.large)
                        .foregroundStyle(Theme.Colors.accent)
                }

                Text("Require \(biometricType.description)")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Use \(biometricType.description.lowercased()) to unlock xT. You can also set up \(biometricType.description) in the Settings app if you haven't already.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Require \(biometricType.description)", isOn: $requireAuth)
                    .tint(Theme.Colors.accent)

                Toggle("Allow passcode fallback", isOn: $allowPasscodeFallback)
                    .tint(Theme.Colors.accent)

                Button(action: { showTestBiometric = true }) {
                    Label("Test \(biometricType.description)", systemImage: biometricType.iconName)
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
    }

    // MARK: - No Biometrics Section

    private var noBiometricsSection: some View {
        Section {
            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.13))
                        .frame(width: 64, height: 64)
                    Image(systemName: "hand.raised.fill")
                        .font(Theme.Fonts.icon)
                        .imageScale(.large)
                        .foregroundStyle(Theme.Colors.accent)
                }

                Text("Biometrics Unavailable")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Your device doesn't have Face ID or Touch ID set up. You can set up Face ID or Touch ID in Settings to unlock xT with biometrics, or use the passcode option below.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Open Settings", systemImage: "gearshape")
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                Toggle("Require passcode instead", isOn: $requireAuth)
                    .tint(Theme.Colors.accent)
            }
            .padding(.vertical, Theme.Spacing.xxs)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tiny) {
            Text("Privacy & Security")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("App lock helps protect your sensitive health data by requiring authentication when opening xT or after a period of inactivity. Your biometric data is never stored on our servers or shared with Apple.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }

    // MARK: - Persistence

    /// Persist on every change (ST6): the screen is pushed, so swiping back must
    /// not discard what the user toggled.
    private func persist() {
        authManager.requireAuthentication = requireAuth
        authManager.autoLockTimeout = selectedTimeout
        authManager.allowPasscodeFallback = allowPasscodeFallback
    }
}

// MARK: - Test Biometric Sheet

struct TestBiometricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authenticationManager) private var authManager
    @State private var result: TestResult?

    var body: some View {
        ZStack {
            Theme.Colors.appBackground.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xxl) {
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
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: authManager.biometricType().iconName)
                .font(Theme.Fonts.icon)
                .imageScale(.large)
                .foregroundStyle(Theme.Colors.accent)
            Text("Test your biometric authentication")
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            ProgressView().tint(Theme.Colors.accent)
        }
    }

    private var successView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(Theme.Fonts.icon)
                .imageScale(.large)
                .foregroundStyle(Theme.Colors.success)
            Text("Biometrics Enabled!")
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Biometric authentication is working correctly.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            ActionPill(title: "Done") { dismiss() }
                .padding(.horizontal, Theme.Spacing.Gutter.screen)
                .padding(.top, Theme.Spacing.lg)
        }
        .transition(.opacity)
        .animation(.easeIn, value: result)
    }

    private var failureView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "xmark.circle.fill")
                .font(Theme.Fonts.icon)
                .imageScale(.large)
                .foregroundStyle(Theme.Colors.warning)
            Text("Authentication failed")
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            ActionPill(title: "Try Again") { Task { await testAgain() } }
                .padding(.horizontal, Theme.Spacing.Gutter.screen)
                .padding(.top, Theme.Spacing.lg)
        }
        .transition(.opacity)
        .animation(.easeIn, value: result)
    }

    private var cancelledView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "xmark")
                .font(Theme.Fonts.icon)
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("Test Cancelled")
                .font(Theme.Fonts.serifTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            ActionPill(title: "Done") { dismiss() }
                .padding(.horizontal, Theme.Spacing.Gutter.screen)
                .padding(.top, Theme.Spacing.lg)
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

#if DEBUG
#Preview {
    NavigationStack {
        AppLockSettingsView()
            .environment(\.authenticationManager, AuthenticationManager.shared)
    }
}
#endif
