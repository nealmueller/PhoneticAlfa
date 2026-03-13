import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds

enum AdMobConfiguration {
    static let bannerAdUnitID = "ca-app-pub-3833805309007689/5581815224"

    static var appID: String? {
        Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
    }

    static var isConfigured: Bool {
        guard let appID else { return false }
        return appID.hasPrefix("ca-app-pub-") && appID.contains("~")
    }
}
#endif

struct AdBannerContainer: View {
    @ObservedObject var monetization: MonetizationManager

    var body: some View {
        Group {
            if monetization.isAdFree {
                EmptyView()
            } else {
                VStack(spacing: 0) {
                    Divider()
                    AdBannerView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .systemBackground))
                }
                .accessibilityIdentifier("adBannerContainer")
            }
        }
    }
}

private struct AdBannerView: View {
    var body: some View {
        #if canImport(GoogleMobileAds)
        if AdMobConfiguration.isConfigured {
            GoogleAdMobBannerView()
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        } else {
            EmptyView()
        }
        #else
        VStack(spacing: 6) {
            Text("Ad")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("AdMob banner placeholder")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct GoogleAdMobBannerView: UIViewRepresentable {
    final class Coordinator {
        var didLoad = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let requestConfiguration = MobileAds.shared.requestConfiguration
        requestConfiguration.maxAdContentRating = .general

        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width))
        banner.adUnitID = AdMobConfiguration.bannerAdUnitID
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = UIApplication.shared.firstKeyWindow?.rootViewController
        }

        guard !context.coordinator.didLoad, uiView.rootViewController != nil else { return }
        uiView.load(Request())
        context.coordinator.didLoad = true
    }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
#endif
