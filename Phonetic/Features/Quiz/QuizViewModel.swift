import Foundation
import Combine

@MainActor
final class QuizViewModel: ObservableObject {
    private static let secondsRange = 1...6
    private static let questionRange = 5...26
    private static let answerRevealDelay: TimeInterval = 0.24

    @Published var phoneticMode: PhoneticMode = .nato
    @Published var quizMode: QuizMode = .visual
    @Published var timedQuizEnabled: Bool {
        didSet {
            UserDefaults.standard.set(timedQuizEnabled, forKey: AppPreferences.timedQuizEnabledKey)
            if isRoundActive {
                configurePressureTimer()
            }
        }
    }
    @Published var secondsPerQuestion: Int {
        didSet {
            UserDefaults.standard.set(secondsPerQuestion, forKey: AppPreferences.timedQuizSecondsKey)
            if isRoundActive {
                configurePressureTimer()
            }
        }
    }
    @Published var questionsPerRound: Int {
        didSet {
            UserDefaults.standard.set(questionsPerRound, forKey: AppPreferences.quizQuestionCountKey)
        }
    }
    @Published var hybridSRSEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hybridSRSEnabled, forKey: AppPreferences.quizSRSEnabledKey)
        }
    }
    @Published private(set) var pressureTimeRemaining: Double = 0
    @Published private(set) var currentQuestion: QuizQuestion?
    @Published private(set) var questionNumber: Int = 0
    @Published private(set) var totalQuestions: Int = 10
    @Published private(set) var score: Int = 0
    @Published private(set) var streak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var correctAnswers: Int = 0
    @Published private(set) var incorrectAnswers: Int = 0
    @Published private(set) var isRoundComplete: Bool = false
    @Published private(set) var latestResult: QuizRoundResult?
    @Published private(set) var isRoundActive: Bool = false
    @Published private(set) var revealCueID: Int = 0
    @Published private(set) var revealCorrectWord: String = ""
    @Published private(set) var highlightedCorrectOption: String?
    @Published private(set) var selectedIncorrectOption: String?
    @Published private(set) var trophyCueID: Int = 0
    @Published private(set) var perfectScoreCueID: Int = 0

    private var rng = SystemRandomNumberGenerator()
    private var askedLetters: [Character] = []
    private var correctCount = 0
    private var totalResponseTime: Double = 0
    private var questionStartedAt = Date()
    private var missedCounts: [Character: Int] = [:]
    private var isAwaitingTransition = false
    private var pressureTimerTask: Task<Void, Never>?

    private static let visualDistractorsByInitial: [Character: [String]] = [
        "A": ["Anchor", "Arrow", "Atom", "Apex", "Amber", "Action", "Archer", "Atlas"],
        "B": ["Boy", "Big", "Bean", "Baker", "Beacon", "Bullet", "Bandit", "Bongo"],
        "C": ["Cable", "Cannon", "Cedar", "Cobalt", "Comet", "Cobra", "Cactus", "Carbon"],
        "D": ["Delta", "Dynamo", "Dagger", "Drift", "Doctor", "Dancer", "Domino", "Dragon"],
        "E": ["Echo", "Eagle", "Ember", "Engine", "Eden", "Empire", "Element", "Escort"],
        "F": ["Falcon", "Fable", "Fiber", "Forest", "Frost", "Fusion", "Figure", "Fjord"],
        "G": ["Gamma", "Giant", "Glider", "Garden", "Grove", "Guitar", "Galaxy", "Garnet"],
        "H": ["Harbor", "Hazel", "Helix", "Hunter", "Hammer", "Horizon", "Honey", "Hector"],
        "I": ["Icicle", "Icon", "Iris", "Ivory", "Impact", "Indigo", "Iron", "Island"],
        "J": ["Jasper", "Joker", "Jungle", "Javelin", "Jet", "Jigsaw", "Jewel", "Jacket"],
        "K": ["Kilo", "Kernel", "Knight", "Kite", "Kingdom", "Keystone", "Kodiak", "Karma"],
        "L": ["Laser", "Lemon", "Legend", "Lunar", "Lighthouse", "Locket", "Lava", "Logic"],
        "M": ["Matrix", "Mango", "Meteor", "Motion", "Monarch", "Marble", "Magnet", "Mission"],
        "N": ["Nova", "Nectar", "Nimbus", "Noble", "Needle", "Nation", "Nickel", "Ninja"],
        "O": ["Orbit", "Olive", "Omega", "Origin", "Osprey", "Opal", "Orange", "Onyx"],
        "P": ["Pilot", "Pixel", "Pluto", "Panda", "Pioneer", "Prism", "Pocket", "Pulse"],
        "Q": ["Quartz", "Quest", "Quick", "Quiver", "Quantum", "Quiet", "Quill", "Queen"],
        "R": ["Radar", "Ranger", "Rocket", "River", "Raven", "Ruby", "Rhythm", "Rescue"],
        "S": ["Saber", "Signal", "Solar", "Sierra", "Silver", "Summit", "Shadow", "Sonic"],
        "T": ["Tango", "Tiger", "Titan", "Token", "Topaz", "Transit", "Tunnel", "Tempest"],
        "U": ["Ultra", "Union", "Umbra", "Urban", "Uplink", "Utopia", "Utility", "Unit"],
        "V": ["Vector", "Velvet", "Vortex", "Voyage", "Vivid", "Valley", "Victor", "Violet"],
        "W": ["Whiskey", "Willow", "Wizard", "Walker", "Window", "Wave", "Winter", "Warden"],
        "X": ["Xray", "Xenon", "Xylo", "Xplorer", "Xtreme", "Xenial", "Xerox", "Xyst"],
        "Y": ["Yankee", "Yellow", "Yonder", "Yukon", "Yard", "Yodel", "Yarrow", "Yeti"],
        "Z": ["Zulu", "Zebra", "Zephyr", "Zodiac", "Zenith", "Zinger", "Zone", "Zest"]
    ]

    private let historyStore: QuizHistoryStore
    private let soundEffects = SoundEffectsManager()

    init(historyStore: QuizHistoryStore) {
        self.historyStore = historyStore
        timedQuizEnabled = UserDefaults.standard.object(forKey: AppPreferences.timedQuizEnabledKey) as? Bool ?? false
        let storedSeconds = UserDefaults.standard.integer(forKey: AppPreferences.timedQuizSecondsKey)
        secondsPerQuestion = Self.clampSeconds(storedSeconds == 0 ? 2 : storedSeconds)
        let storedQuestionCount = UserDefaults.standard.integer(forKey: AppPreferences.quizQuestionCountKey)
        questionsPerRound = Self.clampQuestionCount(storedQuestionCount == 0 ? 10 : storedQuestionCount)
        hybridSRSEnabled = UserDefaults.standard.object(forKey: AppPreferences.quizSRSEnabledKey) as? Bool ?? false
        startRound(questionCount: questionsPerRound)
    }

    func updateSecondsPerQuestion(_ value: Int) {
        let clamped = Self.clampSeconds(value)
        guard clamped != secondsPerQuestion else { return }
        secondsPerQuestion = clamped
    }

    func updateQuestionsPerRound(_ value: Int) {
        let clamped = Self.clampQuestionCount(value)
        guard clamped != questionsPerRound else { return }
        questionsPerRound = clamped
    }

    func startRound(questionCount: Int? = nil) {
        stopPressureTimer()
        totalQuestions = questionCount ?? questionsPerRound
        questionNumber = 0
        score = 0
        streak = 0
        longestStreak = 0
        correctAnswers = 0
        incorrectAnswers = 0
        correctCount = 0
        totalResponseTime = 0
        askedLetters = []
        missedCounts = [:]
        isRoundComplete = false
        latestResult = nil
        isRoundActive = false
        currentQuestion = nil
        revealCorrectWord = ""
        revealCueID = 0
        highlightedCorrectOption = nil
        selectedIncorrectOption = nil
        isAwaitingTransition = false
    }

    func beginRound() {
        guard !isRoundActive else { return }
        isRoundActive = true
        loadNextQuestion()
    }

    func restartRoundAndBegin(questionCount: Int? = nil) {
        startRound(questionCount: questionCount ?? questionsPerRound)
        beginRound()
    }

    func submit(answer: String) {
        guard let question = currentQuestion, !isRoundComplete, isRoundActive, !isAwaitingTransition else { return }
        stopPressureTimer()

        let responseTime = Date().timeIntervalSince(questionStartedAt)
        totalResponseTime += responseTime
        questionNumber += 1

        let isCorrect = answer == question.correctOption
        historyStore.recordReview(letter: question.letter, wasCorrect: isCorrect, responseTime: responseTime, timedOut: false)

        if quizMode == .visual {
            emitReveal(word: question.correctOption)
        }

        if isCorrect {
            correctCount += 1
            correctAnswers += 1
            streak += 1
            longestStreak = max(longestStreak, streak)
            score += 1
            if quizMode == .visual {
                soundEffects.playCorrect()
            }
        } else {
            incorrectAnswers += 1
            streak = 0
            missedCounts[question.letter, default: 0] += 1
            if quizMode == .visual {
                soundEffects.playIncorrect()
            }
        }

        highlightedCorrectOption = question.correctOption
        selectedIncorrectOption = isCorrect ? nil : answer
        isAwaitingTransition = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.answerRevealDelay) { [weak self] in
            guard let self else { return }
            self.highlightedCorrectOption = nil
            self.selectedIncorrectOption = nil
            self.isAwaitingTransition = false
            self.advanceOrCompleteRound()
        }
    }

    func speakPromptIfNeeded(_ onSpeak: (String) -> Void) {
        guard quizMode == .audio, let question = currentQuestion else { return }
        onSpeak(question.promptText)
    }

    private func loadNextQuestion() {
        let letter = nextLetter()
        if !hybridSRSEnabled {
            askedLetters.append(letter)
        }
        highlightedCorrectOption = nil
        selectedIncorrectOption = nil

        let correctWord = PhoneticTranslator.phoneticWord(for: letter, mode: phoneticMode)
        switch quizMode {
        case .visual:
            let options = buildWordOptions(for: letter, correctWord: correctWord)
            currentQuestion = QuizQuestion(
                letter: letter,
                promptText: String(letter),
                correctOption: correctWord,
                options: options.shuffled(using: &rng)
            )
        case .audio:
            let options = buildLetterOptions(for: letter)
            currentQuestion = QuizQuestion(
                letter: letter,
                promptText: correctWord,
                correctOption: String(letter),
                options: options.shuffled(using: &rng)
            )
        }
        questionStartedAt = Date()
        configurePressureTimer()
    }

    private func nextLetter() -> Character {
        hybridSRSEnabled ? weightedLetter() : randomLetter()
    }

    private func randomLetter() -> Character {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        if askedLetters.count >= letters.count {
            askedLetters.removeAll()
        }
        let available = letters.filter { !askedLetters.contains($0) }
        return available.randomElement(using: &rng) ?? letters[0]
    }

    private func weightedLetter() -> Character {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let weightedLetters = letters.map { ($0, historyStore.schedulingWeight(for: $0)) }
        let totalWeight = weightedLetters.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return letters.randomElement(using: &rng) ?? "A" }

        var threshold = Double.random(in: 0..<totalWeight, using: &rng)
        for (letter, weight) in weightedLetters {
            threshold -= weight
            if threshold <= 0 {
                return letter
            }
        }
        return weightedLetters.last?.0 ?? "A"
    }

    private func buildWordOptions(for letter: Character, correctWord: String) -> [String] {
        let initial = Character(String(correctWord.prefix(1)).uppercased())
        var candidates = Set<String>([correctWord])
        let pool = Self.visualDistractorsByInitial[initial] ?? []

        for candidate in pool.shuffled(using: &rng) {
            guard candidates.count < 4 else { break }
            guard candidate.caseInsensitiveCompare(correctWord) != .orderedSame else { continue }
            let lowerCandidate = candidate.lowercased()
            let lowerCorrect = correctWord.lowercased()
            guard !lowerCandidate.hasPrefix(String(lowerCorrect.prefix(3))),
                  !lowerCorrect.hasPrefix(String(lowerCandidate.prefix(3))) else {
                continue
            }
            candidates.insert(candidate)
        }

        if candidates.count < 4 {
            for candidate in pool.shuffled(using: &rng) {
                guard candidates.count < 4 else { break }
                guard candidate.caseInsensitiveCompare(correctWord) != .orderedSame else { continue }
                candidates.insert(candidate)
            }
        }

        while candidates.count < 4 {
            candidates.insert("\(initial)word")
        }

        return Array(candidates.prefix(4))
    }

    private func buildLetterOptions(for letter: Character) -> [String] {
        var options = Set<String>()
        options.insert(String(letter))

        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        while options.count < 4 {
            if let randomLetter = letters.randomElement(using: &rng) {
                options.insert(String(randomLetter))
            }
        }

        return Array(options)
    }

    private func completeRound() {
        stopPressureTimer()
        isRoundComplete = true
        isRoundActive = false
        let accuracy = questionNumber == 0 ? 0 : Double(correctCount) / Double(questionNumber)
        let average = questionNumber == 0 ? 0 : totalResponseTime / Double(questionNumber)
        let mostMissed = missedCounts.sorted { lhs, rhs in lhs.value > rhs.value }
            .prefix(3)
            .map { String($0.key) }

        let result = QuizRoundResult(
            score: score,
            accuracy: accuracy,
            averageResponseTime: average,
            longestStreak: longestStreak,
            mostMissedLetters: mostMissed
        )
        latestResult = result
        historyStore.add(result)

        let bestScore = historyStore.pastResults.map(\.score).max() ?? result.score
        if result.score >= bestScore {
            trophyCueID += 1
        }
        if result.score == totalQuestions {
            perfectScoreCueID += 1
        }
    }

    private func configurePressureTimer() {
        stopPressureTimer()
        guard timedQuizEnabled, isRoundActive else {
            pressureTimeRemaining = 0
            return
        }

        let limit = Double(secondsPerQuestion)
        pressureTimeRemaining = limit
        pressureTimerTask = Task { [weak self] in
            guard let self else { return }
            let start = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                let remaining = max(0, limit - elapsed)
                self.pressureTimeRemaining = remaining
                if remaining <= 0 {
                    self.handlePressureTimeout()
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func stopPressureTimer() {
        pressureTimerTask?.cancel()
        pressureTimerTask = nil
        pressureTimeRemaining = 0
    }

    private func handlePressureTimeout() {
        guard timedQuizEnabled, !isRoundComplete, isRoundActive else { return }
        if let question = currentQuestion {
            missedCounts[question.letter, default: 0] += 1
            questionNumber += 1
            totalResponseTime += Double(secondsPerQuestion)
            incorrectAnswers += 1
            historyStore.recordReview(
                letter: question.letter,
                wasCorrect: false,
                responseTime: Double(secondsPerQuestion),
                timedOut: true
            )
            if quizMode == .visual {
                emitReveal(word: question.correctOption)
            }
            highlightedCorrectOption = question.correctOption
            selectedIncorrectOption = nil
        }
        streak = 0
        if quizMode == .visual {
            soundEffects.playIncorrect()
        }
        isAwaitingTransition = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.answerRevealDelay) { [weak self] in
            guard let self else { return }
            self.highlightedCorrectOption = nil
            self.selectedIncorrectOption = nil
            self.isAwaitingTransition = false
            self.advanceOrCompleteRound()
        }
    }

    private func emitReveal(word: String) {
        revealCorrectWord = word
        revealCueID += 1
    }

    private func advanceOrCompleteRound() {
        if questionNumber >= totalQuestions {
            completeRound()
        } else {
            loadNextQuestion()
        }
    }

    private static func clampSeconds(_ value: Int) -> Int {
        min(max(value, secondsRange.lowerBound), secondsRange.upperBound)
    }

    private static func clampQuestionCount(_ value: Int) -> Int {
        min(max(value, questionRange.lowerBound), questionRange.upperBound)
    }
}
