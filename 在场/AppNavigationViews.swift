import SwiftUI

struct CompactNavigationBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 2) {
            CompactNavigationButton(symbol: "house.fill", title: "在场", isActive: true) {}
            CompactNavigationButton(symbol: "person.2", title: "同桌") { model.activeSheet = .desk }
            CompactNavigationButton(symbol: "record.circle", title: "留声") { model.activeSheet = .voice }
            CompactNavigationButton(symbol: "chart.bar", title: "此刻") { model.activeSheet = .context }
            CompactNavigationButton(symbol: "photo.on.rectangle", title: "场景") { model.activeSheet = .scenes }
        }
        .padding(6)
        .frame(maxWidth: 520)
        .adaptiveGlassSurface(cornerRadius: 14)
    }
}

private struct CompactNavigationButton: View {
    let symbol: String
    let title: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(title).font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isActive ? Palette.amberSoft : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(ZaichangPlainButtonStyle())
        .accessibilityLabel(title)
    }
}

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 6) {
            SidebarButton(symbol: "house", title: "在场", isActive: true) {}
            SidebarButton(symbol: "person.2", title: "同桌") { model.activeSheet = .desk }
            SidebarButton(symbol: "record.circle", title: "留声") { model.activeSheet = .voice }
            SidebarButton(symbol: "book.closed", title: "记忆") { model.activeSheet = .memory }
            Spacer()
            SidebarButton(symbol: "photo.on.rectangle.angled", title: "场景") { model.activeSheet = .scenes }
        }
#if os(macOS)
        .padding(.top, 44)
#else
        .padding(.top, 14)
#endif
        .padding(.bottom, 14)
        .padding(.horizontal, 8)
        .frame(width: LayoutMetrics.sidebarWidth)
        .background(Color(red: 0.095, green: 0.102, blue: 0.115))
    }
}

private struct SidebarButton: View {
    let symbol: String
    let title: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isActive ? Palette.amberSoft : Color(red: 0.56, green: 0.57, blue: 0.59))
            .frame(width: 56, height: 52)
            .background(isActive ? Color(red: 0.18, green: 0.16, blue: 0.14) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(ZaichangPlainButtonStyle())
        .help(title)
    }
}
