import SwiftUI

enum Palette {
    static let ink = Color(red: 0.97, green: 0.94, blue: 0.90)
    static let muted = Color(red: 0.67, green: 0.65, blue: 0.62)
    static let surface = Color(red: 0.09, green: 0.10, blue: 0.12)
    static let surface2 = Color(red: 0.12, green: 0.13, blue: 0.15)
    static let surface3 = Color(red: 0.16, green: 0.17, blue: 0.19)
    static let line = Color.white.opacity(0.10)
    static let amber = Color(red: 0.94, green: 0.70, blue: 0.36)
    static let amberSoft = Color(red: 1.00, green: 0.85, blue: 0.58)
    static let moss = Color(red: 0.50, green: 0.64, blue: 0.47)
    static let blue = Color(red: 0.47, green: 0.66, blue: 0.81)
}

enum LayoutMetrics {
    static let sidebarWidth: CGFloat = 72
    static let contextPanelWidth: CGFloat = 304
    static let windowDragHeight: CGFloat = 18
    static let sceneControlClearance: CGFloat = 84
    static let compactNavigationHeight: CGFloat = 64
    static let sheetMaxWidth: CGFloat = 520
}

enum InteractionMetrics {
#if os(iOS)
    static let minimumHitDimension: CGFloat = 44
#else
    static let minimumHitDimension: CGFloat = 32
#endif
}

struct ZaichangPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension View {
    func adaptiveHitTarget(
        minWidth: CGFloat = 0,
        minHeight: CGFloat = 0
    ) -> some View {
        frame(
            minWidth: max(minWidth, InteractionMetrics.minimumHitDimension),
            minHeight: max(minHeight, InteractionMetrics.minimumHitDimension)
        )
        .contentShape(Rectangle())
    }

    func adaptiveFullWidthHitTarget(minHeight: CGFloat = 0) -> some View {
        frame(
            maxWidth: .infinity,
            minHeight: max(minHeight, InteractionMetrics.minimumHitDimension)
        )
        .contentShape(Rectangle())
    }

    func liquidSceneControl() -> some View {
        background(Palette.surface2.opacity(0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.16)))
    }

    func adaptiveGlassSurface(cornerRadius: CGFloat = 12) -> some View {
        background(Palette.surface2.opacity(0.94), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Color.white.opacity(0.16)))
    }

    func panelDivider() -> some View {
        overlay(alignment: .bottom) { Divider().overlay(Palette.line) }
    }

    func eyebrowStyle() -> some View {
        font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Palette.amberSoft)
            .textCase(.uppercase)
    }

    @ViewBuilder
    func adaptiveSheetFrame(maxWidth: CGFloat = LayoutMetrics.sheetMaxWidth) -> some View {
#if os(macOS)
        frame(width: maxWidth)
#else
        frame(maxWidth: maxWidth)
#endif
    }

    @ViewBuilder
    func adaptiveSheetPresentation() -> some View {
#if os(iOS)
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.surface2)
#else
        self
#endif
    }
}
