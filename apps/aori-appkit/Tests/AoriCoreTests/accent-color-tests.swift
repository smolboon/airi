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

    func testMetaBallsMatchTheSoloLVLParameters() {
        XCTAssertEqual(MetaBalls.blobCount, 12)
        XCTAssertEqual(MetaBalls.minRadius, 20)
        XCTAssertEqual(MetaBalls.maxRadius, 60)
        XCTAssertEqual(MetaBalls.driftSpeed, 0.25)
        XCTAssertEqual(MetaBalls.maxSpeed, 0.75)
        XCTAssertEqual(MetaBalls.edgeMargin, 50)
        XCTAssertEqual(MetaBalls.clumpFactor, 0)
        XCTAssertEqual(MetaBalls.glowGlobalAlpha, 0.70)
        XCTAssertEqual(MetaBalls.glowHexAlpha, 0x90)
        XCTAssertEqual(MetaBalls.glowFade, 0.95)
        XCTAssertEqual(MetaBalls.coreRadiusScale, 0.40)
        XCTAssertEqual(MetaBalls.coreGlobalAlpha, 0.50)

        let field = MetaBalls(width: 640, height: 360, seed: 7)
        XCTAssertEqual(field.blobs.count, 12)
        for blob in field.blobs {
            XCTAssertGreaterThanOrEqual(blob.radius, MetaBalls.minRadius)
            XCTAssertLessThanOrEqual(blob.radius, MetaBalls.maxRadius)
            XCTAssertEqual(MetaBalls.speed(blob), MetaBalls.driftSpeed, accuracy: 0.000_001)
        }
    }

    func testBlobsDriftEaseBackAndStayUnderTheSpeedCap() {
        var field = MetaBalls(
            width: 400,
            height: 300,
            blobs: [
                MetaBalls.Blob(x: 10, y: 150, vx: -0.25, vy: 0, radius: 30),
            ]
        )
        XCTAssertTrue(field.step(reduceMotion: false, visible: true))
        XCTAssertGreaterThan(field.blobs[0].vx, -0.25)
        XCTAssertLessThanOrEqual(MetaBalls.speed(field.blobs[0]), MetaBalls.maxSpeed)

        var fast = MetaBalls(
            width: 400,
            height: 300,
            blobs: [
                MetaBalls.Blob(x: 200, y: 150, vx: 4, vy: 0, radius: 30),
            ]
        )
        fast.step(reduceMotion: false, visible: true)
        XCTAssertEqual(MetaBalls.speed(fast.blobs[0]), MetaBalls.maxSpeed, accuracy: 0.000_001)
        XCTAssertGreaterThan(fast.blobs[0].x, 200)
    }

    func testAnimationStopsWhenHiddenOrReduceMotionIsOn() {
        let blob = MetaBalls.Blob(x: 200, y: 150, vx: 0.25, vy: 0.1, radius: 40)
        var still = MetaBalls(width: 400, height: 300, blobs: [blob])
        var hidden = still
        XCTAssertFalse(still.step(reduceMotion: true, visible: true))
        XCTAssertFalse(hidden.step(reduceMotion: false, visible: false))
        XCTAssertEqual(still.blobs, [blob])
        XCTAssertEqual(hidden.blobs, [blob])

        var moving = MetaBalls(width: 400, height: 300, blobs: [blob])
        XCTAssertTrue(moving.step(reduceMotion: false, visible: true))
        XCTAssertNotEqual(moving.blobs[0].x, blob.x)
    }

    func testFrameUsesBlackYellowLayersAndStaysReadable() throws {
        let field = MetaBalls(
            width: 180,
            height: 120,
            blobs: [
                MetaBalls.Blob(x: 90, y: 60, vx: 0, vy: 0, radius: 40),
            ]
        )
        let pixels = field.pixels(width: 180, height: 120)
        XCTAssertEqual(Array(pixels[0..<4]), [0, 0, 0, 255])

        let center = (60 * 180 + 90) * 4
        XCTAssertGreaterThan(pixels[center], pixels[center + 2])
        XCTAssertGreaterThan(pixels[center], 80)
        XCTAssertEqual(Int(pixels[center + 2]), 0)

        let scrim = MetaBalls.scrimmed(
            red: Int(pixels[center]),
            green: Int(pixels[center + 1]),
            blue: Int(pixels[center + 2])
        )
        let ratio = AccentColor.contrastRatio(
            foregroundRed: 245,
            foregroundGreen: 245,
            foregroundBlue: 245,
            backgroundRed: scrim.red,
            backgroundGreen: scrim.green,
            backgroundBlue: scrim.blue
        )
        XCTAssertGreaterThanOrEqual(ratio, AccentColor.minimumContrast)

        let started = Date()
        var animated = MetaBalls(width: 180, height: 120, seed: 3)
        for _ in 0..<30 {
            animated.step(reduceMotion: false, visible: true)
        }
        let frame = animated.pixels(width: 180, height: 120)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
        XCTAssertEqual(frame.count, 180 * 120 * 4)
        let png = MetaBalls.png(pixels: frame, width: 180, height: 120)
        XCTAssertEqual(Array(png?.prefix(8) ?? Data()), [137, 80, 78, 71, 13, 10, 26, 10])
        if let path = ProcessInfo.processInfo.environment["AORI_METABALLS_PNG"], let png {
            try png.write(to: URL(fileURLWithPath: path))
        }
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
            "AccentField",
            "AccentWashView",
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
