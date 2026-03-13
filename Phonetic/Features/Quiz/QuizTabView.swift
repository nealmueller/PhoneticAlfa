import SwiftUI
import StoreKit

struct QuizTabView: View {
    @AppStorage(AppPreferences.phoneticModeKey) private var phoneticModeRaw = PhoneticMode.nato.rawValue

    @StateObject private var speechManager = SpeechManager()
    @StateObject private var viewModel: QuizViewModel
    @ObservedObject private var historyStore: QuizHistoryStore
    @ObservedObject private var monetization: MonetizationManager
    @State private var showingClearScoresConfirm = false
    @State private var lastTrackedCTAResultID: UUID?
    private let rewardSoundEffects = SoundEffectsManager()

    private var phoneticMode: PhoneticMode {
        AppPreferences.mode(from: phoneticModeRaw)
    }

    init(historyStore: QuizHistoryStore, monetization: MonetizationManager) {
        _historyStore = ObservedObject(wrappedValue: historyStore)
        _monetization = ObservedObject(wrappedValue: monetization)
        _viewModel = StateObject(wrappedValue: QuizViewModel(historyStore: historyStore))
    }

    var body: some View {
        Group {
            if viewModel.isRoundActive, let question = viewModel.currentQuestion, !viewModel.isRoundComplete {
                activeRoundView(question: question)
            } else {
                summaryView
            }
        }
        .background(AppTheme.gradientBackground.ignoresSafeArea())
        .onAppear {
            viewModel.phoneticMode = phoneticMode
            viewModel.startRound(questionCount: viewModel.questionsPerRound)
        }
        .onChange(of: phoneticModeRaw) { _, newValue in
            viewModel.phoneticMode = AppPreferences.mode(from: newValue)
            viewModel.startRound(questionCount: viewModel.questionsPerRound)
        }
        .onChange(of: viewModel.quizMode) { _, _ in
            viewModel.startRound(questionCount: viewModel.questionsPerRound)
        }
        .onChange(of: viewModel.timedQuizEnabled) { _, _ in
            viewModel.startRound(questionCount: viewModel.questionsPerRound)
        }
        .onChange(of: viewModel.secondsPerQuestion) { _, _ in
            viewModel.startRound(questionCount: viewModel.questionsPerRound)
        }
        .onChange(of: viewModel.questionsPerRound) { _, _ in
            viewModel.startRound(questionCount: viewModel.questionsPerRound)
        }
        .onChange(of: viewModel.hybridSRSEnabled) { _, _ in
            viewModel.startRound(questionCount: viewModel.questionsPerRound)
        }
        .onChange(of: viewModel.currentQuestion?.id) { _, _ in
            speakCurrentPromptIfNeeded()
        }
        .onChange(of: viewModel.quizMode) { _, _ in
            speakCurrentPromptIfNeeded()
        }
        .onChange(of: viewModel.revealCueID) { _, _ in
            speakRevealWordIfNeeded()
        }
        .onChange(of: viewModel.trophyCueID) { _, _ in
            rewardSoundEffects.playTrophy()
        }
        .onChange(of: viewModel.perfectScoreCueID) { _, _ in
            rewardSoundEffects.playPerfectScore()
        }
        .alert("Reset all quiz scores?", isPresented: $showingClearScoresConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                historyStore.clear()
            }
        } message: {
            Text("This clears past quiz scores and resets hybrid SRS training.")
        }
    }

    private func activeRoundView(question: QuizQuestion) -> some View {
        GeometryReader { proxy in
            let chromeHeight: CGFloat = viewModel.quizMode == .visual ? 320 : 292
            let buttonHeight = max(92, min(170, (proxy.size.height - chromeHeight) / 2))

            VStack(spacing: 10) {
                HStack {
                    Text("Quiz")
                        .font(.title2.weight(.bold))
                    Spacer()
                    if viewModel.timedQuizEnabled {
                        Text("\(max(0, Int(ceil(viewModel.pressureTimeRemaining))))s")
                            .font(.headline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(viewModel.pressureTimeRemaining < 1 ? .red : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                    }
                }

                VStack(spacing: 4) {
                    Text("Question \(viewModel.questionNumber + 1) of \(viewModel.totalQuestions)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Score \(viewModel.score) / \(viewModel.totalQuestions)")
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    quizStatCard(
                        title: "Correct",
                        value: viewModel.correctAnswers,
                        valueColor: .green
                    )
                    quizStatCard(
                        title: "Incorrect",
                        value: viewModel.incorrectAnswers,
                        valueColor: .red
                    )
                }

                if viewModel.quizMode == .visual {
                    Text(question.promptText)
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack {
                        Text("Audio Prompt")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button("Replay") {
                            speakCurrentPromptIfNeeded(force: true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { _, option in
                        answerButton(
                            option: option,
                            mode: viewModel.quizMode,
                            buttonHeight: buttonHeight,
                            isCorrectSelection: viewModel.highlightedCorrectOption == option,
                            isWrongSelection: viewModel.selectedIncorrectOption == option
                        )
                    }
                }
                .id(question.id)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .animation(nil, value: question.id)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(14)
            .cardStyle()
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func quizStatCard(title: String, value: Int, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quiz")
                    .font(.largeTitle.weight(.bold))

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Mode", selection: $viewModel.quizMode) {
                        ForEach(QuizMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button(viewModel.isRoundComplete ? "Start New Quiz" : "Start Quiz") {
                        viewModel.restartRoundAndBegin(questionCount: viewModel.questionsPerRound)
                    }
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .buttonStyle(.borderedProminent)

                    Toggle("Timed Quiz", isOn: $viewModel.timedQuizEnabled)
                        .font(.headline.weight(.semibold))

                    quizControlRow(
                        title: "Time pressure per question",
                        valueText: "\(viewModel.secondsPerQuestion)s"
                    ) {
                        Stepper(
                            value: Binding(
                                get: { viewModel.secondsPerQuestion },
                                set: { viewModel.updateSecondsPerQuestion($0) }
                            ),
                            in: 1...6,
                            step: 1
                        ) {
                            EmptyView()
                        }
                        .labelsHidden()
                        .disabled(!viewModel.timedQuizEnabled)
                    }

                    quizControlRow(
                        title: "Questions per quiz",
                        valueText: "\(viewModel.questionsPerRound)"
                    ) {
                        Stepper(
                            value: Binding(
                                get: { viewModel.questionsPerRound },
                                set: { viewModel.updateQuestionsPerRound($0) }
                            ),
                            in: 5...26,
                            step: 1
                        ) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Smart Review Mode", isOn: $viewModel.hybridSRSEnabled)
                        .font(.headline.weight(.semibold))

                    Text("This quiz shows up more often for letters you missed or took longer to answer. It uses a hybrid spaced repetition system (SRS) to bring weaker answers back sooner.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Link("What is spaced repetition?", destination: URL(string: "https://en.wikipedia.org/wiki/Spaced_repetition")!)
                        .font(.footnote.weight(.semibold))
                }
                .cardStyle()

                if viewModel.isRoundComplete, let result = viewModel.latestResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Round Summary")
                            .font(.headline)
                        Text("Total score: \(result.score)")
                        Text(String(format: "Accuracy: %.0f%%", result.accuracy * 100))
                        Text(String(format: "Avg response: %.2fs", result.averageResponseTime))
                        Text("Longest streak: \(result.longestStreak)")
                        Text("Most-missed: \(result.mostMissedLetters.joined(separator: ", ").isEmpty ? "None" : result.mostMissedLetters.joined(separator: ", "))")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    if shouldShowRemoveAdsCTA(for: result) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Keep your momentum")
                                .font(.headline)
                            Text("Go ad-free for uninterrupted quiz and flashcard sessions.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button {
                                Task {
                                    await monetization.purchaseRemoveAds(source: "quiz_summary")
                                }
                            } label: {
                                HStack {
                                    Text("Remove Ads Forever")
                                    Spacer()
                                    Text(monetization.removeAdsProduct?.displayPrice ?? "$0.99")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                        .onAppear {
                            guard lastTrackedCTAResultID != result.id else { return }
                            lastTrackedCTAResultID = result.id
                            AppTelemetry.monetizationEvent("quiz_cta_viewed", source: "quiz_summary")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Past Scores")
                            .font(.headline)
                        Spacer()
                        if !historyStore.pastResults.isEmpty {
                            Button("Reset") {
                                showingClearScoresConfirm = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                        }
                    }

                    if historyStore.pastResults.isEmpty {
                        Text("No rounds yet. Run your first quiz.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(historyStore.pastResults.prefix(8)) { entry in
                            HStack(spacing: 10) {
                                if historyStore.bestResultID == entry.id {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(.yellow)
                                } else {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(entry.score) pts")
                                        .font(.subheadline.weight(.semibold))
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.0f%%", entry.accuracy * 100))
                                    .font(.caption.weight(.medium))
                            }
                        }
                    }
                }
                .cardStyle()
            }
            .padding()
        }
    }

    private func quizControlRow<Control: View>(title: String, valueText: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(valueText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
    }

    private func answerButton(
        option: String,
        mode: QuizMode,
        buttonHeight: CGFloat,
        isCorrectSelection: Bool,
        isWrongSelection: Bool
    ) -> some View {
        Button {
            viewModel.submit(answer: option)
        } label: {
            ZStack {
                answerBackground
                Text(option)
                    .font(answerFont(for: mode))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.45)
                    .foregroundStyle(.white)
                    .padding(10)

                if isCorrectSelection {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 8)
                        Spacer()
                    }
                }
            }
            .overlay(answerBorder)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        isCorrectSelection ? Color.green.opacity(0.95) : (isWrongSelection ? Color.red.opacity(0.95) : .clear),
                        lineWidth: isCorrectSelection || isWrongSelection ? 4 : 0
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuizAnswerPressStyle())
        .scaleEffect(isCorrectSelection ? 1.03 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: isCorrectSelection)
        .transition(.identity)
    }

    private func answerFont(for mode: QuizMode) -> Font {
        let size: CGFloat = mode == .audio ? 56 : 30
        return .system(size: size, weight: .heavy, design: .rounded)
    }

    private var answerBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.56, blue: 0.80), Color(red: 0.10, green: 0.39, blue: 0.63)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var answerBorder: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
    }

    private func speakCurrentPromptIfNeeded(force: Bool = false) {
        guard viewModel.quizMode == .audio else { return }
        guard viewModel.isRoundActive || force else { return }
        viewModel.speakPromptIfNeeded { text in
            speechManager.speak(text)
        }
    }

    private func speakRevealWordIfNeeded() {
        guard viewModel.quizMode == .visual else { return }
        let word = viewModel.revealCorrectWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        speechManager.speak(word)
    }

    private func shouldShowRemoveAdsCTA(for result: QuizRoundResult) -> Bool {
        guard !monetization.isAdFree else { return false }
        let isBest = historyStore.bestResultID == result.id
        let isHighScore = result.score >= 8
        let isPerfect = result.score >= viewModel.totalQuestions
        return isBest || isHighScore || isPerfect
    }
}

private struct QuizAnswerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.07 : 0.14),
                radius: configuration.isPressed ? 4 : 10,
                y: configuration.isPressed ? 2 : 6
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
