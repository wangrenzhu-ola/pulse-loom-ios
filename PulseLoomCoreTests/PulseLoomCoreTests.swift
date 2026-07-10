import XCTest
@testable import PulseLoomCore

final class PulseLoomCoreTests: XCTestCase {
    func testTimingStatesUseNonColorThresholds() {
        XCTAssertEqual(TimingStatus.status(for: -80), .early)
        XCTAssertEqual(TimingStatus.status(for: 0), .onTime)
        XCTAssertEqual(TimingStatus.status(for: 81), .late)
    }

    func testAttemptFindsWeakestTwoBeatSegment() {
        let pattern = RhythmPattern.starterPatterns[0]
        let expected = pattern.expectedOffsetsMilliseconds
        var actual = expected
        actual[2] -= 80
        actual[3] += 65
        let attempt = TimingEngine.makeAttempt(pattern: pattern, tapOffsetsMilliseconds: actual)

        XCTAssertEqual(attempt.weakSegment, 2...3)
        XCTAssertEqual(attempt.deviationsMs[2], -80)
        XCTAssertEqual(attempt.deviationsMs[3], 65)
    }

    func testStarterPatternsRemainFreeAndCustomPatternsAreEditable() {
        XCTAssertTrue(RhythmPattern.starterPatterns.contains { $0.isStarter && !$0.isPremium })
        var custom = RhythmPattern.starterPatterns[0]
        custom.isStarter = false
        custom.name = "Offbeat Warm-up"
        custom.bpm = 92
        XCTAssertFalse(custom.isStarter)
        XCTAssertEqual(custom.name, "Offbeat Warm-up")
    }

    func testStarterPatternIDsAreStableAcrossLaunches() {
        XCTAssertEqual(RhythmPattern.starterPatterns[0].id.uuidString, "18A105B9-7D7A-4EA9-9634-37F25ED87901")
        XCTAssertEqual(RhythmPattern.starterPatterns[1].id.uuidString, "A80DF9F1-7B88-40A9-BF60-E0771D8AD839")
        XCTAssertTrue(RhythmPattern.starterPatterns.filter(\.isStarter).allSatisfy { !$0.isPremium })
    }

    func testWeakCellReplayRebasesExpectedOffsetsAndKeepsGlobalSegment() {
        let pattern = RhythmPattern.starterPatterns[0]
        let expected = pattern.expectedOffsetsMilliseconds
        let attempt = TimingEngine.makeAttempt(
            pattern: pattern,
            tapOffsetsMilliseconds: [0, expected[3] - expected[2]],
            replaying: 2...3,
            parentAttemptID: UUID()
        )

        XCTAssertEqual(attempt.deviationsMs, [0, 0])
        XCTAssertEqual(attempt.weakSegment, 0...1)
        XCTAssertEqual(attempt.globalWeakSegment, 2...3)
        XCTAssertEqual(attempt.practicedSegmentStart, 2)
        XCTAssertEqual(attempt.practicedSegmentEnd, 3)
    }

    func testEntitlementCacheRoundTrips() throws {
        let verifiedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let cache = PurchaseEntitlementCache(
            productID: "com.wangrenzhu.pulseloom.fullpractice",
            isUnlocked: true,
            verifiedAt: verifiedAt
        )
        let decoded = try JSONDecoder().decode(
            PurchaseEntitlementCache.self,
            from: JSONEncoder().encode(cache)
        )
        XCTAssertEqual(decoded, cache)
    }
}
