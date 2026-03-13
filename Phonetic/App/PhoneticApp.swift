import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct PhoneticApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var didInitializeAds = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    guard newPhase == .active else { return }
                    initializeAdsIfNeeded()
                }
        }
    }

    @MainActor
    private func initializeAdsIfNeeded() {
        #if canImport(GoogleMobileAds)
        guard !didInitializeAds, AdMobConfiguration.isConfigured else { return }
        didInitializeAds = true
        MobileAds.shared.start()
        #endif
    }
}
