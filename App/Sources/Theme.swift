import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.035, green: 0.067, blue: 0.063)
    static let sidebar = Color(red: 0.045, green: 0.087, blue: 0.079)
    static let surface = Color(red: 0.068, green: 0.112, blue: 0.101)
    static let elevated = Color(red: 0.086, green: 0.139, blue: 0.123)
    static let border = Color.white.opacity(0.09)
    static let primary = Color(red: 0.36, green: 0.91, blue: 0.67)
    static let primarySoft = Color(red: 0.36, green: 0.91, blue: 0.67).opacity(0.13)
    static let text = Color(red: 0.94, green: 0.97, blue: 0.95)
    static let secondaryText = Color(red: 0.62, green: 0.70, blue: 0.66)
    static let warning = Color(red: 1.0, green: 0.70, blue: 0.31)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.38)
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 20
    var elevated = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(elevated ? AppTheme.elevated : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func storageCard(padding: CGFloat = 20, elevated: Bool = false) -> some View {
        modifier(CardStyle(padding: padding, elevated: elevated))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(red: 0.02, green: 0.10, blue: 0.075))
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(AppTheme.primary.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(AppTheme.danger.opacity(configuration.isPressed ? 0.72 : 0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
