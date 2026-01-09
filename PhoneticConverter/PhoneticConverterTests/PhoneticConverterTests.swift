import XCTest
@testable import PhoneticConverter

final class PhoneticConverterTests: XCTestCase {
    func testExampleYX623K73J3() {
        let input = "YX623K73J3"
        let expected = "Yankee Xray 6 2 3 Kilo 7 3 Juliet 3"
        XCTAssertEqual(PhoneticTranslator.translate(input), expected)
    }

    func testExampleDash() {
        let input = "A-B"
        let expected = "Alfa Dash Bravo"
        XCTAssertEqual(PhoneticTranslator.translate(input), expected)
    }

    func testExampleWithSpace() {
        let input = "AB 12"
        let expected = "Alfa Bravo 1 2"
        XCTAssertEqual(PhoneticTranslator.translate(input), expected)
    }

    func testExampleWithSlash() {
        let input = "A/B"
        let expected = "Alfa Bravo"
        XCTAssertEqual(PhoneticTranslator.translate(input), expected)
    }
}
