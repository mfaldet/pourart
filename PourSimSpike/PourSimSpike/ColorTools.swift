import SwiftUI
import simd

// ---------------------------------------------------------------------------
// ColorTools — pure-function color science utilities used everywhere.
// ---------------------------------------------------------------------------
enum ColorTools {

    // MARK: - Hex ↔ RGB

    static func hex(_ rgb: SIMD3<Float>) -> String {
        let r = Int((rgb.x * 255).rounded().clamped(to: 0...255))
        let g = Int((rgb.y * 255).rounded().clamped(to: 0...255))
        let b = Int((rgb.z * 255).rounded().clamped(to: 0...255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    static func rgb(fromHex hex: String) -> SIMD3<Float>? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 {
            // Expand #RGB → #RRGGBB
            s = s.map { String(repeating: $0, count: 2) }.joined()
        }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return SIMD3(
            Float((v >> 16) & 0xFF) / 255,
            Float((v >>  8) & 0xFF) / 255,
            Float( v        & 0xFF) / 255
        )
    }

    // MARK: - HSB conversions

    static func hsb(from rgb: SIMD3<Float>) -> (h: Double, s: Double, b: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        UIColor(red:   CGFloat(rgb.x),
                green: CGFloat(rgb.y),
                blue:  CGFloat(rgb.z), alpha: 1)
            .getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return (Double(h), Double(s), Double(b))
    }

    static func rgb(h: Double, s: Double, b: Double) -> SIMD3<Float> {
        let c = UIColor(hue:        CGFloat(h),
                        saturation: CGFloat(s),
                        brightness: CGFloat(b), alpha: 1)
        var r: CGFloat = 0, gv: CGFloat = 0, bv: CGFloat = 0
        c.getRed(&r, green: &gv, blue: &bv, alpha: nil)
        return SIMD3(Float(r), Float(gv), Float(bv))
    }

    // MARK: - Tints / Shades / Tones

    /// Tints — lerp toward white (lighter variants)
    static func tints(of rgb: SIMD3<Float>, count: Int = 5) -> [SIMD3<Float>] {
        (1...count).map { i in
            let t = Float(i) / Float(count + 1)
            return mix(rgb, SIMD3(1, 1, 1), t)
        }
    }

    /// Shades — lerp toward black (darker variants)
    static func shades(of rgb: SIMD3<Float>, count: Int = 5) -> [SIMD3<Float>] {
        (1...count).map { i in
            let t = Float(i) / Float(count + 1)
            return mix(rgb, SIMD3(0, 0, 0), t)
        }
    }

    /// Tones — lerp toward mid-gray (desaturated variants)
    static func tones(of rgb: SIMD3<Float>, count: Int = 5) -> [SIMD3<Float>] {
        let gray = SIMD3<Float>(0.5, 0.5, 0.5)
        return (1...count).map { i in
            let t = Float(i) / Float(count + 1)
            return mix(rgb, gray, t)
        }
    }

    // MARK: - Adjustments

    static func adjustBrightness(_ rgb: SIMD3<Float>, by delta: Float) -> SIMD3<Float> {
        var (h, s, b) = hsb(from: rgb)
        b = max(0, min(1, b + Double(delta)))
        return self.rgb(h: h, s: s, b: b)
    }

    static func adjustSaturation(_ rgb: SIMD3<Float>, by delta: Float) -> SIMD3<Float> {
        var (h, s, b) = hsb(from: rgb)
        s = max(0, min(1, s + Double(delta)))
        return self.rgb(h: h, s: s, b: b)
    }

    static func rotateHue(_ rgb: SIMD3<Float>, by degrees: Double) -> SIMD3<Float> {
        var (h, s, b) = hsb(from: rgb)
        h = (h + degrees / 360 + 1).truncatingRemainder(dividingBy: 1)
        return self.rgb(h: h, s: s, b: b)
    }

    // MARK: - Contrast / Luminance

    /// WCAG relative luminance (0…1)
    static func luminance(_ rgb: SIMD3<Float>) -> Float {
        func channel(_ c: Float) -> Float {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.x)
             + 0.7152 * channel(rgb.y)
             + 0.0722 * channel(rgb.z)
    }

    /// Returns black or white — whichever contrasts the input color better.
    static func legibleForeground(_ rgb: SIMD3<Float>) -> Color {
        luminance(rgb) > 0.45 ? .black : .white
    }

    // MARK: - Color blindness simulation (approximate Brettel / Viénot model)

    static func simulate(_ rgb: SIMD3<Float>, type: ColorBlindness) -> SIMD3<Float> {
        let m: simd_float3x3
        switch type {
        case .protanopia:
            m = simd_float3x3(rows: [
                SIMD3(0.567, 0.433, 0.000),
                SIMD3(0.558, 0.442, 0.000),
                SIMD3(0.000, 0.242, 0.758)])
        case .deuteranopia:
            m = simd_float3x3(rows: [
                SIMD3(0.625, 0.375, 0.000),
                SIMD3(0.700, 0.300, 0.000),
                SIMD3(0.000, 0.300, 0.700)])
        case .tritanopia:
            m = simd_float3x3(rows: [
                SIMD3(0.950, 0.050, 0.000),
                SIMD3(0.000, 0.433, 0.567),
                SIMD3(0.000, 0.475, 0.525)])
        }
        let result = m * rgb
        return SIMD3(
            max(0, min(1, result.x)),
            max(0, min(1, result.y)),
            max(0, min(1, result.z)))
    }

    // MARK: - Random

    static func randomPalette(harmony: ColorHarmony) -> [SIMD3<Float>] {
        let h = Double.random(in: 0..<1)
        let s = Double.random(in: 0.50...0.95)
        let b = Double.random(in: 0.65...0.95)
        return harmony.paletteRGB(hue: h, saturation: s, brightness: b)
    }

    // MARK: - Image → palette extraction (k-means in RGB)

    static func extractPalette(from image: UIImage, count: Int = 5) -> [SIMD3<Float>] {
        guard let cg = image.cgImage else { return [] }
        let dim = 80
        var bytes = [UInt8](repeating: 0, count: dim * dim * 4)
        let ctx = CGContext(
            data: &bytes, width: dim, height: dim,
            bitsPerComponent: 8, bytesPerRow: dim * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: dim, height: dim))

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(dim * dim)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            points.append(SIMD3(
                Float(bytes[i])     / 255,
                Float(bytes[i + 1]) / 255,
                Float(bytes[i + 2]) / 255))
        }

        // Drop near-black and near-white outliers — they dominate visually
        // but rarely represent the painting's actual color story.
        let filtered = points.filter {
            let s = $0.x + $0.y + $0.z
            return s > 0.15 && s < 2.85
        }

        let centroids = kMeans(points: filtered.isEmpty ? points : filtered, k: count, iterations: 10)
        // Sort by hue for a perceptual ordering
        return centroids.sorted { hsb(from: $0).h < hsb(from: $1).h }
    }

    private static func kMeans(points: [SIMD3<Float>], k: Int, iterations: Int) -> [SIMD3<Float>] {
        guard points.count >= k else { return Array(points.prefix(k)) }
        var centroids = (0..<k).map { _ in points.randomElement()! }

        for _ in 0..<iterations {
            var clusters: [[SIMD3<Float>]] = Array(repeating: [], count: k)
            for p in points {
                var bestI = 0
                var bestD = Float.greatestFiniteMagnitude
                for i in 0..<k {
                    let d = distance_squared(p, centroids[i])
                    if d < bestD { bestD = d; bestI = i }
                }
                clusters[bestI].append(p)
            }
            for i in 0..<k where !clusters[i].isEmpty {
                let sum = clusters[i].reduce(SIMD3<Float>(0,0,0), +)
                centroids[i] = sum / Float(clusters[i].count)
            }
        }
        return centroids
    }

    // MARK: - Helpers

    private static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }
}

// ---------------------------------------------------------------------------
// Color blindness types
// ---------------------------------------------------------------------------
enum ColorBlindness: String, CaseIterable, Identifiable {
    case protanopia, deuteranopia, tritanopia
    var id: String { rawValue }
    var label: String {
        switch self {
        case .protanopia:   return "Protanopia"
        case .deuteranopia: return "Deuteranopia"
        case .tritanopia:   return "Tritanopia"
        }
    }
    var subtitle: String {
        switch self {
        case .protanopia:   return "red-blind · ~1% men"
        case .deuteranopia: return "green-blind · ~6% men"
        case .tritanopia:   return "blue-blind · rare"
        }
    }
}

// ---------------------------------------------------------------------------
// Tiny helpers
// ---------------------------------------------------------------------------
private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
