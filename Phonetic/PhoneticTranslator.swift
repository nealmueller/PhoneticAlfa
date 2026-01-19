import Foundation

struct PhoneticTranslator {
    private static let natoMap: [Character: String] = [
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

    static func translate(_ input: String) -> String {
        var tokens: [String] = []
        for rawChar in input.uppercased() {
            if rawChar == " " {
                continue
            }
            if rawChar == "-" {
                tokens.append("Dash")
                continue
            }
            if let word = natoMap[rawChar] {
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
}
