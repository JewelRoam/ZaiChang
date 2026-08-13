import PhotosUI
import SwiftUI
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
                Image(systemName: "person.crop.square")
                    .foregroundStyle(Palette.amber)
            }

            if let partner {
                content(for: partner)
                    .onAppear { controller.prepare(for: partner) }
                    .onChange(of: partner.id) { _, _ in controller.prepare(for: partner) }
            } else {
                Label("等同桌加入后，再为对方生成桌宠。", systemImage: "person.badge.clock")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 18)
        .panelDivider()
    }

    @ViewBuilder
    private func content(for partner: DeskPartner) -> some View {
        switch controller.state {
        case .idle, .failed:
            PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .automatic) {
                Label("选择好友照片", systemImage: "photo.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                    .adaptiveFullWidthHitTarget(minHeight: 38)
                    .foregroundStyle(Palette.ink)
                    .background(Palette.surface3)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.16)))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .onChange(of: photoItem) { _, item in loadPhoto(item, partner: partner) }

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
            if let profile = controller.profile {
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
                    Button {
                        controller.setEnabled(!profile.isEnabled)
                    } label: {
                        Label(profile.isEnabled ? "移除" : "放到场景里", systemImage: profile.isEnabled ? "eye.slash" : "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                            .adaptiveHitTarget(minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(profile.isEnabled ? Palette.surface3 : Palette.amber)
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?, partner: DeskPartner) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else { return }
            await MainActor.run { controller.selectPhoto(data, for: partner) }
        }
    }
}

struct DeskPetOverlay: View {
    @ObservedObject var controller: DeskPetController
    let profile: DeskPetProfile
    let onDoubleTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.22
            let clampedSize = min(max(size, 80), 200)
            InteractiveDeskPetView(
                controller: controller,
                profile: profile,
                size: clampedSize,
                onDoubleTap: onDoubleTap
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

struct InteractiveDeskPetView: View {
    @ObservedObject var controller: DeskPetController
    let profile: DeskPetProfile
    let size: CGFloat
    let onDoubleTap: () -> Void
    @State private var sentAnimationTrigger = 0

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
