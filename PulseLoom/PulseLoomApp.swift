import SwiftUI

@main
struct PulseLoomApp: App {
    @StateObject private var store = PracticeStore()
    @StateObject private var purchaseStore = PurchaseStore()

    var body: some Scene {
        WindowGroup {
            PulseLoomRootView()
                .environmentObject(store)
                .environmentObject(purchaseStore)
                .preferredColorScheme(.dark)
        }
    }
}

