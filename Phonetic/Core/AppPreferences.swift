import Foundation

enum AppPreferences {
    static let phoneticModeKey = "phonetic_mode"
    static let didChooseInitialModeKey = "did_choose_initial_mode"
    static let didDismissFlashcardSwipeHintKey = "did_dismiss_flashcard_swipe_hint"
    static let flashcardSwipeHintSeenCountKey = "flashcard_swipe_hint_seen_count"
    static let timedQuizEnabledKey = "timed_quiz_enabled"
    static let timedQuizSecondsKey = "timed_quiz_seconds"
    static let quizQuestionCountKey = "quiz_question_count"
    static let quizSRSEnabledKey = "quiz_srs_enabled"

    static func mode(from rawValue: String) -> PhoneticMode {
        PhoneticMode(rawValue: rawValue) ?? .nato
    }
}
