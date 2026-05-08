public enum PromptSubmissionKey: String, Equatable, Sendable {
    case `return`
}

public struct PromptSubmissionPolicy: Equatable, Sendable {
    public let requiresOriginalFocusedElement: Bool
    public let restoresClipboard: Bool
    public let submissionKey: PromptSubmissionKey

    public init(
        requiresOriginalFocusedElement: Bool,
        restoresClipboard: Bool,
        submissionKey: PromptSubmissionKey
    ) {
        self.requiresOriginalFocusedElement = requiresOriginalFocusedElement
        self.restoresClipboard = restoresClipboard
        self.submissionKey = submissionKey
    }

    public static let strictPrompting = PromptSubmissionPolicy(
        requiresOriginalFocusedElement: true,
        restoresClipboard: true,
        submissionKey: .return
    )
}
