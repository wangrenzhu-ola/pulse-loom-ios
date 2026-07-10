import SwiftUI

struct PatternLibraryView: View {
    @EnvironmentObject private var store: PracticeStore
    @EnvironmentObject private var purchaseStore: PurchaseStore
    let startPractice: (RhythmPattern, ClosedRange<Int>?, UUID?) -> Void
    let showPremium: () -> Void
    @State private var editor: PatternEditorContext?
    @State private var patternToDelete: RhythmPattern?

    var body: some View {
        LoomScreen {
            List {
                Section {
                    Text("Included practice patterns are always free. Your custom patterns, timing ribbons, and weak-cell replay never require a purchase.")
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                        .listRowBackground(LoomPalette.panel)
                }

                Section(header: Text("Included")) {
                    ForEach(store.starterPatterns.filter { !$0.isPremium || purchaseStore.isUnlocked }) { pattern in
                        patternRow(pattern)
                    }
                    if !purchaseStore.isUnlocked {
                        Button(action: showPremium) {
                            Label("Full Practice Library", systemImage: "lock.fill")
                                .foregroundColor(LoomPalette.amber)
                        }
                        .listRowBackground(LoomPalette.panel)
                    }
                }

                Section(header: Text("My Patterns")) {
                    if store.customPatterns.isEmpty {
                        VStack(spacing: 14) {
                            EmptyLoomIllustration()
                            Text("No custom patterns yet")
                                .font(.headline)
                            Text("Weave a rhythm you want to practice, then save it here.")
                                .multilineTextAlignment(.center)
                                .font(.footnote)
                                .foregroundColor(LoomPalette.fog)
                            Button("Create your first pattern") { editor = .new }
                                .buttonStyle(SecondaryLoomButtonStyle())
                                .accessibilityIdentifier("create-first-pattern")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .listRowBackground(LoomPalette.panel)
                    } else {
                        ForEach(store.customPatterns) { pattern in
                            patternRow(pattern)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Pattern Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { editor = .new }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New pattern")
            }
        }
        .sheet(item: $editor) { context in
            PatternEditorView(context: context)
        }
        .alert(item: $patternToDelete) { pattern in
            Alert(
                title: Text("Delete \(pattern.name)?"),
                message: Text("This removes \(store.attempts.filter { $0.patternID == pattern.id }.count) linked practice attempts from this device."),
                primaryButton: .destructive(Text("Delete")) { _ = store.delete(pattern: pattern) },
                secondaryButton: .cancel(Text("Keep Pattern"))
            )
        }
    }

    @ViewBuilder
    private func patternRow(_ pattern: RhythmPattern) -> some View {
        NavigationLink(destination: PatternDetailView(pattern: pattern, startPractice: startPractice)) {
            HStack(spacing: 12) {
                MeterIcon(meter: pattern.meter)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.name)
                        .font(.headline)
                    Text("\(pattern.meter) · \(pattern.bpm) BPM · \(pattern.beatCells.count) beat cells")
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                    if pattern.isStarter {
                        Text("Included practice pattern")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(LoomPalette.mint)
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(LoomPalette.panel)
    }
}

struct PatternDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var store: PracticeStore
    let pattern: RhythmPattern
    let startPractice: (RhythmPattern, ClosedRange<Int>?, UUID?) -> Void
    @State private var editor: PatternEditorContext?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        LoomScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(pattern.name)
                        .font(.largeTitle.weight(.bold))
                    Text("\(pattern.meter) · \(pattern.bpm) BPM · \(pattern.beatCells.count) beat cells")
                        .font(.subheadline)
                        .foregroundColor(LoomPalette.fog)
                    BeatLoom(beatCells: pattern.sortedCells, completed: 0, activeIndex: nil)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LoomPalette.panel))
                    Button(action: { startPractice(pattern, nil, nil) }) {
                        Label("Start practice", systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(PrimaryLoomButtonStyle())
                    if !pattern.isStarter {
                        Button("Edit pattern") { editor = .edit(pattern) }
                            .buttonStyle(SecondaryLoomButtonStyle())
                        Button("Delete pattern") { showingDeleteConfirmation = true }
                            .buttonStyle(SecondaryLoomButtonStyle())
                            .foregroundColor(LoomPalette.coral)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Pattern")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { context in PatternEditorView(context: context) }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete \(pattern.name)?"),
                message: Text("This removes \(store.attempts.filter { $0.patternID == pattern.id }.count) linked practice attempts and its saved tempo plan from this device."),
                primaryButton: .destructive(Text("Delete")) {
                    if store.delete(pattern: pattern) { presentationMode.wrappedValue.dismiss() }
                },
                secondaryButton: .cancel(Text("Keep Pattern"))
            )
        }
    }
}

enum PatternEditorContext: Identifiable {
    case new
    case edit(RhythmPattern)

    var id: UUID {
        switch self {
        case .new: return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case let .edit(pattern): return pattern.id
        }
    }
}
