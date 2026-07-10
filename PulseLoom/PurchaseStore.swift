import Foundation
import StoreKit

@MainActor
final class PurchaseStore: ObservableObject {
    static let productID = "com.wangrenzhu.pulseloom.fullpractice"

    enum Availability: Equatable {
        case loading
        case ready
        case unavailable(String)
    }

    @Published private(set) var availability: Availability = .loading
    @Published private(set) var isUnlocked = false
    @Published var message: String?

    private let cacheKey = "PulseLoom.purchase-entitlement.v1"
    private var updatesTask: Task<Void, Never>?

    init() {
        if ProcessInfo.processInfo.arguments.contains("--reset-purchase-state") {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
        loadCache()
        if #available(iOS 15.0, *) {
            updatesTask = observeTransactions()
            Task {
                await refreshEntitlement()
                await loadProduct()
            }
        } else {
            availability = .unavailable("Purchases are temporarily unavailable on this version of iOS.")
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProduct() async {
        if ProcessInfo.processInfo.arguments.contains("--force-store-unavailable") {
            availability = .unavailable("Purchases are temporarily unavailable. Your free practice tools still work.")
            return
        }
        guard #available(iOS 15.0, *) else {
            availability = .unavailable("Purchases are temporarily unavailable on this version of iOS.")
            return
        }
        do {
            let products = try await Product.products(for: [Self.productID])
            if products.first != nil {
                availability = .ready
            } else {
                availability = .unavailable("Purchases are temporarily unavailable. No product is configured yet.")
            }
        } catch {
            availability = .unavailable("Purchases are temporarily unavailable. Please try again later.")
        }
    }

    func purchase() async {
        guard #available(iOS 15.0, *), case .ready = availability else {
            message = "Purchases are temporarily unavailable. Your free practice tools still work."
            return
        }
        do {
            guard let product = try await Product.products(for: [Self.productID]).first else {
                availability = .unavailable("Purchases are temporarily unavailable. No product is configured yet.")
                return
            }
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                await unlock(from: transaction)
                await transaction.finish()
                message = "Full Practice Library unlocked."
            case .success(.unverified):
                message = "We could not verify that purchase. Nothing was unlocked."
            case .pending:
                message = "Purchase is pending approval. Your free practice tools remain available."
            case .userCancelled:
                message = "Purchase cancelled."
            @unknown default:
                message = "Purchase did not complete. Please try again."
            }
        } catch {
            message = "Purchase failed. Please try again."
        }
    }

    func restore() async {
        guard #available(iOS 15.0, *) else {
            message = "Purchases are temporarily unavailable on this version of iOS."
            return
        }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            message = isUnlocked ? "Purchase restored." : "No previous purchase was found."
        } catch {
            message = "Could not restore purchases. Please try again."
        }
    }

    @available(iOS 15.0, *)
    private func observeTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                if transaction.revocationDate == nil {
                    await self?.unlock(from: transaction)
                } else {
                    await self?.refreshEntitlement()
                }
                await transaction.finish()
            }
        }
    }

    @available(iOS 15.0, *)
    private func refreshEntitlement() async {
        var foundActiveEntitlement = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            foundActiveEntitlement = true
        }
        isUnlocked = foundActiveEntitlement
        persistCache(isUnlocked: foundActiveEntitlement)
    }

    @available(iOS 15.0, *)
    private func unlock(from transaction: Transaction) async {
        guard transaction.productID == Self.productID else { return }
        isUnlocked = true
        persistCache(isUnlocked: true)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(PurchaseEntitlementCache.self, from: data),
              cache.productID == Self.productID else { return }
        isUnlocked = cache.isUnlocked
    }

    private func persistCache(isUnlocked: Bool) {
        let cache = PurchaseEntitlementCache(productID: Self.productID, isUnlocked: isUnlocked, verifiedAt: Date())
        if let data = try? JSONEncoder().encode(cache) { UserDefaults.standard.set(data, forKey: cacheKey) }
    }
}
