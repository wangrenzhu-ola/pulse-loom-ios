import Foundation

public enum TimingStatus: String, Codable, CaseIterable, Sendable {
    case early
    case onTime = "on_time"
    case late

    public var shortLabel: String {
        switch self {
        case .early: return "Early"
        case .onTime: return "On time"
        case .late: return "Late"
        }
    }

    public static func status(for deviationMilliseconds: Int) -> TimingStatus {
        if deviationMilliseconds < -35 { return .early }
        if deviationMilliseconds > 35 { return .late }
        return .onTime
    }
}

public struct BeatCell: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var offset: Double
    public var accent: Bool
    public var subdivision: Int
    public var order: Int

    public init(id: UUID = UUID(), offset: Double, accent: Bool = false, subdivision: Int = 1, order: Int) {
        self.id = id
        self.offset = offset
        self.accent = accent
        self.subdivision = subdivision
        self.order = order
    }
}

public struct RhythmPattern: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var bpm: Int
    public var meter: String
    public var beatCells: [BeatCell]
    public var isStarter: Bool
    public var isPremium: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        bpm: Int,
        meter: String,
        beatCells: [BeatCell],
        isStarter: Bool = false,
        isPremium: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.bpm = bpm
        self.meter = meter
        self.beatCells = beatCells
        self.isStarter = isStarter
        self.isPremium = isPremium
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var sortedCells: [BeatCell] { beatCells.sorted { $0.order < $1.order } }

    public var expectedOffsetsMilliseconds: [Int] {
        let beatDuration = 60_000.0 / Double(max(bpm, 1))
        return sortedCells.map { Int(($0.offset * beatDuration).rounded()) }
    }

    public static let starterPatterns: [RhythmPattern] = [
        RhythmPattern(
            id: UUID(uuidString: "18A105B9-7D7A-4EA9-9634-37F25ED87901")!,
            name: "Even Eight",
            bpm: 92,
            meter: "4/4",
            beatCells: (0..<8).map { index in
                BeatCell(offset: Double(index), accent: index == 0 || index == 4, subdivision: 2, order: index)
            },
            isStarter: true
        ),
        RhythmPattern(
            id: UUID(uuidString: "A80DF9F1-7B88-40A9-BF60-E0771D8AD839")!,
            name: "Three Step",
            bpm: 84,
            meter: "3/4",
            beatCells: (0..<6).map { index in
                BeatCell(offset: Double(index), accent: index.isMultiple(of: 3), subdivision: 2, order: index)
            },
            isStarter: true
        ),
        RhythmPattern(
            id: UUID(uuidString: "11CF2F9A-5DAA-4F2E-9FB0-EE30EC57411C")!,
            name: "Cross Current",
            bpm: 96,
            meter: "4/4",
            beatCells: (0..<8).map { index in
                BeatCell(offset: Double(index) * 0.75, accent: index == 0 || index == 5, subdivision: 3, order: index)
            },
            isStarter: false,
            isPremium: true
        )
    ]
}

public struct TapAttempt: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var patternID: UUID
    public var expectedOffsetsMs: [Int]
    public var actualOffsetsMs: [Int]
    public var deviationsMs: [Int]
    public var weakSegment: ClosedRange<Int>
    public var practicedSegmentStart: Int
    public var practicedSegmentEnd: Int
    public var parentAttemptID: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        patternID: UUID,
        expectedOffsetsMs: [Int],
        actualOffsetsMs: [Int],
        deviationsMs: [Int],
        weakSegment: ClosedRange<Int>,
        practicedSegmentStart: Int = 0,
        practicedSegmentEnd: Int? = nil,
        parentAttemptID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.patternID = patternID
        self.expectedOffsetsMs = expectedOffsetsMs
        self.actualOffsetsMs = actualOffsetsMs
        self.deviationsMs = deviationsMs
        self.weakSegment = weakSegment
        self.practicedSegmentStart = practicedSegmentStart
        self.practicedSegmentEnd = practicedSegmentEnd ?? max(practicedSegmentStart, practicedSegmentStart + deviationsMs.count - 1)
        self.parentAttemptID = parentAttemptID
        self.createdAt = createdAt
    }

    public var stability: Int {
        guard !deviationsMs.isEmpty else { return 0 }
        let average = deviationsMs.map { abs($0) }.reduce(0, +) / deviationsMs.count
        return max(0, min(100, 100 - average))
    }

    public var globalWeakSegment: ClosedRange<Int> {
        (practicedSegmentStart + weakSegment.lowerBound)...(practicedSegmentStart + weakSegment.upperBound)
    }
}

public struct TempoPlan: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var patternID: UUID
    public var targetBPM: Int
    public var segmentStart: Int
    public var segmentEnd: Int
    public var lastAttemptID: UUID?

    public init(id: UUID = UUID(), patternID: UUID, targetBPM: Int, segmentStart: Int, segmentEnd: Int, lastAttemptID: UUID? = nil) {
        self.id = id
        self.patternID = patternID
        self.targetBPM = targetBPM
        self.segmentStart = segmentStart
        self.segmentEnd = segmentEnd
        self.lastAttemptID = lastAttemptID
    }
}

public struct PurchaseEntitlementCache: Codable, Hashable, Sendable {
    public var productID: String
    public var isUnlocked: Bool
    public var verifiedAt: Date?

    public init(productID: String, isUnlocked: Bool = false, verifiedAt: Date? = nil) {
        self.productID = productID
        self.isUnlocked = isUnlocked
        self.verifiedAt = verifiedAt
    }
}

public enum TimingEngine {
    public static func makeAttempt(
        pattern: RhythmPattern,
        tapOffsetsMilliseconds: [Int],
        replaying range: ClosedRange<Int>? = nil,
        parentAttemptID: UUID? = nil
    ) -> TapAttempt {
        let allExpected = pattern.expectedOffsetsMilliseconds
        let selectedRange = clampedRange(range, count: allExpected.count)
        let selectedExpected = Array(allExpected[selectedRange])
        let firstExpected = selectedExpected.first ?? 0
        let expected = selectedExpected.map { $0 - firstExpected }
        let normalizedActual = Array(tapOffsetsMilliseconds.prefix(expected.count))
        let paddedActual = normalizedActual + Array(repeating: expected.last ?? 0, count: max(0, expected.count - normalizedActual.count))
        let deviations = zip(expected, paddedActual).map { expectedOffset, actualOffset in
            actualOffset - expectedOffset
        }
        let weak = weakSegment(in: deviations)
        return TapAttempt(
            patternID: pattern.id,
            expectedOffsetsMs: expected,
            actualOffsetsMs: paddedActual,
            deviationsMs: deviations,
            weakSegment: weak,
            practicedSegmentStart: selectedRange.lowerBound,
            practicedSegmentEnd: selectedRange.upperBound,
            parentAttemptID: parentAttemptID
        )
    }

    public static func weakSegment(in deviations: [Int], forcedRange: ClosedRange<Int>? = nil) -> ClosedRange<Int> {
        guard !deviations.isEmpty else { return 0...0 }
        if let forcedRange { return forcedRange }
        let width = min(2, deviations.count)
        var bestStart = 0
        var bestScore = Int.min
        for start in 0...(deviations.count - width) {
            let score = deviations[start..<(start + width)].map { abs($0) }.reduce(0, +)
            if score > bestScore {
                bestScore = score
                bestStart = start
            }
        }
        return bestStart...(bestStart + width - 1)
    }


    private static func clampedRange(_ range: ClosedRange<Int>?, count: Int) -> ClosedRange<Int> {
        guard count > 0 else { return 0...0 }
        guard let range else { return 0...(count - 1) }
        let lower = max(0, min(range.lowerBound, count - 1))
        let upper = max(lower, min(range.upperBound, count - 1))
        return lower...upper
    }
}
