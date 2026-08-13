import SwiftUI

struct AppShellView: View {
    @ObservedObject var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            if usesCompactLayout(width: geometry.size.width) {
                compactShell
            } else {
                desktopShell
            }
        }
        .background(Palette.surface)
        .foregroundStyle(Palette.ink)
        .animation(.easeOut(duration: 0.18), value: model.toastMessage)
        .animation(.easeOut(duration: 0.18), value: model.activeSuggestion?.id)
#if os(macOS)
        .overlay(alignment: .top) {
            WindowDragRegion()
        }
#endif
        .sheet(item: $model.activeSheet) { sheet in
            switch sheet {
            case .desk:
                DeskSheet(model: model)
            case .voice:
                VoiceSheet(model: model, recorder: model.voiceRecorder, memory: model.memory)
            case .phonograph:
                PhonographSheet(model: model, memory: model.memory)
            case .memoryArchive:
                MemoryArchiveView(memory: model.memory)
            case .scenes:
                ScenePickerSheet(model: model)
            case .sceneWorkshop:
                SceneWorkshopSheet(model: model)
            case .context:
                ContextSheet(model: model, recorder: model.voiceRecorder)
            }
        }
    }

    private var desktopShell: some View {
        return ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                SidebarView(model: model)
                Divider().overlay(Palette.line)
                GeometryReader { _ in
                    SceneStageView(model: model, layout: .expanded)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: 0)
                Divider().overlay(Palette.line)
                ContextPanelView(model: model, recorder: model.voiceRecorder)
                    .frame(width: LayoutMetrics.contextPanelWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let toastMessage = model.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, LayoutMetrics.sceneControlClearance)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var compactShell: some View {
        ZStack(alignment: .bottom) {
            SceneStageView(
                model: model,
                layout: .compact,
                bottomInset: LayoutMetrics.compactNavigationHeight + 14
            )

            CompactNavigationBar(model: model)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if let toastMessage = model.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, LayoutMetrics.compactNavigationHeight + 76)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func usesCompactLayout(width: CGFloat) -> Bool {
#if os(macOS)
        false
#else
        horizontalSizeClass == .compact || width < 900
#endif
    }
}

// MARK: - Window Chrome

#if os(macOS)
private struct WindowDragRegion: View {
    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: LayoutMetrics.sidebarWidth)
                .allowsHitTesting(false)
            Color.clear
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
        }
        .frame(height: LayoutMetrics.windowDragHeight)
        .accessibilityHidden(true)
    }
}
#endif

// MARK: - Transient Feedback

private struct ToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle")
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 16)
            .frame(minHeight: 42)
            .background(Palette.surface2)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.16)))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
    }
}
