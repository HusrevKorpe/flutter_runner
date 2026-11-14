import AppKit
import SwiftUI

/// Accent palettes the user can pick in Settings.
enum AppTheme: String, CaseIterable, Identifiable {
    case flutter, forest, sunset, grape, graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flutter: "Flutter"
        case .forest: "Orman"
        case .sunset: "Gün Batımı"
        case .grape: "Üzüm"
        case .graphite: "Grafit"
        }
    }

    /// Main accent: Run button, selection, highlights.
    var accent: Color {
        switch self {
        case .flutter: Color(hex: 0x0A7CFF)
        case .forest: Color(hex: 0x0E9F6E)
        case .sunset: Color(hex: 0xF0435A)
        case .grape: Color(hex: 0x7C4DFF)
        case .graphite: Color(hex: 0x4B5563)
        }
    }

    /// Second gradient stop paired with `accent`.
    var accentEnd: Color {
        switch self {
        case .flutter: Color(hex: 0x22C3FF)
        case .forest: Color(hex: 0x3DD68C)
        case .sunset: Color(hex: 0xFF9A3D)
        case .grape: Color(hex: 0xD06BFF)
        case .graphite: Color(hex: 0x9CA3AF)
        }
    }

    /// Hot reload colour; picked to sit well next to the accent.
    var reload: Color {
        switch self {
        case .flutter: Color(hex: 0xFFB020)
        case .forest: Color(hex: 0xF5A524)
        case .sunset: Color(hex: 0xF5B400)
        case .grape: Color(hex: 0xFF6FB1)
        case .graphite: Color(hex: 0xF59E0B)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistem"
        case .light: "Açık"
        case .dark: "Koyu"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let stop = Color(hex: 0xEF4444)
    static let live = Color(hex: 0x22C55E)
}

// MARK: - Reusable styling

/// Compact action button. `.primary` is a solid accent fill; `.plain` is a quiet
/// neutral button whose icon carries the colour.
struct ActionButtonStyle: ButtonStyle {
    enum Kind { case primary(Color), plain(Color) }

    var kind: Kind
    var height: CGFloat = 26
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .labelStyle(ActionLabelStyle(iconColor: iconColor))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 8)
            .background(background(pressed: configuration.isPressed),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.primary.opacity(isPrimary ? 0 : 0.08), lineWidth: 0.5)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var isPrimary: Bool {
        if case .primary = kind { return true }
        return false
    }

    private var iconColor: Color {
        switch kind {
        case .primary: .white
        case let .plain(color): isEnabled ? color : .secondary
        }
    }

    private var textColor: Color {
        isPrimary ? .white : .primary
    }

    private func background(pressed: Bool) -> AnyShapeStyle {
        let hover = isEnabled && isHovering
        switch kind {
        case let .primary(color):
            return AnyShapeStyle(color.opacity(pressed ? 0.8 : hover ? 0.92 : 1))
        case .plain:
            return AnyShapeStyle(.primary.opacity(pressed ? 0.12 : hover ? 0.09 : 0.055))
        }
    }
}

private struct ActionLabelStyle: LabelStyle {
    let iconColor: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(iconColor)
            configuration.title.lineLimit(1)
        }
    }
}

/// Rounded, subtly filled container.
struct Card<Content: View>: View {
    var padding: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07), lineWidth: 0.5)
            }
    }
}

/// The gradient app glyph shown in headers.
struct AppGlyph: View {
    let theme: AppTheme
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(theme.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.42, weight: .heavy))
                    .foregroundStyle(.white)
                    .offset(x: size * 0.03)
            }
            .shadow(color: theme.accent.opacity(0.25), radius: 2, y: 1)
    }
}

/// Coloured capsule describing the run state.
struct StatusPill: View {
    let viewModel: RunnerViewModel
    let theme: AppTheme

    private var color: Color {
        if viewModel.isBooting { return theme.reload }
        switch viewModel.status {
        case .idle: return .secondary
        case .running: return .live
        case .launching, .reloading, .restarting: return theme.reload
        case .stopping: return .stop
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // A static dot on purpose: a repeating animation keeps redrawing the
            // (hidden) menu bar window and costs ~10% CPU for as long as it runs.
            Circle().fill(color).frame(width: 6, height: 6)
            Text(viewModel.isBooting ? "Cihaz açılıyor…" : viewModel.status.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.status == .idle && !viewModel.isBooting ? .secondary : color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1), in: Capsule())
        .fixedSize()
        .animation(.easeInOut(duration: 0.2), value: viewModel.status)
    }
}

extension LogLine.Level {
    func color(theme: AppTheme) -> Color {
        switch self {
        case .info: .primary
        case .progress: .secondary
        case .error: .stop
        case .system: theme.accent
        }
    }
}
