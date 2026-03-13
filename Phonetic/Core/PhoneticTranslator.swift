import Foundation

enum PhoneticMode: String, CaseIterable, Identifiable, Codable {
    case nato
    case lapd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nato:
            return "NATO"
        case .lapd:
            return "LAPD"
        }
    }

    fileprivate var alphabetMap: [Character: String] {
        switch self {
        case .nato:
            return PhoneticTranslator.natoMap
        case .lapd:
            return PhoneticTranslator.lapdMap
        }
    }
}

struct PhoneticTranslator {
    fileprivate static let natoMap: [Character: String] = [
        "A": "Alfa",
        "B": "Bravo",
        "C": "Charlie",
        "D": "Delta",
        "E": "Echo",
        "F": "Foxtrot",
        "G": "Golf",
        "H": "Hotel",
        "I": "India",
        "J": "Juliet",
        "K": "Kilo",
        "L": "Lima",
        "M": "Mike",
        "N": "November",
        "O": "Oscar",
        "P": "Papa",
        "Q": "Quebec",
        "R": "Romeo",
        "S": "Sierra",
        "T": "Tango",
        "U": "Uniform",
        "V": "Victor",
        "W": "Whiskey",
        "X": "Xray",
        "Y": "Yankee",
        "Z": "Zulu"
    ]

    fileprivate static let lapdMap: [Character: String] = [
        "A": "Adam",
        "B": "Boy",
        "C": "Charles",
        "D": "David",
        "E": "Edward",
        "F": "Frank",
        "G": "George",
        "H": "Henry",
        "I": "Ida",
        "J": "John",
        "K": "King",
        "L": "Lincoln",
        "M": "Mary",
        "N": "Nora",
        "O": "Ocean",
        "P": "Paul",
        "Q": "Queen",
        "R": "Robert",
        "S": "Sam",
        "T": "Tom",
        "U": "Union",
        "V": "Victor",
        "W": "William",
        "X": "Xray",
        "Y": "Young",
        "Z": "Zebra"
    ]

    static func translate(_ input: String, mode: PhoneticMode = .nato) -> String {
        var tokens: [String] = []
        for rawChar in input.uppercased() {
            if rawChar == " " {
                continue
            }
            if rawChar == "-" {
                tokens.append("Dash")
                continue
            }
            if let word = mode.alphabetMap[rawChar] {
                tokens.append(word)
                continue
            }
            if rawChar.isNumber {
                tokens.append(String(rawChar))
                continue
            }
        }
        return tokens.joined(separator: " ")
    }

    static func phoneticWord(for letter: Character, mode: PhoneticMode) -> String {
        let normalized = Character(String(letter).uppercased())
        return mode.alphabetMap[normalized] ?? String(normalized)
    }

    static func allLetterPairs(mode: PhoneticMode) -> [(letter: Character, word: String)] {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return letters.compactMap { letter in
            guard let word = mode.alphabetMap[letter] else {
                return nil
            }
            return (letter, word)
        }
    }
}
