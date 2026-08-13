import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

struct DeskPetSection: View {
    @ObservedObject var controller: DeskPetController
    let partner: DeskPartner?
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("好友桌宠")
                        .font(.system(size: 13, weight: .semibold))
                    Text("用同桌的照片，生成一个陪你留在桌边的小形象。")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                if controller.partnerProfile != nil {
                    let editingPartner = partner ?? DeskPartner.ahe
                    DeskPetPhotoPicker(selection: $photoItem) { data in
                        controller.selectPhoto(data, for: editingPartner)
                    } label: {
                        Label("更换好友形象", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .adaptiveHitTarget(minHeight: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("更换好友桌宠形象")
                } else {
                    Image(systemName: "person.crop.square")
                        .foregroundStyle(Palette.amber)
                }
            }

            let editingPartner = partner ?? DeskPartner.ahe
            content(for: editingPartner)
                .onAppear {
                    guard partner != nil else { return }
                    Task { @MainActor in controller.prepare(for: editingPartner) }
                }
                .onChange(of: partner?.id) { _, _ in
                    guard partner != nil else { return }
                    Task { @MainActor in controller.prepare(for: editingPartner) }
                }
                .opacity(partner == nil && controller.partnerProfile == nil ? 0.55 : 1)
                .overlay(alignment: .topLeading) {
                    if partner == nil {
                        Label("同桌加入后可生成新的好友桌宠", systemImage: "person.badge.clock")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.muted)
                            .padding(.top, -2)
                    }
                }
        }
        .padding(.vertical, 18)
        .panelDivider()
    }

    @ViewBuilder
    private func content(for partner: DeskPartner) -> some View {
        switch controller.state {
        case .idle, .failed:
            DeskPetPhotoPicker(selection: $photoItem) { data in
                controller.selectPhoto(data, for: partner)
            } label: {
                Label("选择好友照片", systemImage: "photo.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                    .adaptiveFullWidthHitTarget(minHeight: 38)
                    .foregroundStyle(Palette.ink)
                    .background(Palette.surface3)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.16)))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(ZaichangPlainButtonStyle())

            if case let .failed(message) = controller.state {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.90, green: 0.52, blue: 0.46))
            }
        case .photoSelected:
            HStack(spacing: 10) {
                if let data = controller.selectedPhotoData {
                    DeskPetImage(data: data)
                        .frame(width: 54, height: 54)
                        .background(Palette.surface3)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("照片已经准备好").font(.system(size: 11, weight: .semibold))
                    Text("下一步会生成桌宠预览，并自动处理为透明背景。")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("生成", action: controller.generate)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.amber)
            }
        case .generating:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small).tint(Palette.amber)
                VStack(alignment: .leading, spacing: 3) {
                    Text("正在生成桌宠").font(.system(size: 11, weight: .semibold))
                    Text("会保留好友的发型、配色和识别特征。")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .ready:
            if let profile = controller.activePartnerProfile {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                    DeskPetImage(data: profile.generatedImageData)
                        .frame(width: 64, height: 64)
                        .background(Palette.surface3)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(profile.partnerName)的桌宠预览")
                            .font(.system(size: 11, weight: .semibold))
                        Text("桌宠已经生成，可以放到当前场景里。")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(2)
                    }
                        Spacer(minLength: 4)
                    }

                }
            }
        }
    }
}

/// Provides one photo entry point while keeping platform-native sources behind it.
struct DeskPetPhotoPicker<Content: View>: View {
    @Binding var selection: PhotosPickerItem?
    let onData: (Data) -> Void
    @ViewBuilder let label: () -> Content

    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false

    var body: some View {
        Menu {
            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("从照片图库选择", systemImage: "photo.on.rectangle")
            }

            Button {
                presentFilePicker()
            } label: {
                Label(filePickerTitle, systemImage: "folder")
            }
        }
        label: {
            label()
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selection,
            matching: .images,
            preferredItemEncoding: .automatic
        )
        .onChange(of: selection) { _, item in
            loadPhoto(item)
        }
#if !os(macOS)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result,
                  let url = urls.first else { return }
            loadFile(url)
        }
#endif
    }

    private var filePickerTitle: String {
#if os(macOS)
        "从 Finder 选择照片"
#else
        "从文件中选择照片"
#endif
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                selection = nil
                guard let data, !data.isEmpty else { return }
                onData(data)
            }
        }
    }

    private func loadFile(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return }
        onData(data)
    }

    private func presentFilePicker() {
#if os(macOS)
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.image]

            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                panel.beginSheetModal(for: window) { response in
                    guard response == .OK, let url = panel.url else { return }
                    self.loadFile(url)
                }
            } else {
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    self.loadFile(url)
                }
            }
        }
#else
        isFileImporterPresented = true
#endif
    }
}

struct DeskPetOverlay: View {
    @ObservedObject var controller: DeskPetController
    let profile: DeskPetProfile
    let onDoubleTap: () -> Void
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.22
            let clampedSize = min(max(size, 80), 200)
            let half = clampedSize / 2
            let defaultPos = CGPoint(
                x: geo.size.width - half - 22,
                y: geo.size.height - half - 84
            )
            let basePos = controller.partnerScenePosition ?? defaultPos
            let currentPos = CGPoint(
                x: basePos.x + dragOffset.width,
                y: basePos.y + dragOffset.height
            )

            InteractiveDeskPetView(
                controller: controller,
                profile: profile,
                size: clampedSize,
                onDoubleTap: onDoubleTap,
                autonomousJump: true,
                isDragging: dragOffset != .zero
            )
            .position(currentPos)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let newX = min(max(basePos.x + value.translation.width, half), geo.size.width - half)
                        let newY = min(max(basePos.y + value.translation.height, half), geo.size.height - half)
                        controller.movePartnerPet(to: CGPoint(x: newX, y: newY))
                    }
            )
        }
    }
}

struct DeskPetPairOverlay: View {
    @ObservedObject var controller: DeskPetController
    let partnerProfile: DeskPetProfile?
    let partnerName: String?
    let onPartnerDoubleTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let petSize = min(max(min(geo.size.width, geo.size.height) * 0.20, 76), 176)
            HStack(alignment: .bottom, spacing: max(8, petSize * 0.10)) {
                BuiltInOwnDeskPetView(size: petSize)
                if let partnerProfile {
                    InteractiveDeskPetView(
                        controller: controller,
                        profile: partnerProfile,
                        size: petSize,
                        onDoubleTap: onPartnerDoubleTap,
                        autonomousJump: true
                    )
                } else if let partnerName {
                    PartnerDeskPetPlaceholder(name: partnerName, size: petSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .onAppear { controller.updatePartnerPetSize(petSize) }
            .onChange(of: petSize) { _, newValue in controller.updatePartnerPetSize(newValue) }
        }
    }
}

private struct BuiltInOwnDeskPetView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let data = Self.imageData {
                DeskPetImage(data: data)
            } else {
                PixelDeskPetSilhouette(
                    primary: Color(red: 0.86, green: 0.49, blue: 0.24),
                    secondary: Color(red: 0.98, green: 0.75, blue: 0.36),
                    size: size
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.34), radius: 8, y: 4)
        .autonomousJump(size: size)
        .accessibilityLabel("我的桌宠")
    }

    private static var imageData: Data? {
        guard let url = Bundle.main.url(forResource: "own-desk-pet", withExtension: "png") else { return nil }
        return try? Data(contentsOf: url)
    }
}

private struct PartnerDeskPetPlaceholder: View {
    let name: String
    let size: CGFloat

    var body: some View {
        PixelDeskPetSilhouette(
            primary: Color(red: 0.36, green: 0.52, blue: 0.42),
            secondary: Color(red: 0.68, green: 0.76, blue: 0.55),
            size: size
        )
        .autonomousJump(size: size)
        .accessibilityLabel("\(name)的默认桌宠")
    }
}

/// 让桌宠每隔 6~13 秒随机跳一跳。每个视图各自计时，互相独立。
private struct AutonomousJumpModifier: ViewModifier {
    let size: CGFloat
    @State private var jumpTrigger = 0

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: jumpTrigger) { view, offsetY in
                view.offset(y: offsetY)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(-size * 0.32, duration: 0.24, spring: .bouncy)
                    SpringKeyframe(0, duration: 0.32, spring: .bouncy)
                }
            }
            .task {
                while !Task.isCancelled {
                    let delay = 6.0 + Double.random(in: 0...7)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if Task.isCancelled { break }
                    jumpTrigger += 1
                }
            }
    }
}

extension View {
    func autonomousJump(size: CGFloat) -> some View {
        modifier(AutonomousJumpModifier(size: size))
    }
}

private struct PixelDeskPetSilhouette: View {
    let primary: Color
    let secondary: Color
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let unit = min(canvasSize.width, canvasSize.height) / 10
            let pixels: [(Int, Int, Color)] = [
                (2, 1, secondary), (7, 1, secondary),
                (2, 2, primary), (3, 2, primary), (6, 2, primary), (7, 2, primary),
                (1, 3, primary), (2, 3, primary), (3, 3, secondary), (4, 3, primary),
                (5, 3, primary), (6, 3, secondary), (7, 3, primary), (8, 3, primary),
                (1, 4, primary), (2, 4, primary), (3, 4, primary), (4, 4, secondary),
                (5, 4, secondary), (6, 4, primary), (7, 4, primary), (8, 4, primary),
                (2, 5, primary), (3, 5, secondary), (4, 5, primary),
                (5, 5, primary), (6, 5, secondary), (7, 5, primary),
                (3, 6, primary), (4, 6, primary), (5, 6, primary), (6, 6, primary),
                (3, 7, primary), (4, 7, secondary), (5, 7, secondary), (6, 7, primary),
                (2, 8, primary), (3, 8, primary), (6, 8, primary), (7, 8, primary)
            ]
            for (x, y, color) in pixels {
                context.fill(
                    Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit)),
                    with: .color(color)
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.34), radius: 8, y: 4)
    }
}

struct InteractiveDeskPetView: View {
    @ObservedObject var controller: DeskPetController
    let profile: DeskPetProfile
    let size: CGFloat
    let onDoubleTap: () -> Void
    var autonomousJump: Bool = false
    var isDragging: Bool = false
    @State private var sentAnimationTrigger = 0
    @State private var jumpTrigger = 0

    private var feedback: DeskPetNudgeFeedback? { controller.nudgeFeedback }

    var body: some View {
        ZStack(alignment: .top) {
            DeskPetImage(data: profile.generatedImageData)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .shadow(
                    color: feedback?.kind.animatesDeskPet == true ? Palette.amber.opacity(0.85) : .black.opacity(0.35),
                    radius: feedback?.kind.animatesDeskPet == true ? 14 : 8,
                    y: 4
                )
                .keyframeAnimator(
                    initialValue: DeskPetNudgeMotion(),
                    trigger: sentAnimationTrigger
                ) { content, motion in
                    content
                        .scaleEffect(motion.scale)
                        .rotationEffect(.degrees(motion.rotation))
                } keyframes: { _ in
                    KeyframeTrack(\.rotation) {
                        LinearKeyframe(-7, duration: 0.08)
                        LinearKeyframe(7, duration: 0.08)
                        LinearKeyframe(-6, duration: 0.08)
                        LinearKeyframe(6, duration: 0.08)
                        LinearKeyframe(-3, duration: 0.08)
                        LinearKeyframe(0, duration: 0.08)
                    }
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.07, duration: 0.16, spring: .snappy)
                        SpringKeyframe(1, duration: 0.32, spring: .smooth)
                    }
                }
                .keyframeAnimator(
                    initialValue: 0.0,
                    trigger: jumpTrigger
                ) { content, offsetY in
                    content.offset(y: offsetY)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(-size * 0.32, duration: 0.24, spring: .bouncy)
                        SpringKeyframe(0, duration: 0.32, spring: .bouncy)
                    }
                }
                .onTapGesture(count: 2, perform: onDoubleTap)

            if let feedback {
                Text(feedback.message)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.76))
                    .overlay(
                        Capsule().stroke(
                            feedback.kind.animatesDeskPet ? Palette.amber.opacity(0.8) : Color.white.opacity(0.2)
                        )
                    )
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.24, dampingFraction: 0.58), value: feedback?.id)
        .onChange(of: feedback?.id) { _, _ in
            guard feedback?.kind.animatesDeskPet == true else { return }
            sentAnimationTrigger += 1
        }
        .accessibilityLabel("\(profile.partnerName)的桌宠")
        .task(id: "\(autonomousJump)-\(isDragging)") {
            guard autonomousJump, !isDragging else { return }
            while !Task.isCancelled {
                // 每隔 6 ~ 13 秒随机跳一跳
                let delay = 6.0 + Double.random(in: 0...7)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { break }
                jumpTrigger += 1
            }
        }
    }
}

private struct DeskPetNudgeMotion {
    var rotation = 0.0
    var scale = 1.0
}

struct DeskPetImage: View {
    let data: Data

    var body: some View {
#if os(macOS)
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage).resizable().scaledToFit()
        } else {
            fallback
        }
#elseif os(iOS) || os(visionOS)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFit()
        } else {
            fallback
        }
#else
        fallback
#endif
    }

    private var fallback: some View {
        Image(systemName: "person.crop.square").foregroundStyle(Palette.muted)
    }
}
