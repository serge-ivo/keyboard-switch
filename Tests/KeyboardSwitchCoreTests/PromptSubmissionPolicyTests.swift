import XCTest
@testable import KeyboardSwitchCore

final class PromptSubmissionPolicyTests: XCTestCase {
    func testStrictPromptingRequiresOriginalFocusedElement() {
        XCTAssertTrue(PromptSubmissionPolicy.strictPrompting.requiresOriginalFocusedElement)
        XCTAssertTrue(PromptSubmissionPolicy.strictPrompting.restoresClipboard)
    }

    func testStrictPromptingSubmitsWithReturn() {
        XCTAssertEqual(PromptSubmissionPolicy.strictPrompting.submissionKey, .return)
    }
}
