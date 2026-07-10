import XCTest
@testable import PulseLoom

final class PulseLoomAppTests: XCTestCase {
    func testTimingEngineBuildsWeakSegment() {
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

    func testStarterCoreRemainsFree() {
        XCTAssertTrue(RhythmPattern.starterPatterns.contains { $0.isStarter && !$0.isPremium })
    }

    func testReplayRebasesSegmentOffsets() {
        let pattern = RhythmPattern.starterPatterns[0]
        let expected = pattern.expectedOffsetsMilliseconds
        let attempt = TimingEngine.makeAttempt(
            pattern: pattern,
            tapOffsetsMilliseconds: [0, expected[3] - expected[2]],
            replaying: 2...3
        )
        XCTAssertEqual(attempt.deviationsMs, [0, 0])
        XCTAssertEqual(attempt.globalWeakSegment, 2...3)
    }

    @MainActor
    func testPatternAttemptAndTempoPlanSurviveStoreRecreation() {
        let suiteName = "PulseLoomAppTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstStore = PracticeStore(defaults: defaults)
        let custom = RhythmPattern(
            name: "Offbeat Warm-up",
            bpm: 92,
            meter: "4/4",
            beatCells: RhythmPattern.starterPatterns[0].beatCells
        )
        XCTAssertTrue(firstStore.save(pattern: custom))
        let expected = custom.expectedOffsetsMilliseconds
        let attempt = TimingEngine.makeAttempt(pattern: custom, tapOffsetsMilliseconds: expected)
        XCTAssertTrue(firstStore.save(attempt: attempt, for: custom))

        let relaunchedStore = PracticeStore(defaults: defaults)
        XCTAssertEqual(relaunchedStore.customPatterns.first?.name, "Offbeat Warm-up")
        XCTAssertEqual(relaunchedStore.attempts.first?.patternID, custom.id)
        XCTAssertEqual(relaunchedStore.tempoPlans.first?.lastAttemptID, attempt.id)
    }

    @MainActor
    func testInjectedSaveFailurePreservesEditorSourceState() {
        let suiteName = "PulseLoomAppTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "PulseLoom.force-save-failure")
        let store = PracticeStore(defaults: defaults)
        let pattern = RhythmPattern(
            name: "Unsaved Weave",
            bpm: 88,
            meter: "4/4",
            beatCells: RhythmPattern.starterPatterns[0].beatCells
        )

        XCTAssertFalse(store.save(pattern: pattern))
        XCTAssertTrue(store.customPatterns.isEmpty)
        XCTAssertNotNil(store.saveError)
    }

    func testStoreKitConfigurationDeclaresNonConsumableProduct() throws {
        let configurationURL = try XCTUnwrap(
            Bundle(for: PulseLoomAppTests.self).url(forResource: "Configuration", withExtension: "storekit")
        )
        let data = try Data(contentsOf: configurationURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        let product = try XCTUnwrap(products.first)
        XCTAssertEqual(product["productID"] as? String, PurchaseStore.productID)
        XCTAssertEqual(product["type"] as? String, "NonConsumable")
    }
}
