import XCTest
@testable import AoriCore

final class AccentColorTests: XCTestCase {
    func testAccentIsBrightYellowAndInkPassesAA() {
        XCTAssertEqual(AccentColor.hex, "FFEA00")
        XCTAssertEqual(AccentColor.css, "#FFEA00")
        XCTAssertEqual(AccentColor.red, 255)
        XCTAssertEqual(AccentColor.green, 234)
        XCTAssertEqual(AccentColor.blue, 0)
        XCTAssertEqual(AccentColor.foregroundCSS, "#141414")
        XCTAssertTrue(AccentColor.inkOnFillPassesAA())
        XCTAssertFalse(AccentColor.whiteOnFillPassesAA())
    }

    func testWashUsesTheAccentAndStopsWhenStill() {
        let moving = AccentField.frame(width: 48, height: 32, time: 3.5, reduceMotion: false, visible: true)
        let later = AccentField.frame(width: 48, height: 32, time: 8.0, reduceMotion: false, visible: true)
        XCTAssertTrue(moving.advances)
        XCTAssertNotEqual(moving.pixels, later.pixels)

        let still = AccentField.frame(width: 48, height: 32, time: 3.5, reduceMotion: true, visible: true)
        let stillLater = AccentField.frame(width: 48, height: 32, time: 8.0, reduceMotion: true, visible: true)
        XCTAssertFalse(still.advances)
        XCTAssertEqual(still.pixels, stillLater.pixels)

        let hidden = AccentField.frame(width: 48, height: 32, time: 3.5, reduceMotion: false, visible: false)
        XCTAssertFalse(hidden.advances)
        XCTAssertEqual(hidden.pixels, still.pixels)
        XCTAssertEqual(AccentField.layerCount, 3)
    }

    func testWashStaysDarkEnoughForLightText() throws {
        let frame = AccentField.frame(width: 80, height: 48, time: 2.2, reduceMotion: false, visible: true)
        let bright = AccentField.brightest(in: frame.pixels)
        let ratio = AccentColor.contrastRatio(
            foregroundRed: 245,
            foregroundGreen: 245,
            foregroundBlue: 245,
            backgroundRed: bright.red,
            backgroundGreen: bright.green,
            backgroundBlue: bright.blue
        )
        XCTAssertGreaterThanOrEqual(ratio, AccentColor.minimumContrast)
        let png = AccentField.png(pixels: frame.pixels, width: frame.width, height: frame.height)
        XCTAssertEqual(Array(png?.prefix(8) ?? Data()), [137, 80, 78, 71, 13, 10, 26, 10])
        if let path = ProcessInfo.processInfo.environment["AORI_ACCENT_PNG"], let png {
            try png.write(to: URL(fileURLWithPath: path))
        }
    }

    func testWashFrameStaysInsideTheMemoryBudget() {
        let started = Date()
        let frame = AccentField.frame(width: 160, height: 90, time: 1, reduceMotion: false, visible: true)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.2)
        XCTAssertEqual(frame.pixels.count, 160 * 90 * 4)
        XCTAssertGreaterThan(RuntimeMetrics.memoryMegabytes(), 0)
        XCTAssertLessThanOrEqual(RuntimeMetrics.memoryMegabytes(), RuntimeMetrics.residentBudgetMegabytes)
    }

    func testSourcesDoNotBringCyanAccentsBack() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let banned = [
            "systemTeal",
            "systemCyan",
            "NSColor.cyan",
            "#00FFFF",
            "#00ffff",
            "#40E0D0",
            "#48D1CC",
            "#20B2AA",
            "#00CED1",
            "#5EEAD4",
            "#2DD4BF",
            "#14B8A6",
            "#06B6D4",
            "#22D3EE",
            "#67E8F9",
        ]
        let files = try sourceFiles(in: sources)
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for token in banned {
                XCTAssertFalse(
                    text.localizedCaseInsensitiveContains(token),
                    "\(file.lastPathComponent) contains \(token)"
                )
            }
        }
    }

    private func sourceFiles(in directory: URL) throws -> [URL] {
        let items = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []
        for item in items {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory) else {
                continue
            }
            if isDirectory.boolValue {
                files.append(contentsOf: try sourceFiles(in: item))
            } else if item.pathExtension == "swift" || item.pathExtension == "rs" {
                files.append(item)
            }
        }
        return files
    }
}
