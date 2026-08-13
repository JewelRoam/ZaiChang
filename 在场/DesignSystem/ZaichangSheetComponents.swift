import SwiftUI

// MARK: - Sheet Actions

struct PanelButton: View {
    let title: String
    let symbol: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .adaptiveFullWidthHitTarget(minHeight: 38)
                .foregroundStyle(isProminent ? Color(red: 0.17, green: 0.13, blue: 0.09) : Palette.ink)
                .background(isProminent ? Palette.amber : Palette.surface3)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isProminent ? Palette.amber : Color.white.opacity(0.16)))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(ZaichangPlainButtonStyle())
    }
}

// MARK: - Sheet Container

struct SheetContainer<Content: View>: View {
    let eyebrow: String
    let title: String
    let dismiss: DismissAction
    let maxWidth: CGFloat
    @ViewBuilder let content: Content

    init(eyebrow: String, title: String, dismiss: DismissAction, maxWidth: CGFloat = LayoutMetrics.sheetMaxWidth, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.dismiss = dismiss
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        Group {
#if os(iOS)
            ScrollView {
                sheetContent
            }
            .scrollBounceBehavior(.basedOnSize)
#else
            sheetContent
#endif
        }
        .adaptiveSheetFrame(maxWidth: maxWidth)
        .background(Palette.surface2)
        .foregroundStyle(Palette.ink)
        .adaptiveSheetPresentation()
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow).eyebrowStyle()
                    Text(title).font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .adaptiveHitTarget(minWidth: 32, minHeight: 32)
                }
                .buttonStyle(ZaichangPlainButtonStyle())
            }
            .padding(.bottom, 22)
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
