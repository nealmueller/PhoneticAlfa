import SwiftUI
import StoreKit
import UIKit

struct SettingsTabView: View {
    @AppStorage(AppPreferences.phoneticModeKey) private var phoneticModeRaw = PhoneticMode.nato.rawValue

    @ObservedObject var monetization: MonetizationManager
    @Environment(\.requestReview) private var requestReview

    private let appStoreURL = URL(string: "https://apps.apple.com/us/app/phonetic-alfa/id6757892845")
    private let appStoreReviewURL = URL(string: "itms-apps://itunes.apple.com/app/id6757892845?action=write-review")

    var body: some View {
        NavigationStack {
            List {
                Section("Alphabet") {
                    Picker("Readback Alphabet", selection: $phoneticModeRaw) {
                        ForEach(PhoneticMode.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if monetization.isAdFree {
                        Label("Ads removed", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task {
                                await monetization.purchaseRemoveAds(source: "settings")
                            }
                        } label: {
                            HStack {
                                Text("Remove Ads Forever")
                                Spacer()
                                Text(monetization.removeAdsProduct?.displayPrice ?? "$0.99")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button("Restore Purchase") {
                        Task {
                            await monetization.restorePurchases(source: "settings")
                        }
                    }

                    if let message = monetization.purchaseMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Ads")
                } footer: {
                    if monetization.isAdFree {
                        Text("Premium is unlocked for this Apple ID.")
                    } else {
                        Text("One-time purchase. Remove ads forever. Restorable with your Apple ID.")
                    }
                }

                Section {
                    Button("Rate in the App Store") {
                        requestReview()
                        if let writeReview = appStoreReviewURL {
                            UIApplication.shared.open(writeReview)
                        }
                    }

                    if let shareURL = appStoreURL {
                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button("Send Feedback") {
                        if let url = URL(string: "mailto:neal@nealmueller.com?subject=Phonetic%20Alfa%20Feedback") {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Support")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(AppTheme.gradientBackground.ignoresSafeArea())
            .listRowSpacing(10)
        }
    }
}
