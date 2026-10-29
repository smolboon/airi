import Foundation

/// A slow three-layer wash behind Aori windows.
///
/// NOTICE:
/// The wash is local because the named SoloLVL repository is missing.
/// github.com/smolboon/SoloLVL-rs returns not found.
/// https://github.com/smolboon/SoloLVL-rs
/// Remove this note when that repository publishes a background source file.
public enum AccentField {
    public static let layerCount = 3
    public static let baseRed = 20
    public static let baseGreen = 20
    public static let baseBlue = 20
    /// Peak coverage of one layer. Higher values make the wash too light for text.
    public static let peakAlpha = 0.22

    public struct Frame: Equatable, Sendable {
        public var pixels: [UInt8]
        public var width: Int
        public var height: Int
        public var advances: Bool
    }

    public static func frame(
        width: Int,
        height: Int,
        time: Double,
        reduceMotion: Bool,
        visible: Bool
    ) -> Frame {
        let advances = visible && !reduceMotion
        let clock = advances ? time : 0
        var pixels = [UInt8](repeating: 0, count: max(0, width) * max(0, height) * 4)
        guard width > 1, height > 1 else {
            return Frame(pixels: pixels, width: width, height: height, advances: false)
        }
        let layers = layerCenters(time: clock)
        for y in 0..<height {
            for x in 0..<width {
                var red = Double(baseRed)
                var green = Double(baseGreen)
                var blue = Double(baseBlue)
                let u = Double(x) / Double(width - 1)
                let v = Double(y) / Double(height - 1)
                for layer in layers {
                    let dx = u - layer.x
                    let dy = v - layer.y
                    let distance = (dx * dx + dy * dy).squareRoot()
                    let falloff = max(0, 1 - distance / layer.radius)
                    let alpha = peakAlpha * falloff * falloff
                    red = red * (1 - alpha) + Double(AccentColor.red) * alpha
                    green = green * (1 - alpha) + Double(AccentColor.green) * alpha
                    blue = blue * (1 - alpha) + Double(AccentColor.blue) * alpha
                }
                let offset = (y * width + x) * 4
                pixels[offset] = byte(red)
                pixels[offset + 1] = byte(green)
                pixels[offset + 2] = byte(blue)
                pixels[offset + 3] = 255
            }
        }
        return Frame(pixels: pixels, width: width, height: height, advances: advances)
    }

    public static func brightest(in pixels: [UInt8]) -> (red: Int, green: Int, blue: Int) {
        var best = (red: baseRed, green: baseGreen, blue: baseBlue)
        var bestLuminance = AccentColor.relativeLuminance(red: best.red, green: best.green, blue: best.blue)
        var offset = 0
        while offset + 3 < pixels.count {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let luminance = AccentColor.relativeLuminance(red: red, green: green, blue: blue)
            if luminance > bestLuminance {
                bestLuminance = luminance
                best = (red, green, blue)
            }
            offset += 4
        }
        return best
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

    private struct Layer {
        var x: Double
        var y: Double
        var radius: Double
    }

    private static func layerCenters(time: Double) -> [Layer] {
        let speeds = [0.35, 0.22, 0.15]
        let phases = [0.0, 2.1, 4.2]
        return (0..<layerCount).map { index in
            let speed = speeds[index]
            let phase = phases[index]
            return Layer(
                x: 0.5 + 0.28 * sin(time * speed + phase),
                y: 0.5 + 0.22 * cos(time * speed * 0.8 + phase),
                radius: 0.42
            )
        }
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(min(255, max(0, value.rounded())))
    }

    private static func u32(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]
    }

    private static func chunk(type: String, data: Data) -> Data {
        var body = Data(type.utf8)
        body.append(data)
        var result = Data(u32(UInt32(data.count)))
        result.append(body)
        result.append(contentsOf: u32(crc32(body)))
        return result
    }

    private static func crc32(_ data: Data) -> UInt32 {
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

    /// Zlib wrapper around stored deflate blocks. The wash PNG does not need a compressor.
    private static func zlibStore(_ data: Data) -> Data {
        var output = Data([0x78, 0x01])
        let bytes = [UInt8](data)
        var offset = 0
        while offset < bytes.count || bytes.isEmpty && offset == 0 {
            let end = min(offset + 65_535, bytes.count)
            let last = end == bytes.count
            output.append(last ? 1 : 0)
            let length = UInt16(end - offset)
            output.append(UInt8(length & 0xff))
            output.append(UInt8((length >> 8) & 0xff))
            let complement = ~length
            output.append(UInt8(complement & 0xff))
            output.append(UInt8((complement >> 8) & 0xff))
            if end > offset {
                output.append(contentsOf: bytes[offset..<end])
            }
            offset = end
            if bytes.isEmpty {
                break
            }
        }
        let checksum = adler32(bytes)
        output.append(contentsOf: u32(checksum))
        return output
    }

    private static func adler32(_ bytes: [UInt8]) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in bytes {
            a = (a + UInt32(byte)) % 65_521
            b = (b + a) % 65_521
        }
        return (b << 16) | a
    }
}
