import Foundation
import Combine
import StoreKit

@MainActor
final class MonetizationManager: ObservableObject {
    static let removeAdsProductID = "com.nealmueller.phonetic.removeads"

    @Published private(set) var isAdFree: Bool = false
    @Published private(set) var removeAdsProduct: Product?
    @Published var purchaseMessage: String?
    private let forceAdFree: Bool

    init() {
        let environment = ProcessInfo.processInfo.environment
        let simulatorDeviceName = environment["SIMULATOR_DEVICE_NAME"] ?? ""
        let simulatorPremiumOverride = simulatorDeviceName.localizedCaseInsensitiveContains("Premium")
        forceAdFree =
            environment["UITEST_FORCE_AD_FREE"] == "1" ||
            environment["SIM_FORCE_AD_FREE"] == "1" ||
            simulatorPremiumOverride

        if forceAdFree {
            isAdFree = true
            purchaseMessage = "Simulator premium override is enabled."
            return
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        guard !forceAdFree else { return }
        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            removeAdsProduct = products.first
            AppTelemetry.monetizationEvent(
                "products_loaded",
                detail: removeAdsProduct == nil ? "remove_ads_missing" : "remove_ads_found"
            )
        } catch {
            purchaseMessage = "Unable to load purchase options right now."
            AppTelemetry.monetizationEvent("products_load_failed", detail: "storekit_error")
        }
    }

    func purchaseRemoveAds(source: String = "unknown") async {
        AppTelemetry.monetizationEvent("purchase_tap", source: source)
        guard !forceAdFree else {
            purchaseMessage = "Premium simulator override is active."
            return
        }
        guard let product = removeAdsProduct else {
            purchaseMessage = "Remove Ads is not available yet."
            AppTelemetry.monetizationEvent("purchase_unavailable", source: source)
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    purchaseMessage = "Ads removed successfully."
                    AppTelemetry.monetizationEvent("purchase_success", source: source)
                case .unverified:
                    purchaseMessage = "Purchase could not be verified."
                    AppTelemetry.monetizationEvent("purchase_unverified", source: source)
                }
            case .userCancelled:
                purchaseMessage = nil
                AppTelemetry.monetizationEvent("purchase_cancelled", source: source)
            case .pending:
                purchaseMessage = "Purchase is pending approval."
                AppTelemetry.monetizationEvent("purchase_pending", source: source)
            @unknown default:
                purchaseMessage = "Unknown purchase state."
                AppTelemetry.monetizationEvent("purchase_unknown_state", source: source)
            }
        } catch {
            purchaseMessage = "Purchase failed. Please try again."
            AppTelemetry.monetizationEvent("purchase_failed", source: source, detail: "storekit_error")
        }
    }

    func restorePurchases(source: String = "unknown") async {
        AppTelemetry.monetizationEvent("restore_tap", source: source)
        guard !forceAdFree else {
            purchaseMessage = "Premium simulator override is active."
            return
        }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseMessage = isAdFree ? "Purchase restored." : "No prior purchase found."
            AppTelemetry.monetizationEvent(
                isAdFree ? "restore_success" : "restore_no_purchase",
                source: source
            )
        } catch {
            purchaseMessage = "Restore failed. Try again in a moment."
            AppTelemetry.monetizationEvent("restore_failed", source: source, detail: "storekit_error")
        }
    }

    func refreshEntitlements() async {
        guard !forceAdFree else {
            isAdFree = true
            return
        }
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID {
                unlocked = true
            }
        }
        isAdFree = unlocked
    }
}
