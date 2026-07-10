import Foundation
import SwiftUI

@MainActor
final class PracticeStore: ObservableObject {
    @Published private(set) var customPatterns: [RhythmPattern] = []
    @Published private(set) var attempts: [TapAttempt] = []
    @Published private(set) var tempoPlans: [TempoPlan] = []
    @Published var saveError: String?

    private let storageKey = "PulseLoom.practice-state.v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        if ProcessInfo.processInfo.arguments.contains("--reset-practice-state") {
            defaults.removeObject(forKey: storageKey)
            defaults.removeObject(forKey: "PulseLoom.force-save-failure")
        }
        load()
    }

    var starterPatterns: [RhythmPattern] { RhythmPattern.starterPatterns }
    var allPatterns: [RhythmPattern] { starterPatterns + customPatterns }
    var lastAttempt: TapAttempt? { attempts.sorted { $0.createdAt > $1.createdAt }.first }

    func pattern(id: UUID) -> RhythmPattern? {
        allPatterns.first { $0.id == id }
    }

    func save(pattern: RhythmPattern) -> Bool {
        let patternsBefore = customPatterns
        var editable = pattern
        editable.updatedAt = Date()
        if let index = customPatterns.firstIndex(where: { $0.id == editable.id }) {
            customPatterns[index] = editable
        } else {
            customPatterns.append(editable)
        }
        if persistOrRollback(message: "Could not save this pattern. Your edits are still on screen—try again.") { return true }
        customPatterns = patternsBefore
        return false
    }

    func delete(pattern: RhythmPattern) -> Bool {
        let patternsBefore = customPatterns
        let attemptsBefore = attempts
        let plansBefore = tempoPlans
        customPatterns.removeAll { $0.id == pattern.id }
        attempts.removeAll { $0.patternID == pattern.id }
        tempoPlans.removeAll { $0.patternID == pattern.id }
        if persistOrRollback(message: "Could not delete this pattern. Please try again.") { return true }
        customPatterns = patternsBefore
        attempts = attemptsBefore
        tempoPlans = plansBefore
        return false
    }

    func save(attempt: TapAttempt, for pattern: RhythmPattern) -> Bool {
        let attemptsBefore = attempts
        let plansBefore = tempoPlans
        attempts.insert(attempt, at: 0)
        attempts = Array(attempts.prefix(50))
        let plan = TempoPlan(
            patternID: pattern.id,
            targetBPM: pattern.bpm,
            segmentStart: attempt.globalWeakSegment.lowerBound,
            segmentEnd: attempt.globalWeakSegment.upperBound,
            lastAttemptID: attempt.id
        )
        if let index = tempoPlans.firstIndex(where: { $0.patternID == pattern.id }) {
            tempoPlans[index] = plan
        } else {
            tempoPlans.append(plan)
        }
        if persistOrRollback(message: "Your timing review is ready, but it could not be saved. Retry after reviewing it.") { return true }
        attempts = attemptsBefore
        tempoPlans = plansBefore
        return false
    }

    func plan(for patternID: UUID) -> TempoPlan? { tempoPlans.first { $0.patternID == patternID } }

    func delete(attempt: TapAttempt) -> Bool {
        let attemptsBefore = attempts
        let plansBefore = tempoPlans
        attempts.removeAll { $0.id == attempt.id }
        tempoPlans.removeAll { $0.lastAttemptID == attempt.id }
        if persistOrRollback(message: "Could not delete this timing review. Please try again.") { return true }
        attempts = attemptsBefore
        tempoPlans = plansBefore
        return false
    }

    func clearError() { saveError = nil }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            let state = try decoder.decode(PersistedState.self, from: data)
            customPatterns = state.customPatterns
            attempts = state.attempts
            tempoPlans = state.tempoPlans
        } catch {
            saveError = "Saved practice data could not be read. New practice is still available."
        }
    }

    @discardableResult
    private func persistOrRollback(message: String) -> Bool {
        if ProcessInfo.processInfo.arguments.contains("--force-save-failure") || defaults.bool(forKey: "PulseLoom.force-save-failure") {
            saveError = message
            return false
        }
        do {
            let state = PersistedState(customPatterns: customPatterns, attempts: attempts, tempoPlans: tempoPlans)
            defaults.set(try encoder.encode(state), forKey: storageKey)
            saveError = nil
            return true
        } catch {
            saveError = message
            return false
        }
    }
}

private struct PersistedState: Codable {
    let customPatterns: [RhythmPattern]
    let attempts: [TapAttempt]
    let tempoPlans: [TempoPlan]
}
