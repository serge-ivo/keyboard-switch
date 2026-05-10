import AppKit

public enum StatusDotAttributedTitleBuilder {
    public static func build(_ presentation: StatusDotPresentation) -> NSAttributedString {
        let color: NSColor
        switch presentation.palette {
        case .connectedGreen:
            color = NSColor(srgbRed: 0.20, green: 0.82, blue: 0.33, alpha: 1.0)
        case .disconnectedWhite:
            color = .white
        }

        return NSAttributedString(
            string: presentation.symbol,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: presentation.fontSize),
                .strokeWidth: presentation.strokeWidth
            ]
        )
    }
}
