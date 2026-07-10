import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: PracticeStore
    let replay: (AttemptContext) -> Void
    let startPractice: () -> Void

    var body: some View {
        LoomScreen {
            Group {
                if store.attempts.isEmpty {
                    VStack(spacing: 14) {
                        EmptyLoomIllustration()
                        Text("No timing reviews yet")
                            .font(.headline)
                        Text("Finish a Quick Weave to keep a local timing ribbon here.")
                            .font(.footnote)
                            .foregroundColor(LoomPalette.fog)
                        Button(action: startPractice) {
                            Label("Start Quick Weave", systemImage: "play.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PrimaryLoomButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(30)
                } else {
                    List(store.attempts) { attempt in
                        if let pattern = store.pattern(id: attempt.patternID) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(pattern.name).font(.headline)
                                    Spacer()
                                    Text("\(attempt.stability)% stable")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(LoomPalette.mint)
                                }
                                TimingRibbon(deviations: attempt.deviationsMs, highlightedRange: attempt.weakSegment)
                                HStack {
                                    Button(action: { replay(AttemptContext(attempt: attempt, pattern: pattern)) }) {
                                        Label("Replay beats \(attempt.globalWeakSegment.lowerBound + 1)–\(attempt.globalWeakSegment.upperBound + 1)", systemImage: "arrow.counterclockwise")
                                            .frame(minHeight: 44)
                                    }
                                    Spacer()
                                    Button(action: { _ = store.delete(attempt: attempt) }) {
                                        Image(systemName: "trash")
                                            .frame(minWidth: 44, minHeight: 44)
                                            .foregroundColor(LoomPalette.coral)
                                    }
                                    .accessibilityLabel("Delete timing review for \(pattern.name)")
                                }
                            }
                            .listRowBackground(LoomPalette.panel)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle("Practice History")
    }
}

struct SettingsView: View {
    @AppStorage("PulseLoom.haptics-enabled") private var hapticsEnabled = true
    let showPremium: () -> Void

    var body: some View {
        LoomScreen {
            List {
                Section(header: Text("Practice")) {
                    Toggle("Haptic pulse", isOn: $hapticsEnabled)
                        .accentColor(LoomPalette.mint)
                    Text("Visual timing always remains available, including when Reduce Motion is enabled.")
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                }
                .listRowBackground(LoomPalette.panel)

                Section(header: Text("Full Practice Library")) {
                    Button(action: showPremium) {
                        Label("Unlock advanced packs", systemImage: "lock.open")
                    }
                    .listRowBackground(LoomPalette.panel)
                }

                Section(header: Text("Privacy")) {
                    NavigationLink(destination: PrivacyView()) {
                        Label("Local-only practice data", systemImage: "hand.tap")
                    }
                    .listRowBackground(LoomPalette.panel)
                }

                Section(header: Text("About")) {
                    Text("Pulse Loom 1.0.0 · English (United States)")
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                        .listRowBackground(LoomPalette.panel)
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Settings")
    }
}

struct PremiumSettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var purchaseStore: PurchaseStore

    var body: some View {
        NavigationView {
            LoomScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Image(systemName: purchaseStore.isUnlocked ? "checkmark.seal.fill" : "waveform.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(purchaseStore.isUnlocked ? LoomPalette.mint : LoomPalette.amber)
                        Text(purchaseStore.isUnlocked ? "Full Practice Library unlocked" : "Full Practice Library")
                            .font(.largeTitle.weight(.bold))
                        Text("Unlock advanced syncopation and compound-meter packs. Starter patterns, custom patterns, Timing Ribbon, and Weak-Cell Replay stay free forever.")
                            .font(.body)
                            .foregroundColor(LoomPalette.fog)
                        featureRow("Advanced pattern packs", icon: "square.grid.2x2")
                        featureRow("Verified non-consumable unlock", icon: "checkmark.shield")
                        featureRow("Restore purchases on this Apple ID", icon: "arrow.clockwise")
                        purchaseControls
                        if let message = purchaseStore.message {
                            Text(message)
                                .font(.footnote)
                                .foregroundColor(LoomPalette.fog)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LoomPalette.panel))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Premium")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { presentationMode.wrappedValue.dismiss() } } }
        }
    }

    @ViewBuilder
    private var purchaseControls: some View {
        if purchaseStore.isUnlocked {
            Label("Unlocked on this device", systemImage: "checkmark.circle.fill")
                .foregroundColor(LoomPalette.mint)
        } else {
            switch purchaseStore.availability {
            case .loading:
                ProgressView("Checking purchases…")
                    .accentColor(LoomPalette.mint)
            case .ready:
                Button("Unlock Full Practice Library") { Task { await purchaseStore.purchase() } }
                    .buttonStyle(PrimaryLoomButtonStyle())
            case let .unavailable(reason):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Purchases are temporarily unavailable", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(LoomPalette.amber)
                    Text(reason)
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                    Button("Try again") { Task { await purchaseStore.loadProduct() } }
                        .buttonStyle(SecondaryLoomButtonStyle())
                }
            }
            if #available(iOS 15.0, *) {
                Button("Restore purchases") { Task { await purchaseStore.restore() } }
                    .buttonStyle(SecondaryLoomButtonStyle())
            }
        }
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(.vertical, 4)
    }
}

struct PrivacyView: View {
    var body: some View {
        LoomScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 42))
                        .foregroundColor(LoomPalette.mint)
                    Text("Your practice stays here.")
                        .font(.largeTitle.weight(.bold))
                    privacyItem("What Pulse Loom stores", "Your pattern names, touch-timing results, timing ribbons, weak-cell plans, and a verified purchase cache are stored on this device.")
                    privacyItem("What Pulse Loom does not use", "No microphone, audio recording, camera, account, cloud sync, AI coach, chat, or online practice profile is used in this version.")
                    privacyItem("Why timing is local", "Timing feedback comes from the taps you make on screen. It does not need sound or an internet connection.")
                    Text("You can delete custom patterns and their linked attempts from Pattern Library at any time.")
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                }
                .padding(20)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyItem(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundColor(LoomPalette.fog)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LoomPalette.panel))
    }
}
