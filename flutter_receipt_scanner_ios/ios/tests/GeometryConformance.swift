import Foundation

private struct Corpus: Decodable {
    let schemaVersion: Int
    let geometry: Geometry
}

private struct Geometry: Decodable {
    let quantizeCases: [QuantizeCase]
    let angleCases: [AngleCase]
    let correctionCases: [CorrectionCase]
    let boxCases: [BoxCase]
    let quadCases: [QuadCase]
}

private struct QuantizeCase: Decodable {
    let id: String
    let degrees: Float
    let expected: Int
}

private struct AngleCase: Decodable {
    let id: String
    let angles: [Float]
    let expectedHistogram: [Int]
    let expectedDominant: Int?
}

private struct CorrectionCase: Decodable {
    let id: String
    let quarterTurn: Int
    let expected: Int
}

private struct BoxCase: Decodable {
    let id: String
    let frame: [Double]
    let box: [Double]
    let degrees: Int
    let expectedFrame: [Double]
    let expectedRotated: [Double]
    let expectedClamped: [Double]?
}

private struct QuadCase: Decodable {
    let id: String
    let corners: [Float]
    let expectedDistorted: Bool
}

private struct Mismatch: Error, CustomStringConvertible {
    let description: String
}

private func check(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw Mismatch(description: message)
    }
}

private func rect(_ values: [Double]) throws -> CGRect {
    try check(values.count == 4, "Expected [x, y, width, height]")
    return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
}

private func size(_ values: [Double]) throws -> CGSize {
    try check(values.count == 2, "Expected [width, height]")
    return CGSize(width: values[0], height: values[1])
}

@main
private enum GeometryConformance {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run() throws {
        try check(CommandLine.arguments.count == 2, "Usage: geometry-conformance /absolute/path/contract.json")
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN"
        )
        let corpus = try decoder.decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        try check(corpus.schemaVersion == 1, "Unsupported schema version")
        let g = corpus.geometry
        let counts = [g.quantizeCases.count, g.angleCases.count, g.correctionCases.count, g.boxCases.count, g.quadCases.count]
        try check(counts == [13, 14, 7, 14, 16], "Unexpected geometry group counts: \(counts)")

        for c in g.quantizeCases {
            let actual = OcrGeometry.quantizeQuarterTurn(CGFloat(c.degrees))
            try check(actual == c.expected, "\(c.id): quantize expected \(c.expected), got \(actual)")
            print("PASS quantizeCases/\(c.id)")
        }
        for c in g.angleCases {
            let angles = c.angles.map { CGFloat($0) }
            let histogram = OcrGeometry.quarterTurnHistogram(fromAngles: angles)
            let dominant = OcrGeometry.dominantQuarterTurn(fromAngles: angles)
            try check(histogram == c.expectedHistogram, "\(c.id): histogram expected \(c.expectedHistogram), got \(histogram)")
            try check(dominant == (c.expectedDominant ?? OcrGeometry.quarterTurnUnknown), "\(c.id): dominant got \(dominant)")
            print("PASS angleCases/\(c.id)")
        }
        for c in g.correctionCases {
            let actual = OcrGeometry.correctionForTextAngle(c.quarterTurn)
            try check(actual == c.expected, "\(c.id): correction expected \(c.expected), got \(actual)")
            print("PASS correctionCases/\(c.id)")
        }
        for c in g.boxCases {
            let frame = try size(c.frame)
            let input = try rect(c.box)
            let rotated = OcrGeometry.rect(byRotating: input, frameSize: frame, clockwiseDegrees: c.degrees)
            try check(rotated == rect(c.expectedRotated), "\(c.id): rotated box got \(rotated)")
            let rotatedFrame = OcrGeometry.rect(
                byRotating: CGRect(origin: .zero, size: frame), frameSize: frame, clockwiseDegrees: c.degrees
            ).size
            try check(rotatedFrame == size(c.expectedFrame), "\(c.id): rotated frame got \(rotatedFrame)")
            let lines = OcrGeometry.linesByRotating(
                [OcrLineBox(text: c.id, box: input, confidence: 0.75)],
                frameSize: frame, clockwiseDegrees: c.degrees, outputSize: rotatedFrame
            )
            if let expected = c.expectedClamped {
                try check(lines.count == 1, "\(c.id): missing clamped line")
                try check(lines[0].box == rect(expected), "\(c.id): clamped box got \(lines[0].box)")
                try check(lines[0].text == c.id && lines[0].confidence == 0.75, "\(c.id): line metadata changed")
            } else {
                try check(lines.isEmpty, "\(c.id): expected dropped line")
            }
            // Vision supplies normalized bottom-left boxes, including out-of-frame values.
            let vision = CGRect(x: input.minX / frame.width, y: 1 - input.maxY / frame.height,
                                width: input.width / frame.width, height: input.height / frame.height)
            let converted = OcrGeometry.rect(fromNormalizedBox: vision, pixelSize: frame)
            let deltas = [converted.minX - input.minX, converted.minY - input.minY,
                          converted.width - input.width, converted.height - input.height]
            try check(deltas.allSatisfy { abs($0) <= 0.000001 }, "\(c.id): Vision box conversion got \(converted)")
            print("PASS boxCases/\(c.id)")
        }
        for c in g.quadCases {
            try check(c.corners.count.isMultiple(of: 2), "\(c.id): incomplete corner")
            // Canonical top-left pixels → CI/Vision bottom-left; reflect Y without reordering corners.
            let corners = stride(from: 0, to: c.corners.count, by: 2).map {
                CGPoint(x: CGFloat(c.corners[$0]), y: -CGFloat(c.corners[$0 + 1]))
            }
            let actual = QuadDetector.isDistorted(corners)
            try check(actual == c.expectedDistorted, "\(c.id): distorted expected \(c.expectedDistorted), got \(actual)")
            print("PASS quadCases/\(c.id)")
        }
        // Non-square pixel frame catches a missing aspect-ratio scale or Vision Y inversion.
        let angle = OcrGeometry.clockwiseAngle(
            fromTopLeft: CGPoint(x: 0.1, y: 0.8), topRight: CGPoint(x: 0.3, y: 0.4),
            pixelSize: CGSize(width: 1000, height: 500)
        )
        try check(abs(angle - 45) <= 0.000001, "Vision angle expected 45, got \(angle)")
        print("PASS Vision angle adapter")
        print("PASS Swift geometry: \(counts.reduce(0, +))/64 corpus cases; Vision adapters")
    }
}
