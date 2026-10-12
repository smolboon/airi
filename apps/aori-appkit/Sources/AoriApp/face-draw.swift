import AppKit
import AoriCore

@_silgen_name("aori_face_add_morph")
func aoriFaceAddMorph(
    _ positions: UnsafeMutablePointer<Float>,
    _ delta: UnsafePointer<Float>,
    _ weight: Float,
    _ count: UInt
) -> Int32

@_silgen_name("aori_face_load")
func aoriFaceLoad(_ bytes: UnsafePointer<UInt8>, _ length: UInt) -> OpaquePointer?

@_silgen_name("aori_face_free")
func aoriFaceFree(_ scene: OpaquePointer?)

@_silgen_name("aori_face_render")
func aoriFaceRender(
    _ scene: OpaquePointer?,
    _ mouth: Float,
    _ blink: Float,
    _ happy: Float,
    _ sad: Float,
    _ surprised: Float,
    _ viseme: Int32,
    _ time: Float,
    _ width: UInt32,
    _ height: UInt32,
    _ outRGBA: UnsafeMutablePointer<UInt8>
) -> Int32

@_silgen_name("aori_face_project")
func aoriFaceProject(
    _ positions: UnsafePointer<Float>,
    _ vertexCount: UInt,
    _ sway: Float,
    _ originX: Float,
    _ originY: Float,
    _ scale: Float,
    _ outXY: UnsafeMutablePointer<Float>
) -> Int32

enum FaceRaster {
    static func load(_ bytes: Data) -> OpaquePointer? {
        bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count > 0 else {
                return nil
            }
            return aoriFaceLoad(base, UInt(raw.count))
        }
    }

    static func render(
        scene: OpaquePointer,
        mouth: Float,
        blink: Float,
        happy: Float,
        sad: Float,
        surprised: Float,
        viseme: Int32,
        time: Float,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        guard width > 0, height > 0, width <= 1280, height <= 1280 else {
            return nil
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let code = pixels.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return Int32(-1)
            }
            return aoriFaceRender(
                scene,
                mouth,
                blink,
                happy,
                sad,
                surprised,
                viseme,
                time,
                UInt32(width),
                UInt32(height),
                base
            )
        }
        return code == 0 ? pixels : nil
    }

    static func image(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard pixels.count == width * height * 4 else {
            return nil
        }
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    static func png(pixels: [UInt8], width: Int, height: Int) -> Data? {
        guard let image = image(pixels: pixels, width: width, height: height) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    static func draw(pixels: [UInt8], width: Int, height: Int, in bounds: NSRect) {
        guard let image = image(pixels: pixels, width: width, height: height) else {
            return
        }
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.maxY)
        context.scaleBy(x: bounds.width / CGFloat(width), y: -bounds.height / CGFloat(height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.restoreGState()
    }
}

enum FaceDraw {
    static func paint(
        meshes: [VRMMesh],
        weights: [MorphWeight],
        sway: Double,
        bounds: NSRect
    ) {
        let scale = Float(min(bounds.width, bounds.height) * 0.9)
        guard scale > 0 else {
            return
        }
        let originX = Float(bounds.midX)
        let originY = Float(bounds.midY) - (0.2 * scale)
        for (meshIndex, mesh) in meshes.enumerated() {
            guard !mesh.positions.isEmpty else {
                continue
            }
            var positions = flatten(mesh.positions)
            for morphIndex in mesh.morphs.indices {
                let weight = lastWeight(weights, mesh: meshIndex, morph: morphIndex)
                guard weight > 0 else {
                    continue
                }
                let delta = flatten(mesh.morphs[morphIndex].positionDeltas)
                let count = min(positions.count, delta.count)
                guard count > 0 else {
                    continue
                }
                positions.withUnsafeMutableBufferPointer { dest in
                    delta.withUnsafeBufferPointer { source in
                        guard let destBase = dest.baseAddress, let sourceBase = source.baseAddress else {
                            return
                        }
                        _ = aoriFaceAddMorph(destBase, sourceBase, Float(weight), UInt(count))
                    }
                }
            }
            var projected = [Float](repeating: 0, count: mesh.positions.count * 2)
            positions.withUnsafeBufferPointer { source in
                projected.withUnsafeMutableBufferPointer { dest in
                    guard let sourceBase = source.baseAddress, let destBase = dest.baseAddress else {
                        return
                    }
                    _ = aoriFaceProject(
                        sourceBase,
                        UInt(mesh.positions.count),
                        Float(sway),
                        originX,
                        originY,
                        scale,
                        destBase
                    )
                }
            }
            let color = NSColor(
                srgbRed: CGFloat(mesh.color.red),
                green: CGFloat(mesh.color.green),
                blue: CGFloat(mesh.color.blue),
                alpha: CGFloat(mesh.color.alpha)
            )
            color.setFill()
            for triangle in sortedTriangles(mesh: mesh, positions: positions) {
                let path = NSBezierPath()
                path.move(to: point(triangle.0, xy: projected))
                path.line(to: point(triangle.1, xy: projected))
                path.line(to: point(triangle.2, xy: projected))
                path.close()
                path.fill()
            }
        }
    }

    private static func lastWeight(_ weights: [MorphWeight], mesh: Int, morph: Int) -> Double {
        var value = 0.0
        for weight in weights where weight.mesh == mesh && weight.morph == morph {
            value = weight.weight
        }
        return value
    }

    private static func sortedTriangles(mesh: VRMMesh, positions: [Float]) -> [(Int, Int, Int)] {
        var triangles: [(z: Float, indices: (Int, Int, Int))] = []
        var index = 0
        while index + 2 < mesh.indices.count {
            let first = Int(mesh.indices[index])
            let second = Int(mesh.indices[index + 1])
            let third = Int(mesh.indices[index + 2])
            index += 3
            let vertexCount = mesh.positions.count
            guard first < vertexCount, second < vertexCount, third < vertexCount else {
                continue
            }
            let z = (zAt(first, positions) + zAt(second, positions) + zAt(third, positions)) / 3
            triangles.append((z, (first, second, third)))
        }
        triangles.sort { $0.z < $1.z }
        return triangles.map(\.indices)
    }

    private static func zAt(_ index: Int, _ positions: [Float]) -> Float {
        positions[index * 3 + 2]
    }

    private static func point(_ index: Int, xy: [Float]) -> NSPoint {
        NSPoint(x: CGFloat(xy[index * 2]), y: CGFloat(xy[index * 2 + 1]))
    }

    private static func flatten(_ vectors: [VRMVec3]) -> [Float] {
        var values: [Float] = []
        values.reserveCapacity(vectors.count * 3)
        for vector in vectors {
            values.append(vector.x)
            values.append(vector.y)
            values.append(vector.z)
        }
        return values
    }
}
