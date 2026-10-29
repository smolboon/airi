import Foundation

/// SoloLVL `MetaBalls`. Twelve blobs drift on a black canvas.
/// The color is `AccentColor`. `clumpFactor` is 0, so the blobs only drift.
public struct MetaBalls: Equatable, Sendable {
    public static let blobCount = 12
    public static let minRadius = 20.0
    public static let maxRadius = 60.0
    public static let driftSpeed = 0.25
    public static let maxSpeed = 0.75
    public static let edgeMargin = 50.0
    public static let clumpFactor = 0.0
    /// Pull toward the center, per pixel, per frame. Zero clump skips this.
    public static let clumpGain = 0.001
    /// Pull back into the page, per pixel inside the edge margin, per frame.
    public static let edgeEase = 0.02
    public static let glowGlobalAlpha = 0.70
    /// CSS `color + "90"`. 0x90 is the hex alpha byte.
    public static let glowHexAlpha = 0x90
    public static let glowFade = 0.95
    public static let coreRadiusScale = 0.40
    public static let coreGlobalAlpha = 0.50
    /// Black cover over the field where text sits. Light text stays above WCAG AA.
    public static let textScrimAlpha = 0.84

    public struct Blob: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var vx: Double
        public var vy: Double
        public var radius: Double
    }

    public private(set) var blobs: [Blob]
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double, seed: UInt64) {
        self.width = width
        self.height = height
        var random = SplitMix(seed: seed == 0 ? 1 : seed)
        var made: [Blob] = []
        made.reserveCapacity(Self.blobCount)
        for _ in 0..<Self.blobCount {
            let radius = Self.minRadius + random.nextUnit() * (Self.maxRadius - Self.minRadius)
            let spanX = max(1, width - radius * 2)
            let spanY = max(1, height - radius * 2)
            let angle = random.nextUnit() * Double.pi * 2
            made.append(Blob(
                x: radius + random.nextUnit() * spanX,
                y: radius + random.nextUnit() * spanY,
                vx: cos(angle) * Self.driftSpeed,
                vy: sin(angle) * Self.driftSpeed,
                radius: radius
            ))
        }
        blobs = made
    }

    public init(width: Double, height: Double, blobs: [Blob]) {
        self.width = width
        self.height = height
        self.blobs = blobs
    }

    public mutating func resize(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// Returns true when this call moved the blobs.
    @discardableResult
    public mutating func step(reduceMotion: Bool, visible: Bool) -> Bool {
        guard visible, !reduceMotion else {
            return false
        }
        for index in blobs.indices {
            var blob = blobs[index]
            if Self.clumpFactor != 0 {
                blob.vx += (width / 2 - blob.x) * Self.clumpGain * Self.clumpFactor
                blob.vy += (height / 2 - blob.y) * Self.clumpGain * Self.clumpFactor
            }
            ease(&blob)
            cap(&blob)
            blob.x += blob.vx
            blob.y += blob.vy
            blobs[index] = blob
        }
        return true
    }

    public func pixels(width: Int, height: Int) -> [UInt8] {
        guard width > 1, height > 1 else {
            return []
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in stride(from: 3, to: pixels.count, by: 4) {
            pixels[index] = 255
        }
        let scaleX = Double(width) / max(self.width, 1)
        let scaleY = Double(height) / max(self.height, 1)
        for blob in blobs {
            paint(blob, into: &pixels, width: width, height: height, scaleX: scaleX, scaleY: scaleY)
        }
        return pixels
    }

    public static func png(pixels: [UInt8], width: Int, height: Int) -> Data? {
        guard width > 0, height > 0, pixels.count == width * height * 4 else {
            return nil
        }
        var raw = Data()
        raw.reserveCapacity((width * 4 + 1) * height)
        for y in 0..<height {
            raw.append(0)
            let start = y * width * 4
            raw.append(contentsOf: pixels[start..<(start + width * 4)])
        }
        let compressed = zlibStore(raw)
        var data = Data([137, 80, 78, 71, 13, 10, 26, 10])
        var ihdr = Data()
        ihdr.append(contentsOf: u32(UInt32(width)))
        ihdr.append(contentsOf: u32(UInt32(height)))
        ihdr.append(contentsOf: [8, 6, 0, 0, 0])
        data.append(contentsOf: chunk(type: "IHDR", data: ihdr))
        data.append(contentsOf: chunk(type: "IDAT", data: compressed))
        data.append(contentsOf: chunk(type: "IEND", data: Data()))
        return data
    }

    public static func speed(_ blob: Blob) -> Double {
        (blob.vx * blob.vx + blob.vy * blob.vy).squareRoot()
    }

    /// Light text over a black scrim on top of a field pixel.
    public static func scrimmed(
        red: Int,
        green: Int,
        blue: Int
    ) -> (red: Int, green: Int, blue: Int) {
        let keep = 1 - textScrimAlpha
        return (
            Int((Double(red) * keep).rounded()),
            Int((Double(green) * keep).rounded()),
            Int((Double(blue) * keep).rounded())
        )
    }

    private func ease(_ blob: inout Blob) {
        if blob.x < Self.edgeMargin {
            blob.vx += (Self.edgeMargin - blob.x) * Self.edgeEase
        }
        if blob.x > width - Self.edgeMargin {
            blob.vx -= (blob.x - (width - Self.edgeMargin)) * Self.edgeEase
        }
        if blob.y < Self.edgeMargin {
            blob.vy += (Self.edgeMargin - blob.y) * Self.edgeEase
        }
        if blob.y > height - Self.edgeMargin {
            blob.vy -= (blob.y - (height - Self.edgeMargin)) * Self.edgeEase
        }
    }

    private func cap(_ blob: inout Blob) {
        let speed = Self.speed(blob)
        guard speed > Self.maxSpeed, speed > 0 else {
            return
        }
        let scale = Self.maxSpeed / speed
        blob.vx *= scale
        blob.vy *= scale
    }

    private func paint(
        _ blob: Blob,
        into pixels: inout [UInt8],
        width: Int,
        height: Int,
        scaleX: Double,
        scaleY: Double
    ) {
        let centerX = blob.x * scaleX
        let centerY = blob.y * scaleY
        let radius = blob.radius * min(scaleX, scaleY)
        let glowRadius = max(radius, 1)
        let coreRadius = max(radius * Self.coreRadiusScale, 1)
        let left = max(0, Int((centerX - glowRadius).rounded(.down)))
        let right = min(width - 1, Int((centerX + glowRadius).rounded(.up)))
        let top = max(0, Int((centerY - glowRadius).rounded(.down)))
        let bottom = min(height - 1, Int((centerY + glowRadius).rounded(.up)))
        let glowAlpha = Double(Self.glowHexAlpha) / 255 * Self.glowGlobalAlpha
        guard right >= left, bottom >= top else {
            return
        }
        for y in top...bottom {
            for x in left...right {
                let dx = Double(x) - centerX
                let dy = Double(y) - centerY
                let distance = (dx * dx + dy * dy).squareRoot()
                let offset = (y * width + x) * 4
                if distance <= glowRadius {
                    let t = distance / glowRadius
                    if t < Self.glowFade {
                        let alpha = (1 - t / Self.glowFade) * glowAlpha
                        over(&pixels, offset: offset, alpha: alpha)
                    }
                }
                if distance <= coreRadius {
                    let t = distance / coreRadius
                    let alpha = (1 - t) * Self.coreGlobalAlpha
                    over(&pixels, offset: offset, alpha: alpha)
                }
            }
        }
    }

    private func over(_ pixels: inout [UInt8], offset: Int, alpha: Double) {
        let keep = 1 - alpha
        pixels[offset] = UInt8(min(255, (Double(AccentColor.red) * alpha + Double(pixels[offset]) * keep).rounded()))
        pixels[offset + 1] = UInt8(min(255, (Double(AccentColor.green) * alpha + Double(pixels[offset + 1]) * keep).rounded()))
        pixels[offset + 2] = UInt8(min(255, (Double(AccentColor.blue) * alpha + Double(pixels[offset + 2]) * keep).rounded()))
    }
}

private struct SplitMix {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUnit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

private func u32(_ value: UInt32) -> [UInt8] {
    [
        UInt8((value >> 24) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8(value & 0xff),
    ]
}

private func chunk(type: String, data: Data) -> Data {
    var body = Data(type.utf8)
    body.append(data)
    var result = Data(u32(UInt32(data.count)))
    result.append(body)
    result.append(contentsOf: u32(crc32(body)))
    return result
}

private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xffff_ffff
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            let mask = 0 &- (crc & 1)
            crc = (crc >> 1) ^ (0xedb8_8320 & mask)
        }
    }
    return crc ^ 0xffff_ffff
}

private func zlibStore(_ data: Data) -> Data {
    var output = Data([0x78, 0x01])
    let bytes = [UInt8](data)
    var offset = 0
    while offset < bytes.count {
        let end = min(offset + 65_535, bytes.count)
        let last = end == bytes.count
        output.append(last ? 1 : 0)
        let length = UInt16(end - offset)
        output.append(UInt8(length & 0xff))
        output.append(UInt8((length >> 8) & 0xff))
        let complement = ~length
        output.append(UInt8(complement & 0xff))
        output.append(UInt8((complement >> 8) & 0xff))
        output.append(contentsOf: bytes[offset..<end])
        offset = end
    }
    output.append(contentsOf: u32(adler32(bytes)))
    return output
}

private func adler32(_ bytes: [UInt8]) -> UInt32 {
    var a: UInt32 = 1
    var b: UInt32 = 0
    for byte in bytes {
        a = (a + UInt32(byte)) % 65_521
        b = (b + a) % 65_521
    }
    return (b << 16) | a
}
