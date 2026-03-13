import Foundation
import Combine

enum QuizMode: String, CaseIterable, Identifiable {
    case visual
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visual:
            return "Visual"
        case .audio:
            return "Audio"
        }
    }
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let letter: Character
    let promptText: String
    let correctOption: String
    let options: [String]
}

struct QuizRoundResult: Codable, Identifiable {
    let id: UUID
    let date: Date
    let score: Int
    let accuracy: Double
    let averageResponseTime: Double
    let longestStreak: Int
    let mostMissedLetters: [String]

    init(id: UUID = UUID(), date: Date = Date(), score: Int, accuracy: Double, averageResponseTime: Double, longestStreak: Int, mostMissedLetters: [String]) {
        self.id = id
        self.date = date
        self.score = score
        self.accuracy = accuracy
        self.averageResponseTime = averageResponseTime
        self.longestStreak = longestStreak
        self.mostMissedLetters = mostMissedLetters
    }
}

struct QuizCardTrainingState: Codable {
    var familiarity: Double
    var averageResponseTime: Double
    var reviewCount: Int
    var correctCount: Int
    var incorrectCount: Int
    var nextReviewDate: Date
    var lastReviewedAt: Date?

    init(
        familiarity: Double = 0,
        averageResponseTime: Double = 0,
        reviewCount: Int = 0,
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        nextReviewDate: Date = .distantPast,
        lastReviewedAt: Date? = nil
    ) {
        self.familiarity = familiarity
        self.averageResponseTime = averageResponseTime
        self.reviewCount = reviewCount
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
    }
}

@MainActor
final class QuizHistoryStore: ObservableObject {
    @Published private(set) var pastResults: [QuizRoundResult] = []
    @Published private(set) var trainingStates: [String: QuizCardTrainingState] = [:]

    private let storageKey = "quiz_history_v1"
    private let trainingStorageKey = "quiz_training_v1"

    init() {
        load()
    }

    var bestResultID: UUID? {
        pastResults.max(by: { $0.score < $1.score })?.id
    }

    func add(_ result: QuizRoundResult) {
        pastResults.insert(result, at: 0)
        if pastResults.count > 50 {
            pastResults = Array(pastResults.prefix(50))
        }
        save()
    }

    func clear() {
        pastResults = []
        trainingStates = [:]
        save()
    }

    func trainingState(for letter: Character) -> QuizCardTrainingState {
        trainingStates[String(letter)] ?? QuizCardTrainingState()
    }

    func recordReview(letter: Character, wasCorrect: Bool, responseTime: Double, timedOut: Bool) {
        let key = String(letter)
        var state = trainingStates[key] ?? QuizCardTrainingState()
        state.reviewCount += 1
        state.lastReviewedAt = Date()

        if state.averageResponseTime == 0 {
            state.averageResponseTime = responseTime
        } else {
            state.averageResponseTime = (state.averageResponseTime * 0.72) + (responseTime * 0.28)
        }

        if wasCorrect {
            state.correctCount += 1
        } else {
            state.incorrectCount += 1
        }

        let latencyPenalty = max(0, responseTime - 1.1)
        let timeoutPenalty = timedOut ? 0.7 : 0
        let familiarityDelta = wasCorrect ? max(0.15, 0.8 - (latencyPenalty * 0.22)) : (-0.95 - timeoutPenalty)
        state.familiarity = max(0, min(8, state.familiarity + familiarityDelta))

        let secondsUntilReview: TimeInterval
        if wasCorrect {
            let intervalMultiplier = pow(1.9, state.familiarity)
            let responseAdjustment = max(0.55, 1.2 - min(0.5, latencyPenalty * 0.12))
            secondsUntilReview = min(60 * 60 * 24 * 45, (60 * 30) * intervalMultiplier * responseAdjustment)
        } else {
            secondsUntilReview = timedOut ? 60 * 8 : 60 * 14
        }

        state.nextReviewDate = Date().addingTimeInterval(secondsUntilReview)
        trainingStates[key] = state
        save()
    }

    func schedulingWeight(for letter: Character, now: Date = Date()) -> Double {
        let state = trainingState(for: letter)
        let dueBoost: Double
        if state.nextReviewDate <= now {
            dueBoost = 2.6
        } else {
            let timeUntilDue = state.nextReviewDate.timeIntervalSince(now)
            dueBoost = max(0.45, 1.2 - min(0.75, timeUntilDue / (60 * 60 * 24 * 4)))
        }

        let errorBoost = 1 + (Double(state.incorrectCount) * 0.22)
        let latencyBoost = 1 + max(0, state.averageResponseTime - 1.5) * 0.3
        let familiarityPenalty = max(0.4, 2.15 - (state.familiarity * 0.22))
        return dueBoost * errorBoost * latencyBoost * familiarityPenalty
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                pastResults = try JSONDecoder().decode([QuizRoundResult].self, from: data)
            } catch {
                pastResults = []
            }
        }

        if let trainingData = UserDefaults.standard.data(forKey: trainingStorageKey) {
            do {
                trainingStates = try JSONDecoder().decode([String: QuizCardTrainingState].self, from: trainingData)
            } catch {
                trainingStates = [:]
            }
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(pastResults)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Ignore save failures and keep runtime state.
        }

        do {
            let trainingData = try JSONEncoder().encode(trainingStates)
            UserDefaults.standard.set(trainingData, forKey: trainingStorageKey)
        } catch {
            // Ignore save failures and keep runtime state.
        }
    }
}
