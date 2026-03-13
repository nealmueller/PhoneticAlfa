import SwiftUI

enum RootTab: Hashable {
    case flashcard
    case quiz
    case speak
    case settings
}

struct RootTabView: View {
    @AppStorage(AppPreferences.phoneticModeKey) private var phoneticModeRaw = PhoneticMode.nato.rawValue
    @AppStorage(AppPreferences.didChooseInitialModeKey) private var didChooseInitialMode = false
    @State private var selectedTab: RootTab = .flashcard
    @State private var flashcardVisitToken = 0
    @State private var showInitialModeChooser = false
    @StateObject private var monetization = MonetizationManager()
    @StateObject private var quizHistoryStore = QuizHistoryStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            tabContent {
                FlashcardTabView(visitToken: flashcardVisitToken)
            }
            .tabItem {
                Label("Flashcard", systemImage: "rectangle.on.rectangle")
            }
            .tag(RootTab.flashcard)

            tabContent {
                QuizTabView(historyStore: quizHistoryStore, monetization: monetization)
            }
            .tabItem {
                Label("Quiz", systemImage: "timer")
            }
            .tag(RootTab.quiz)

            tabContent {
                SpeakTabView()
            }
            .tabItem {
                Label("Speak", systemImage: "speaker.wave.2.fill")
            }
            .tag(RootTab.speak)

            tabContent {
                SettingsTabView(monetization: monetization)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(RootTab.settings)
        }
        .tint(AppTheme.accent)
        .toolbar(.visible, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            if selectedTab == .flashcard {
                flashcardVisitToken += 1
            }
            showInitialModeChooser = !didChooseInitialMode
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .flashcard else { return }
            flashcardVisitToken += 1
        }
        .sheet(isPresented: $showInitialModeChooser) {
            VStack(spacing: 20) {
                Spacer()

                Text("Choose Your Alphabet")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Pick a default mode for Flashcard, Quiz, and Speak.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button {
                        chooseInitialMode(.nato)
                    } label: {
                        VStack(spacing: 4) {
                            Text("NATO")
                                .font(.headline.weight(.bold))
                            Text("Alfa, Bravo, Charlie")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        chooseInitialMode(.lapd)
                    } label: {
                        VStack(spacing: 4) {
                            Text("LAPD")
                                .font(.headline.weight(.bold))
                            Text("Adam, Boy, Charles")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(24)
            .presentationDetents([.medium])
            .interactiveDismissDisabled(true)
        }
    }

    @ViewBuilder
    private func tabContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdBannerContainer(monetization: monetization)
            }
    }

    private func chooseInitialMode(_ mode: PhoneticMode) {
        phoneticModeRaw = mode.rawValue
        didChooseInitialMode = true
        showInitialModeChooser = false
    }
}
