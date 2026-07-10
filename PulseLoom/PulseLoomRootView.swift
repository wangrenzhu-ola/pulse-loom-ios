import SwiftUI

enum AppTab: Hashable {
    case home
    case library
    case history
    case settings
}

enum PracticeDestination: Identifiable {
    case countdown(PracticeSession)
    case review(AttemptContext)
    case premium

    var id: String {
        switch self {
        case let .countdown(session): return "countdown-\(session.id)"
        case let .review(context): return "review-\(context.attempt.id)"
        case .premium: return "premium"
        }
    }
}

struct PracticeSession: Identifiable {
    let id = UUID()
    let pattern: RhythmPattern
    let segment: ClosedRange<Int>?
    let parentAttemptID: UUID?
}

struct AttemptContext: Identifiable {
    let attempt: TapAttempt
    let pattern: RhythmPattern
    var persisted: Bool = true
    var id: UUID { attempt.id }
}

struct PulseLoomRootView: View {
    @EnvironmentObject private var store: PracticeStore
    @EnvironmentObject private var purchaseStore: PurchaseStore
    @State private var selectedTab: AppTab = .home
    @State private var destination: PracticeDestination?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeView(
                    startPractice: startQuickWeave,
                    showLibrary: { selectedTab = .library },
                    showPremium: { destination = .premium }
                )
            }
            .tabItem { Label("Today", systemImage: "waveform.path.ecg") }
            .tag(AppTab.home)

            NavigationView {
                PatternLibraryView(
                    startPractice: startPractice,
                    showPremium: { destination = .premium }
                )
            }
            .tabItem { Label("Patterns", systemImage: "rectangle.3.group") }
            .tag(AppTab.library)

            NavigationView {
                HistoryView(replay: replay, startPractice: startQuickWeave)
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.history)

            NavigationView {
                SettingsView(showPremium: { destination = .premium })
            }
            .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            .tag(AppTab.settings)
        }
        .accentColor(LoomPalette.mint)
        .sheet(item: $destination) { destination in
            switch destination {
            case let .countdown(session):
                CountdownView(session: session) { context in
                    self.destination = .review(context)
                }
            case let .review(context):
                AttemptReviewView(context: context, replay: replay)
            case .premium:
                PremiumSettingsView()
            }
        }
    }

    private func startQuickWeave() {
        if let plan = store.tempoPlans.last,
           let pattern = store.pattern(id: plan.patternID) {
            startPractice(pattern, plan.segmentStart...plan.segmentEnd, plan.lastAttemptID)
        } else if let pattern = store.starterPatterns.first {
            startPractice(pattern, nil, nil)
        }
    }

    private func startPractice(_ pattern: RhythmPattern, _ segment: ClosedRange<Int>? = nil, _ parentAttemptID: UUID? = nil) {
        if pattern.isPremium && !purchaseStore.isUnlocked {
            destination = .premium
            return
        }
        destination = .countdown(PracticeSession(pattern: pattern, segment: segment, parentAttemptID: parentAttemptID))
    }

    private func replay(_ context: AttemptContext) {
        startPractice(context.pattern, context.attempt.globalWeakSegment, context.attempt.id)
    }
}

enum LoomPalette {
    static let navy = Color(red: 0.035, green: 0.075, blue: 0.13)
    static let panel = Color(red: 0.08, green: 0.14, blue: 0.22)
    static let mint = Color(red: 0.36, green: 0.89, blue: 0.71)
    static let amber = Color(red: 0.98, green: 0.70, blue: 0.24)
    static let coral = Color(red: 0.96, green: 0.39, blue: 0.38)
    static let fog = Color(red: 0.63, green: 0.70, blue: 0.77)
}

struct LoomScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LoomPalette.navy.ignoresSafeArea()
            content
        }
        .foregroundColor(.white)
    }
}
