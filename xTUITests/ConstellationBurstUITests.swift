//  ConstellationBurstUITests.swift
//  xTUITests
//
//  UI smoke test for the playful constellation tap feedback on the Time tab:
//  taps the 3D starfield body three times in quick succession (so the second
//  and third taps "poke"-flare the still-alive bursts) and captures frames
//  during the ~1.2 s burst window. Assertions only cover crash-free
//  navigation and rendering — the screenshots are the real artifact, saved
//  to /tmp for eyeballing and attached to the test result.

import XCTest

final class ConstellationBurstUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testConstellationBurstOnBodyTaps() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to the Time tab and let the body model finish loading.
        app.tabBars.buttons["Time"].tap()
        sleep(3)

        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)

        // Three quick taps across the upper torso: each spawns a burst, and
        // the later taps flare the earlier ones.
        let spots: [(CGFloat, CGFloat)] = [(0.50, 0.38), (0.47, 0.40), (0.53, 0.39)]
        for (i, spot) in spots.enumerated() {
            window.coordinate(withNormalizedOffset: CGVector(dx: spot.0, dy: spot.1)).tap()
            captureFrame(named: "burst-tap\(i+1)")
            usleep(250_000)
        }

        // The twinkle/hold window, then the fade-out.
        usleep(400_000)
        captureFrame(named: "burst-hold")
        usleep(1_200_000)
        captureFrame(named: "burst-faded")

        // Tap on empty space (far right) dismisses any open card without crashing.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.25)).tap()
        sleep(1)
        captureFrame(named: "after-empty-tap")

        XCTAssertEqual(app.state, .runningForeground)
    }

    private func captureFrame(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also drop a copy on disk for quick inspection outside of the
        // .xcresult bundle (no CI in this repo — purely a debugging aid).
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/xT_\(name).png"))
    }
}
