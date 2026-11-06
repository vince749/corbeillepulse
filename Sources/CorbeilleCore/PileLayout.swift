import Foundation

/// Geometry of the debris pile. Pure so it can be tested without a screen.
public struct PiecePlacement: Sendable {
    public let verticalPosition: Double  // 0 = bottom of the pile, 1 = top
    public let horizontalSpread: Double  // -1 ... 1
    public let rotationDegrees: Double
    public let sizeJitter: Double  // 0 ... 1
    public let bobDuration: Double
    public let bobDelay: Double

    public var size: Double { 28 + (1 - verticalPosition) * 14 + sizeJitter * 8 }

    /// Centre of the piece, measured from the bottom-left corner of the pile.
    public func center(pileWidth: Double, pileHeight: Double) -> (x: Double, y: Double) {
        let taper = 1 - verticalPosition * 0.78
        return ((0.5 + horizontalSpread * 0.5 * taper) * pileWidth, verticalPosition * pileHeight)
    }
}

public struct PileMetrics: Equatable, Sendable {
    public let width: Double
    public let height: Double
    public let pieceCount: Int
    public let glowOpacity: Double
}

public enum PileLayout {
    public static let poolSize = 52

    /// Small seeded generator, so the pile looks the same on every launch.
    public static func generator(seed: UInt32) -> () -> Double {
        var state = seed
        return {
            state &+= 0x6D2B_79F5
            var t = (state ^ (state >> 15)) &* (1 | state)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return Double(t ^ (t >> 14)) / 4_294_967_296
        }
    }

    /// Sorted from the bottom up, so a small pile shows only its base.
    public static let pieces: [PiecePlacement] = {
        let random = generator(seed: 0x9E37_79B9)
        var result: [PiecePlacement] = []
        for _ in 0..<poolSize {
            let vertical = pow(random(), 0.7)
            let horizontal = random() * 2 - 1
            let rotation = (random() * 2 - 1) * 34
            let jitter = random()
            let duration = 2.6 + random() * 2.2
            let delay = -random() * 4
            result.append(PiecePlacement(
                verticalPosition: vertical, horizontalSpread: horizontal, rotationDegrees: rotation,
                sizeJitter: jitter, bobDuration: duration, bobDelay: delay))
        }
        return result.sorted { $0.verticalPosition < $1.verticalPosition }
    }()

    private struct Preset {
        let gain, heightFraction, widthFraction: Double
        let pieces: Double
        let glow: Double
    }

    private static func preset(_ intensity: Intensity) -> Preset {
        switch intensity {
        case .light: Preset(gain: 0.5, heightFraction: 0.42, widthFraction: 0.52, pieces: 20, glow: 0.6)
        case .progressive: Preset(gain: 1.0, heightFraction: 0.78, widthFraction: 0.82, pieces: 38, glow: 1)
        case .dramatic: Preset(gain: 2.6, heightFraction: 0.98, widthFraction: 0.96, pieces: 52, glow: 1.4)
        }
    }

    /// `nil` under the threshold: nothing is drawn until the Trash overflows.
    public static func metrics(
        fillRatio: Double, intensity: Intensity, areaWidth: Double, areaHeight: Double
    ) -> PileMetrics? {
        guard fillRatio >= 1 else { return nil }
        let preset = preset(intensity)
        let growth = 1 - 1 / (1 + (fillRatio - 1) * preset.gain)
        let baseHeight = 0.08
        let baseWidth = 0.22
        return PileMetrics(
            width: min(areaWidth * 0.97, areaWidth * (baseWidth + growth * (preset.widthFraction - baseWidth))),
            height: min(areaHeight * 0.98, areaHeight * (baseHeight + growth * (preset.heightFraction - baseHeight))),
            pieceCount: min(poolSize, max(3, Int((3 + growth * (preset.pieces - 3)).rounded()))),
            glowOpacity: min(0.5, (0.12 + growth * 0.32) * preset.glow))
    }
}
