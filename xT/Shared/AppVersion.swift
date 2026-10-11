//
//  AppVersion.swift
//  xT
//
//  Bundle-derived version string (element F8). Replaces the hard-coded "0.9" in the
//  Settings About row. Reads `CFBundleShortVersionString` + `CFBundleVersion` so the
//  displayed version always tracks the build, never a literal that drifts.
//

import Foundation

enum AppVersion {
    /// Marketing version, e.g. "1.0". Falls back to "—" if the key is missing.
    static var short: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// Build number, e.g. "42".
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// "VERSION 1.0 (42)" — the About-row trailing value (uppercased by the mono label).
    static var versionLine: String {
        "VERSION \(short) (\(build))"
    }

    /// "ISOCLINE · VERSION 1.0 (42)" — the flush Settings footer line (element ST10).
    static var footerLine: String {
        "ISOCLINE · \(versionLine)"
    }
}
