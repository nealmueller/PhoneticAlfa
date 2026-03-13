import SwiftUI

enum AppTheme {
    static let cardCornerRadius: CGFloat = 22
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let elevatedSurface = Color(uiColor: .systemBackground)
    static let accent = Color(red: 0.07, green: 0.40, blue: 0.66)
    static let backgroundTop = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
            }
            return UIColor(red: 0.95, green: 0.98, blue: 1.00, alpha: 1)
        }
    )
    static let backgroundBottom = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1)
            }
            return UIColor(red: 0.90, green: 0.95, blue: 0.99, alpha: 1)
        }
    )

    static var gradientBackground: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
