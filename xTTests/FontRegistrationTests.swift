//
//  FontRegistrationTests.swift
//  xTTests
//
//  Guards element F1/F2: every `Theme.FontFace` must resolve to a real, bundled
//  face. Catches a wrong PostScript name (the classic trap is IBM Plex Mono Medium,
//  whose PS name is `IBMPlexMono-Medm`, not `-Medium`), a missing `UIAppFonts`
//  entry, or a font file that never made it into the target.
//
//  Runs in the host app process (TEST_HOST = xT.app), so the app's UIAppFonts are
//  registered and `UIFont(name:)` resolves exactly as it does at runtime.
//

import XCTest
import UIKit
@testable import xT

final class FontRegistrationTests: XCTestCase {

    func testEveryFaceResolvesToARealFont() {
        for face in Theme.FontFace.allCases {
            let name = face.postScriptName
            let font = UIFont(name: name, size: 17)
            XCTAssertNotNil(
                font,
                "Font '\(name)' did not resolve. Is the .ttf bundled and listed in UIAppFonts?"
            )
            if let font {
                XCTAssertEqual(
                    font.fontName.caseInsensitiveCompare(name), .orderedSame,
                    "Resolved font name '\(font.fontName)' does not match requested PostScript name '\(name)'."
                )
            }
        }
    }
}
