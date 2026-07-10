import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PracticeStore
    @Environment(\.sizeCategory) private var sizeCategory
    let startPractice: () -> Void
    let showLibrary: () -> Void
    let showPremium: () -> Void

    var body: some View {
        LoomScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    timingHero
                    quickWeaveCard
                    weakCellCard
                    Button(action: showLibrary) {
                        Label("Browse practice patterns", systemImage: "rectangle.3.group")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryLoomButtonStyle())
                    Button("Explore Full Practice Library", action: showPremium)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(LoomPalette.mint)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(20)
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PULSE LOOM")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundColor(LoomPalette.mint)
            Text("Find the beat that needs you.")
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("A short fingertip practice, a clear timing answer, then one focused replay.")
                .font(.subheadline)
                .foregroundColor(LoomPalette.fog)
        }
    }

    private var timingHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            ribbonHeader
            TimingRibbon(deviations: store.lastAttempt?.deviationsMs ?? [-12, 8, -80, 42, 10, -18, 6, 22])
            Text(store.lastAttempt == nil ? "Tap through an included practice pattern to weave your first ribbon." : "Your saved timing stays on this device.")
                .font(.footnote)
                .foregroundColor(LoomPalette.fog)
        }
        .padding(18)
        .background(LoomPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(LoomPalette.mint.opacity(0.25)))
        .accessibilityIdentifier("home-timing-ribbon")
    }

    @ViewBuilder
    private var ribbonHeader: some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(alignment: .leading, spacing: 6) {
                Label("Latest timing ribbon", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(store.lastAttempt == nil ? "Ready" : "Reviewed")
                    .font(.caption.weight(.bold))
                    .foregroundColor(LoomPalette.mint)
            }
        } else {
            HStack {
                Label("Latest timing ribbon", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                Text(store.lastAttempt == nil ? "Ready" : "Reviewed")
                    .font(.caption.weight(.bold))
                    .foregroundColor(LoomPalette.mint)
            }
        }
    }

    private var quickWeaveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TODAY'S QUICK WEAVE")
                .font(.caption.weight(.heavy))
                .tracking(1.4)
                .foregroundColor(LoomPalette.amber)
            Text("\(quickPattern.name) · \(quickPattern.bpm) BPM")
                .font(.title3.weight(.bold))
            Text(quickDetail)
                .font(.subheadline)
                .foregroundColor(LoomPalette.fog)
            Button(action: startPractice) {
                Label("Start Quick Weave", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryLoomButtonStyle())
            .accessibilityIdentifier("start-quick-weave")
        }
        .padding(18)
        .background(LoomPalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var weakCellCard: some View {
        let detail = store.lastAttempt.map { "Your next replay will begin at beats \($0.globalWeakSegment.lowerBound + 1)–\($0.globalWeakSegment.upperBound + 1)." } ?? "Finish a practice run to isolate the beat cells that drift most."
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "scope")
                .font(.title2)
                .foregroundColor(LoomPalette.coral)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text("Weak-cell replay")
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(LoomPalette.fog)
            }
        }
        .padding(16)
        .background(LoomPalette.panel.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quickPattern: RhythmPattern {
        if let plan = store.tempoPlans.last, let pattern = store.pattern(id: plan.patternID) { return pattern }
        return store.starterPatterns[0]
    }

    private var quickDetail: String {
        if let plan = store.tempoPlans.last, plan.patternID == quickPattern.id {
            return "Continue beats \(plan.segmentStart + 1)–\(plan.segmentEnd + 1) · saved on this device"
        }
        return "Included practice pattern · \(quickPattern.beatCells.count) beats · about 25 seconds"
    }
}

struct PrimaryLoomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(LoomPalette.navy)
            .background(LoomPalette.mint.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryLoomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 13)
            .background(LoomPalette.panel.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(LoomPalette.fog.opacity(0.4)))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
