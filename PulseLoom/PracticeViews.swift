import SwiftUI
import UIKit

struct CountdownView: View {
    @Environment(\.presentationMode) private var presentationMode
    let session: PracticeSession
    let completed: (AttemptContext) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var count = 4
    @State private var isRunning = true
    @State private var isPracticing = false

    var body: some View {
        Group {
            if isPracticing {
                PracticeRunView(session: session, complete: completed)
            } else {
                countdown
            }
        }
    }

    private var countdown: some View {
        LoomScreen {
            VStack(spacing: 28) {
                Spacer()
                Text(session.segment == nil ? "Get ready" : "Replay weak cells")
                    .font(.headline)
                    .foregroundColor(LoomPalette.fog)
                Text("\(count)")
                    .font(.system(size: 132, weight: .black, design: .rounded))
                    .foregroundColor(LoomPalette.mint)
                    .frame(width: 200, height: 200)
                    .background(LoomPalette.panel)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(LoomPalette.mint, lineWidth: reduceMotion ? 5 : 2))
                    .scaleEffect(reduceMotion ? 1 : (isRunning ? 1.04 : 1))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: isRunning)
                    .accessibilityLabel("Countdown, \(count)")
                Text("Follow four visual pulses. No microphone or audio input is used.")
                    .font(.subheadline)
                    .foregroundColor(LoomPalette.fog)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .buttonStyle(SecondaryLoomButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .onAppear { Task { await runCountdown() } }
    }

    private func runCountdown() async {
        while count > 0, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            count -= 1
        }
        guard !Task.isCancelled else { return }
        isRunning = false
        isPracticing = true
    }
}

struct PracticeRunView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var store: PracticeStore
    @AppStorage("PulseLoom.haptics-enabled") private var hapticsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: PracticeSession
    let complete: (AttemptContext) -> Void
    @State private var startedAtUptime: TimeInterval?
    @State private var taps: [Int] = []
    @State private var isPaused = false
    @State private var pulseIndex = 0
    @State private var pulseEmphasis = false

    private var activeCells: [BeatCell] {
        let cells = session.pattern.sortedCells
        guard let segment = session.segment else { return cells }
        return cells.enumerated().compactMap { segment.contains($0.offset) ? $0.element : nil }
    }

    var body: some View {
        LoomScreen {
            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text(session.pattern.name)
                        .font(.headline)
                    Text("\(session.pattern.bpm) BPM · Tap each beat cell")
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                }
                .padding(.top, 22)
                BeatLoom(beatCells: activeCells, completed: taps.count, activeIndex: pulseIndex)
                    .padding(.horizontal, 20)
                Spacer()
                Button(action: registerTap) {
                    VStack(spacing: 10) {
                        Image(systemName: taps.count >= activeCells.count ? "checkmark" : "hand.tap.fill")
                            .font(.system(size: 42, weight: .bold))
                        Text(taps.count >= activeCells.count ? "Review timing" : "Tap beat \(min(taps.count + 1, activeCells.count))")
                            .font(.title3.weight(.bold))
                        Text("Large touch target · \(taps.count) of \(activeCells.count) captured")
                            .font(.footnote)
                            .foregroundColor(LoomPalette.fog)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
                .buttonStyle(TapSurfaceStyle())
                .disabled(isPaused)
                .accessibilityIdentifier("practice-tap-surface")
                .accessibilityLabel(taps.count >= activeCells.count ? "Review timing" : "Tap beat \(min(taps.count + 1, activeCells.count)) of \(activeCells.count)")
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(LoomPalette.amber.opacity(pulseEmphasis ? 1 : 0.2), lineWidth: reduceMotion ? 4 : 2)
                        .padding(.horizontal, 20)
                )
                HStack(spacing: 12) {
                    Button(isPaused ? "Resume" : "Pause") { isPaused.toggle() }
                        .buttonStyle(SecondaryLoomButtonStyle())
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                        .buttonStyle(SecondaryLoomButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear { Task { await runVisualPulse() } }
    }

    private func registerTap() {
        guard taps.count < activeCells.count else {
            finishAttempt()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = Int(((now - (startedAtUptime ?? now)) * 1_000).rounded())
        taps.append(elapsed)
        if hapticsEnabled && taps.count == activeCells.count {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func finishAttempt() {
        let adjusted = taps.map { $0 - (taps.first ?? 0) }
        let attempt = TimingEngine.makeAttempt(
            pattern: session.pattern,
            tapOffsetsMilliseconds: adjusted,
            replaying: session.segment,
            parentAttemptID: session.parentAttemptID
        )
        let persisted = store.save(attempt: attempt, for: session.pattern)
        complete(AttemptContext(attempt: attempt, pattern: session.pattern, persisted: persisted))
    }

    private func runVisualPulse() async {
        let leadIn: UInt64 = 500_000_000
        try? await Task.sleep(nanoseconds: leadIn)
        startedAtUptime = ProcessInfo.processInfo.systemUptime
        let beatNanoseconds = UInt64((60.0 / Double(max(session.pattern.bpm, 1))) * 1_000_000_000)
        while !Task.isCancelled && taps.count < activeCells.count {
            if !isPaused {
                pulseEmphasis = true
                if hapticsEnabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                if !reduceMotion {
                    try? await Task.sleep(nanoseconds: min(120_000_000, beatNanoseconds / 3))
                }
                pulseEmphasis = false
                pulseIndex = (pulseIndex + 1) % max(activeCells.count, 1)
            }
            try? await Task.sleep(nanoseconds: beatNanoseconds)
        }
    }
}

struct TapSurfaceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(configuration.isPressed ? LoomPalette.mint.opacity(0.25) : LoomPalette.panel)
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(LoomPalette.mint, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, 20)
    }
}

struct AttemptReviewView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var store: PracticeStore
    let context: AttemptContext
    let replay: (AttemptContext) -> Void
    @State private var isPersisted: Bool

    init(context: AttemptContext, replay: @escaping (AttemptContext) -> Void) {
        self.context = context
        self.replay = replay
        _isPersisted = State(initialValue: context.persisted)
    }

    var body: some View {
        NavigationView {
            LoomScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Timing review")
                            .font(.largeTitle.weight(.bold))
                        summary
                        ribbon
                        comparison
                        weakCallout
                        deviationList
                        Button(action: { presentationMode.wrappedValue.dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { replay(context) } }) {
                            Label("Replay weak cells", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(PrimaryLoomButtonStyle())
                        .accessibilityIdentifier("replay-weak-cells")
                        Button("Done") { presentationMode.wrappedValue.dismiss() }
                            .buttonStyle(SecondaryLoomButtonStyle())
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { presentationMode.wrappedValue.dismiss() } }
            }
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.attempt.stability)%")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(LoomPalette.mint)
                Text("timing stability")
                    .font(.footnote)
                    .foregroundColor(LoomPalette.fog)
            }
            Spacer()
            Text(isPersisted ? "Saved locally" : "Not saved yet")
                .font(.caption.weight(.bold))
                .foregroundColor(isPersisted ? LoomPalette.mint : LoomPalette.amber)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LoomPalette.panel))
    }

    @ViewBuilder
    private var comparison: some View {
        if let parentID = context.attempt.parentAttemptID,
           let previous = store.attempts.first(where: { $0.id == parentID }) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Before and replay")
                    .font(.headline)
                Text("Previous attempt")
                    .font(.caption.weight(.bold))
                    .foregroundColor(LoomPalette.fog)
                TimingRibbon(deviations: previous.deviationsMs, highlightedRange: previous.weakSegment)
                Text("Weak-cell replay")
                    .font(.caption.weight(.bold))
                    .foregroundColor(LoomPalette.mint)
                TimingRibbon(deviations: context.attempt.deviationsMs, highlightedRange: context.attempt.weakSegment)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LoomPalette.panel))
        }
        if !isPersisted {
            VStack(alignment: .leading, spacing: 10) {
                Text("This review could not be saved")
                    .font(.headline)
                    .foregroundColor(LoomPalette.amber)
                Text("Your completed timing ribbon is still visible. Retry the local save or copy the beat details.")
                    .font(.footnote)
                    .foregroundColor(LoomPalette.fog)
                HStack {
                    Button("Retry save", action: retrySave)
                        .buttonStyle(SecondaryLoomButtonStyle())
                    Button("Copy details", action: copyDetails)
                        .buttonStyle(SecondaryLoomButtonStyle())
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LoomPalette.amber.opacity(0.12)))
        }
    }

    private var ribbon: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timing Ribbon")
                .font(.headline)
            TimingRibbon(deviations: context.attempt.deviationsMs, highlightedRange: context.attempt.weakSegment)
            Text("Shape, color, and label each describe timing: left notch for early, dot for on time, right notch for late.")
                .font(.footnote)
                .foregroundColor(LoomPalette.fog)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LoomPalette.panel))
    }

    private var weakCallout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Weak-cell replay is ready", systemImage: "scope")
                .font(.headline)
                .foregroundColor(LoomPalette.amber)
            Text("Beats \(context.attempt.globalWeakSegment.lowerBound + 1)–\(context.attempt.globalWeakSegment.upperBound + 1) had the largest combined drift. Rehearse only that segment at \(context.pattern.bpm) BPM.")
                .font(.subheadline)
                .foregroundColor(LoomPalette.fog)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LoomPalette.amber.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LoomPalette.amber.opacity(0.5)))
    }

    private var deviationList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Beat detail")
                .font(.headline)
            ForEach(Array(context.attempt.deviationsMs.enumerated()), id: \.offset) { index, deviation in
                HStack {
                    Text("Beat \(index + 1)")
                    Spacer()
                    Text("\(TimingStatus.status(for: deviation).shortLabel) · \(deviation >= 0 ? "+" : "")\(deviation) ms")
                        .foregroundColor(color(for: deviation))
                        .accessibilityLabel("Beat \(index + 1), \(TimingStatus.status(for: deviation).shortLabel), \(abs(deviation)) milliseconds")
                }
                .font(.subheadline)
                .padding(.vertical, 5)
                Divider().overlay(LoomPalette.fog.opacity(0.2))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LoomPalette.panel))
    }

    private func color(for deviation: Int) -> Color {
        switch TimingStatus.status(for: deviation) {
        case .early: return LoomPalette.amber
        case .onTime: return LoomPalette.mint
        case .late: return LoomPalette.coral
        }
    }

    private func retrySave() {
        isPersisted = store.save(attempt: context.attempt, for: context.pattern)
    }

    private func copyDetails() {
        let details = context.attempt.deviationsMs.enumerated().map { index, deviation in
            "Beat \(context.attempt.practicedSegmentStart + index + 1): \(deviation) ms"
        }.joined(separator: "\n")
        UIPasteboard.general.string = "\(context.pattern.name)\n\(details)"
    }
}
