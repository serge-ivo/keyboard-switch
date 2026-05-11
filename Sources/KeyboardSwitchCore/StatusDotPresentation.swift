import Foundation

public enum StatusDotPalette: String, Equatable, Sendable {
    case connectedGreen
    case disconnectedGray
}

public enum StatusDotRenderer: String, Equatable, Sendable {
    case attributedTitle
}

public struct StatusDotPresentation: Equatable, Sendable {
    public let width: Double
    public let renderer: StatusDotRenderer
    public let symbol: String
    public let fontSize: Double
    public let strokeWidth: Double
    public let palette: StatusDotPalette
    public let toolTip: String

    public init(
        width: Double,
        renderer: StatusDotRenderer,
        symbol: String,
        fontSize: Double,
        strokeWidth: Double,
        palette: StatusDotPalette,
        toolTip: String
    ) {
        self.width = width
        self.renderer = renderer
        self.symbol = symbol
        self.fontSize = fontSize
        self.strokeWidth = strokeWidth
        self.palette = palette
        self.toolTip = toolTip
    }
}

public enum StatusDotPresenter {
    public static func presentation(deviceName: String, connected: Bool) -> StatusDotPresentation {
        StatusDotPresentation(
            width: 26,
            renderer: .attributedTitle,
            symbol: "●",
            fontSize: 17,
            strokeWidth: -3,
            palette: connected ? .connectedGreen : .disconnectedGray,
            toolTip: connected ? "\(deviceName) connected" : "\(deviceName) not connected"
        )
    }
}
